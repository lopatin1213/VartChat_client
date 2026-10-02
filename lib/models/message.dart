import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 0)
class ChatMessage extends HiveObject {
  @HiveField(0)
  int id;

  @HiveField(1)
  String sender;

  @HiveField(2)
  String recipient;

  @HiveField(3)
  String text;

  @HiveField(4)
  bool isMe;

  @HiveField(5)
  DateTime timestamp;

  @HiveField(6)
  int readStatus;

  /// id сообщения, на которое это сообщение отвечает.
  /// 0 = обычное, > 0 = reply на это msg_id.
  @HiveField(7)
  int replyToId;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.readStatus = 0,
    this.replyToId = 0,
  });
}