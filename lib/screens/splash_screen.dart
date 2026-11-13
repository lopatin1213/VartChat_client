import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rustore_update/flutter_rustore_update.dart';
import '../services/websocket_service.dart';
import '../services/fcm_service.dart';
import '../services/protocol.dart';
import 'chat_list_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 800));

    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();

    final token = await secureStorage.read(key: 'token');
    final username = prefs.getString('username');
    final server = prefs.getString('server');

    if (token == null || username == null || server == null) {
      _goToLogin();
      return;
    }

    final wsService = WebSocketService();
    wsService.setCredentials(username, fcmToken: FcmService.token);

    try {
      await wsService.connect(server);
    } catch (e) {
      print('>>> [SPLASH] Ошибка сети при подключении: $e');
      _goToChatList(wsService, username);
      return;
    }

    try {
      final hsErr = await wsService.performHandshake();

      if (hsErr != null) {
        if (Platform.isAndroid) {
          try {
            await RustoreUpdateClient.immediate();
            return;
          } catch (e) {
            print('>>> [SPLASH] RuStore immediate failed: $e');
          }
        }
        _showVersionDialog(hsErr);
        return;
      }
    } catch (e) {
      print('>>> [SPLASH] Ошибка handshake: $e');
      _goToChatList(wsService, username);
      return;
    }

    try {
      final completer = Completer<void>();
      final sub = wsService.onMessage.listen((data) {
        try {
          final parsed = Protocol.parsePacket(data);
          if (parsed.type == Protocol.MSG_TYPE_SYSTEM) {
            final text = Protocol.readString(parsed.payload, 0);
            if (text.startsWith('Успех|')) {
              wsService.markAuthenticated();
              if (!completer.isCompleted) completer.complete();
            }
          }
        } catch (_) {}
      });

      await wsService.sendToken(token, fcmToken: FcmService.token);

      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Таймаут авторизации'),
      );

      sub.cancel();
      _goToChatList(wsService, username);
    } catch (e) {
      print('>>> [SPLASH] Ошибка авторизации: $e');
      _goToChatList(wsService, username);
    }
  }

  void _showVersionDialog(String reason) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Несовместимая версия'),
        content: Text('Сервер сообщил: $reason\n\nОбновите приложение, чтобы продолжить.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  void _goToChatList(WebSocketService wsService, String username) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatListScreen(
          wsService: wsService,
          username: username,
        ),
      ),
    );
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon/icon.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.chat_bubble, size: 120, color: Colors.blue);
              },
            ),
            const SizedBox(height: 24),
            Text('VartChat', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}