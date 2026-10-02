import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

class StorageService {
  static const String _keyServer = 'server';
  static const String _keyToken = 'token';
  static const String _keyUsername = 'username';
  static const String _keyUserId = 'userId';
  static const String _keyPrivateKey = 'privateKey';
  static const String _keyPeerPublicKey = 'peerPublicKey';
  static const String _keySessionKey = 'sessionKey';

  static Future<void> saveServer(String server) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServer, server);
  }

  static Future<String?> getServer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServer);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
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

  static Future<void> savePrivateKey(Uint8List key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrivateKey, _encode(key));
  }

  static Future<Uint8List?> getPrivateKey() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyPrivateKey);
    return str != null ? _decode(str) : null;
  }

  static Future<void> savePeerPublicKey(Uint8List key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPeerPublicKey, _encode(key));
  }

  static Future<Uint8List?> getPeerPublicKey() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyPeerPublicKey);
    return str != null ? _decode(str) : null;
  }

  static Future<void> saveSessionKey(Uint8List key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionKey, _encode(key));
  }

  static Future<Uint8List?> getSessionKey() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keySessionKey);
    return str != null ? _decode(str) : null;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServer);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyPrivateKey);
    await prefs.remove(_keyPeerPublicKey);
    await prefs.remove(_keySessionKey);
  }

  static String _encode(Uint8List bytes) => base64.encode(bytes);
  static Uint8List _decode(String str) => base64.decode(str);
}