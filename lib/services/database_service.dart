import 'package:hive/hive.dart';
import '../models/message.dart';
import '../models/chat.dart';

class DatabaseService {
  static const String messagesBoxName = 'messages';
  static const String chatsBoxName = 'chats';

  static Box<ChatMessage> get messagesBox => Hive.box<ChatMessage>(messagesBoxName);
  static Box<Chat> get chatsBox => Hive.box<Chat>(chatsBoxName);

  // --- Сообщения ---
  static Future<void> saveMessage(ChatMessage message) async {
    await messagesBox.put(message.id, message);
  }

  static List<ChatMessage> getMessagesForChat(String chatId) {
    return messagesBox.values.where((msg) => msg.recipient == chatId || msg.sender == chatId).toList();
  }

  static List<ChatMessage> getAllMessages() {
    return messagesBox.values.toList();
  }

  static Future<void> deleteMessage(int id) async {
    await messagesBox.delete(id);
  }

  static Future<void> clearAllMessages() async {
    await messagesBox.clear();
  }

  // --- Чаты ---
  static Future<void> saveChat(Chat chat) async {
    await chatsBox.put(chat.id, chat);
  }

  static List<Chat> getAllChats() {
    return chatsBox.values.toList();
  }

  static Chat? getChat(String id) {
    return chatsBox.get(id);
  }

  static Future<void> deleteChat(String id) async {
    await chatsBox.delete(id);
  }

  static Future<void> clearAllChats() async {
    await chatsBox.clear();
  }

  static Future<void> clearData() async {
    await clearAllMessages();
    await clearAllChats();
  }

  /// Оставлено для совместимости. Скрытые сообщения теперь на сервере.
  static Future<void> clearAllData() async {
    await clearData();
  }
}