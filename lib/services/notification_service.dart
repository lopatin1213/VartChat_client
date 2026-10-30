import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static const String personalChannelKey = 'personal_chat_channel';
  static const String groupChannelKey = 'group_chat_channel';
  static const String channelBroadcastKey = 'channel_broadcast_channel';
  static const String systemChannelKey = 'system_alerts_channel';

  static Future<void> init() async {
    await AwesomeNotifications().initialize(
      null, // Использовать иконку приложения по умолчанию
      [
        NotificationChannel(
          channelKey: personalChannelKey,
          channelName: 'Личные сообщения',
          channelDescription: 'Уведомления о личных сообщениях',
          importance: NotificationImportance.High,
          playSound: true,
          criticalAlert: true,
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

    // Запрос разрешений (для Android 13+ и iOS)
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  static Future<void> showNotification(Map<String, dynamic> data) async {
    final String title = data['title'] ?? 'VartChat';
    final String body = data['body'] ?? '';
    final String kind = data['kind'] ?? 'personal';
    final String? chatKey = data['chatKey'];

    String channelKey = personalChannelKey;
    if (kind == 'group') {
      channelKey = groupChannelKey;
    } else if (kind == 'channel') {
      channelKey = channelBroadcastKey;
    } else if (kind == 'system') {
      channelKey = systemChannelKey;
    }

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: channelKey,
        title: title,
        body: body,
        payload: {'chatKey': chatKey ?? ''},
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'REPLY',
          label: 'Ответить',
          autoCancel: true,
          showUserInterface: true,
        ),
        NotificationActionButton(
          key: 'MARK_AS_READ',
          label: 'Прочитано',
          autoCancel: true,
          showUserInterface: false,
        ),
      ],
    );
  }
}