import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_parser_basically/providers/language_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LanguageProvider Unit Tests', () {
    test('Initializes with default locale (en)', () async {
      final provider = LanguageProvider();
      await provider.init();
      expect(provider.currentLocale, 'en');
      expect(provider.translate('nav_home'), 'Home');
    });

    test('Loads saved locale from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_language_locale': 'hi'});
      final provider = LanguageProvider();
      await provider.init();
      expect(provider.currentLocale, 'hi');
      expect(provider.translate('nav_home'), 'होम');
    });

    test('Updates locale and translates correctly', () async {
      final provider = LanguageProvider();
      await provider.init();
      expect(provider.currentLocale, 'en');

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.setLanguage('hi');
      expect(provider.currentLocale, 'hi');
      expect(notified, true);
      expect(provider.translate('nav_home'), 'होम');
    });

    test('All 23 supported locales translate key strings correctly', () async {
      final provider = LanguageProvider();
      await provider.init();
      
      final locales = [
        'en', 'hi', 'as', 'bn', 'brx', 'doi', 'gu', 'kn', 'ks', 'kok',
        'mai', 'ml', 'mni', 'mr', 'ne', 'or', 'pa', 'sa', 'sat', 'sd',
        'ta', 'te', 'ur'
      ];
      
      expect(LanguageProvider.supportedLocales.length, 23);
      for (final locale in locales) {
        await provider.setLanguage(locale);
        expect(provider.currentLocale, locale);
        
        // Assert that translation is found and not falling back to key itself (unless they match, which isn't the case for nav_home)
        final navHomeTrans = provider.translate('nav_home');
        expect(navHomeTrans, isNot('nav_home'));
        expect(navHomeTrans.isNotEmpty, true);
        
        final appTitleTrans = provider.translate('app_title');
        expect(appTitleTrans, isNot('app_title'));
        expect(appTitleTrans.isNotEmpty, true);
      }
    });
  });
}
