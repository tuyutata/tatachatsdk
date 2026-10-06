package chat.tata.sdk;

import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Matrix;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.UserManager;
import android.system.Os;
import android.provider.OpenableColumns;
import android.webkit.MimeTypeMap;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Pattern;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/** TataChatSDK自有的单文件选择与视频探测，不承载宿主业务。 */
public final class TataChatSdkPlugin implements FlutterPlugin, ActivityAware,
        MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {
    private static final String CHANNEL = "chat.tata.sdk/attachment";
    private static final int PICK_FILE_REQUEST = 41702;
    private static final long MAX_SELECTED_BYTES = 512L * 1024L * 1024L;
    private static final int THUMBNAIL_EDGE = 64;
    private static final int MAX_THUMBNAIL_BYTES = 256 * 1024;
    private static final Pattern MIME = Pattern.compile(
        "^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$");

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private ExecutorService worker;
    private MethodChannel channel;
    private MethodChannel securityChannel;
    private Context applicationContext;
    private Activity activity;
    private ActivityPluginBinding activityBinding;
    private MethodChannel.Result pendingPicker;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();
        worker = Executors.newSingleThreadExecutor();
        worker.execute(() -> clearStagedFiles(applicationContext));
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
        securityChannel = new MethodChannel(binding.getBinaryMessenger(), "tatachat_sdk/security");
        securityChannel.setMethodCallHandler((call, result) -> {
            if ("eraseMlsStorage".equals(call.method)) {
                try { eraseMlsStorage(call); result.success(null); }
                catch (Exception error) { result.error("mls_storage_unavailable", "MLS安全存储清理失败", null); }
                return;
            }
            if (!"prepareMlsStorage".equals(call.method)) { result.notImplemented(); return; }
            try { result.success(prepareMlsStorage(call)); }
            catch (Exception error) { result.error("mls_storage_unavailable", "MLS安全存储不可用", null); }
        });
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        failPendingPicker("picker_detached", "文件选择生命周期已结束");
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        if (worker != null) {
            worker.shutdownNow();
            worker = null;
        }
        if (securityChannel != null) { securityChannel.setMethodCallHandler(null); securityChannel = null; }
        applicationContext = null;
    }

    /** 只删除SDK自有目录，不读取或清空宿主安全存储。 */
    private void eraseMlsStorage(MethodCall call) throws Exception {
        Context context = applicationContext;
        if (context == null || context.isDeviceProtectedStorage()) throw new IOException("storage unavailable");
        UserManager users = (UserManager) context.getSystemService(Context.USER_SERVICE);
        if (users == null || !users.isUserUnlocked()) throw new IOException("storage locked");
        File target = new File(context.getNoBackupFilesDir().getCanonicalFile(), "tatachat_sdk_mls");
        if (call.hasArgument("user_id")) {
            String user = call.argument("user_id");
            if (user == null || user.trim().isEmpty() || user.contains(":")) throw new IOException("invalid owner");
            byte[] bytes = user.getBytes(StandardCharsets.UTF_8);
            if (bytes.length > 120) throw new IOException("invalid owner length");
            StringBuilder name = new StringBuilder();
            for (byte value : bytes) name.append(String.format(Locale.ROOT, "%02x", value & 255));
            target = new File(target, name.toString());
        }
        eraseOwnedMlsDirectory(target);
    }
    private static void eraseOwnedMlsDirectory(File directory) throws IOException {
        if (!directory.getCanonicalPath().equals(directory.getAbsolutePath())) throw new IOException("symlink");
        if (!directory.exists()) return;
        if (directory.isDirectory()) {
            File[] entries = directory.listFiles();
            if (entries == null) throw new IOException("list failed");
            for (File entry : entries) eraseOwnedMlsDirectory(entry);
        }
        if (!directory.delete() || directory.exists()) throw new IOException("erase failed");
    }

    /** 默认凭据加密非备份区域；不创建KeyStore包装钥，不要求逐次生物识别。 */
    private Map<String, Object> prepareMlsStorage(MethodCall call) throws Exception {
        Context context = applicationContext;
        if (context == null || context.isDeviceProtectedStorage()) throw new IOException("storage unavailable");
        UserManager users = (UserManager) context.getSystemService(Context.USER_SERVICE);
        if (users == null || !users.isUserUnlocked()) throw new IOException("storage locked");
        String user = call.argument("user_id");
        if (user == null || user.trim().isEmpty() || user.contains(":")) throw new IOException("invalid owner");
        byte[] bytes = user.getBytes(StandardCharsets.UTF_8);
        if (bytes.length > 120) throw new IOException("invalid owner length");
        StringBuilder name = new StringBuilder();
        for (byte value : bytes) name.append(String.format(Locale.ROOT, "%02x", value & 255));
        // 规范系统提供的容器别名；SDK子目录仍须逐项拒绝符号链接。
        File root = new File(context.getNoBackupFilesDir().getCanonicalFile(), "tatachat_sdk_mls");
        File target = new File(root, name.toString());
        boolean created = !target.exists();
        for (File directory : new File[]{root, target}) {
            if (!directory.getCanonicalPath().equals(directory.getAbsolutePath())) throw new IOException("symlink");
            if (!directory.exists() && !directory.mkdir()) throw new IOException("mkdir failed");
            if (!directory.isDirectory()) throw new IOException("not directory");
            Os.chmod(directory.getAbsolutePath(), 0700);
            if ((Os.stat(directory.getAbsolutePath()).st_mode & 0777) != 0700) throw new IOException("permissions failed");
        }
        Map<String, Object> result = new HashMap<>();
        result.put("path", target.getCanonicalPath()); result.put("created", created);
        return result;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activity = binding.getActivity();
        activityBinding = binding;
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        detachActivity(false);
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        detachActivity(true);
    }

    private void detachActivity(boolean terminal) {
        if (activityBinding != null) {
            activityBinding.removeActivityResultListener(this);
            activityBinding = null;
        }
        activity = null;
        if (terminal) failPendingPicker("picker_detached", "文件选择页面已关闭");
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "pickFile":
                pickFile(result);
                return;
            case "probeVideo":
                probeVideo(call, result);
                return;
            default:
                result.notImplemented();
        }
    }

    private void probeVideo(MethodCall call, MethodChannel.Result result) {
        final String path = call.argument("path");
        final ExecutorService current = worker;
        if (path == null || current == null) {
            result.error("invalid_video", "视频探测参数无效", null);
            return;
        }
        current.execute(() -> {
            try {
                final Map<String, Object> value = probeVideo(path);
                mainHandler.post(() -> result.success(value));
            } catch (Exception error) {
                // 路径和系统错误不返回Dart或日志，只保留可处理的固定失败。
                mainHandler.post(() -> result.error(
                    "video_probe_failed", "无法读取视频媒体", null));
            }
        });
    }

    private void pickFile(MethodChannel.Result result) {
        if (pendingPicker != null) {
            result.error("picker_busy", "已有文件选择正在进行", null);
            return;
        }
        final Activity current = activity;
        if (current == null || applicationContext == null || worker == null) {
            result.error("picker_unavailable", "文件选择页面不可用", null);
            return;
        }
        final Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
            .putExtra(Intent.EXTRA_ALLOW_MULTIPLE, false);
        pendingPicker = result;
        try {
            current.startActivityForResult(intent, PICK_FILE_REQUEST);
        } catch (RuntimeException error) {
            pendingPicker = null;
            result.error("picker_unavailable", "无法打开系统文件选择", null);
        }
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != PICK_FILE_REQUEST) return false;
        final MethodChannel.Result pending = pendingPicker;
        if (pending == null) return true;
        if (resultCode != Activity.RESULT_OK) {
            pendingPicker = null;
            pending.success(null);
            return true;
        }
        final Uri uri = data == null ? null : data.getData();
        final Context context = applicationContext;
        final ExecutorService current = worker;
        if (uri == null || context == null || current == null) {
            pendingPicker = null;
            pending.error("picker_invalid", "系统没有返回可读取文件", null);
            return true;
        }
        current.execute(() -> {
            Map<String, Object> staged = null;
            try {
                staged = stageSelectedFile(context, uri);
                final Map<String, Object> value = staged;
                mainHandler.post(() -> finishPicker(pending, value, null, null));
            } catch (Exception error) {
                deleteStaged(staged);
                mainHandler.post(() -> finishPicker(
                    pending, null, "picker_copy_failed", "无法读取所选文件"));
            }
        });
        return true;
    }

    private void finishPicker(MethodChannel.Result expected, Map<String, Object> value,
            String code, String message) {
        if (pendingPicker != expected) {
            deleteStaged(value);
            return;
        }
        pendingPicker = null;
        if (code == null) expected.success(value);
        else expected.error(code, message, null);
    }

    private void failPendingPicker(String code, String message) {
        final MethodChannel.Result pending = pendingPicker;
        pendingPicker = null;
        if (pending != null) pending.error(code, message, null);
    }

    private static Map<String, Object> stageSelectedFile(Context context, Uri uri)
            throws IOException {
        if (!ContentResolver.SCHEME_CONTENT.equals(uri.getScheme())) {
            throw new IOException("unsupported uri");
        }
        final ContentResolver resolver = context.getContentResolver();
        String fileName = null;
        Long reportedSize = null;
        try (Cursor cursor = resolver.query(uri,
                new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE},
                null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) {
                final int nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                final int sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE);
                if (nameIndex >= 0 && !cursor.isNull(nameIndex)) fileName = cursor.getString(nameIndex);
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) reportedSize = cursor.getLong(sizeIndex);
            }
        }
        if (reportedSize != null && (reportedSize < 0 || reportedSize > MAX_SELECTED_BYTES)) {
            throw new IOException("file too large");
        }
        fileName = safeFileName(fileName);
        String mime = resolver.getType(uri);
        if (mime != null) mime = mime.toLowerCase(Locale.ROOT);
        if (mime == null || !MIME.matcher(mime).matches()) {
            final String extension = extension(fileName);
            final String inferred = extension.isEmpty()
                ? null : MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension.substring(1));
            mime = inferred == null ? "application/octet-stream" : inferred.toLowerCase(Locale.ROOT);
        }

        final File directory = new File(context.getCacheDir(), "tatachat_picker");
        if ((!directory.isDirectory() && !directory.mkdirs()) || !directory.getCanonicalPath()
                .startsWith(context.getCacheDir().getCanonicalPath() + File.separator)) {
            throw new IOException("invalid cache directory");
        }
        final File destination = new File(directory,
            UUID.randomUUID().toString().toLowerCase(Locale.ROOT) + extension(fileName));
        if (!destination.getCanonicalFile().getParentFile().equals(directory.getCanonicalFile())) {
            throw new IOException("invalid destination");
        }
        long total = 0;
        try (InputStream input = resolver.openInputStream(uri);
             FileOutputStream output = new FileOutputStream(destination, false)) {
            if (input == null) throw new IOException("missing input");
            final byte[] buffer = new byte[64 * 1024];
            int count;
            while ((count = input.read(buffer)) != -1) {
                if (Thread.currentThread().isInterrupted() || total + count > MAX_SELECTED_BYTES) {
                    throw new IOException("copy interrupted or too large");
                }
                output.write(buffer, 0, count);
                total += count;
            }
            output.flush();
            output.getFD().sync();
        } catch (IOException error) {
            destination.delete();
            throw error;
        }
        final Map<String, Object> value = new HashMap<>();
        value.put("path", destination.getCanonicalPath());
        value.put("file_name", fileName);
        value.put("mime", mime);
        return value;
    }

    private static String safeFileName(String source) {
        String value = source == null ? "" : source.trim()
            .replaceAll("/", "_").replaceAll("\\\\", "_");
        final StringBuilder clean = new StringBuilder();
        value.codePoints().filter(point -> point >= 32 && point != 127)
            .forEach(clean::appendCodePoint);
        value = clean.toString();
        if (value.isEmpty() || value.getBytes(StandardCharsets.UTF_8).length > 255) {
            value = "attachment" + extension(value);
        }
        return value;
    }

    private static String extension(String fileName) {
        final int dot = fileName.lastIndexOf('.');
        if (dot <= 0 || dot == fileName.length() - 1) return "";
        final String value = fileName.substring(dot).toLowerCase(Locale.ROOT);
        return value.matches("\\.[a-z0-9]{1,16}") ? value : "";
    }

    private static void deleteStaged(Map<String, Object> value) {
        if (value == null || !(value.get("path") instanceof String)) return;
        new File((String) value.get("path")).delete();
    }

    private static void clearStagedFiles(Context context) {
        if (context == null) return;
        try {
            final File directory = new File(context.getCacheDir(), "tatachat_picker");
            final File canonical = directory.getCanonicalFile();
            final File[] children = directory.listFiles();
            if (children == null) return;
            for (File child : children) {
                if (child.isFile() && child.getCanonicalFile().getParentFile().equals(canonical)) {
                    child.delete();
                }
            }
        } catch (IOException ignored) {
            // 临时目录清扫失败不得扩大删除范围；本轮选择仍使用随机新文件名。
        }
    }

    private static Map<String, Object> probeVideo(String path) throws IOException {
        if (path.length() > 4096 || path.indexOf('\0') >= 0) {
            throw new IOException("invalid path");
        }
        final File file = new File(path);
        if (!file.isAbsolute() || !file.isFile()) {
            throw new IOException("unreadable file");
        }

        final MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        try {
            retriever.setDataSource(file.getCanonicalPath());
            final Integer sourceWidth = positiveMetadata(
                retriever, MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH);
            final Integer sourceHeight = positiveMetadata(
                retriever, MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT);
            final Integer duration = positiveMetadata(
                retriever, MediaMetadataRetriever.METADATA_KEY_DURATION);
            final Integer rotation = positiveOrZeroMetadata(
                retriever, MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION);

            final boolean swapsAxes = rotation != null && (rotation == 90 || rotation == 270);
            final Map<String, Object> value = new HashMap<>();
            if (sourceWidth != null && sourceHeight != null) {
                value.put("width", swapsAxes ? sourceHeight : sourceWidth);
                value.put("height", swapsAxes ? sourceWidth : sourceHeight);
                final byte[] thumbnail = thumbnail(
                    retriever, sourceWidth, sourceHeight, rotation == null ? 0 : rotation);
                if (thumbnail != null) value.put("thumbnail_bytes", thumbnail);
            }
            if (duration != null) value.put("duration_ms", duration);
            return value;
        } finally {
            retriever.release();
        }
    }

    private static Integer positiveMetadata(MediaMetadataRetriever retriever, int key) {
        final Integer value = integerMetadata(retriever, key);
        return value != null && value > 0 ? value : null;
    }

    private static Integer positiveOrZeroMetadata(MediaMetadataRetriever retriever, int key) {
        final Integer value = integerMetadata(retriever, key);
        return value != null && value >= 0 ? value : null;
    }

    private static Integer integerMetadata(MediaMetadataRetriever retriever, int key) {
        final String raw = retriever.extractMetadata(key);
        if (raw == null) return null;
        try {
            final long value = Long.parseLong(raw);
            return value <= Integer.MAX_VALUE ? (int) value : null;
        } catch (NumberFormatException ignored) {
            return null;
        }
    }

    private static byte[] thumbnail(
            MediaMetadataRetriever retriever, int width, int height, int rotation) {
        // API 27以前只能先解码整帧；为避免4K/8K媒体放大内存，宁可不产生blurhash。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1 || width <= 0 || height <= 0) {
            return null;
        }
        final double scale = Math.min(1.0, (double) THUMBNAIL_EDGE / Math.max(width, height));
        final int targetWidth = Math.max(1, (int) Math.round(width * scale));
        final int targetHeight = Math.max(1, (int) Math.round(height * scale));
        Bitmap frame = retriever.getScaledFrameAtTime(
            0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC, targetWidth, targetHeight);
        if (frame == null) return null;
        try {
            if (rotation == 90 || rotation == 180 || rotation == 270) {
                final Matrix matrix = new Matrix();
                matrix.postRotate(rotation);
                final Bitmap rotated = Bitmap.createBitmap(
                    frame, 0, 0, frame.getWidth(), frame.getHeight(), matrix, true);
                if (rotated != frame) {
                    frame.recycle();
                    frame = rotated;
                }
            }
            final ByteArrayOutputStream output = new ByteArrayOutputStream();
            if (!frame.compress(Bitmap.CompressFormat.JPEG, 60, output)) return null;
            final byte[] bytes = output.toByteArray();
            return bytes.length > 0 && bytes.length <= MAX_THUMBNAIL_BYTES ? bytes : null;
        } finally {
            frame.recycle();
        }
    }
}
