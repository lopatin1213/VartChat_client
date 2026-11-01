import 'dart:async';
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

  bool _isAuthenticated = false;
  final List<Uint8List> _preAuthQueue = [];

  void Function(String reason)? onServerLogout;

  void setCredentials(String username, {String? fcmToken}) {
    _currentUsername = username;
    _fcmToken = fcmToken;
  }

  void markAuthenticated() {
    if (_isAuthenticated) return;
    _isAuthenticated = true;
    debugPrint('[WS] Authenticated. Flushing pre-auth queue (${_preAuthQueue.length} items).');
    for (final packet in _preAuthQueue) {
      _channel?.sink.add(packet);
    }
    _preAuthQueue.clear();
  }

  void _sendData(Uint8List data) {
    if (!_isAuthenticated) {
      if (data.isNotEmpty && (data[0] == Protocol.MSG_TYPE_AUTH || data[0] == Protocol.MSG_TYPE_LOGOUT)) {
        _channel?.sink.add(data);
      } else {
        debugPrint('[WS] Packet queued (not auth yet): type=${data.isNotEmpty ? data[0] : "empty"}');
        _preAuthQueue.add(data);
      }
      return;
    }
    _channel?.sink.add(data);
  }
  Future<void> connect(String serverUrl, {bool enablePing = true}) async {
    print('>>> [WS BG] connect() called with url=$serverUrl');
    await disconnect();
    if (serverUrl.trim().isEmpty) throw Exception('Адрес сервера не может быть пустым');

    _messageController = StreamController<Uint8List>.broadcast();
    var url = serverUrl.trim();
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = (url.startsWith('localhost') || url.startsWith('127.0.0.1')) ? 'ws://$url' : 'wss://$url';
    }
    print('>>> [WS BG] Final url: $url');

    final channel = IOWebSocketChannel.connect(
      Uri.parse(url),
      pingInterval: enablePing ? const Duration(seconds: 5) : null,
    );
    _channel = channel;

    channel.ready.then((_) {
      print('>>> [WS BG] Channel ready!');
    }).catchError((e) {
      print('>>> [WS BG] Channel ready error: $e');
      if (_channel == channel) _channel = null;
    });

    channel.stream.listen(
          (data) {
        if (data is Uint8List) _messageController?.add(data);
      },
      onDone: () {
        print('>>> [WS BG] Channel stream onDone');
        if (_channel == channel) {
          _channel = null;
          _messageController?.close();
          _messageController = null;
        }
      },
      onError: (error) {
        print('>>> [WS BG] Channel stream onError: $error');
        if (_channel == channel) {
          _channel = null;
          _messageController?.addError(error);
        }
      },
    );
  }

  Future<void> reconnect() async {
    final server = await StorageService.getServer();
    if (server == null) return;
    await disconnect();
    await connect(server);
    final err = await performHandshake();
    if (err != null) throw Exception('Несовместимая версия протокола: $err');
  }

  Future<String?> performHandshake() async {
    print('>>> [WS BG] performHandshake() start');
    if (_channel == null || _messageController == null) {
      throw Exception('Not connected');
    }

    final keyPair = CryptoService.generateKeyPair();
    final privateKey = keyPair.privateKey;
    final publicKey = keyPair.publicKey;

    final firstResp = _messageController!.stream.firstWhere(
          (data) =>
      data.length == 32 ||
          data.length >= 35 ||
          (data.isNotEmpty && data[0] == Protocol.HANDSHAKE_REJECT),
      orElse: () => throw Exception('No valid handshake response'),
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception('Handshake timeout');
    });

    print('>>> [WS BG] Sending HandshakeHello...');
    _channel?.sink.add(Protocol.buildHandshakeHello(publicKey));

    final resp = await firstResp;
    print('>>> [WS BG] Got handshake response, length: ${resp.length}');

    if (resp.length == 32) {
      final serverPublicKey = resp;
      final sharedSecret = CryptoService.computeSharedSecret(privateKey, serverPublicKey);
      _sessionKey = await CryptoService.deriveKey(sharedSecret);
      _agreedVersion = 1;
      print('>>> [WS BG] Handshake OK v1 (old)');
      return null;
    }

    final parsed = Protocol.parseHandshakeResponse(resp);
    if (!parsed.ok) {
      print('>>> [WS BG] Handshake reject: ${parsed.reason}');
      return parsed.reason ?? 'Несовместимая версия протокола';
    }

    _agreedVersion = parsed.agreedVersion;
    final serverPublicKey = parsed.serverKey!;

    final sharedSecret = CryptoService.computeSharedSecret(privateKey, serverPublicKey);
    _sessionKey = await CryptoService.deriveKey(sharedSecret);
    print('>>> [WS BG] Handshake OK v$_agreedVersion');

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
        bool isBackground = false,
      }) async {
    if (_channel == null || _sessionKey == null) throw Exception('Not ready');

    var authData = "$command|$phone|$password";
    if (command == "register") {
      authData += "|${firstName ?? ''}|${lastName ?? ''}|${username ?? ''}";
    }
    authData += "|$device";
    authData += "|${fcmToken ?? _fcmToken ?? ''}";

    final plaintext = Uint8List.fromList(utf8.encode(authData));
    final result = await CryptoService.encryptAesGcm(plaintext, _sessionKey!);
    final packet = Protocol.buildEncryptedAuthPacket(result.nonce, result.ciphertext, isBackground);

    await DatabaseService.clearData();
    _sendData(packet);
  }

  Future<void> sendToken(String token, {String? fcmToken, String device = 'flutter', bool isBackground = false}) async {
    if (_channel == null || _sessionKey == null) throw Exception('Not ready');

    final authData = "token|$token|$device|${fcmToken ?? _fcmToken ?? ''}";
    final plaintext = Uint8List.fromList(utf8.encode(authData));
    final result = await CryptoService.encryptAesGcm(plaintext, _sessionKey!);
    final packet = Protocol.buildEncryptedAuthPacket(result.nonce, result.ciphertext, isBackground);

    _sendData(packet);
  }

  Future<void> sendLogout(String token, {int type = 0, String password = ''}) async {
    if (_channel == null || _sessionKey == null) throw Exception('Not ready');

    final plaintext = Uint8List.fromList(utf8.encode("$token|$type|$password"));
    final result = await CryptoService.encryptAesGcm(plaintext, _sessionKey!);
    final packet = Protocol.buildEncryptedLogoutPacket(result.nonce, result.ciphertext);

    _sendData(packet);
    await Future.delayed(const Duration(milliseconds: 150));
  }

  Future<void> sendDeleteAccount(String token, String password) async {
    await sendLogout(token, type: Protocol.LOGOUT_TYPE_DELETE_ACCOUNT, password: password);
  }

  Future<void> sendEncryptedMessage(String recipient, String text,
      {int replyToId = 0, int? timestamp, int? clientMsgId}) async {
    if (_channel == null || _sessionKey == null) throw Exception('Not ready');
    final sender = _currentUsername ?? '';
    if (sender.isEmpty) throw Exception('Username not set');

    final plaintext = Uint8List.fromList(utf8.encode(text));
    final result = await CryptoService.encryptAesGcm(plaintext, _sessionKey!);
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final cMsgId = clientMsgId ?? DateTime.now().microsecondsSinceEpoch;

    final packet = Protocol.buildUserPacket(
      sender,
      recipient,
      result.ciphertext,
      result.nonce,
      ts,
      cMsgId,
      replyToId: replyToId,
    );
    _sendData(packet);
  }

  Future<void> sendTyping(int kind, String recipient) async {
    if (_channel == null) return;
    final sender = _currentUsername ?? '';
    if (sender.isEmpty) return;
    final packet = Protocol.buildTypingPacket(kind, sender, recipient);
    _sendData(packet);
  }

  Future<void> sendEditMessage(int msgId, int kind, String newText) async {
    if (_channel == null || _sessionKey == null) throw Exception('Not ready');
    final plaintext = Uint8List.fromList(utf8.encode(newText));
    final result = await CryptoService.encryptAesGcm(plaintext, _sessionKey!);
    final packet = Protocol.buildEditPacket(msgId, kind, result.nonce, result.ciphertext);
    _sendData(packet);
  }

  Future<void> sendDeleteChat(int kind, String name, {int type = 0}) async {
    if (_channel == null) throw Exception('Not connected');
    final packet = Protocol.buildDeleteChatPacket(kind, name, type: type);
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
    if (_channel == null) return;
    try {
      final packet = Protocol.buildStringPacket(Protocol.MSG_TYPE_COMMAND, cmd);
      _sendData(packet);
    } catch (e) {
      print('[WS] sendCommand error: $e');
    }
  }

  Future<void> disconnect() async {
    _isAuthenticated = false;
    _preAuthQueue.clear();

    final oldChannel = _channel;
    final oldController = _messageController;

    _channel = null;
    _messageController = null;
    _sessionKey = null;

    try {
      await oldChannel?.sink.close(status.normalClosure).timeout(const Duration(seconds: 1));
    } catch (_) {}
    try {
      await oldController?.close();
    } catch (_) {}
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