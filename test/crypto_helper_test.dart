import 'package:flutter_test/flutter_test.dart';
import 'package:sms_parser_basically/utils/crypto_helper.dart';

void main() {
  group('CryptoHelper Unit Tests', () {
    const testEmail = 'user@gigtax.in';
    const rawText = 'Credited INR 5000.00 from Swiggy';

    test('Encrypts and decrypts string successfully for a user email', () {
      final encrypted = CryptoHelper.encrypt(rawText, testEmail);
      expect(encrypted, startsWith('ENC:'));
      expect(encrypted, isNot(rawText));

      final decrypted = CryptoHelper.decrypt(encrypted, testEmail);
      expect(decrypted, rawText);
    });

    test('Derived keys are email-isolated', () {
      final encryptedUser1 = CryptoHelper.encrypt(rawText, 'user1@gigtax.in');
      final decryptedUser2 = CryptoHelper.decrypt(encryptedUser1, 'user2@gigtax.in');
      
      // Decryption with wrong email should fail/mismatch or return fallback
      expect(decryptedUser2, isNot(rawText));
    });

    test('Returns original text if not prefixed with ENC:', () {
      const plainText = 'Not encrypted string';
      final decrypted = CryptoHelper.decrypt(plainText, testEmail);
      expect(decrypted, plainText);
    });

    test('Handles empty string encryption gracefully', () {
      final encrypted = CryptoHelper.encrypt('', testEmail);
      expect(encrypted, '');
    });
  });
}
