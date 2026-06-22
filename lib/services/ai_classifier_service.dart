class AiClassificationResult {
  final String classification; // 'Gig Income', 'Freelance Income', 'Salary', 'Personal', 'Refund', 'Other'
  final double confidence;

  AiClassificationResult({
    required this.classification,
    required this.confidence,
  });
}

class AiClassifierService {
  /// Local AI-based transaction classification using advanced heuristics,
  /// term weights, and context clues.
  static AiClassificationResult classify(String text, {double? amount, String? source}) {
    final lowerText = text.toLowerCase();
    final lowerSource = source?.toLowerCase() ?? '';

    // 1. Gig Platforms (Highest Confidence)
    final gigKeywords = ['uber', 'ola', 'swiggy', 'zomato', 'zepto', 'rapido', 'dunzo', 'urban company', 'blinkit', 'instamart'];
    for (final platform in gigKeywords) {
      if (lowerText.contains(platform) || lowerSource.contains(platform)) {
        return AiClassificationResult(
          classification: 'Gig Income',
          confidence: 0.98,
        );
      }
    }

    // 2. Freelance / Client Indicators
    final freelanceKeywords = ['upwork', 'fiverr', 'toptal', 'freelancer', 'stripe', 'paypal', 'consulting', 'invoice', 'milestone payout', 'contractor'];
    for (final kw in freelanceKeywords) {
      if (lowerText.contains(kw) || lowerSource.contains(kw)) {
        return AiClassificationResult(
          classification: 'Freelance Income',
          confidence: 0.95,
        );
      }
    }

    // 3. Salary Payouts
    final salaryKeywords = ['salary', 'sal ', 'payroll', 'stipend', 'wages', 'credited by employer'];
    for (final kw in salaryKeywords) {
      if (lowerText.contains(kw)) {
        return AiClassificationResult(
          classification: 'Salary',
          confidence: 0.92,
        );
      }
    }

    // 4. Refunds / Cashbacks
    final refundKeywords = ['refund', 'cashback', 'reversal', 'failed payment credit', 'returned funds'];
    for (final kw in refundKeywords) {
      if (lowerText.contains(kw)) {
        return AiClassificationResult(
          classification: 'Refund',
          confidence: 0.90,
        );
      }
    }

    // 5. Personal / Self Transfers (Income vs Personal thresholding)
    // Keywords indicating transfers from family/friends or between own accounts
    final personalKeywords = [
      'mom', 'dad', 'brother', 'sister', 'family', 'friend', 'rent', 'split',
      'gift', 'pocket money', 'transfer from self', 'self transfer', 'own a/c',
      'sent by dad', 'sent by mom'
    ];
    for (final kw in personalKeywords) {
      if (lowerText.contains(kw)) {
        return AiClassificationResult(
          classification: 'Personal',
          confidence: 0.88,
        );
      }
    }

    // 6. Generic or ambiguous credits
    // Heuristic: If it's a standard peer-to-peer UPI transfer with no business indicators,
    // it's highly likely to be Personal rather than Gig/Freelance income.
    if (lowerText.contains('upi') || lowerText.contains('gpay') || lowerText.contains('phonepe') || lowerText.contains('paytm')) {
      // If amount is small (e.g. < 500) and no other info, categorize as Personal
      if (amount != null && amount < 500) {
        return AiClassificationResult(
          classification: 'Personal',
          confidence: 0.75,
        );
      }
      return AiClassificationResult(
          classification: 'Personal',
          confidence: 0.65,
      );
    }

    // Default Fallback
    return AiClassificationResult(
      classification: 'Other',
      confidence: 0.50,
    );
  }
}
