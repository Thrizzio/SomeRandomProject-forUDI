class ParsedTransaction {
  final double amount;
  final String sender;
  final String platform; // UPI, PhonePe, GPay, Paytm, Razorpay, Amazon Pay, NetBanking, etc.
  final DateTime date;
  final String reference;
  final String bank; // SBI, HDFC, ICICI, Axis, Kotak, IDFC, BOB, PNB, Unknown
  final String rawMessage;
  final bool isCredit;
  final double confidence; // 0.0 to 1.0
  final String classification; // Gig Income, Freelance Income, Salary, Refund, Transfer, Other
  final String source; // Normalized source name (e.g., Swiggy, Zomato)

  ParsedTransaction({
    required this.amount,
    required this.sender,
    required this.platform,
    required this.date,
    required this.reference,
    required this.bank,
    required this.rawMessage,
    required this.isCredit,
    required this.confidence,
    required this.classification,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'sender': sender,
      'platform': platform,
      'date': date.toIso8601String(),
      'reference': reference,
      'bank': bank,
      'rawMessage': rawMessage,
      'isCredit': isCredit,
      'confidence': confidence,
      'classification': classification,
      'source': source,
    };
  }

  factory ParsedTransaction.fromJson(Map<String, dynamic> json) {
    return ParsedTransaction(
      amount: (json['amount'] as num).toDouble(),
      sender: json['sender'] as String? ?? 'Unknown',
      platform: json['platform'] as String? ?? 'Unknown',
      date: DateTime.parse(json['date'] as String),
      reference: json['reference'] as String? ?? '',
      bank: json['bank'] as String? ?? 'Unknown',
      rawMessage: json['rawMessage'] as String? ?? '',
      isCredit: json['isCredit'] as bool? ?? true,
      confidence: (json['confidence'] as num? ?? 1.0).toDouble(),
      classification: json['classification'] as String? ?? 'Other',
      source: json['source'] as String? ?? 'Unknown',
    );
  }

  ParsedTransaction copyWith({
    double? amount,
    String? sender,
    String? platform,
    DateTime? date,
    String? reference,
    String? bank,
    String? rawMessage,
    bool? isCredit,
    double? confidence,
    String? classification,
    String? source,
  }) {
    return ParsedTransaction(
      amount: amount ?? this.amount,
      sender: sender ?? this.sender,
      platform: platform ?? this.platform,
      date: date ?? this.date,
      reference: reference ?? this.reference,
      bank: bank ?? this.bank,
      rawMessage: rawMessage ?? this.rawMessage,
      isCredit: isCredit ?? this.isCredit,
      confidence: confidence ?? this.confidence,
      classification: classification ?? this.classification,
      source: source ?? this.source,
    );
  }
}
