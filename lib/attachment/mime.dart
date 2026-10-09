import '../core/chat_message.dart';

/// 由文件名推断 MIME 类型。聊天媒体的 MIME 单源,发送端与采集端共用。
String mimeFromFileName(String fileName) {
  final lower = fileName.toLowerCase();
  // 图片
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  // 视频
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.m4v')) return 'video/x-m4v';
  if (lower.endsWith('.3gp')) return 'video/3gpp';
  if (lower.endsWith('.avi')) return 'video/x-msvideo';
  if (lower.endsWith('.mkv')) return 'video/x-matroska';
  if (lower.endsWith('.webm')) return 'video/webm';
  // 音频
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.aac')) return 'audio/aac';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.ogg')) return 'audio/ogg';
  // 文件
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.txt')) return 'text/plain';
  return 'application/octet-stream';
}

/// 由外部文件 MIME 判定聊天消息类型:image / video / 其余为 file。
/// `audio` 只允许由按住说话录音入口显式创建，设备音频文件仍作为通用文件发送。
ChatMessageKind mediaKindFromMime(String mime) {
  if (mime.startsWith('image/')) return ChatMessageKind.image;
  if (mime.startsWith('video/')) return ChatMessageKind.video;
  return ChatMessageKind.file;
}
