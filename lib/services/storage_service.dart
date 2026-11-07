import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const String _keyServer = 'server';
  static const String _keyUsername = 'username';
  static const String _keyUserId = 'userId';
  static const String _keyToken = 'token';
  static const String _keyLastContactsSync = 'last_contacts_sync';

  static const _secureStorage = FlutterSecureStorage();

  static Future<void> saveServer(String server) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServer, server);
  }
  static Future<String?> getServer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServer);
  }

  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
  }
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
  }
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<void> saveLastContactsSync(int timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastContactsSync, timestamp);
  }

  static Future<int> getLastContactsSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastContactsSync) ?? 0;
  }

  static Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _keyToken, value: token);
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: _keyToken);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServer);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyLastContactsSync);
    await _secureStorage.delete(key: _keyToken);
  }

  static Future<void> savePendingReply(String chatKey, String text) async {
    await _secureStorage.write(key: 'pending_reply_chat', value: chatKey);
    await _secureStorage.write(key: 'pending_reply_text', value: text);
  }

  static Future<Map<String, String>?> getPendingReply() async {
    final chat = await _secureStorage.read(key: 'pending_reply_chat');
    final text = await _secureStorage.read(key: 'pending_reply_text');
    if (chat != null && text != null) {
      await _secureStorage.delete(key: 'pending_reply_chat');
      await _secureStorage.delete(key: 'pending_reply_text');
      return {'chatKey': chat, 'text': text};
    }
    return null;
  }
}