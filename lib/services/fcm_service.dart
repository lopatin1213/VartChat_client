import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import '../firebase_options.dart';

class FcmService {
  static String? _token;

  static Future<void> init() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('Firebase initialized');
        await FirebaseMessaging.instance.requestPermission();
        print("Запрошено разрешение");
        _token = await FirebaseMessaging.instance.getToken();
        print('FCM Token: $_token');
      }
    } catch (e) {
      print('FCM init error: $e');
      // Не выбрасываем исключение, чтобы приложение продолжало работать
    }
  }

  static String? get token => _token;
}