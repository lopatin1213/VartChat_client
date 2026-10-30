import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../firebase_options.dart';
import 'notification_service.dart';

// Фоновый обработчик (обязателен для data-only пушей)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.init();
  await NotificationService.showNotification(message.data);
}

class FcmService {
  static String? _token;
  static StreamSubscription<String>? _refreshSub;
  static final ValueNotifier<String?> openChatNotifier = ValueNotifier<String?>(null);

  static Future<void> init() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Регистрируем фоновый обработчик
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        await FirebaseMessaging.instance.requestPermission();
        _token = await FirebaseMessaging.instance.getToken();
        print('FCM Token: $_token');

        _refreshSub?.cancel();
        _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          _token = newToken;
        });

        // Приложение открыто (foreground)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          NotificationService.showNotification(message.data);
        });

        // Приложение было в фоне, пользователь нажал на пуш
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final chatKey = message.data['chatKey'];
          if (chatKey != null && chatKey.isNotEmpty) {
            openChatNotifier.value = chatKey;
          }
        });
      }
    } catch (e) {
      print('FCM init error: $e');
    }
  }

  static String? get token => _token;

  static void dispose() {
    _refreshSub?.cancel();
    _refreshSub = null;
  }
}