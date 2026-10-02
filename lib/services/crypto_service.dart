import 'dart:typed_data';
import 'dart:convert';
import 'package:x25519/x25519.dart' as x25519;
import 'package:cryptography/cryptography.dart';

class CryptoService {
  static const String hkdfInfo = "relay-server";

  static String bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static ({Uint8List privateKey, Uint8List publicKey}) generateKeyPair() {
    final keyPair = x25519.generateKeyPair();
    return (
    privateKey: Uint8List.fromList(keyPair.privateKey),
    publicKey: Uint8List.fromList(keyPair.publicKey),
    );
  }

  static Uint8List computeSharedSecret(Uint8List privateKey, Uint8List peerPublicKey) {
    final shared = x25519.x25519(Uint8List(32), privateKey, peerPublicKey);
    return Uint8List.fromList(shared);
  }

  static Future<Uint8List> deriveKey(Uint8List sharedSecret) async {
    final hkdf = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );
    final secretKey = SecretKey(sharedSecret);
    final info = Uint8List.fromList(utf8.encode(hkdfInfo));
    final derivedKey = await hkdf.deriveKey(
      secretKey: secretKey,
      info: info,
    );
    final output = await derivedKey.extractBytes();
    return Uint8List.fromList(output);
  }

  static Future<({Uint8List ciphertext, Uint8List nonce})> encryptAesGcm(
      Uint8List plaintext,
      Uint8List key,
      ) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(key);
    final nonce = algorithm.newNonce(); // ← генерация nonce через алгоритм

    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Используем встроенный метод concatenation для объединения nonce + ciphertext + mac
    final combined = secretBox.concatenation();
    print(combined);
    // Извлекаем байты nonce для возврата (используем свойство nonce из SecretBox)
    final nonceBytes = Uint8List.fromList(secretBox.nonce);

    return (
    ciphertext: combined.sublist(12),
    nonce: nonceBytes,
    );
  }

  static Future<Uint8List> decryptAesGcm(
      Uint8List ciphertextWithTag,
      Uint8List key,
      Uint8List nonceBytes,
      ) async {
    final algorithm = AesGcm.with256bits();

    // Собираем данные обратно в формат, который понимает SecretBox.fromConcatenation
    // nonceLength для AES-GCM = 12 байт, macLength = 16 байт
    final data = Uint8List(nonceBytes.length + ciphertextWithTag.length)
      ..setAll(0, nonceBytes)
      ..setAll(nonceBytes.length, ciphertextWithTag);

    // Используем fromConcatenation для автоматического разбора
    final secretBox = SecretBox.fromConcatenation(
      data,
      nonceLength: 12, // AES-GCM nonce length
      macLength: 16,   // AES-GCM MAC length
    );

    final secretKey = SecretKey(key);
    final plaintext = await algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return Uint8List.fromList(plaintext);
  }
}