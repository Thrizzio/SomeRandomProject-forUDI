import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';

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

// --- Add Income Dialog ---

class AddIncomeDialog extends StatefulWidget {
  final Function(double amount, String source) onSave;
  const AddIncomeDialog({required this.onSave, super.key});

  @override
  State<AddIncomeDialog> createState() => _AddIncomeDialogState();
}

class _AddIncomeDialogState extends State<AddIncomeDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _errorMessage = null);

    final amountText = _amountController.text.trim();
    final source = _sourceController.text.trim();

    if (amountText.isEmpty) {
      setState(() => _errorMessage = 'Amount is required');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Enter a valid amount > 0');
      return;
    }

    if (source.isEmpty) {
      setState(() => _errorMessage = 'Source is required');
      return;
    }

    Navigator.pop(context);
    widget.onSave(amount, source);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Income',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: 'e.g., 5000',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sourceController,
              decoration: InputDecoration(
                labelText: 'Source',
                hintText: 'e.g., Freelance, Client',
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.red.shade50,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: const Text('Add'),
                ),
              ],
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

  double get _totalIncome =>
      _incomes.fold(0.0, (sum, item) => sum + item.amount);

  @override
  void initState() {
    super.initState();
    _initializeBankStatementDatabase();
    _loadSavedTransactions();
    startListening();
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

  Future<void> _addManualIncome(double amount, String source) async {
    try {
      final income = ParsedIncome(
        amount: amount,
        source: source,
        date: DateTime.now(),
      );
      await _onNewIncome(income, messageBody: 'Manual income entry');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Income added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
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