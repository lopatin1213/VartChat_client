import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'crypto_service.dart';
import 'protocol.dart';
import 'storage_service.dart';
import '../services/database_service.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Uint8List>? _messageController;
  Stream<Uint8List> get onMessage =>
      _messageController?.stream ?? const Stream.empty();

  bool get isConnected => _channel != null && _channel!.closeCode == null;

  Uint8List? _sessionKey;
  Uint8List? get sessionKey => _sessionKey;

  String? _currentUsername;
  String? _fcmToken;
  int? _agreedVersion;
  int? get agreedVersion => _agreedVersion;

  /// Вызывается, когда сервер присылает S→C 0x06 (принудительное завершение).
  void Function(String reason)? onServerLogout;

  void setCredentials(String username, {String? fcmToken}) {
    _currentUsername = username;
    _fcmToken = fcmToken;
  }

  void _sendData(Uint8List data) {
    print('[WS] sendData: длина=${data.length}, hex=${CryptoService.bytesToHex(data)}');
    _channel!.sink.add(data);
  }

  Future<void> connect(String serverUrl) async {
    await disconnect();
    if (serverUrl.trim().isEmpty) {
      throw Exception('Адрес сервера не может быть пустым');
    }

    _messageController = StreamController<Uint8List>.broadcast();

    var url = serverUrl.trim();
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      if (url.startsWith('localhost') || url.startsWith('127.0.0.1')) {
        url = 'ws://$url';
      } else {
        print('Используеться WebSocket over TLS');
        url = 'wss://$url';
      }
    }
    final uri = Uri.parse(url);
    final channel = IOWebSocketChannel.connect(
      uri,
      pingInterval: const Duration(seconds: 5),
    );
    _channel = channel;

    channel.ready.catchError((e) {
      _channel = null;
      debugPrint('[WS] connect failed: $e');
    });

    channel.stream.listen(
          (data) {
        if (data is Uint8List) {
          _messageController?.add(data);
        }
      },
      onDone: () {
        _channel = null;
        _messageController?.close();
        _messageController = null;
      },
      onError: (error) {
        _channel = null;
        _messageController?.addError(error);
      },
    );
  }

  /// Handshake с версионированием.
  /// Отправляем: [proto u16][pub 32] = 34 байта.
  /// Читаем:     [0x00][agreed u16][pub 32]   — OK (35 байт)
  ///             [0xFF][reason_len u32][utf8] — отказ
  ///             [pub 32]                     — старый сервер v1
  /// Возвращает null при успехе, строку с причиной при отказе.
  Future<String?> performHandshake() async {
    if (_channel == null || _messageController == null) {
      throw Exception('Not connected');
    }

    final keyPair = CryptoService.generateKeyPair();
    final privateKey = keyPair.privateKey;
    final publicKey = keyPair.publicKey;

    await StorageService.savePrivateKey(privateKey);

    // Слушаем ответ ДО отправки, чтобы не потерять его.
    final firstResp = _messageController!.stream.firstWhere(
          (data) =>
      data.length == 32 ||
          data.length >= 35 ||
          (data.isNotEmpty && data[0] == Protocol.HANDSHAKE_REJECT),
      orElse: () => throw Exception('No valid handshake response'),
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception('Handshake timeout');
    });

    _sendData(Protocol.buildHandshakeHello(publicKey));

    final resp = await firstResp;

    // Старый сервер v1: просто 32 байта публичного ключа, без версии.
    if (resp.length == 32) {
      debugPrint('[WS] Старый сервер (v1), без версии в ответе');
      final serverPublicKey = resp;
      final sharedSecret =
      CryptoService.computeSharedSecret(privateKey, serverPublicKey);
      _sessionKey = await CryptoService.deriveKey(sharedSecret);
      _agreedVersion = 1;
      await StorageService.saveSessionKey(_sessionKey!);
      await StorageService.savePeerPublicKey(serverPublicKey);
      return null;
    }

    // Новый сервер: разбираем.
    final parsed = Protocol.parseHandshakeResponse(resp);
    if (!parsed.ok) {
      debugPrint('[WS] Handshake отклонён: ${parsed.reason}');
      return parsed.reason ?? 'Несовместимая версия протокола';
    }

    _agreedVersion = parsed.agreedVersion;
    final serverPublicKey = parsed.serverKey!;
    debugPrint('[WS] Handshake OK, протокол v$_agreedVersion');

    final sharedSecret =
    CryptoService.computeSharedSecret(privateKey, serverPublicKey);
    _sessionKey = await CryptoService.deriveKey(sharedSecret);
    print('[WS] Handshake: ключ сессии = ${CryptoService.bytesToHex(_sessionKey!)}');

    await StorageService.saveSessionKey(_sessionKey!);
    await StorageService.savePeerPublicKey(serverPublicKey);
    return null;
  }

  Future<void> sendAuth(
      String command,
      String phone,
      String password, {
        String? firstName,
        String? lastName,
        String? username,
        String device = 'flutter',
        String? fcmToken,
      }) async {
    if (_channel == null) throw Exception('Not connected');
    final packet = Protocol.buildAuthPacket(
      command,
      phone,
      password,
      firstName: firstName,
      lastName: lastName,
      username: username,
      device: device,
      fcmToken: fcmToken ?? _fcmToken,
    );
    await DatabaseService.clearData();
    _sendData(packet);
  }

  Future<void> sendToken(String token,
      {String? fcmToken, String device = 'flutter'}) async {
    if (_channel == null) throw Exception('Not connected');
    final packet = Protocol.buildTokenPacket(
      token,
      device: device,
      fcmToken: fcmToken ?? _fcmToken,
    );
    _sendData(packet);
  }

  /// C→S 0x06. type == 0 → exit, type == 1 → delete_account.
  Future<void> sendLogout(String token, {int type = 0}) async {
    if (_channel == null) throw Exception('Not connected');
    final packet = Protocol.buildLogoutPacket(token, type: type);
    _sendData(packet);
    await Future.delayed(const Duration(milliseconds: 150));
  }

  /// Специальный случай logout — удаление аккаунта.
  Future<void> sendDeleteAccount(String token) async {
    await sendLogout(token, type: Protocol.LOGOUT_TYPE_DELETE_ACCOUNT);
  }

  Future<void> sendEncryptedMessage(String recipient, String text,
      {int replyToId = 0, int? timestamp}) async {
    if (_channel == null || _sessionKey == null) {
      throw Exception('Not ready');
    }
    final sender = _currentUsername ?? '';
    if (sender.isEmpty) throw Exception('Username not set');
    final plaintext = Uint8List.fromList(utf8.encode(text));
    final result = await CryptoService.encryptAesGcm(plaintext, _sessionKey!);
    final ciphertext = result.ciphertext;
    final nonce = result.nonce;
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final packet = Protocol.buildUserPacket(
      sender,
      recipient,
      ciphertext,
      nonce,
      ts,
      0,
      replyToId: replyToId,
    );
    _sendData(packet);
  }

  /// C→S 0x08 (EDIT). Шифрует newText сессионным ключом.
  Future<void> sendEditMessage(int msgId, int kind, String newText) async {
    if (_channel == null || _sessionKey == null) {
      throw Exception('Not ready');
    }
    final plaintext = Uint8List.fromList(utf8.encode(newText));
    final result = await CryptoService.encryptAesGcm(plaintext, _sessionKey!);
    final packet = Protocol.buildEditPacket(
      msgId,
      kind,
      result.nonce,
      result.ciphertext,
    );
    _sendData(packet);
  }

  Future<void> sendDeleteMessage(int msgId, int kind, {int type = 0}) async {
    if (_channel == null) throw Exception('Not connected');
    final packet = Protocol.buildDeletePacket(msgId, kind, type: type);
    _sendData(packet);
  }

  Future<void> sendRead(List<({int kind, int msgId})> items) async {
    if (_channel == null) throw Exception('Not connected');
    if (items.isEmpty) return;
    final packet = Protocol.buildReadPacket(items);
    _sendData(packet);
  }

  Future<void> sendCommand(String cmd) async {
    if (_channel == null) {
      print('[WS] sendCommand пропущена (нет соединения): $cmd');
      return;
    }
    try {
      final packet = Protocol.buildStringPacket(Protocol.MSG_TYPE_COMMAND, cmd);
      _sendData(packet);
    } catch (e) {
      print('[WS] sendCommand error: $e');
    }
  }

  Future<void> disconnect() async {
    _channel?.sink.close(status.normalClosure);
    _channel = null;
    _sessionKey = null;
    await _messageController?.close();
    _messageController = null;
  }

  Future<void> reconnect() async {
    final server = await StorageService.getServer();
    if (server == null) return;
    await disconnect();
    await connect(server);
    final err = await performHandshake();
    if (err != null) {
      throw Exception('Несовместимая версия протокола: $err');
    }

    final token = await StorageService.getToken();
    if (token != null) {
      await sendToken(token);
    }
  }

  Future<void> resetSession() async {
    await disconnect();
    await StorageService.clearAll();
    await DatabaseService.clearAllData();
    _sessionKey = null;
    _currentUsername = null;
  }

  void dispose() {
    disconnect();
  }
}