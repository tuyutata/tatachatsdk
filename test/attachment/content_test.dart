import 'package:flutter_test/flutter_test.dart';
import 'package:tatachat_sdk/tatachat_sdk.dart';
import 'package:tatachat_sdk/src/protocol/media_content.pb.dart' as protocol;

void main() {
  final sender = 'CID-A:' + '11' * 32;
  final receiver = 'CID-B:' + '22' * 32;

  // 所有协议边界使用合成公开描述；不生成应用钥或读取设备秘密。
  MediaContent content({
    MediaContentKind kind = MediaContentKind.file,
    int byteSize = 1024,
    int? cipherByteSize,
    String attachmentId = 'attachment-1',
    String? groupId,
    List<int> welcome = const [1, 2, 3],
    List<String>? members,
    String? senderIdentity,
    int? chunkCount,
    int epoch = 1,
    List<int>? plainHash,
    List<int>? cipherHash,
  }) => MediaContent(
    kind: kind,
    attachmentId: attachmentId,
    fileName: kind == MediaContentKind.video ? 'clip.mp4' : 'document.bin',
    mime: kind == MediaContentKind.video ? 'video/mp4' : 'application/octet-stream',
    byteSize: byteSize,
    durationMs: kind == MediaContentKind.video ? 3000 : null,
    attachmentChatEpoch: epoch,
    attachmentGroupId: groupId ?? 'attachment:' + (senderIdentity ?? sender) + ':' + attachmentId,
    attachmentWelcome: welcome,
    attachmentMemberIdentities: members ?? [sender, receiver],
    attachmentSenderMemberIdentity: senderIdentity ?? sender,
    attachmentChunkCount: chunkCount ?? (byteSize + 1024 * 1024 - 1) ~/ (1024 * 1024),
    plainSha256: plainHash ?? List<int>.filled(32, 7),
    cipherByteSize: cipherByteSize ?? byteSize + 36,
    cipherSha256: cipherHash ?? List<int>.filled(32, 9),
  );

  test('媒体合同保留超过四GiB的准确大小及MLS公开描述', () {
    const clearSize = 5 * 1024 * 1024 * 1024;
    final decoded = MediaContentCodec.decode(MediaContentCodec.encode(
      content(byteSize: clearSize, cipherByteSize: clearSize + 81920),
    ));
    expect(decoded.byteSize, clearSize);
    expect(decoded.cipherByteSize, clearSize + 81920);
    expect(decoded.attachmentWelcome, [1, 2, 3]);
    expect(decoded.attachmentMemberIdentities, [sender, receiver]);
    expect(decoded.attachmentSenderMemberIdentity, sender);
    expect(decoded.plainSha256, List<int>.filled(32, 7));
  });

  test('未知外层字段、已禁用数字tag及非规范编码全部拒绝', () {
    final valid = MediaContentCodec.encode(content());
    expect(() => MediaContentCodec.decode([...valid, 0xa0, 0x01, 0x01]), throwsFormatException);
    final unknown = protocol.MediaPayload.fromBuffer(valid);
    unknown.file.mergeFromBuffer([0x4a, 0x01, 0x00]);
    expect(() => MediaContentCodec.decode(unknown.writeToBuffer()), throwsFormatException);
    // 外层file字段号18的冗长varint编码具有相同语义，仍不允许第二种线格式。
    expect(() => MediaContentCodec.decode([0x92, 0x81, 0x00, ...valid.sublist(2)]), throwsFormatException);
  });

  test('Welcome、块数、epoch和开销上下界', () {
    final atLimit = content(welcome: List<int>.filled(48 * 1024, 1), epoch: 9007199254740991,
      cipherByteSize: 1024 + 4096);
    expect(MediaContentCodec.decode(MediaContentCodec.encode(atLimit)).attachmentWelcome.length, 48 * 1024);
    for (final invalid in [
      content(welcome: []),
      content(welcome: List<int>.filled(48 * 1024 + 1, 1)),
      content(welcome: [256]),
      content(plainHash: List<int>.filled(31, 1)),
      content(cipherHash: List<int>.filled(32, -1)),
      content(byteSize: 0),
      content(cipherByteSize: 1024),
      content(cipherByteSize: 1024 + 4097),
      content(chunkCount: 0),
      content(chunkCount: 2),
      content(byteSize: 0x100000000 * 1024 * 1024, chunkCount: 0x100000000),
      content(epoch: -1),
      content(epoch: 9007199254740992),
    ]) {
      expect(() => MediaContentCodec.encode(invalid), throwsFormatException);
    }
  });

  test('组、实际发送设备和闭集成员不能伪造或使用另一种排序', () {
    for (final invalid in [
      content(attachmentId: ''),
      content(attachmentId: 'x' * 129),
      content(groupId: 'ordinary-chat'),
      content(members: [sender]),
      content(members: [sender, sender]),
      content(members: [receiver, sender]),
      content(members: [sender, 'CID-B:' + 'AA' * 32]),
      content(senderIdentity: 'CID-C:' + '33' * 32),
      content(senderIdentity: 'x' * 256 + ':' + '11' * 32,
        members: ['x' * 256 + ':' + '11' * 32, 'y:' + '22' * 32]),
    ]) {
      expect(() => MediaContentCodec.encode(invalid), throwsFormatException);
    }
    final large = [sender, receiver, for (var i = 0; i < 1987; i++)
      'CID-C:' + i.toRadixString(16).padLeft(64, '0')]..sort();
    expect(() => MediaContentCodec.encode(content(members: large)), throwsFormatException);
    large.add('CID-D:' + '44' * 32);
    large.sort();
    expect(() => MediaContentCodec.encode(content(members: large)), throwsFormatException);
  });

  test('媒体展示类型约束保留', () {
    expect(() => MediaContentCodec.encode(content(kind: MediaContentKind.audio)), throwsFormatException);
    expect(MediaContentCodec.decode(MediaContentCodec.encode(content(kind: MediaContentKind.video))).durationMs, 3000);
  });

  test('附件传输地址只允许HTTPS', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    expect((TataChatServerAccess(
      tataChatServerUrl: Uri.parse('https://objects.example.com'),
      tataChatServerToken: 'token',
      expiresAtMillis: now + 120000,
    )..validate(now)).tataChatServerUrl.scheme, 'https');
    expect(() => TataChatServerAccess(
      tataChatServerUrl: Uri.parse('http' '://objects.example.com'),
      tataChatServerToken: 'token',
      expiresAtMillis: now + 120000,
    ).validate(now), throwsStateError);
    expect(() => TataChatServerAccess(
      tataChatServerUrl: Uri.parse('https://user@example.com'),
      tataChatServerToken: 'token',
      expiresAtMillis: now + 120000,
    ).validate(now), throwsStateError);
  });
}
