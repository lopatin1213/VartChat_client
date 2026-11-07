import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    try {
      final wsService = WebSocketService();
      wsService.setCredentials(username, fcmToken: FcmService.token);

      await wsService.connect(server);
      final hsErr = await wsService.performHandshake();

      if (hsErr != null) {
        _goToLogin();
        return;
      }

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

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatListScreen(wsService: wsService, username: username),
          ),
        );
      }
    } catch (e) {
      print('>>> [SPLASH] Ошибка авторизации: $e');
      _goToLogin();
    }
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
            // ЗАМЕНИТЕ ПУТЬ НА ВАШ ЛОГОТИП, ЕСЛИ ОН ДРУГОЙ
            Image.asset(
              'assets/icon/icon.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                // Если картинка не найдена, показываем стандартную иконку, чтобы приложение не упало
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