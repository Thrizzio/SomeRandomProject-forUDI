import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import 'tax-intelligence/index.dart';
import 'widgets/transaction_card.dart';
import 'widgets/tax_health_card.dart';
import 'widgets/suggestion_card.dart';
import 'widgets/income_summary_card.dart';
import 'theme/app_spacing.dart';
import 'services/database_service.dart';
import 'services/bank_statement_service.dart';
import 'models/transaction.dart' as app_models;
import 'screens/bank_statement/bank_statement_upload_page.dart';

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

@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage message) async {
  try {
    final parsed = SmsParser.parse(message);
    if (parsed == null) return;

    await DatabaseService.insertTransaction(
      app_models.Transaction(
        amount: parsed.amount.toString(),
        sender: parsed.source,
        messageBody: message.body ?? 'Parsed SMS income',
        transactionType: 'income',
        date: parsed.date,
      ),
    );
  } catch (e) {
    debugPrint('Background SMS handler failed: $e');
  }
}

class _ReadSmsScreenState extends State<ReadSmsScreen>
    with WidgetsBindingObserver {
  final Telephony telephony = Telephony.instance;
  final List<ParsedIncome> _incomes = [];
  TaxIntelligenceResult? _taxResult;

  double get _totalIncome =>
      _incomes.fold(0.0, (sum, item) => sum + item.amount);

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _initializeBankStatementDatabase();
  _loadSavedTransactions();
  startListening();
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _loadSavedTransactions();
  }
}

  Future<void> _initializeBankStatementDatabase() async {
    try {
      await BankStatementService.initBankStatementTable();
    } catch (e) {
      debugPrint('Failed to initialize bank statement table: $e');
    }
  }

  Future<void> _loadSavedTransactions() async {
    try {
      // Load SMS transactions
      final smsTransactions =
          await DatabaseService.getTransactionsByType('income');

      final smsIncomes = smsTransactions.map((t) {
        return ParsedIncome(
          amount: _parseAmountString(t.amount),
          source: t.sender,
          date: t.date,
        );
      }).toList();

      // Load bank statement transactions - ALL organizations
      final bankStatementTransactions =
          await BankStatementService.getAllTransactions();

      final bankIncomes = bankStatementTransactions.map((t) {
        return ParsedIncome(
          amount: t.amount,
          source: t.organization,
          date: t.transactionDate,
        );
      }).toList();

      // Combine all transactions
      final allIncomes = [...smsIncomes, ...bankIncomes];
      allIncomes.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;

      setState(() {
        _incomes
          ..clear()
          ..addAll(allIncomes);

        _taxResult =
            _incomes.isEmpty ? null : TaxIntelligence.analyze(_totalIncome);
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

  Future<void> _saveIncomeToDatabase(
    ParsedIncome income, {
    String messageBody = 'Parsed SMS income',
  }) async {
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

 Future<void> _onNewIncome(
  ParsedIncome income, {
  String messageBody = 'Parsed SMS income',
}) async {
  final alreadyExists = _incomes.any(
    (item) =>
        item.amount == income.amount &&
        item.source == income.source &&
        item.date.millisecondsSinceEpoch ==
            income.date.millisecondsSinceEpoch,
  );

  if (alreadyExists) return;

  setState(() {
    _incomes.insert(0, income);
    _incomes.sort((a, b) => b.date.compareTo(a.date));
    _taxResult = TaxIntelligence.analyze(_totalIncome);
  });

  await _saveIncomeToDatabase(income, messageBody: messageBody);
}

  Future<void> startListening() async {
  final bool? permissionsGranted =
      await telephony.requestPhoneAndSmsPermissions;

  if (permissionsGranted != true) {
    debugPrint('SMS permissions not granted');
    return;
  }

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
    onBackgroundMessage: smsBackgroundHandler,
    listenInBackground: true,
  );
}

void _showBankStatementUploadDialog() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const BankStatementUploadPage(),
    ),
  );
}

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Gig Income Tracker"),
      actions: widget.appBarActions,
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _showBankStatementUploadDialog,
      tooltip: 'Upload Bank Statement',
      child: const Icon(Icons.add),
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

                      Text(
                        'Rendered items: ${_incomes.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      ..._incomes.map((income) {
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
                      }).toList(),
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
}