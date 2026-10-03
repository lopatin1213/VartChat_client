import 'dart:typed_data';
import 'dart:convert';

class Protocol {
  static const int MSG_TYPE_USER = 0x01;
  static const int MSG_TYPE_SYSTEM = 0x02;
  static const int MSG_TYPE_COMMAND = 0x03;
  static const int MSG_TYPE_AUTH = 0x04;
  static const int MSG_TYPE_DELETE = 0x05;
  static const int MSG_TYPE_LOGOUT = 0x06;
  static const int MSG_TYPE_READ = 0x07;

  static const int MSG_KIND_PERSONAL = 1;
  static const int MSG_KIND_GROUP = 2;
  static const int MSG_KIND_CHANNEL = 3;

  static Uint8List buildAuthPacket(
      String command,
      String phone,
      String password, {
        String? firstName,
        String? lastName,
        String? username,
        String device = 'flutter',
        String? fcmToken,
      }) {
    var authData = "$command|$phone|$password";
    if (command == "register") {
      authData += "|${firstName ?? ''}|${lastName ?? ''}|${username ?? ''}";
    }
    authData += "|$device";
    authData += "|${fcmToken ?? ''}";
    final bytes = Uint8List.fromList(utf8.encode(authData));
    final packet = Uint8List(1 + 4 + bytes.length);
    packet[0] = MSG_TYPE_AUTH;
    _writeUint32(packet, 1, bytes.length);
    packet.setAll(5, bytes);
    return packet;
  }

  static Uint8List buildTokenPacket(String token,
      {String device = 'flutter', String? fcmToken}) {
    final authData = "token|$token|$device|${fcmToken ?? ''}";
    final bytes = Uint8List.fromList(utf8.encode(authData));
    final packet = Uint8List(1 + 4 + bytes.length);
    packet[0] = MSG_TYPE_AUTH;
    _writeUint32(packet, 1, bytes.length);
    packet.setAll(5, bytes);
    return packet;
  }

  /// MSG_TYPE_USER:
  /// [0x01][sender][recipient][nonce 12][enc_len u32][encrypted]
  /// [timestamp 8][msg_id 8][reply_to_id 8]
  static Uint8List buildUserPacket(
      String sender,
      String recipient,
      Uint8List encrypted,
      Uint8List nonce,
      int timestamp,
      int msgId, {
        int replyToId = 0,
      }) {
    final senderBytes = Uint8List.fromList(utf8.encode(sender));
    final recipientBytes = Uint8List.fromList(utf8.encode(recipient));
    final totalLen = 1 +
        4 + senderBytes.length +
        4 + recipientBytes.length +
        12 +
        4 + encrypted.length +
        8 +
        8 +
        8;
    final packet = Uint8List(totalLen);
    var offset = 0;
    packet[offset++] = MSG_TYPE_USER;
    _writeUint32(packet, offset, senderBytes.length);
    offset += 4;
    packet.setAll(offset, senderBytes);
    offset += senderBytes.length;
    _writeUint32(packet, offset, recipientBytes.length);
    offset += 4;
    packet.setAll(offset, recipientBytes);
    offset += recipientBytes.length;
    packet.setAll(offset, nonce);
    offset += 12;
    _writeUint32(packet, offset, encrypted.length);
    offset += 4;
    packet.setAll(offset, encrypted);
    offset += encrypted.length;
    final tsBytes = Uint8List(8);
    ByteData.sublistView(tsBytes).setInt64(0, timestamp, Endian.big);
    packet.setAll(offset, tsBytes);
    offset += 8;
    final idBytes = Uint8List(8);
    ByteData.sublistView(idBytes).setInt64(0, msgId, Endian.big);
    packet.setAll(offset, idBytes);
    offset += 8;
    final replyBytes = Uint8List(8);
    ByteData.sublistView(replyBytes).setInt64(0, replyToId, Endian.big);
    packet.setAll(offset, replyBytes);
    return packet;
  }

  /// Разбор MSG_TYPE_USER.
  /// Суффикс (опционально, для совместимости): [flag_me u8][flag_any u8] и [views u32] для каналов.
  static ({
  String sender,
  String recipient,
  Uint8List encrypted,
  Uint8List nonce,
  int timestamp,
  int msgId,
  int replyToId,
  bool flagMe,
  bool flagAny,
  int? views,
  }) parseUserPacket(Uint8List payload) {
    var offset = 0;
    final senderLen = _readUint32(payload, offset);
    offset += 4;
    final sender = utf8.decode(payload.sublist(offset, offset + senderLen));
    offset += senderLen;
    final recipientLen = _readUint32(payload, offset);
    offset += 4;
    final recipient =
    utf8.decode(payload.sublist(offset, offset + recipientLen));
    offset += recipientLen;
    final nonce = payload.sublist(offset, offset + 12);
    offset += 12;
    final encLen = _readUint32(payload, offset);
    offset += 4;
    final encrypted = payload.sublist(offset, offset + encLen);
    offset += encLen;
    final tsBytes = payload.sublist(offset, offset + 8);
    final timestamp = ByteData.sublistView(tsBytes).getInt64(0, Endian.big);
    offset += 8;

    int msgId = 0;
    if (payload.length >= offset + 8) {
      msgId = ByteData.sublistView(payload, offset, offset + 8)
          .getInt64(0, Endian.big);
      offset += 8;
    }

    int replyToId = 0;
    if (payload.length >= offset + 8) {
      replyToId = ByteData.sublistView(payload, offset, offset + 8)
          .getInt64(0, Endian.big);
      offset += 8;
    }

    bool flagMe = false;
    if (payload.length >= offset + 1) {
      flagMe = payload[offset] != 0;
      offset += 1;
    }
    bool flagAny = false;
    if (payload.length >= offset + 1) {
      flagAny = payload[offset] != 0;
      offset += 1;
    }

    int? views;
    if (payload.length >= offset + 4) {
      views = ByteData.sublistView(payload, offset, offset + 4)
          .getUint32(0, Endian.big);
    }

    return (
    sender: sender,
    recipient: recipient,
    encrypted: encrypted,
    nonce: nonce,
    timestamp: timestamp,
    msgId: msgId,
    replyToId: replyToId,
    flagMe: flagMe,
    flagAny: flagAny,
    views: views,
    );
  }

  /// MSG_TYPE_READ: [0x07][count u16 BE][{kind u8, msg_id i64 BE} × N].
  static Uint8List buildReadPacket(List<({int kind, int msgId})> items) {
    final size = 1 + 2 + items.length * 9;
    final packet = Uint8List(size);
    var off = 0;
    packet[off++] = MSG_TYPE_READ;
    packet[off++] = (items.length >> 8) & 0xFF;
    packet[off++] = items.length & 0xFF;
    for (final it in items) {
      packet[off++] = it.kind;
      ByteData.sublistView(packet, off, off + 8)
          .setInt64(0, it.msgId, Endian.big);
      off += 8;
    }
    return packet;
  }

  static List<({int kind, int msgId})> parseReadPacket(Uint8List payload) {
    if (payload.length < 2) return [];
    final count = (payload[0] << 8) | payload[1];
    if (payload.length < 2 + count * 9) return [];
    final out = <({int kind, int msgId})>[];
    for (var i = 0; i < count; i++) {
      final off = 2 + i * 9;
      final kind = payload[off];
      final msgId = ByteData.sublistView(payload, off + 1, off + 9)
          .getInt64(0, Endian.big);
      out.add((kind: kind, msgId: msgId));
    }
    return out;
  }

  static Uint8List buildDeletePacket(int msgId, int kind, {int type = 0}) {
    final size = (type == 0) ? 10 : 11;
    final packet = Uint8List(size);
    packet[0] = MSG_TYPE_DELETE;
    ByteData.sublistView(packet, 1, 9).setInt64(0, msgId, Endian.big);
    packet[9] = kind;
    if (type != 0) packet[10] = type;
    return packet;
  }

  static Uint8List buildLogoutPacket(String token) {
    final tokenBytes = Uint8List.fromList(utf8.encode(token));
    final packet = Uint8List(1 + 4 + tokenBytes.length);
    packet[0] = MSG_TYPE_LOGOUT;
    _writeUint32(packet, 1, tokenBytes.length);
    packet.setAll(5, tokenBytes);
    return packet;
  }

  static Uint8List buildStringPacket(int type, String text) {
    final bytes = Uint8List.fromList(utf8.encode(text));
    final packet = Uint8List(1 + 4 + bytes.length);
    packet[0] = type;
    _writeUint32(packet, 1, bytes.length);
    packet.setAll(5, bytes);
    return packet;
  }

  static String readString(Uint8List data, int offset) {
    final len = _readUint32(data, offset);
    final bytes = data.sublist(offset + 4, offset + 4 + len);
    return utf8.decode(bytes);
  }

  static ({int type, Uint8List payload}) parsePacket(Uint8List packet) {
    if (packet.isEmpty) throw Exception('Empty packet');
    final type = packet[0];
    final payload = Uint8List.sublistView(packet, 1);
    return (type: type, payload: payload);
  }

  static int _readUint32(Uint8List data, int offset) {
    return (data[offset] << 24) |
    (data[offset + 1] << 16) |
    (data[offset + 2] << 8) |
    data[offset + 3];
  }

  static void _writeUint32(Uint8List data, int offset, int value) {
    data[offset] = (value >> 24) & 0xFF;
    data[offset + 1] = (value >> 16) & 0xFF;
    data[offset + 2] = (value >> 8) & 0xFF;
    data[offset + 3] = value & 0xFF;
  }
}