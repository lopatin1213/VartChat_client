import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'websocket_service.dart';
import 'protocol.dart';

class BackgroundSender {
  static Future<void> sendReply(String chatKey, String text) async {
    print('>>> [BG SEND] 1. Начало отправки ответа');
    const secureStorage = FlutterSecureStorage();
    final wsService = WebSocketService();

    try {
      final token = await secureStorage.read(key: 'token');
      final server = await secureStorage.read(key: 'server');
      final username = await secureStorage.read(key: 'username');

      if (token == null || server == null || username == null) {
        print('>>> [BG SEND] ОШИБКА: Нет данных для авторизации');
        return;
      }

      wsService.setCredentials(username);
      await wsService.connect(server, enablePing: false);
      print('>>> [BG SEND] 2. WebSocket подключен');

      final hsErr = await wsService.performHandshake();
      if (hsErr != null) {
        print('>>> [BG SEND] ОШИБКА Handshake: $hsErr');
        return;
      }

      // Создаем Completer для ожидания "Успеха"
      final completer = Completer<void>();

      // Слушаем сообщения от сервера
      final sub = wsService.onMessage.listen((data) {
        try {
          final parsed = Protocol.parsePacket(data);
          if (parsed.type == Protocol.MSG_TYPE_SYSTEM) {
            final sysText = Protocol.readString(parsed.payload, 0);
            if (sysText.startsWith('Успех|')) {
              print('>>> [BG SEND] 3. Получен "Успех". Авторизация подтверждена.');
              wsService.markAuthenticated(); // <--- ВАЖНО: снимаем блокировку!
              if (!completer.isCompleted) completer.complete();
            }
          }
        } catch (_) {}
      });

      print('>>> [BG SEND] 4. Отправляем AUTH (isBackground)...');
      await wsService.sendToken(token, isBackground: true);

      // Ждем "Успех" максимум 5 секунд
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => print('>>> [BG SEND] Таймаут ожидания Успеха'),
      );

      sub.cancel(); // Отписываемся

      print('>>> [BG SEND] 5. Отправляем сообщение...');
      await wsService.sendEncryptedMessage(chatKey, text);

      await Future.delayed(const Duration(milliseconds: 500));
      await wsService.disconnect();
      print('>>> [BG SEND] 6. УСПЕХ! Соединение закрыто.');

    } catch (e, st) {
      print('>>> [BG SEND] КРИТИЧЕСКАЯ ОШИБКА: $e');
      try { await wsService.disconnect(); } catch (_) {}
    }
  }
}