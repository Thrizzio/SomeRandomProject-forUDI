class ParsedIncome {
  final double amount;
  final String source;
  final DateTime date;

  ParsedIncome({
    required this.amount,
    required this.source,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'source': source,
        'date': date.toIso8601String(),
      };

  factory ParsedIncome.fromJson(Map<String, dynamic> json) => ParsedIncome(
        amount: (json['amount'] as num).toDouble(),
        source: json['source'] as String,
        date: DateTime.parse(json['date'] as String),
      );

  String get dedupeKey => '${amount}_${source}_${date.millisecondsSinceEpoch}';
}
