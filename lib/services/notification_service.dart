import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';
class NotificationService {
  static const String personalChannelKey = 'personal_chat_channel';
  static const String groupChannelKey = 'group_chat_channel';
  static const String channelBroadcastKey = 'channel_broadcast_channel';
  static const String systemChannelKey = 'system_alerts_channel';

  static Future<void> init({bool requestPermission = true}) async {
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_notification',
      [
        NotificationChannel(
          channelKey: personalChannelKey,
          channelName: 'Личные сообщения',
          channelDescription: 'Уведомления о личных сообщениях',
          importance: NotificationImportance.High,
          playSound: true,
          criticalAlerts: true,
        ),
        NotificationChannel(
          channelKey: groupChannelKey,
          channelName: 'Группы',
          channelDescription: 'Уведомления из групповых чатов',
          importance: NotificationImportance.Default,
          playSound: false,
        ),
        NotificationChannel(
          channelKey: channelBroadcastKey,
          channelName: 'Каналы',
          channelDescription: 'Уведомления из каналов',
          importance: NotificationImportance.Low,
          playSound: false,
        ),
        NotificationChannel(
          channelKey: systemChannelKey,
          channelName: 'Системные уведомления',
          channelDescription: 'Важные системные оповещения',
          importance: NotificationImportance.High,
          playSound: true,
        ),
      ],
    );

    if (requestPermission) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static Future<void> showNotification(Map<String, dynamic> data) async {
    final String kind = data['kind'] ?? 'personal';
    final String? msgIdStr = data['msg_id'];
    final int msgId = int.tryParse(msgIdStr ?? '') ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (kind == 'delete') {
      await AwesomeNotifications().cancel(msgId);
      debugPrint('>>> [BG] Уведомление $msgId удалено по команде с сервера.');
      return;
    }

    final String title = data['title'] ?? 'VartChat';
    final String body = data['body'] ?? '';
    final String? fullText = data['full_text'];
    final String? chatKey = data['chatKey'];

    String channelKey = personalChannelKey;
    if (kind == 'group') {
      channelKey = groupChannelKey;
    } else if (kind == 'channel') {
      channelKey = channelBroadcastKey;
    } else if (kind == 'system') {
      channelKey = systemChannelKey;
    }

    String? imageUrl;
    String cleanBody = body;

    if (fullText != null) {
      final mdRegex = RegExp(r'!\[.*?\]\((.*?)\)');
      final match = mdRegex.firstMatch(fullText);

      if (match != null) {
        imageUrl = match.group(1)?.trim();
        cleanBody = body.replaceAll(match.group(0)!, '[Изображение]').trim();
      }
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: msgId,
        channelKey: channelKey,
        title: title,
        body: cleanBody,
        bigPicture: imageUrl,
        notificationLayout: imageUrl != null
            ? NotificationLayout.BigPicture
            : NotificationLayout.Default,
        payload: {'chatKey': chatKey ?? ''},
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'REPLY',
          label: 'Ответить',
          requireInputText: true,
          autoDismissible: true,
        ),
        NotificationActionButton(
          key: 'MARK_AS_READ',
          label: 'Прочитано',
          autoDismissible: true,
          actionType: ActionType.DisabledAction,
        ),
      ],
    );
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    await AwesomeNotifications().cancelAll();

    final text = receivedAction.buttonKeyInput;
    final chatKey = receivedAction.payload?['chatKey'];

    if (receivedAction.buttonKeyPressed == 'REPLY' && text != null && chatKey != null) {
      print('>>> [ACTION] Сохраняем ответ в SecureStorage');
      await StorageService.savePendingReply(chatKey, text);
    }
  }
}