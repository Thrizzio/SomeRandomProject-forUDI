class Transaction {
  final String? id; // Firestore document ID
  final String amount;
  final String sender;
  final String messageBody;
  final String transactionType; // 'income' or 'expense'
  final String date; // ISO8601 string for Firestore compatibility
  final String createdAt; // ISO8601 string

  Transaction({
    this.id,
    required this.amount,
    required this.sender,
    required this.messageBody,
    required this.transactionType,
    required this.date,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  /// Validate transaction data
  bool isValid() {
    return amount.isNotEmpty &&
        sender.isNotEmpty &&
        messageBody.isNotEmpty &&
        transactionType.isNotEmpty &&
        date.isNotEmpty;
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'sender': sender,
      'messageBody': messageBody,
      'transactionType': transactionType,
      'date': date,
      'createdAt': createdAt,
    };
  }

  /// Create from JSON (Firestore retrieval)
  factory Transaction.fromJson(Map<String, dynamic> json) {
    try {
      return Transaction(
        id: json['id'] as String?,
        amount: json['amount']?.toString() ?? '',
        sender: json['sender']?.toString() ?? '',
        messageBody: json['messageBody']?.toString() ?? '',
        transactionType: json['transactionType']?.toString() ?? 'income',
        date: json['date']?.toString() ?? DateTime.now().toIso8601String(),
        createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      );
    } catch (e) {
      throw Exception('Failed to parse transaction from JSON: $e');
    }
  }

  /// Copy with method for updates
  Transaction copyWith({
    String? id,
    String? amount,
    String? sender,
    String? messageBody,
    String? transactionType,
    String? date,
    String? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      sender: sender ?? this.sender,
      messageBody: messageBody ?? this.messageBody,
      transactionType: transactionType ?? this.transactionType,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get DateTime from ISO8601 string
  DateTime getDateTime() {
    try {
      return DateTime.parse(date);
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Get createdAt as DateTime
  DateTime getCreatedAtTime() {
    try {
      return DateTime.parse(createdAt);
    } catch (e) {
      return DateTime.now();
    }
  }

  @override
  String toString() =>
      'Transaction(id: $id, amount: $amount, sender: $sender, type: $transactionType, date: $date)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          amount == other.amount &&
          date == other.date;

  @override
  int get hashCode => id.hashCode ^ amount.hashCode ^ date.hashCode;
}
