import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
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
      if (url.startsWith('localhost') | url.startsWith('127.0.0.1')) {
        url = 'ws://$url';
      } else {
        print('Используеться WebSocket over TLS');
        url = 'wss://$url';
      }
    }
    final uri = Uri.parse(url);
    _channel = IOWebSocketChannel.connect(
      uri,
      pingInterval: const Duration(seconds: 30),
    );

    _channel!.stream.listen(
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

  Future<void> performHandshake() async {
    if (_channel == null || _messageController == null) {
      throw Exception('Not connected');
    }

    final keyPair = CryptoService.generateKeyPair();
    final privateKey = keyPair.privateKey;
    final publicKey = keyPair.publicKey;

    await StorageService.savePrivateKey(privateKey);
    _sendData(publicKey);

    final serverPublicKey = await _messageController!.stream
        .firstWhere(
          (data) => data.length == 32,
      orElse: () => throw Exception('No valid key received'),
    )
        .timeout(const Duration(seconds: 10), onTimeout: () {
      throw Exception('Handshake timeout');
    });

    final sharedSecret =
    CryptoService.computeSharedSecret(privateKey, serverPublicKey);
    final key = await CryptoService.deriveKey(sharedSecret);
    print('[WS] Handshake: ключ сессии = ${CryptoService.bytesToHex(key)}');
    _sessionKey = key;

    await StorageService.saveSessionKey(key);
    await StorageService.savePeerPublicKey(serverPublicKey);
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

  Future<void> sendLogout(String token) async {
    if (_channel == null) throw Exception('Not connected');
    final packet = Protocol.buildLogoutPacket(token);
    _sendData(packet);
    await Future.delayed(const Duration(milliseconds: 150));
  }

  Future<void> sendEncryptedMessage(String recipient, String text,
      {int replyToId = 0}) async {
    if (_channel == null || _sessionKey == null) {
      throw Exception('Not ready');
    }
    final sender = _currentUsername ?? '';
    if (sender.isEmpty) throw Exception('Username not set');
    final plaintext = Uint8List.fromList(utf8.encode(text));
    final result = await CryptoService.encryptAesGcm(plaintext, _sessionKey!);
    final ciphertext = result.ciphertext;
    final nonce = result.nonce;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final packet = Protocol.buildUserPacket(
      sender,
      recipient,
      ciphertext,
      nonce,
      timestamp,
      0,
      replyToId: replyToId,
    );
    _sendData(packet);
  }

  Future<void> sendDeleteMessage(int msgId, int kind, {int type = 0}) async {
    if (_channel == null) throw Exception('Not connected');
    final packet = Protocol.buildDeletePacket(msgId, kind, type: type);
    _sendData(packet);
  }

  /// 0x07: пометить сообщения прочитанными.
  Future<void> sendRead(List<({int kind, int msgId})> items) async {
    if (_channel == null) throw Exception('Not connected');
    if (items.isEmpty) return;
    final packet = Protocol.buildReadPacket(items);
    _sendData(packet);
  }

  Future<void> sendCommand(String cmd) async {
    if (_channel == null) throw Exception('Not connected');
    final packet = Protocol.buildStringPacket(Protocol.MSG_TYPE_COMMAND, cmd);
    _sendData(packet);
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
    await performHandshake();

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