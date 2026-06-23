import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoHelper {
  // Use a secure seed for key derivation
  static const String _defaultKeySeed = "GigTaxSecureLedgerEncryptionKey2026";
  static const String _defaultIvSeed = "GigTaxIvSeed2026";

  static enc.Key _deriveKey(String? userEmail) {
    final seed = userEmail != null && userEmail.isNotEmpty 
        ? "$userEmail#$_defaultKeySeed" 
        : _defaultKeySeed;
    // Derive exactly 32 bytes for AES-256
    final bytes = utf8.encode(seed);
    final keyBytes = List<int>.generate(32, (i) => bytes[i % bytes.length]);
    return enc.Key(Uint8List.fromList(keyBytes));
  }

  static enc.IV _deriveIV() {
    final bytes = utf8.encode(_defaultIvSeed);
    final ivBytes = List<int>.generate(16, (i) => bytes[i % bytes.length]);
    return enc.IV(Uint8List.fromList(ivBytes));
  }

  /// Encrypts plain text. Returns prefixed ciphertext "ENC:..."
  static String encrypt(String plainText, String? userEmail) {
    if (plainText.isEmpty) return plainText;
    try {
      final key = _deriveKey(userEmail);
      final iv = _deriveIV();
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return "ENC:${encrypted.base64}";
    } catch (e) {
      return plainText; 
    }
  }

  /// Decrypts cipher text prefixed with "ENC:...".
  static String decrypt(String cipherText, String? userEmail) {
    if (!cipherText.startsWith("ENC:")) return cipherText;
    try {
      final base64Data = cipherText.substring(4);
      final key = _deriveKey(userEmail);
      final iv = _deriveIV();
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt(enc.Encrypted.fromBase64(base64Data), iv: iv);
    } catch (e) {
      return cipherText; // Fallback to raw text if decryption fails
    }
  }
}
