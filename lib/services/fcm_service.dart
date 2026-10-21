import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import '../firebase_options.dart';

class FcmService {
  static String? _token;
  static StreamSubscription<String>? _refreshSub;

  static Future<void> init() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        await FirebaseMessaging.instance.requestPermission();
        _token = await FirebaseMessaging.instance.getToken();
        print('FCM Token: $_token');

        _refreshSub?.cancel();
        _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          print('[FCM] token refreshed: $newToken');
          _token = newToken;
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