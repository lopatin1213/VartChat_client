import 'dart:typed_data';
import 'dart:convert';

class Protocol {
  // ==================== Версии протокола ====================
  static const int MIN_PROTO_VERSION = 1;
  static const int CURRENT_PROTO_VERSION = 2;

  static const int HANDSHAKE_OK = 0x00;
  static const int HANDSHAKE_REJECT = 0xFF;

  // ==================== MSG_TYPES ====================
  static const int MSG_TYPE_USER = 0x01;
  static const int MSG_TYPE_SYSTEM = 0x02;
  static const int MSG_TYPE_COMMAND = 0x03;
  static const int MSG_TYPE_AUTH = 0x04;
  static const int MSG_TYPE_DELETE = 0x05;
  static const int MSG_TYPE_LOGOUT = 0x06;
  static const int MSG_TYPE_READ = 0x07;
  static const int MSG_TYPE_EDIT = 0x08;

  static const int LOGOUT_TYPE_EXIT = 0;
  static const int LOGOUT_TYPE_DELETE_ACCOUNT = 1;

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

  /// Тело первого пакета handshake: [proto_version u16 BE][pub_key 32] = 34 байта.
  static Uint8List buildHandshakeHello(Uint8List publicKey) {
    if (publicKey.length != 32) {
      throw ArgumentError('Public key must be 32 bytes');
    }
    final packet = Uint8List(2 + 32);
    packet[0] = (CURRENT_PROTO_VERSION >> 8) & 0xFF;
    packet[1] = CURRENT_PROTO_VERSION & 0xFF;
    packet.setAll(2, publicKey);
    return packet;
  }

  /// Разбор ответа сервера на handshake.
  /// OK:   [0x00][agreed u16 BE][pub_key 32]      — 35 байт
  /// FAIL: [0xFF][reason_len u32 BE][reason utf8]
  static ({bool ok, int? agreedVersion, Uint8List? serverKey, String? reason})
  parseHandshakeResponse(Uint8List data) {
    if (data.isEmpty) {
      return (ok: false, agreedVersion: null, serverKey: null, reason: 'Пустой ответ');
    }
    if (data[0] == HANDSHAKE_OK) {
      if (data.length < 3 + 32) {
        return (ok: false, agreedVersion: null, serverKey: null, reason: 'Обрезан OK-ответ');
      }
      final agreed = (data[1] << 8) | data[2];
      final key = data.sublist(3, 3 + 32);
      return (ok: true, agreedVersion: agreed, serverKey: key, reason: null);
    }
    if (data[0] == HANDSHAKE_REJECT) {
      if (data.length < 5) {
        return (ok: false, agreedVersion: null, serverKey: null, reason: 'Несовместимая версия');
      }
      final len = (data[1] << 24) | (data[2] << 16) | (data[3] << 8) | data[4];
      final reason = len > 0 && data.length >= 5 + len
          ? utf8.decode(data.sublist(5, 5 + len), allowMalformed: true)
          : 'Несовместимая версия';
      return (ok: false, agreedVersion: null, serverKey: null, reason: reason);
    }
    return (ok: false, agreedVersion: null, serverKey: null, reason: 'Неизвестный ответ');
  }

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

  /// C→S 0x08 (EDIT): [0x08][msg_id i64 BE][kind u8][nonce 12][enc_len u32 BE][enc].
  static Uint8List buildEditPacket(
      int msgId,
      int kind,
      Uint8List nonce,
      Uint8List encrypted,
      ) {
    final totalLen = 1 + 8 + 1 + 12 + 4 + encrypted.length;
    final packet = Uint8List(totalLen);
    var offset = 0;
    packet[offset++] = MSG_TYPE_EDIT;
    ByteData.sublistView(packet, offset, offset + 8)
        .setInt64(0, msgId, Endian.big);
    offset += 8;
    packet[offset++] = kind;
    packet.setAll(offset, nonce);
    offset += 12;
    _writeUint32(packet, offset, encrypted.length);
    offset += 4;
    packet.setAll(offset, encrypted);
    return packet;
  }

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
  bool edited,
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
      offset += 4;
    }

    bool edited = false;
    if (payload.length >= offset + 1) {
      edited = payload[offset] != 0;
      offset += 1;
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
    edited: edited,
    );
  }

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

  /// C→S 0x06: [0x06][token_len u32 BE][token utf8][type u8?].
  /// type == 0 (или нет байта) → exit; type == 1 → delete_account.
  static Uint8List buildLogoutPacket(String token, {int type = 0}) {
    final tokenBytes = Uint8List.fromList(utf8.encode(token));
    final totalLen = (type == 0)
        ? 1 + 4 + tokenBytes.length
        : 1 + 4 + tokenBytes.length + 1;
    final packet = Uint8List(totalLen);
    packet[0] = MSG_TYPE_LOGOUT;
    _writeUint32(packet, 1, tokenBytes.length);
    packet.setAll(5, tokenBytes);
    if (type != 0) packet[5 + tokenBytes.length] = type;
    return packet;
  }

  /// S→C 0x06: [0x06][reason_len u32 BE][reason utf8].
  static String parseLogoutFromServer(Uint8List payload) {
    if (payload.length < 4) return 'Сессия завершена';
    final len = _readUint32(payload, 0);
    if (payload.length < 4 + len) return 'Сессия завершена';
    return utf8.decode(payload.sublist(4, 4 + len), allowMalformed: true);
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