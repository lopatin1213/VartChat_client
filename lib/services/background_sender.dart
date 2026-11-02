import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'websocket_service.dart';
import 'protocol.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
class BackgroundSender {
  @pragma('vm:entry-point')
  static Future<void> sendReply(String chatKey, String text, int msgId) async {
    WidgetsFlutterBinding.ensureInitialized();

    final lockFile = File('${Directory.systemTemp.path}/vartchat_reply_$msgId.lock');

    try {
      lockFile.createSync(exclusive: true);
    } on FileSystemException {
      debugPrint('>>> [BG SEND] Событие $msgId уже обрабатывается другим изолятом. Выходим.');
      return;
    }

    debugPrint('>>> [BG SEND] 1. Начало отправки ответа для msgId=$msgId');

    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    final wsService = WebSocketService();

    try {
      final token = await secureStorage.read(key: 'token');
      final server = prefs.getString('server');
      final username = prefs.getString('username');

      if (token == null || server == null || username == null) {
        debugPrint('>>> [BG SEND] ОШИБКА: Нет данных для авторизации. Сохраняем в SecureStorage.');
        await StorageService.savePendingReply(chatKey, text);
        return;
      }

      wsService.setCredentials(username);
      await wsService.connect(server, enablePing: false);
      debugPrint('>>> [BG SEND] 2. WebSocket подключен');

      final hsErr = await wsService.performHandshake();
      if (hsErr != null) {
        debugPrint('>>> [BG SEND] ОШИБКА Handshake: $hsErr');
        await StorageService.savePendingReply(chatKey, text);
        return;
      }

      final authCompleter = Completer<void>();
      final ackCompleter = Completer<void>();
      final errorCompleter = Completer<void>();

      final clientMsgId = DateTime.now().microsecondsSinceEpoch;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final sub = wsService.onMessage.listen(
            (data) {
          try {
            final parsed = Protocol.parsePacket(data);
            print("$parsed");
            // 1. Ждем авторизацию
            if (parsed.type == Protocol.MSG_TYPE_SYSTEM && !authCompleter.isCompleted) {
              final sysText = Protocol.readString(parsed.payload, 0);
              if (sysText.startsWith('Успех|')) {
                debugPrint('>>> [BG SEND] 3. Получен "Успех". Авторизация подтверждена.');
                wsService.markAuthenticated();
                authCompleter.complete();
              }
            }
            // 2. Ждем подтверждение доставки (Ack) от сервера
            else if (parsed.type == Protocol.MSG_TYPE_USER && authCompleter.isCompleted) {
              print("0x01");
              final userPacket = Protocol.parseUserPacket(parsed.payload);
              print("Получен пакет $userPacket");
              if (userPacket.clientMsgId == clientMsgId) {
                debugPrint('>>> [BG SEND] 5. Получен ACK от сервера! Сообщение доставлено.');
                if (!ackCompleter.isCompleted) ackCompleter.complete();
              }
            }
          } catch (_) {}
        },
        onDone: () {
          if (!errorCompleter.isCompleted) {
            errorCompleter.completeError('Соединение закрыто сервером');
          }
        },
        onError: (e) {
          if (!errorCompleter.isCompleted) {
            errorCompleter.completeError('Ошибка сокета: $e');
          }
        },
      );

      debugPrint('>>> [BG SEND] 4. Отправляем AUTH (isBackground)...');
      await wsService.sendToken(token, isBackground: true);

      // Ждем успешной авторизации
      await Future.any([authCompleter.future, errorCompleter.future]);

      debugPrint('>>> [BG SEND] 5. Отправляем сообщение...');
      await wsService.sendEncryptedMessage(
        chatKey,
        text,
        clientMsgId: clientMsgId,
        timestamp: timestamp,
      );

      // Ждем ACK от сервера (с защитой от зависания на 5 сек)
      await Future.any([
        ackCompleter.future,
        errorCompleter.future,
        Future.delayed(const Duration(seconds: 1000)).then((_) => throw TimeoutException('ACK timeout'))
      ]);

      sub.cancel();
      await wsService.disconnect();
      debugPrint('>>> [BG SEND] 6. УСПЕХ! Соединение закрыто.');

    } catch (e, st) {
      debugPrint('>>> [BG SEND] КРИТИЧЕСКАЯ ОШИБКА: $e');
      try {
        await wsService.disconnect();
      } catch (_) {}

      debugPrint('>>> [BG SEND] Сохраняем ответ в SecureStorage для последующей отправки.');
      await StorageService.savePendingReply(chatKey, text);
    } finally {
      try {
        if (lockFile.existsSync()) lockFile.deleteSync();
      } catch (e) {
        debugPrint('>>> [BG SEND] Ошибка удаления lock-файла: $e');
      }
    }
  }

  @pragma('vm:entry-point')
  static Future<void> markAsRead(String chatKey, int kind, int msgId) async {
    WidgetsFlutterBinding.ensureInitialized();

    final lockFile = File('${Directory.systemTemp.path}/vartchat_read_$msgId.lock');

    try {
      lockFile.createSync(exclusive: true);
    } on FileSystemException {
      debugPrint('>>> [BG READ] Событие $msgId уже обрабатывается другим изолятом. Выходим.');
      return;
    }

    debugPrint('>>> [BG READ] 1. Начало отправки read для msgId=$msgId, kind=$kind');

    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    final wsService = WebSocketService();

    try {
      final token = await secureStorage.read(key: 'token');
      final server = prefs.getString('server');
      final username = prefs.getString('username');

      if (token == null || server == null || username == null) {
        debugPrint('>>> [BG READ] ОШИБКА: Нет данных для авторизации.');
        return;
      }

      wsService.setCredentials(username);
      await wsService.connect(server, enablePing: false);
      debugPrint('>>> [BG READ] 2. WebSocket подключен');

      final hsErr = await wsService.performHandshake();
      if (hsErr != null) {
        debugPrint('>>> [BG READ] ОШИБКА Handshake: $hsErr');
        return;
      }

      final completer = Completer<void>();
      final errorCompleter = Completer<void>();

      final sub = wsService.onMessage.listen(
            (data) {
          try {
            final parsed = Protocol.parsePacket(data);
            if (parsed.type == Protocol.MSG_TYPE_SYSTEM) {
              final sysText = Protocol.readString(parsed.payload, 0);
              if (sysText.startsWith('Успех|')) {
                debugPrint('>>> [BG READ] 3. Получен "Успех". Авторизация подтверждена.');
                wsService.markAuthenticated();
                if (!completer.isCompleted) completer.complete();
              }
            }
          } catch (_) {}
        },
        onDone: () {
          if (!completer.isCompleted && !errorCompleter.isCompleted) {
            errorCompleter.completeError('Соединение закрыто сервером до получения "Успех"');
          }
        },
        onError: (e) {
          if (!completer.isCompleted && !errorCompleter.isCompleted) {
            errorCompleter.completeError('Ошибка сокета: $e');
          }
        },
      );

      debugPrint('>>> [BG READ] 4. Отправляем AUTH (isBackground)...');
      await wsService.sendToken(token, isBackground: true);

      await Future.any([completer.future, errorCompleter.future]);
      sub.cancel();

      debugPrint('>>> [BG READ] 5. Отправляем 0x07...');
      await wsService.sendRead([(kind: kind, msgId: msgId)]);

      await Future.delayed(const Duration(milliseconds: 300));
      await wsService.disconnect();
      debugPrint('>>> [BG READ] 6. УСПЕХ! Соединение закрыто.');

    } catch (e) {
      debugPrint('>>> [BG READ] КРИТИЧЕСКАЯ ОШИБКА: $e');
      try {
        await wsService.disconnect();
      } catch (_) {}
    } finally {
      try {
        if (lockFile.existsSync()) lockFile.deleteSync();
      } catch (e) {
        debugPrint('>>> [BG READ] Ошибка удаления lock-файла: $e');
      }
    }
  }
}