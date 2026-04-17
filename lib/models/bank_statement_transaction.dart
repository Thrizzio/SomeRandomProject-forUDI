class BankStatementTransaction {
  final int? id;
  final String transactionId;
  final String organization;
  final double amount;
  final String description;
  final DateTime transactionDate;
  final String transactionType; // 'income' or 'expense'
  final DateTime uploadedAt;
  final String bankStatementFileName;

  BankStatementTransaction({
    this.id,
    required this.transactionId,
    required this.organization,
    required this.amount,
    required this.description,
    required this.transactionDate,
    required this.transactionType,
    required this.bankStatementFileName,
    DateTime? uploadedAt,
  }) : uploadedAt = uploadedAt ?? DateTime.now();

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transactionId': transactionId,
      'organization': organization,
      'amount': amount,
      'description': description,
      'transactionDate': transactionDate.toIso8601String(),
      'transactionType': transactionType,
      'uploadedAt': uploadedAt.toIso8601String(),
      'bankStatementFileName': bankStatementFileName,
    };
  }

  /// Create from JSON (database retrieval)
  factory BankStatementTransaction.fromJson(Map<String, dynamic> json) {
    return BankStatementTransaction(
      id: json['id'] as int?,
      transactionId: json['transactionId'] as String,
      organization: json['organization'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      transactionType: json['transactionType'] as String,
      bankStatementFileName: json['bankStatementFileName'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );
  }

  /// Copy with method for updates
  BankStatementTransaction copyWith({
    int? id,
    String? transactionId,
    String? organization,
    double? amount,
    String? description,
    DateTime? transactionDate,
    String? transactionType,
    DateTime? uploadedAt,
    String? bankStatementFileName,
  }) {
    return BankStatementTransaction(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      organization: organization ?? this.organization,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionType: transactionType ?? this.transactionType,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      bankStatementFileName: bankStatementFileName ?? this.bankStatementFileName,
    );
  }
}
