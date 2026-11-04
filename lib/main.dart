import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart'; // Добавлен импорт
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'models/message.dart';
import 'models/chat.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'dart:io';

void main() {
  // Самый первый принт. Он должен появиться в консоли ДО всего остального.
  print('>>> [MAIN] ТОЧКА ВХОДА. kDebugMode = $kDebugMode');

  try {
    _bootstrap().catchError((e, st) {
      print('>>> [MAIN] ОШИБКА В _bootstrap: $e');
      print('>>> [MAIN] Stacktrace: $st');
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Краш: $e', style: const TextStyle(color: Colors.red))),
        ),
      ));
    });
  } catch (e, st) {
    print('>>> [MAIN] СИНХРОННАЯ ОШИБКА: $e');
    print('>>> [MAIN] Stacktrace: $st');
  }
}

Future<void> _bootstrap() async {
  try {
    print('>>> [MAIN] 1. Старт _bootstrap');
    WidgetsFlutterBinding.ensureInitialized();
    print('>>> [MAIN] 2. Binding готов');

    print('>>> [MAIN] 3. Инициализируем Notifications...');
    await NotificationService.init().timeout(const Duration(seconds: 3));
    print('>>> [MAIN] 4. Notifications OK');

    print('>>> [MAIN] 5. Инициализируем FCM...');
    await FcmService.init().timeout(const Duration(seconds: 3));
    print('>>> [MAIN] 6. FCM OK');

    print('>>> [MAIN] 7. Проверяем initialAction...');
    final initialAction = await AwesomeNotifications()
        .getInitialNotificationAction(removeFromActionEvents: true)
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
    print('>>> [MAIN] 8. initialAction: $initialAction');

    if (initialAction != null && initialAction.buttonKeyPressed == 'REPLY') {
      print('>>> [MAIN] 9. Запущено из REPLY');
      await NotificationService.onActionReceivedMethod(initialAction);
      runApp(const SizedBox());
      return;
    }

    print('>>> [MAIN] 10. Инициализируем Hive...');
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '.';
      final configDir = Directory('$home/.config/VartChat');
      await configDir.create(recursive: true);
      Hive.init(configDir.path);
    } else if (Platform.isWindows) {
      final home = Platform.environment['LOCALAPPDATA'] ?? '.';
      final configDir = Directory('$home/VartChat');
      await configDir.create(recursive: true);
      Hive.init(configDir.path);
    } else {
      await Hive.initFlutter();
    }
    print('>>> [MAIN] 11. Hive init OK');

    await initializeDateFormatting('ru', null);
    await initializeDateFormatting('en', null);
    print('>>> [MAIN] 12. DateFormat OK');

    Hive.registerAdapter(ChatMessageAdapter());
    Hive.registerAdapter(ChatAdapter());
    print('>>> [MAIN] 13. Адаптеры OK');

    final prefs = await SharedPreferences.getInstance();
    const schemaKey = 'messages_schema_version';
    const currentSchema = 5;
    if ((prefs.getInt(schemaKey) ?? 1) < currentSchema) {
      await Hive.deleteBoxFromDisk('messages');
      await prefs.setInt(schemaKey, currentSchema);
    }

    await Hive.openBox<ChatMessage>('messages');
    await Hive.openBox<Chat>('chats');
    print('>>> [MAIN] 14. Боксы открыты');

    if ((prefs.getInt('hidden_messages_removed') ?? 0) < 1) {
      try {
        await Hive.deleteBoxFromDisk('hidden_messages');
      } catch (_) {}
      await prefs.setInt('hidden_messages_removed', 1);
    }

    print('>>> [MAIN] 15. Запускаем runApp!');
    runApp(const MyApp());
    print('>>> [MAIN] 16. runApp выполнен');
  } catch (e, st) {
    print('>>> [MAIN] КРИТИЧЕСКАЯ ОШИБКА: $e');
    print('>>> [MAIN] Stacktrace: $st');
    // Показываем ошибку на экране, чтобы не было черного экрана
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Ошибка запуска: $e', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VartChat',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.lightBlue,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const LoginScreen(),
    );
  }
}