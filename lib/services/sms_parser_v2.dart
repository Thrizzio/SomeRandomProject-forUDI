import '../models/parsed_transaction.dart';
import 'app_logger.dart';
import 'ai_classifier_service.dart';

class SmsParserV2 {
  static const String _tag = 'SmsParserV2';

  // Constants
  static const List<String> supportedPlatforms = [
    'PhonePe',
    'Google Pay',
    'Paytm',
    'Razorpay',
    'Amazon Pay',
    'UPI',
  ];

  static const List<String> supportedBanks = [
    'SBI',
    'HDFC',
    'ICICI',
    'Axis',
    'Kotak',
    'IDFC',
    'BOB',
    'PNB',
  ];

  /// Core entry point to parse a raw SMS body
  static ParsedTransaction? parseMessage(String body, DateTime date, String senderName) {
    try {
      final text = body.trim();
      if (text.isEmpty) return null;

      // 1. Filter out spam, OTPs, debits, marketing, failures
      if (_isSpamOrOtpOrMarketing(text)) {
        AppLogger.debug(_tag, 'Message classified as spam/OTP/marketing: "${text.substring(0, text.length > 30 ? 30 : text.length)}..."');
        return null;
      }

      if (!_isCreditMessage(text)) {
        AppLogger.debug(_tag, 'Message is not a credit: "${text.substring(0, text.length > 30 ? 30 : text.length)}..."');
        return null;
      }

      // 2. Extract Amount
      final amount = _extractAmount(text);
      if (amount == null || amount <= 0) {
        return null;
      }

      // 3. Extract Bank
      final bank = _detectBank(text, senderName);

      // 4. Extract Platform
      final platform = _detectPlatform(text);

      // 5. Extract Transaction Reference/ID
      final reference = _extractReference(text);

      // 6. Source Normalization
      final source = _normalizeSource(text, senderName);

      // 7. Transaction Classification using AI
      final aiResult = AiClassifierService.classify(text, amount: amount, source: source);

      return ParsedTransaction(
        amount: amount,
        sender: senderName,
        platform: platform,
        date: date,
        reference: reference,
        bank: bank,
        rawMessage: text,
        isCredit: true,
        confidence: aiResult.confidence,
        classification: aiResult.classification,
        source: source,
      );
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to parse SMS message', e, stackTrace);
      return null;
    }
  }

  /// Check if the message is credit-only
  static bool _isCreditMessage(String text) {
    final lower = text.toLowerCase();

    // Explicitly reject debited messages
    if (lower.contains('debited') ||
        lower.contains('dr.') ||
        lower.contains('withdrawn') ||
        lower.contains('spent') ||
        lower.contains('paid to') ||
        lower.contains('sent to') ||
        lower.contains('निकाले') ||
        lower.contains('काटे') ||
        lower.contains('डेबिट') ||
        lower.contains('भुगतान')) {
      return false;
    }

    // Credits detection
    final creditIndicators = [
      'credited',
      'received',
      'deposited',
      'refunded',
      'cashback',
      'added to your a/c',
      'added to a/c',
      'cr.',
      'credited to',
      'reversal of',
      'प्राप्त',
      'जमा',
      'खाते में',
      'क्रेडिट',
    ];

    for (final indicator in creditIndicators) {
      if (lower.contains(indicator)) {
        return true;
      }
    }

    return false;
  }

  /// Identify spam, OTP, or marketing patterns
  static bool _isSpamOrOtpOrMarketing(String text) {
    final lower = text.toLowerCase();

    // OTP/Verification codes
    if (lower.contains('otp') ||
        lower.contains('verification code') ||
        lower.contains('security code') ||
        lower.contains('one time password') ||
        lower.contains('code is:')) {
      return true;
    }

    // Failed or declined transactions
    if (lower.contains('failed') ||
        lower.contains('declined') ||
        lower.contains('insufficient balance') ||
        lower.contains('unsuccessful') ||
        lower.contains('limit exceeded')) {
      return true;
    }

    // Marketing/Promotional keyword list
    final marketingKeywords = [
      'pre-approved',
      'loan',
      'apply now',
      'discount',
      'offer',
      'win up to',
      'cashback up to',
      'congratulations',
      'voucher',
      'subscribe',
      'invest now',
    ];

    int matchCount = 0;
    for (final kw in marketingKeywords) {
      if (lower.contains(kw)) {
        matchCount++;
      }
    }
    // If it contains multiple marketing keywords or clear spam indicators, filter out
    if (matchCount >= 2 || (lower.contains('apply') && lower.contains('loan'))) {
      return true;
    }

    return false;
  }

  /// Parse the credited amount
  static double? _extractAmount(String text) {
    final lower = text.toLowerCase();
    
    // Regular expressions for Indian currency credit transactions
    final patterns = [
      RegExp(r'(?:rs|inr|val|amount|रुपये|रूपये)\.?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(?:credited\s+with|credited\s+for|received|deposited|जमा|प्राप्त)\s*(?:rs|inr)?\.?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'([\d,]+(?:\.\d{1,2})?)\s*(?:credited|received|deposited|added|जमा|प्राप्त)', caseSensitive: false),
      RegExp(r'₹\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(lower);
      if (match != null) {
        final val = match.group(1)?.replaceAll(',', '');
        if (val != null) {
          final amt = double.tryParse(val);
          if (amt != null && amt > 0) {
            return amt;
          }
        }
      }
    }

    // Backup general numeric regex
    final generalPattern = RegExp(r'([\d,]+\.\d{2})');
    final match = generalPattern.firstMatch(lower);
    if (match != null) {
      final val = match.group(1)?.replaceAll(',', '');
      if (val != null) {
        return double.tryParse(val);
      }
    }

    return null;
  }

  /// Detect the bank that sent/received the funds
  static String _detectBank(String text, String senderName) {
    final lowerText = text.toLowerCase();
    final lowerSender = senderName.toLowerCase();

    // Prioritize sender name matching
    if (lowerSender.contains('sbi') || lowerSender.contains('state bank')) return 'SBI';
    if (lowerSender.contains('hdfc')) return 'HDFC';
    if (lowerSender.contains('icici')) return 'ICICI';
    if (lowerSender.contains('axis')) return 'Axis';
    if (lowerSender.contains('kotak')) return 'Kotak';
    if (lowerSender.contains('idfc')) return 'IDFC';
    if (lowerSender.contains('bob') || lowerSender.contains('baroda')) return 'BOB';
    if (lowerSender.contains('pnb') || lowerSender.contains('punjab')) return 'PNB';

    // Body text matching using word boundaries to avoid matching UPI VPA domains like "okaxis", "oksbi"
    if (RegExp(r'\bsbi\b|\bstate bank\b').hasMatch(lowerText)) return 'SBI';
    if (RegExp(r'\bhdfc\b').hasMatch(lowerText)) return 'HDFC';
    if (RegExp(r'\bicici\b').hasMatch(lowerText)) return 'ICICI';
    if (RegExp(r'\baxis\b').hasMatch(lowerText)) return 'Axis';
    if (RegExp(r'\bkotak\b').hasMatch(lowerText)) return 'Kotak';
    if (RegExp(r'\bidfc\b').hasMatch(lowerText)) return 'IDFC';
    if (RegExp(r'\bbob\b|\bbaroda\b').hasMatch(lowerText)) return 'BOB';
    if (RegExp(r'\bpnb\b|\bpunjab\b').hasMatch(lowerText)) return 'PNB';

    return 'Unknown';
  }

  /// Detect the UPI platform or payment gateway
  static String _detectPlatform(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('phonepe') || lower.contains('ybl') || lower.contains('ibl')) return 'PhonePe';
    if (lower.contains('gpay') || lower.contains('google pay') || lower.contains('okaxis') || lower.contains('oksbi')) return 'Google Pay';
    if (lower.contains('paytm') || lower.contains('pytm')) return 'Paytm';
    if (lower.contains('razorpay') || lower.contains('rzp')) return 'Razorpay';
    if (lower.contains('amazon pay') || lower.contains('apr')) return 'Amazon Pay';
    if (lower.contains('upi') || lower.contains('vpa') || lower.contains('imps')) return 'UPI';

    return 'NetBanking';
  }

  /// Extract the transaction reference/UPI Ref/IMPS Ref
  static String _extractReference(String text) {
    final lower = text.toLowerCase();
    
    // Regular expressions for transaction references
    final patterns = [
      RegExp(r'upi\s*(?:ref|reference)?\s*(?:no|num)?\.?\s*([a-z0-9]{4,20})', caseSensitive: false),
      RegExp(r'ref(?:\s*no)?\.?\s*:?\s*([a-z0-9]{4,20})', caseSensitive: false),
      RegExp(r'txn\s*(?:id|no)?\.?\s*([a-z0-9]{4,20})', caseSensitive: false),
      RegExp(r'rrn\s*:?\s*(\d{12})', caseSensitive: false),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(lower);
      if (match != null) {
        return match.group(1) ?? '';
      }
    }

    // Default: grab any 12-digit sequence which is standard for UPI RRN
    final rrnMatch = RegExp(r'\b\d{12}\b').firstMatch(text);
    if (rrnMatch != null) {
      return rrnMatch.group(0) ?? '';
    }

    return '';
  }

  /// Source Normalization (e.g. "Swiggy Delivery" -> "Swiggy")
  static String _normalizeSource(String text, String senderName) {
    final lower = (text + ' ' + senderName).toLowerCase();

    final mappings = {
      'Swiggy': ['swiggy', 'swigy', 'swiggi', 'swiggie', 'instamart'],
      'Zomato': ['zomato', 'zomto', 'zomata', 'blinkit'],
      'Uber': ['uber', 'ubereats', 'uber drivers'],
      'Ola': ['ola', 'olacabs', 'ola electric'],
      'Zepto': ['zepto', 'zept'],
      'Urban Company': ['urban company', 'urbanclap', 'uc'],
      'Dunzo': ['dunzo', 'dunz'],
      'Rapido': ['rapido', 'rapid'],
      'Upwork': ['upwork', 'upw'],
      'Fiverr': ['fiverr', 'fivr'],
    };

    for (final entry in mappings.entries) {
      for (final variant in entry.value) {
        if (lower.contains(variant)) {
          return entry.key;
        }
      }
    }

    // Fallback: extract the sender/payer name from the message
    final payPatterns = [
      RegExp(r'transfer\s+from\s+([a-zA-Z\s]+?)\s+to', caseSensitive: false),
      RegExp(r'paid\s+by\s+([a-zA-Z\s]+?)\s+to', caseSensitive: false),
      RegExp(r'sent\s+by\s+([a-zA-Z\s]+?)\s+to', caseSensitive: false),
      RegExp(r'by\s+([a-zA-Z\s]+?)\s+ref', caseSensitive: false),
    ];

    for (final regex in payPatterns) {
      final match = regex.firstMatch(text);
      if (match != null) {
        final name = match.group(1)!.trim();
        if (name.isNotEmpty && name.length < 30) {
          return name;
        }
      }
    }

    return 'Other';
  }

  /// Auto classify transactions based on amount/source patterns
  static String _classifyTransaction(String text, double amount, String source) {
    final lower = text.toLowerCase();
    
    // Gig Income
    final gigSources = ['swiggy', 'zomato', 'uber', 'ola', 'zepto', 'rapido', 'dunzo', 'urban company'];
    if (gigSources.contains(source.toLowerCase())) {
      return 'Gig Income';
    }

    // Freelance Income
    final freelanceSources = ['upwork', 'fiverr', 'toptal', 'freelancer', 'stripe', 'paypal'];
    if (freelanceSources.contains(source.toLowerCase()) || lower.contains('freelance') || lower.contains('consulting')) {
      return 'Freelance Income';
    }

    // Salary
    if (lower.contains('salary') || lower.contains('sal ') || lower.contains('payroll') || lower.contains('stipend')) {
      return 'Salary';
    }

    // Refund
    if (lower.contains('refund') || lower.contains('cashback') || lower.contains('reversal')) {
      return 'Refund';
    }

    // Transfer
    if (lower.contains('self transfer') || lower.contains('transfer from self') || lower.contains('own a/c')) {
      return 'Transfer';
    }

    return 'Other';
  }
}
