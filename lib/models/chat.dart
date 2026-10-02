import 'package:hive/hive.dart';

part 'chat.g.dart';

@HiveType(typeId: 1)
class Chat extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String type; // 'personal', 'group', 'channel'

  @HiveField(3)
  String? lastMessage;

  @HiveField(4)
  DateTime? lastMessageTime;

  Chat({
    required this.id,
    required this.name,
    required this.type,
    this.lastMessage,
    this.lastMessageTime,
  });
}