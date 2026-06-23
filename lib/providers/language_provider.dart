import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLocale = 'en';

  String get currentLocale => _currentLocale;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLocale = prefs.getString('app_language_locale') ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String locale) async {
    if (locale == _currentLocale) return;
    _currentLocale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language_locale', locale);
    notifyListeners();
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'GigTax',
      'nav_home': 'Home',
      'nav_analytics': 'Analytics',
      'nav_receipts': 'Receipts',
      'nav_tax': 'Tax',
      'nav_settings': 'Settings',
      'settings_title': 'Settings Center',
      'settings_account_info': 'Account Info',
      'settings_member': 'Verified Member',
      'settings_system_toggles': 'System & Toggles',
      'settings_sms_title': 'Automatic SMS Parsing',
      'settings_sms_sub': 'Process financial receipt SMS in the background',
      'settings_imports_title': 'Automatic Statement Imports',
      'settings_imports_sub': 'Allow CSV & text statement conversions',
      'settings_notif_title': 'Save Notification History',
      'settings_notif_sub': 'Store in-app notifications in local history',
      'settings_biometric_title': 'Biometric Lock Screen',
      'settings_biometric_sub': 'Prompt for fingerprint/FaceID on app startup',
      'settings_monetization': 'Monetization & Startup Growth',
      'settings_upgrade': 'Upgrade to GigTax Pro',
      'settings_upgrade_sub': 'Access What-If simulator, local AI tax advisor, and unlimited PDF exports',
      'settings_founder': 'Founder Command Center',
      'settings_founder_sub': 'Real-time startup health, user retention cohorts, support tickets, and performance indicators',
      'settings_support': 'Submit Support Ticket & Feedback',
      'settings_support_sub': 'Rate experience, submit bug reports, feature requests, or contact support',
      'settings_referral': 'Referral Program & Rewards',
      'settings_referral_sub': 'Share your referral code and earn ₹500 in Pro credits',
      'settings_storage': 'Storage & Management',
      'settings_clear_logs': 'Clear Transaction Logs',
      'settings_clear_logs_sub': 'Wipe out all local and cached transactional records',
      'settings_import_mock': 'Import Test Data',
      'settings_import_mock_sub': 'Add 6+ mock transaction receipts for dashboard testing',
      'tax_report_center': 'Tax Report Center (CA-Ready)',
      'tax_report_sub': 'Download dedicated PDF logs matching your business requirements.',
      'tax_generate_btn': 'Generate and Download Report',
    },
    'hi': {
      'app_title': 'गिगटैक्स (GigTax)',
      'nav_home': 'होम',
      'nav_analytics': 'एनालिटिक्स',
      'nav_receipts': 'रसीदें',
      'nav_tax': 'टैक्स',
      'nav_settings': 'सेटिंग्स',
      'settings_title': 'सेटिंग्स केंद्र',
      'settings_account_info': 'खाता जानकारी',
      'settings_member': 'सत्यापित सदस्य',
      'settings_system_toggles': 'सिस्टम और टॉगल',
      'settings_sms_title': 'स्वचालित एसएमएस पार्सिंग',
      'settings_sms_sub': 'बैकग्राउंड में वित्तीय रसीद एसएमएस प्रोसेस करें',
      'settings_imports_title': 'स्वचालित स्टेटमेंट इंपोर्ट',
      'settings_imports_sub': 'CSV और टेक्स्ट स्टेटमेंट कन्वर्शन सक्षम करें',
      'settings_notif_title': 'नोटिफिकेशन हिस्ट्री सहेजें',
      'settings_notif_sub': 'इन-ऐप नोटिफिकेशन को लोकल स्टोरेज में सहेजें',
      'settings_biometric_title': 'बायोमेट्रिक लॉक स्क्रीन',
      'settings_biometric_sub': 'ऐप स्टार्टअप पर फिंगरप्रिंट/FaceID मांगें',
      'settings_monetization': 'मुद्रीकरण और स्टार्टअप विकास',
      'settings_upgrade': 'गिगटैक्स प्रो में अपग्रेड करें',
      'settings_upgrade_sub': 'वॉट-इफ सिम्युलेटर, लोकल एआई टैक्स सलाहकार और अनलिमिटेड PDF एक्सपोर्ट पाएं',
      'settings_founder': 'फाउंडर कमांड सेंटर',
      'settings_founder_sub': 'स्टार्टअप स्वास्थ्य, उपयोगकर्ता प्रतिधारण समूह, समर्थन टिकट और प्रदर्शन संकेतक',
      'settings_support': 'सपोर्ट टिकट और फीडबैक भेजें',
      'settings_support_sub': 'अनुभव को रेट करें, बग रिपोर्ट, फीचर अनुरोध सबमिट करें',
      'settings_referral': 'रेफरल कार्यक्रम और पुरस्कार',
      'settings_referral_sub': 'अपना रेफरल कोड साझा करें और ₹500 प्रो क्रेडिट अर्जित करें',
      'settings_storage': 'स्टोरेज और प्रबंधन',
      'settings_clear_logs': 'लेनदेन लॉग्स साफ करें',
      'settings_clear_logs_sub': 'सभी स्थानीय और कैश्ड लेनदेन रिकॉर्ड हटा दें',
      'settings_import_mock': 'टेस्ट डेटा इंपोर्ट करें',
      'settings_import_mock_sub': 'डैशबोर्ड टेस्टिंग के लिए 6+ मॉक रसीदें जोड़ें',
      'tax_report_center': 'टैक्स रिपोर्ट केंद्र (CA-Ready)',
      'tax_report_sub': 'अपनी व्यावसायिक आवश्यकताओं के अनुसार समर्पित PDF लॉग डाउनलोड करें।',
      'tax_generate_btn': 'रिपोर्ट बनाएं और डाउनलोड करें',
    }
  };

  String translate(String key) {
    return _localizedValues[_currentLocale]?[key] ?? key;
  }
}
