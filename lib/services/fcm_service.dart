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
  print('>>> [BG] Фоновый обработчик запущен!');
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Инициализируем БЕЗ запроса разрешений, чтобы не крашить фоновый изолят
    await NotificationService.init(requestPermission: false);

    print('>>> [BG] Данные пуша: ${message.data}');
    await NotificationService.showNotification(message.data);
    print('>>> [BG] Уведомление показано!');
  } catch (e, stacktrace) {
    print('>>> [BG] ОШИБКА: $e');
    print('>>> [BG] Stacktrace: $stacktrace');
  }
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

        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        await FirebaseMessaging.instance.requestPermission();
        _token = await FirebaseMessaging.instance.getToken();
        print('FCM Token: $_token');

        _refreshSub?.cancel();
        _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          _token = newToken;
        });

        // Передний план
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          NotificationService.showNotification(message.data);
        });

        // Клик по пушу (приложение в фоне)
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