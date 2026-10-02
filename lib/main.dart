import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'models/message.dart';
import 'models/chat.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/fcm_service.dart';
import 'dart:io';

void main() {
  // В release все print() внутри зоны гасятся (в т.ч. утечки ключей/hex).
  // В debug — всё как обычно.
  if (!kDebugMode) {
    runZoned(
      _bootstrap,
      zoneSpecification: ZoneSpecification(
        print: (_, __, ___, String line) {},
      ),
    );
  } else {
    _bootstrap();
  }
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FcmService.init();
  if (Platform.isLinux) {
    final home = Platform.environment['HOME'] ?? '.';
    final configDir = Directory('$home/.config/VartChat');
    await configDir.create(recursive: true);
    Hive.init(configDir.path);
  } else {
    await Hive.initFlutter();
  }

  await initializeDateFormatting('ru', null);
  await initializeDateFormatting('en', null);

  Hive.registerAdapter(ChatMessageAdapter());
  Hive.registerAdapter(ChatAdapter());

  // Сбрасываем Hive-бокс messages при апгрейде схемы (String id → int id).
  final prefs = await SharedPreferences.getInstance();
  const schemaKey = 'messages_schema_version';
  const currentSchema = 2;
  if ((prefs.getInt(schemaKey) ?? 1) < currentSchema) {
    await Hive.deleteBoxFromDisk('messages');
    await prefs.setInt(schemaKey, currentSchema);
  }

  await Hive.openBox<ChatMessage>('messages');
  await Hive.openBox<Chat>('chats');

  // Старый локальный бокс скрытых больше не используется — удаляем при апгрейде.
  if ((prefs.getInt('hidden_messages_removed') ?? 0) < 1) {
    try {
      await Hive.deleteBoxFromDisk('hidden_messages');
    } catch (_) {}
    await prefs.setInt('hidden_messages_removed', 1);
  }

  runApp(const MyApp());
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
