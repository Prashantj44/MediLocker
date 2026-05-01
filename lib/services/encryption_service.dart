import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  final _storage = const FlutterSecureStorage();

  Future<void> generateAndStoreSecretKey() async {
    final key = encrypt.Key.fromSecureRandom(32);
    await _storage.write(key: 'encryption_key', value: key.base64);
  }

  Future<encrypt.Key?> _getSecretKey() async {
    final key = await _storage.read(key: 'encryption_key');
    if (key == null) return null;
    return encrypt.Key.fromBase64(key);
  }

  Future<String?> encryptData(String plainText) async {
    final key = await _getSecretKey();
    if (key == null) return null;

    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    // Prepend IV for decryption. IV is not secret.
    return '${iv.base64}:${encrypted.base64}';
  }

  Future<String?> decryptData(String encryptedText) async {
    final key = await _getSecretKey();
    if (key == null) return null;

    try {
      final parts = encryptedText.split(':');
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      print("Decryption failed: $e");
      // If decryption fails, it might be unencrypted legacy data.
      // Or the key is wrong. For safety, we return a placeholder.
      return encryptedText; // Fallback to show the raw (likely unencrypted) data
    }
  }
}
