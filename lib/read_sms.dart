import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:intl/intl.dart';

import 'tax-intelligence/index.dart';
import 'widgets/transaction_card.dart';
import 'widgets/tax_health_card.dart';
import 'widgets/suggestion_card.dart';
import 'widgets/income_summary_card.dart';
import 'theme/app_spacing.dart';
import 'services/database_service.dart';
import 'models/transaction.dart' as app_models;

// --- Model ---

class ParsedIncome {
  final double amount;
  final String source;
  final DateTime date;

  ParsedIncome({
    required this.amount,
    required this.source,
    required this.date,
  });
}

// --- Parser ---

class SmsParser {
  static bool isIncomeMessage(String body) {
    final text = body.toLowerCase();
    if (text.contains("debited") ||
        text.contains("dr.") ||
        text.contains("spent") ||
        text.contains("withdrawn")) {
      return false;
    }
    return text.contains("credited") ||
        text.contains("received") ||
        text.contains("deposited") ||
        text.contains("cr.");
  }

  static bool isGigIncome(String body) {
    final text = body.toLowerCase();
    return text.contains("swiggy") ||
        text.contains("zomato") ||
        text.contains("uber") ||
        text.contains("ola") ||
        text.contains("zepto") ||
        text.contains("earnings") ||
        text.contains("payout") ||
        text.contains("settlement");
  }

  static bool isValidGigIncome(String body) {
    return isIncomeMessage(body) && isGigIncome(body);
  }

  static double? extractAmount(String text) {
    final patterns = [
      RegExp(r'₹\s?([\d,]+(?:\.\d{1,2})?)'),
      RegExp(r'inr\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'rs\.?\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)!.replaceAll(",", "");
        return double.tryParse(raw);
      }
    }
    return null;
  }

  static String extractSource(String text) {
    final lower = text.toLowerCase();
    if (lower.contains("swiggy")) return "Swiggy";
    if (lower.contains("zomato")) return "Zomato";
    if (lower.contains("uber")) return "Uber";
    if (lower.contains("ola")) return "Ola";
    if (lower.contains("zepto")) return "Zepto";
    if (lower.contains("amazon")) return "Amazon";
    if (lower.contains("techcorp")) return "TechCorp";
    if (lower.contains("freelance")) return "Freelance";
    if (lower.contains("interior")) return "Interior Design";
    // Extract sender name from "from <name>" or "to <name>" patterns
    final fromMatch = RegExp(r'from\s+([A-Za-z]+)').firstMatch(lower);
    if (fromMatch != null) {
      final name = fromMatch.group(1) ?? "Unknown";
      return name[0].toUpperCase() + name.substring(1);
    }
    final toMatch = RegExp(r'to\s+([A-Za-z]+)').firstMatch(lower);
    if (toMatch != null) {
      final name = toMatch.group(1) ?? "Unknown";
      return name[0].toUpperCase() + name.substring(1);
    }
    return "Unknown";
  }

  static DateTime? extractDate(SmsMessage message) {
    final ms = message.date;
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static ParsedIncome? parse(SmsMessage message) {
    final body = message.body ?? "";
    if (!isValidGigIncome(body)) return null;

    final amount = extractAmount(body);
    if (amount == null) return null;

    final date = extractDate(message);
    if (date == null) return null;

    return ParsedIncome(
      amount: amount,
      source: extractSource(body),
      date: date,
    );
  }
}

// --- Production SMS Model ---

class ParsedSms {
  final String source;
  final double amount;
  final bool isCredit;

  ParsedSms({
    required this.source,
    required this.amount,
    required this.isCredit,
  });
}

// --- Demo SMS Screen (Production-Ready) ---

class DemoSmsListScreen extends StatefulWidget {
  const DemoSmsListScreen({super.key});

  @override
  State<DemoSmsListScreen> createState() => _DemoSmsListScreenState();
}

class _DemoSmsListScreenState extends State<DemoSmsListScreen> {
  late final List<ParsedSms> _cachedTransactions;

  @override
  void initState() {
    super.initState();
    _cachedTransactions = _parseDemoMessages();
  }

  static const List<String> _demoMessages = [
    "Acct XX123 credited with Rs. 5,000 from SWIGGY on 15 Apr. Avl bal Rs. 25,490",
    "INR 2,500 received via UPI from FreelanceClient. Ref: 234567. Bal Rs. 27,990",
    "₹1,200 debited for fuel. Txn ID: 998877. Avl balance Rs. 24,790",
    "ZOMATO order of ₹850 debited from your account. Bal Rs. 23,940",
    "₹12,500 transferred to UBER. Ref no: 556677. Balance Rs. 11,440",
    "Payment of Rs. 3,200 to AMAZON successful. Avl bal Rs. 8,240",
    "Rs. 8,000 credited from UBER weekly payout. Ref: 778899. Bal Rs. 16,240",
    "INR 15,000 received for freelance project. Txn ID: 112233. Bal Rs. 31,240",
    "₹5,500 bank transfer received from CLIENT. Avl Rs. 36,740",
    "Rs. 25,000 credited for Interior Design project. Ref: 445566. Bal Rs. 61,740",
    "UPI received ₹3,750 from HARPREET. UPI Ref: 667788. Bal Rs. 65,490",
    "SWIGGY delivery earnings: Rs. 4,200 credited. Avl Rs. 69,690",
    "₹2,100 debited for ZOMATO subscription. Txn ID: 889900. Bal Rs. 67,590",
    "Rs. 18,000 credited from TECHCORP freelance payment. Ref: 223344. Bal Rs. 85,590",
    "UPI transfer INR 1,500 to SHARMA. Ref: 998822. Avl Rs. 84,090",
  ];

  /// Parse all demo messages safely, skipping any that fail
  List<ParsedSms> _parseDemoMessages() {
    final results = <ParsedSms>[];

    for (int i = 0; i < _demoMessages.length; i++) {
      final message = _demoMessages[i];
      try {
        final amount = SmsParser.extractAmount(message);
        
        // Skip if amount extraction fails
        if (amount == null || amount <= 0) {
          continue;
        }

        final isCredit = SmsParser.isIncomeMessage(message);
        final source = SmsParser.extractSource(message);

        results.add(
          ParsedSms(
            source: source,
            amount: amount,
            isCredit: isCredit,
          ),
        );
      } catch (e, stackTrace) {
        // Safely skip any parsing errors
        debugPrint('Parse error at message ${i + 1}: $e\n$stackTrace');
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _cachedTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Demo'),
        elevation: 0,
      ),
      body: transactions.isEmpty
          ? Center(
              child: Text(
                'No transactions parsed',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final txn = transactions[index];
                return _buildTransactionTile(txn);
              },
            ),
    );
  }

  Widget _buildTransactionTile(ParsedSms txn) {
    final textColor = txn.isCredit ? Colors.green.shade700 : Colors.red.shade700;
    final bgColor =
        txn.isCredit ? Colors.green.shade50 : Colors.red.shade50;
    final amountPrefix = txn.isCredit ? '+' : '−';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.source,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    txn.isCredit ? 'Income' : 'Expense',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$amountPrefix₹${txn.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Screen ---

class ReadSmsScreen extends StatefulWidget {
  const ReadSmsScreen({
    super.key,
    this.appBarActions,
  });

  final List<Widget>? appBarActions;

  @override
  State<ReadSmsScreen> createState() => _ReadSmsScreenState();
}

class _ReadSmsScreenState extends State<ReadSmsScreen> {
  final Telephony telephony = Telephony.instance;
  final List<ParsedIncome> _incomes = [];
  TaxIntelligenceResult? _taxResult;

  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');
  final _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  double get _totalIncome =>
      _incomes.fold(0.0, (sum, item) => sum + item.amount);

  @override
  void initState() {
    super.initState();
    _loadSavedTransactions();
    startListening();
  }

  Future<void> _loadSavedTransactions() async {
    try {
      final transactions =
          await DatabaseService.getTransactionsByType('income');

      final loadedIncomes = transactions.map((t) {
        return ParsedIncome(
          amount: _parseAmountString(t.amount),
          source: t.sender,
          date: t.date,
        );
      }).toList();

      loadedIncomes.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;

      setState(() {
        _incomes
          ..clear()
          ..addAll(loadedIncomes);

        _taxResult = _incomes.isEmpty
            ? null
            : TaxIntelligence.analyze(_totalIncome);
      });
    } catch (e) {
      debugPrint('Failed to load saved transactions: $e');
    }
  }

  double _parseAmountString(String value) {
    return double.tryParse(
          value.replaceAll(',', '').replaceAll('₹', '').trim(),
        ) ??
        0.0;
  }

  Future<void> _saveIncomeToDatabase(ParsedIncome income,
      {String messageBody = 'Parsed SMS income'}) async {
    try {
      await DatabaseService.insertTransaction(
        app_models.Transaction(
          amount: income.amount.toString(),
          sender: income.source,
          messageBody: messageBody,
          transactionType: 'income',
          date: income.date,
        ),
      );
    } catch (e) {
      debugPrint('Failed to save transaction: $e');
    }
  }

  Future<void> _onNewIncome(ParsedIncome income,
      {String messageBody = 'Parsed SMS income'}) async {
    setState(() {
      final alreadyExists = _incomes.any(
        (item) =>
            item.amount == income.amount &&
            item.source == income.source &&
            item.date.millisecondsSinceEpoch ==
                income.date.millisecondsSinceEpoch,
      );

      if (!alreadyExists) {
        _incomes.insert(0, income);
        _incomes.sort((a, b) => b.date.compareTo(a.date));
      }

      _taxResult = TaxIntelligence.analyze(_totalIncome);
    });

    await _saveIncomeToDatabase(income, messageBody: messageBody);
  }

  void startListening() {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        final parsed = SmsParser.parse(message);
        if (parsed != null) {
          await _onNewIncome(
            parsed,
            messageBody: message.body ?? 'Parsed SMS income',
          );
        }
      },
      listenInBackground: false,
    );
  }

  Future<void> _injectTestSms(String body) async {
    final amount = SmsParser.extractAmount(body);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Parser couldn't extract amount")),
      );
      return;
    }

    await _onNewIncome(
      ParsedIncome(
        amount: amount,
        source: SmsParser.extractSource(body),
        date: DateTime.now(),
      ),
      messageBody: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gig Income Tracker"),
        actions: widget.appBarActions,
      ),
      body: _incomes.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _testBtn(
                                "Swiggy ₹850",
                                "Your account has been credited with ₹850.00. Payment received from Swiggy settlement.",
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _testBtn(
                                "Zomato ₹1200",
                                "INR 1,200.50 credited to your account. Zomato payout for week ending 10-Apr-2025.",
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _testBtn(
                                "Uber ₹450",
                                "Rs. 450 deposited to your a/c. Uber earnings settlement.",
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        IncomeSummaryCard(
                          count: _incomes.length,
                          total: _totalIncome,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Recent Transactions',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ..._incomes.take(5).map((income) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: TransactionCard(
                              source: income.source,
                              amount: income.amount,
                              date: income.date,
                            ),
                          );
                        }),
                        if (_incomes.length > 5)
                          const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                  if (_taxResult != null) _buildTaxSection(_taxResult!),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline,
              size: 48,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No income tracked yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'We\'ll monitor your SMS and automatically detect income deposits.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Or test with sample transactions:',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _testBtn(
                    "Add Swiggy",
                    "Your account has been credited with ₹850.00. Payment received from Swiggy settlement.",
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _testBtn(
                    "Add Zomato",
                    "INR 1,200.50 credited to your account. Zomato payout for week ending 10-Apr-2025.",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxSection(TaxIntelligenceResult result) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaxHealthCard(
            grossIncome: result.totalIncome,
            taxableIncome: result.taxableIncome,
            taxPayable: result.taxPayable,
          ),
          if (result.suggestions.isNotEmpty)
            const SizedBox(height: AppSpacing.lg),
          if (result.suggestions.isNotEmpty)
            _buildSuggestionsSection(result),
        ],
      ),
    );
  }

  Widget _buildSuggestionsSection(TaxIntelligenceResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tips & Recommendations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        ...result.suggestions.map((suggestion) {
          final type = _getSuggestionType(suggestion);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: SuggestionCard(
              suggestion: suggestion,
              type: type,
            ),
          );
        }),
      ],
    );
  }

  SuggestionType _getSuggestionType(String suggestion) {
    final lower = suggestion.toLowerCase();
    if (lower.contains('rebate') ||
        lower.contains('eligible') ||
        lower.contains('zero')) {
      return SuggestionType.positive;
    }
    if (lower.contains('advance') ||
        lower.contains('warning') ||
        lower.contains('high')) {
      return SuggestionType.warning;
    }
    return SuggestionType.info;
  }

  Widget _testBtn(String label, String sms) {
    return ElevatedButton(
      onPressed: () => _injectTestSms(sms),
      child: Text(label),
    );
  }
}