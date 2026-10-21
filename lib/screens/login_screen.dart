import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Для TapGestureRecognizer
import 'package:url_launcher/url_launcher.dart'; // Для открытия ссылок
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
  bool _isAgreed = false; // <--- НОВОЕ ПОЛЕ ДЛЯ ЧЕКБОКСА
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
        final hsErr = await _wsService.performHandshake();
        if (hsErr != null) {
          await _wsService.disconnect();
          if (mounted) {
            setState(() {
              _errorMessage = hsErr;
              _isLoading = false;
            });
            _showVersionDialog(hsErr);
          }
          return;
        }
        _subscription?.cancel();
        _subscription = _wsService.onMessage.listen(_handleIncomingMessage);
        await StorageService.saveServer(_serverAddress);
      }

      if (restoreToken != null) {
        await _wsService.sendToken(restoreToken, fcmToken: FcmService.token);
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

  void _showVersionDialog(String reason) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Несовместимая версия'),
        content: Text('Сервер сообщил: $reason\n\nОбновите приложение, чтобы продолжить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _handleIncomingMessage(Uint8List data) {
    try {
      final parsed = Protocol.parsePacket(data);
      final type = parsed.type;
      final payload = parsed.payload;

      if (type == Protocol.MSG_TYPE_LOGOUT) {
        final reason = Protocol.parseLogoutFromServer(payload);
        _subscription?.cancel();
        _subscription = null;
        StorageService.clearAll();
        DatabaseService.clearData();
        _wsService.disconnect();
        if (!mounted) return;
        setState(() {
          _errorMessage = reason;
          _isLoading = false;
        });
        return;
      }

      if (type == Protocol.MSG_TYPE_SYSTEM) {
        final text = Protocol.readString(payload, 0);

        if (text.contains('Недействительный токен') ||
            text.contains('Ошибка восстановления') ||
            text.contains('Неверный телефон') ||
            text.contains('Сессия не найдена')) {
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
            _currentUsername = username;
            _wsService.setCredentials(username, fcmToken: FcmService.token);
            StorageService.saveToken(token);
            StorageService.saveUsername(username);
            StorageService.saveUserId(userId);

            Future.delayed(const Duration(milliseconds: 500), () async {
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
        final parsedUser = Protocol.parseUserPacket(payload);
        final key = _wsService.sessionKey;
        if (key == null) return;

        try {
          CryptoService.decryptAesGcm(parsedUser.encrypted, key, parsedUser.nonce).then((plaintext) {
            final text = utf8.decode(plaintext, allowMalformed: true);
            final isMe = (parsedUser.sender == _currentUsername);
            final message = ChatMessage(
              id: parsedUser.msgId,
              sender: parsedUser.sender,
              recipient: parsedUser.recipient,
              text: text,
              isMe: isMe,
              timestamp: DateTime.fromMillisecondsSinceEpoch(parsedUser.timestamp),
              replyToId: parsedUser.replyToId,
              readMe: parsedUser.flagMe,
              readAny: parsedUser.flagAny,
              views: parsedUser.views,
              edited: parsedUser.edited,
            );
            _historyMessages.add(message);
          }).catchError((e) {
            print('[UI] Ошибка расшифровки: $e');
          });
        } catch (e) {
          print('[UI] Ошибка расшифровки: $e');
        }
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
    if (!_isAgreed) return; // Дополнительная защита
    await _connectAndAuth();
  }

  // --- Виджет для отображения согласия со ссылками ---
  Widget _buildAgreementCheckbox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _isAgreed,
            onChanged: (val) {
              setState(() => _isAgreed = val ?? false);
            },
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                  children: [
                    const TextSpan(text: 'Я даю согласие на '),
                    TextSpan(
                      text: 'обработку персональных данных',
                      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(Uri.parse('https://vartrusdata.alwaysdata.net/coglpersdanvartchat.html'), mode: LaunchMode.externalApplication),
                    ),
                    const TextSpan(text: ', а также я прочитал(а) '),
                    TextSpan(
                      text: 'политику конфиденциальности',
                      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(Uri.parse('https://vartrusdata.alwaysdata.net/pkvartchat.html?v=2'), mode: LaunchMode.externalApplication),
                    ),
                    const TextSpan(text: ' и '),
                    TextSpan(
                      text: 'условия пользования',
                      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrl(Uri.parse('https://vartrusdata.alwaysdata.net/ypvartchat.html?v=2'), mode: LaunchMode.externalApplication),
                    ),
                    const TextSpan(text: ' и согласен(сна) с ними.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
      body: SingleChildScrollView( // <--- Добавлен скролл на случай маленького экрана
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text('VartChat', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 32),
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
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

            // --- ЧЕКБОКС СОГЛАСИЯ ---
            _buildAgreementCheckbox(),
            const SizedBox(height: 16),

            ElevatedButton(
              // Кнопка заблокирована, если не согласен или идет загрузка
              onPressed: (!_isAgreed || _isLoading) ? null : _onLoginPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}