import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'background_sender.dart';

@pragma('vm:entry-point')
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

    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
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

    int kindInt = 1;
    if (kind == 'group') {
      kindInt = 2;
    } else if (kind == 'channel') {
      kindInt = 3;
    } else if (kind == 'system') {
      kindInt = 4;
    }

    final String title = data['title'] ?? 'VartChat';
    final String body = data['body'] ?? '';
    final String? fullText = data['full_text'];

    String? chatKey = data['chatKey'];
    if (chatKey == null || chatKey.isEmpty) {
      if (kind == 'personal') {
        chatKey = data['sender_username'] ?? data['sender'];
      } else if (kind == 'group' && data['group'] != null) {
        chatKey = '#${data['group']}';
      } else if (kind == 'channel' && data['channel'] != null) {
        chatKey = '&${data['channel']}';
      }
    }

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

    List<NotificationActionButton>? actions;
    if (kind == 'system') {
      actions = null;
    } else if (kind == 'channel') {
      actions = [
        NotificationActionButton(
          key: 'MARK_AS_READ',
          label: 'Прочитано',
          autoDismissible: true,
          actionType: ActionType.SilentAction,
        ),
      ];
    } else {
      actions = [
        NotificationActionButton(
          key: 'REPLY',
          label: 'Ответить',
          requireInputText: true,
          autoDismissible: true,
          actionType: ActionType.SilentAction,
        ),
        NotificationActionButton(
          key: 'MARK_AS_READ',
          label: 'Прочитано',
          autoDismissible: true,
          actionType: ActionType.SilentAction,
        ),
      ];
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
        payload: {
          'chatKey': chatKey ?? '',
          'kind': kindInt.toString(),
          'msgId': msgId.toString(),
        },
      ),
      actionButtons: actions,
    );
  }

  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    WidgetsFlutterBinding.ensureInitialized();

    final payload = receivedAction.payload;
    final String? chatKey = payload?['chatKey'];
    print("$chatKey");
    final String? kindStr = payload?['kind'];
    final String? msgIdStr = payload?['msgId'];

    final int kind = int.tryParse(kindStr ?? '') ?? 1;
    final int msgId = int.tryParse(msgIdStr ?? '') ?? (receivedAction.id ?? DateTime.now().millisecondsSinceEpoch);

    if (receivedAction.buttonKeyPressed == 'REPLY') {
      final text = receivedAction.buttonKeyInput;
      if (text.isNotEmpty && chatKey != null && chatKey.isNotEmpty) {
        debugPrint('>>> [ACTION] Перехвачен "Ответить". Передаем в BackgroundSender.');

        await BackgroundSender.sendReply(chatKey, text, msgId);
      }
    } else if (receivedAction.buttonKeyPressed == 'MARK_AS_READ') {
      if (chatKey != null && chatKey.isNotEmpty && msgId > 0) {
        debugPrint('>>> [ACTION] Перехвачен "Прочитано". Передаем в BackgroundSender.');
        await AwesomeNotifications().cancelAll();
        await BackgroundSender.markAsRead(chatKey, kind, msgId);
      }
    }
    await AwesomeNotifications().cancel(msgId);
  }
}