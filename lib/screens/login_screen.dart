import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';
import '../services/protocol.dart';
import '../services/crypto_service.dart';
import '../services/database_service.dart';
import '../services/fcm_service.dart';
import '../models/message.dart';
import 'chat_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isRegister = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _serverAddress = 'vartchat.alwaysdata.net';

  final WebSocketService _wsService = WebSocketService();
  StreamSubscription? _subscription;
  final List<ChatMessage> _historyMessages = [];
  bool _authSuccess = false;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _loadSavedServer();
    _tryRestoreSession();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedServer() async {
    final savedServer = await StorageService.getServer();
    if (savedServer != null) {
      setState(() => _serverAddress = savedServer);
    }
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'deviceId';
    String? deviceId = prefs.getString(key);
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(key, deviceId);
    }
    return deviceId;
  }

  Future<void> _tryRestoreSession() async {
    final savedToken = await StorageService.getToken();
    final savedUsername = await StorageService.getUsername();
    if (savedToken != null && savedUsername != null) {
      _currentUsername = savedUsername;
      _wsService.setCredentials(savedUsername, fcmToken: FcmService.token);
      try {
        await _connectAndAuth(restoreToken: savedToken);
      } catch (e) {
        print('[UI] Ошибка восстановления сессии: $e');
      }
    }
  }

  Future<void> _connectAndAuth({String? restoreToken}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (!_wsService.isConnected) {
        await _wsService.connect(_serverAddress);
        await _wsService.performHandshake();
        _subscription?.cancel();
        _subscription = _wsService.onMessage.listen(_handleIncomingMessage);
        await StorageService.saveServer(_serverAddress);
        print('[UI] Подключение к серверу $_serverAddress установлено');
      }

      if (restoreToken != null) {
        await _wsService.sendToken(restoreToken, fcmToken: FcmService.token);
        print('[UI] Токен восстановления отправлен');
      } else {
        final phone = _phoneController.text.trim();
        final password = _passwordController.text.trim();
        if (phone.isEmpty || password.isEmpty) {
          throw Exception('Телефон и пароль обязательны');
        }
        final deviceId = await _getDeviceId();
        if (_isRegister) {
          final firstName = _firstNameController.text.trim();
          final lastName = _lastNameController.text.trim();
          final username = _usernameController.text.trim();
          await _wsService.sendAuth(
            'register',
            phone,
            password,
            firstName: firstName.isEmpty ? null : firstName,
            lastName: lastName.isEmpty ? null : lastName,
            username: username.isEmpty ? null : username,
            device: deviceId,
            fcmToken: FcmService.token,
          );
        } else {
          await _wsService.sendAuth(
            'login',
            phone,
            password,
            device: deviceId,
            fcmToken: FcmService.token,
          );
        }
        print('[UI] Запрос аутентификации отправлен');
      }
    } catch (e) {
      print('[UI] Ошибка подключения/аутентификации: $e');
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isLoading = false;
      });
      if (!_wsService.isConnected) {
        _subscription?.cancel();
        _subscription = null;
      }
    }
  }

  void _handleIncomingMessage(Uint8List data) {
    print('[UI] _handleIncomingMessage: получен пакет, длина=${data.length}');
    try {
      final parsed = Protocol.parsePacket(data);
      final type = parsed.type;
      final payload = parsed.payload;
      print('[UI] тип=0x${type.toRadixString(16)}');

      if (type == Protocol.MSG_TYPE_SYSTEM) {
        final text = Protocol.readString(payload, 0);
        print('[UI] Системное сообщение: $text');

        if (text.contains('Недействительный токен') ||
            text.contains('Ошибка восстановления') ||
            text.contains('Неверный телефон') ||
            text.contains('Сессия не найдена')) {
          print('[UI] Ошибка аутентификации: $text');
          _subscription?.cancel();
          _subscription = null;
          setState(() {
            _errorMessage = 'Ошибка: $text. Войдите заново.';
            _isLoading = false;
          });
          StorageService.clearAll();
          DatabaseService.clearData();
          _wsService.disconnect();
          return;
        }

        if (text.startsWith('Успех|') && !_authSuccess) {
          _authSuccess = true;

          final parts = text.split('|');
          if (parts.length >= 4) {
            final userId = parts[1];
            final token = parts[2];
            final username = parts[3];
            print('[UI] Аутентификация успешна! userId=$userId, token=$token, username=$username');
            _currentUsername = username;
            _wsService.setCredentials(username, fcmToken: FcmService.token);
            StorageService.saveToken(token);
            StorageService.saveUsername(username);
            StorageService.saveUserId(userId);

            Future.delayed(const Duration(milliseconds: 500), () async {
              print('[UI] Задержка завершена. Всего исторических сообщений: ${_historyMessages.length}');
              _subscription?.cancel();
              _subscription = null;
              await DatabaseService.clearData();
              _historyMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              for (var msg in _historyMessages) {
                DatabaseService.saveMessage(msg);
              }

              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatListScreen(
                      wsService: _wsService,
                      username: username,
                    ),
                  ),
                );
              }
            });
          }
        }
      } else if (type == Protocol.MSG_TYPE_USER) {
        print('[UI] ==== ПОЛУЧЕНО ПОЛЬЗОВАТЕЛЬСКОЕ СООБЩЕНИЕ (история) ====');
        final parsedUser = Protocol.parseUserPacket(payload);
        final sender = parsedUser.sender;
        final recipient = parsedUser.recipient;
        final encrypted = parsedUser.encrypted;
        final nonce = parsedUser.nonce;
        final timestamp = parsedUser.timestamp;

        final key = _wsService.sessionKey;
        if (key == null) {
          print('[UI] Нет ключа для расшифровки');
          return;
        }

        try {
          CryptoService.decryptAesGcm(encrypted, key, nonce).then((plaintext) {
            final text = utf8.decode(plaintext, allowMalformed: true);
            final isMe = (sender == _currentUsername);
            final message = ChatMessage(
              id: parsedUser.msgId,   // ← ИЗМЕНЕНО
              sender: sender,
              recipient: recipient,
              text: text,
              isMe: isMe,
              timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
            );
            _historyMessages.add(message);
            print('[UI] История сохранена, всего сообщений: ${_historyMessages.length}');
          }).catchError((e) {
            print('[UI] Ошибка расшифровки: $e');
          });
        } catch (e) {
          print('[UI] Ошибка расшифровки: $e');
        }
      } else {
        print('[UI] Неизвестный тип сообщения: ${type.toRadixString(16)}');
      }
    } catch (e) {
      print('[UI] Ошибка обработки входящего сообщения: $e');
    }
  }

  void _showServerDialog() {
    final controller = TextEditingController(text: _serverAddress);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Адрес сервера'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'например, vartchat.alwaysdata.net'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final newAddress = controller.text.trim();
              if (newAddress.isNotEmpty) {
                setState(() {
                  _serverAddress = newAddress;
                  _errorMessage = null;
                });
                _wsService.disconnect();
                _subscription?.cancel();
                _subscription = null;
                _authSuccess = false;
                _historyMessages.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _onLoginPressed() async {
    await _connectAndAuth();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VartChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showServerDialog,
            tooltip: 'Сменить сервер',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('VartChat', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Телефон'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Пароль'),
              obscureText: true,
            ),
            if (_isRegister) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'Имя'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Фамилия'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _onLoginPressed,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(_isRegister ? 'Зарегистрироваться' : 'Войти'),
            ),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(_isRegister ? 'Уже есть аккаунт?' : 'Нет аккаунта?'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _wsService.isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _wsService.isConnected ? 'Подключено' : 'Не подключено',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 16),
                Text(
                  'Сервер: $_serverAddress',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}