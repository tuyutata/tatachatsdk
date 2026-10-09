import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// 根据当前密文消息的既有字段生成确定性 ID，不引入额外操作编号。
final class MessageId {
  MessageId._();

  static String derive({
    required String conversationId,
    required String senderUserId,
    required String recipientUserId,
    required int createdAtMillis,
    required List<int> encryptedMessage,
  }) {
    if (conversationId.isEmpty ||
        senderUserId.isEmpty ||
        recipientUserId.isEmpty ||
        createdAtMillis < 0 ||
        encryptedMessage.isEmpty) {
      throw ArgumentError('生成消息 ID 所需字段不完整');
    }
    final bytes = BytesBuilder(copy: false);
    _addField(bytes, utf8.encode('TataChatSDK Message'));
    _addField(bytes, utf8.encode(conversationId));
    _addField(bytes, utf8.encode(senderUserId));
    _addField(bytes, utf8.encode(recipientUserId));
    final time = ByteData(8)..setInt64(0, createdAtMillis, Endian.big);
    _addField(bytes, time.buffer.asUint8List());
    _addField(bytes, encryptedMessage);
    return crypto.sha256.convert(bytes.takeBytes()).toString();
  }

  static void _addField(BytesBuilder target, List<int> value) {
    final length = ByteData(4)..setUint32(0, value.length, Endian.big);
    target
      ..add(length.buffer.asUint8List())
      ..add(value);
  }
}
