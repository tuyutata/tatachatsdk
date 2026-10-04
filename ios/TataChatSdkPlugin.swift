import AVFoundation
import Flutter
import UIKit
import UniformTypeIdentifiers

/// TataChatSDK自有的附件处理与聊天存储备份排除，不承载宿主业务。
public final class TataChatSdkPlugin: NSObject, FlutterPlugin,
  UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate
{
  private static let channel = "chat.tata.sdk/attachment"
  private static let maximumSelectedBytes: Int64 = 512 * 1024 * 1024
  private static let maximumPathLength = 4096
  private static let maximumThumbnailBytes = 256 * 1024
  private weak var viewController: UIViewController?
  private var pendingPicker: (id: UUID, result: FlutterResult)?
  private var pickerCopying = false

  private init(viewController: UIViewController?) {
    self.viewController = viewController
    super.init()
    Self.clearStagedFiles()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: Self.channel, binaryMessenger: registrar.messenger())
    let plugin = TataChatSdkPlugin(viewController: registrar.viewController)
    registrar.addMethodCallDelegate(plugin, channel: methodChannel)
    // 聊天数据安全归SDK；宿主无需注册或复制聊天数据库备份排除方法。
    let securityChannel = FlutterMethodChannel(
      name: "tatachat_sdk/security", binaryMessenger: registrar.messenger())
    securityChannel.setMethodCallHandler { call, result in
      guard call.method == "excludeChatDataFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        try Self.excludeChatDataFromBackup()
        result(nil)
      } catch {
        result(FlutterError(
          code: "chat_backup_exclusion_failed", message: "聊天数据备份排除失败", details: nil))
      }
    }
  }

  /// 只处理SDK拥有的聊天路径；设置后回读属性，不能以调用成功替代安全结果。
  private static func excludeChatDataFromBackup() throws {
    let manager = FileManager.default
    guard let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
          let documents = manager.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw CocoaError(.fileNoSuchFile)
    }
    let files = try manager.contentsOfDirectory(
      at: support, includingPropertiesForKeys: [.isSymbolicLinkKey])
    var paths = files.filter {
      $0.lastPathComponent == "tatachat_sdk_chat.isar" ||
        $0.lastPathComponent.hasPrefix("tatachat_sdk_chat.isar.")
    }
    guard !paths.isEmpty else { throw CocoaError(.fileNoSuchFile) }
    let attachments = documents.appendingPathComponent("chat", isDirectory: true)
    if manager.fileExists(atPath: attachments.path) { paths.append(attachments) }
    for var path in paths {
      let resource = try path.resourceValues(forKeys: [.isSymbolicLinkKey])
      guard resource.isSymbolicLink != true else { throw CocoaError(.fileReadInvalidFileName) }
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try path.setResourceValues(values)
      guard try path.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else {
        throw CocoaError(.fileWriteUnknown)
      }
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickFile":
      DispatchQueue.main.async { self.pickFile(result) }
    case "probeVideo":
      probeVideo(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func probeVideo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String,
          path.utf8.count <= Self.maximumPathLength,
          !path.utf8.contains(0),
          path.hasPrefix("/") else {
      result(FlutterError(code: "invalid_video", message: "视频探测参数无效", details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let value = try Self.probeVideo(path)
        DispatchQueue.main.async { result(value) }
      } catch {
        // 不回传真实路径、AVFoundation详情或其它可识别设备数据。
        DispatchQueue.main.async {
          result(FlutterError(
            code: "video_probe_failed", message: "无法读取视频媒体", details: nil))
        }
      }
    }
  }

  private func pickFile(_ result: @escaping FlutterResult) {
    guard pendingPicker == nil else {
      result(FlutterError(code: "picker_busy", message: "已有文件选择正在进行", details: nil))
      return
    }
    guard let presenter = topViewController(), presenter.viewIfLoaded?.window != nil else {
      result(FlutterError(code: "picker_unavailable", message: "文件选择页面不可用", details: nil))
      return
    }
    let id = UUID()
    pendingPicker = (id, result)
    pickerCopying = false
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: [.data], asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
    picker.presentationController?.delegate = self
  }

  public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishPicker(value: nil)
  }

  public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    if !pickerCopying { finishPicker(value: nil) }
  }

  public func documentPicker(
    _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
  ) {
    guard urls.count == 1, let request = pendingPicker else {
      finishPicker(errorCode: "picker_invalid", message: "系统没有返回唯一可读取文件")
      return
    }
    let source = urls[0]
    pickerCopying = true
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let value = try Self.stageSelectedFile(source)
        DispatchQueue.main.async {
          guard self.pendingPicker?.id == request.id else {
            Self.deleteStaged(value)
            return
          }
          self.finishPicker(value: value)
        }
      } catch {
        DispatchQueue.main.async {
          guard self.pendingPicker?.id == request.id else { return }
          self.finishPicker(errorCode: "picker_copy_failed", message: "无法读取所选文件")
        }
      }
    }
  }

  private func finishPicker(
    value: [String: Any]? = nil, errorCode: String? = nil, message: String? = nil
  ) {
    guard let request = pendingPicker else {
      if let value { Self.deleteStaged(value) }
      return
    }
    pendingPicker = nil
    pickerCopying = false
    if let errorCode {
      request.result(FlutterError(code: errorCode, message: message, details: nil))
    } else {
      request.result(value)
    }
  }

  private func topViewController() -> UIViewController? {
    var current = viewController
    while let presented = current?.presentedViewController { current = presented }
    return current
  }

  private static func stageSelectedFile(_ source: URL) throws -> [String: Any] {
    let accessed = source.startAccessingSecurityScopedResource()
    defer { if accessed { source.stopAccessingSecurityScopedResource() } }
    let values = try source.resourceValues(forKeys: [
      .isRegularFileKey, .fileSizeKey, .contentTypeKey,
    ])
    guard values.isRegularFile == true,
          Int64(values.fileSize ?? -1) >= 0,
          Int64(values.fileSize ?? -1) <= maximumSelectedBytes else {
      throw ProbeError.unreadable
    }
    let fileName = safeFileName(source.lastPathComponent)
    let fileExtension = safeExtension(fileName)
    let mime = values.contentType?.preferredMIMEType
      .flatMap(validMime) ?? "application/octet-stream"
    let directory = stagingDirectory()
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.complete])
    let destination = directory.appendingPathComponent(
      UUID().uuidString.lowercased() + fileExtension, isDirectory: false)
    guard destination.deletingLastPathComponent().standardizedFileURL ==
            directory.standardizedFileURL else {
      throw ProbeError.unreadable
    }

    guard let input = InputStream(url: source),
          let output = OutputStream(url: destination, append: false) else {
      throw ProbeError.unreadable
    }
    input.open()
    output.open()
    defer {
      input.close()
      output.close()
    }
    var buffer = [UInt8](repeating: 0, count: 64 * 1024)
    var total: Int64 = 0
    do {
      while true {
        let read = input.read(&buffer, maxLength: buffer.count)
        if read < 0 { throw input.streamError ?? ProbeError.unreadable }
        if read == 0 { break }
        total += Int64(read)
        if total > maximumSelectedBytes { throw ProbeError.unreadable }
        var written = 0
        while written < read {
          let count = buffer.withUnsafeBytes { raw in
            output.write(
              raw.baseAddress!.advanced(by: written).assumingMemoryBound(to: UInt8.self),
              maxLength: read - written)
          }
          if count <= 0 { throw output.streamError ?? ProbeError.unreadable }
          written += count
        }
      }
    } catch {
      try? FileManager.default.removeItem(at: destination)
      throw error
    }
    return [
      "path": destination.path,
      "file_name": fileName,
      "mime": mime,
    ]
  }

  private static func safeFileName(_ source: String) -> String {
    let clean = source.trimmingCharacters(in: .whitespacesAndNewlines)
      .unicodeScalars.filter { $0.value >= 32 && $0.value != 127 && $0 != "/" && $0 != "\\" }
      .map(String.init).joined()
    if !clean.isEmpty && clean.utf8.count <= 255 { return clean }
    return "attachment" + safeExtension(clean)
  }

  private static func safeExtension(_ fileName: String) -> String {
    let value = URL(fileURLWithPath: fileName).pathExtension.lowercased()
    guard value.range(of: "^[a-z0-9]{1,16}$", options: .regularExpression) != nil else {
      return ""
    }
    return "." + value
  }

  private static func validMime(_ value: String) -> String? {
    let normalized = value.lowercased()
    return normalized.range(
      of: "^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$",
      options: .regularExpression) == nil ? nil : normalized
  }

  private static func stagingDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      "tatachat_picker", isDirectory: true)
  }

  private static func deleteStaged(_ value: [String: Any]) {
    guard let path = value["path"] as? String else { return }
    try? FileManager.default.removeItem(atPath: path)
  }

  private static func clearStagedFiles() {
    let directory = stagingDirectory()
    guard let children = try? FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]) else { return }
    for child in children where
      (try? child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    {
      try? FileManager.default.removeItem(at: child)
    }
  }

  private static func probeVideo(_ path: String) throws -> [String: Any] {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
          !isDirectory.boolValue,
          FileManager.default.isReadableFile(atPath: path) else {
      throw ProbeError.unreadable
    }

    let asset = AVURLAsset(url: URL(fileURLWithPath: path, isDirectory: false))
    guard let track = asset.tracks(withMediaType: .video).first else {
      throw ProbeError.missingTrack
    }
    let transformed = track.naturalSize.applying(track.preferredTransform)
    let width = Int(abs(transformed.width).rounded())
    let height = Int(abs(transformed.height).rounded())
    let seconds = CMTimeGetSeconds(asset.duration)
    guard width > 0, height > 0, seconds.isFinite, seconds > 0 else {
      throw ProbeError.invalidMetadata
    }

    var value: [String: Any] = [
      "width": width,
      "height": height,
      "duration_ms": min(Int64((seconds * 1000).rounded()), Int64(UInt32.max)),
    ]
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 64, height: 64)
    generator.apertureMode = .encodedPixels
    let image = try generator.copyCGImage(at: .zero, actualTime: nil)
    if let bytes = UIImage(cgImage: image).jpegData(compressionQuality: 0.6),
       !bytes.isEmpty,
       bytes.count <= maximumThumbnailBytes {
      value["thumbnail_bytes"] = FlutterStandardTypedData(bytes: bytes)
    }
    return value
  }

  private enum ProbeError: Error {
    case unreadable
    case missingTrack
    case invalidMetadata
  }
}
