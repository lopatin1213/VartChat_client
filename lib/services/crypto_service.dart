import 'dart:typed_data';
import 'dart:convert';
import 'package:x25519/x25519.dart' as x25519;
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' hide Hmac;

class CryptoService {
  static const String hkdfInfo = "relay-server";

  static const String _pepper = String.fromEnvironment(
    'VARTCHAT_PEPPER',
    defaultValue: 'vartchat-secure--x8wNh3UCuGlOO6Klie79S4MzENCnwarKMQx0m83frGLkIJmcO2DPN1bnCmuGfkAY1bh5206czOfiqhtUPDYbfkiVxLLxznTbFaPY8FCQEIjZbyABWzA2iI9ZOXGmN6RvOO',
  );

  static String bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String hashPhone(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final bytes = utf8.encode(cleanPhone + _pepper);
    final digest = sha256.convert(bytes);
    return digest.toString();
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
    final nonce = algorithm.newNonce();

    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    final combined = secretBox.concatenation();
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

    final data = Uint8List(nonceBytes.length + ciphertextWithTag.length)
      ..setAll(0, nonceBytes)
      ..setAll(nonceBytes.length, ciphertextWithTag);

    final secretBox = SecretBox.fromConcatenation(
      data,
      nonceLength: 12,
      macLength: 16,
    );

    final secretKey = SecretKey(key);
    final plaintext = await algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return Uint8List.fromList(plaintext);
  }
}