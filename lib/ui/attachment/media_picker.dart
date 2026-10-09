import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../attachment/mime.dart';
import '../../core/chat_message.dart';

/// 采集到的媒体文件(路径型,不载入字节)。
class PickedMediaFile {
  const PickedMediaFile({
    required this.path,
    required this.fileName,
    required this.mime,
    required this.kind,
  });

  final String path;
  final String fileName;
  final String mime;
  final ChatMessageKind kind;
}

typedef ChatGalleryFilesPicker =
    Future<List<XFile>> Function(BuildContext context);

/// Chat 相册唯一边界：一次只允许一个视频，或一至九张照片。
class MediaPicker {
  MediaPicker({ChatGalleryFilesPicker? pickGallery})
    : _pickGallery = pickGallery ?? _defaultPickGallery;

  final ChatGalleryFilesPicker _pickGallery;

  Future<List<PickedMediaFile>> gallery(BuildContext context) async {
    final files = await _pickGallery(context);
    final picked = <PickedMediaFile>[];
    for (final file in files) {
      final fileName = file.name;
      final mime = file.mimeType ?? mimeFromFileName(fileName);
      final kind = mediaKindFromMime(mime);
      if (kind != ChatMessageKind.image && kind != ChatMessageKind.video) {
        throw const FormatException('相册只能选择照片或视频');
      }
      picked.add(
        PickedMediaFile(
          path: file.path,
          fileName: fileName,
          mime: mime,
          kind: kind,
        ),
      );
    }
    if (picked.isEmpty) return const <PickedMediaFile>[];
    final kind = picked.first.kind;
    if (picked.any((item) => item.kind != kind) ||
        (kind == ChatMessageKind.video && picked.length != 1) ||
        (kind == ChatMessageKind.image && picked.length > 9)) {
      throw const FormatException('一次只能选择1个视频，或1至9张照片');
    }
    return picked;
  }
}

Future<List<XFile>> _defaultPickGallery(BuildContext context) async {
  final assets = await AssetPicker.pickAssets(
    context,
    // wechatMoment 在选择阶段强制“单视频或多图”互斥，返回边界仍再次校验。
    // ignore: prefer_const_constructors
    pickerConfig: AssetPickerConfig(
      maxAssets: 9,
      requestType: RequestType.common,
      specialPickerType: SpecialPickerType.wechatMoment,
      themeColor: Theme.of(context).colorScheme.primary,
      textDelegate: const AssetPickerTextDelegate(),
    ),
  );
  if (assets == null || assets.isEmpty) return const <XFile>[];
  final files = <XFile>[];
  for (final asset in assets) {
    final file = await asset.file;
    if (file == null) continue;
    final title = await asset.titleAsync;
    files.add(
      XFile(
        file.path,
        name: title.isEmpty ? null : title,
        mimeType: await asset.mimeTypeAsync,
      ),
    );
  }
  return files;
}
