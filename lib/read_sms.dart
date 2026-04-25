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
import 'services/app_logger.dart';
import 'models/transaction.dart' as app_models;
import 'screens/bank_statement/bank_statement_upload_page.dart';
import 'widgets/error_and_loading_widgets.dart';

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
    
    // Direct matches (high confidence)
    if (lower.contains("swiggy")) return "Swiggy";
    if (lower.contains("zomato")) return "Zomato";
    if (lower.contains("uber")) return "Uber";
    if (lower.contains("ola")) return "Ola";
    if (lower.contains("zepto")) return "Zepto";
    
    // Fuzzy matching as fallback
    return fuzzyMatchSource(text);
  }

  static DateTime? extractDate(SmsMessage message) {
    final ms = message.date;
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static ParsedIncome? parse(SmsMessage message) {
    try {
      final body = message.body ?? "";
      if (body.isEmpty) return null;
      
      // Check if valid income message
      if (!isValidGigIncome(body)) return null;

      // Extract amount with validation
      final amount = extractAmount(body);
      if (amount == null || amount <= 0) return null;

      // Extract date with fallback
      final date = extractDate(message) ?? DateTime.now();

      // Extract source with fuzzy matching
      final source = extractSource(body);
      if (source.isEmpty) return null;

      return ParsedIncome(
        amount: amount.abs(), // Ensure positive
        source: source,
        date: date,
      );
    } catch (e, stackTrace) {
      AppLogger.error('SmsParser', 'SMS parse error', e, stackTrace);
      return null;
    }
  }

  /// Check for duplicate transactions (prevent duplicates)
  static bool isDuplicate(
    ParsedIncome current,
    List<ParsedIncome> existing, {
    Duration tolerance = const Duration(minutes: 5),
  }) {
    for (final prev in existing) {
      // Same amount, source, and within 5 minutes = duplicate
      final timeDiff = current.date.difference(prev.date).abs();
      if (current.amount == prev.amount &&
          current.source == prev.source &&
          timeDiff.inMinutes <= tolerance.inMinutes) {
        return true;
      }
    }
    return false;
  }

  /// Fuzzy match source (handle typos, variations)
  static String fuzzyMatchSource(String text) {
    final lower = text.toLowerCase();
    final sources = {
      'swiggy': ['swiggy', 'swigy', 'swiggi', 'swiggie'],
      'zomato': ['zomato', 'zomto', 'zomata', 'jomato'],
      'uber': ['uber', 'uber eats', 'ubereats', 'uber eat'],
      'ola': ['ola', 'ola cabs', 'olacabs'],
      'zepto': ['zepto', 'zept', 'zepto.in'],
    };

    for (final entry in sources.entries) {
      for (final variant in entry.value) {
        if (lower.contains(variant)) {
          return entry.key;
        }
      }
    }
    return 'Unknown';
  }

  /// Validate transaction quality (return confidence score)
  static double getConfidenceScore(ParsedIncome income) {
    double score = 0.0;

    // Amount validation
    if (income.amount > 50 && income.amount < 50000) score += 0.3;

    // Source confidence
    if (income.source != 'Unknown') score += 0.4;

    // Date confidence (not too old)
    final ageDays = DateTime.now().difference(income.date).inDays;
    if (ageDays < 30) score += 0.3;

    return score;
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
  static const String _tag = 'ReadSmsScreen';

  final Telephony telephony = Telephony.instance;
  final List<ParsedIncome> _incomes = [];
  TaxIntelligenceResult? _taxResult;
  bool _isLoading = true;
  String? _loadingError;

  double get _totalIncome =>
      _incomes.fold(0.0, (sum, item) => sum + item.amount);

  @override
  void initState() {
    super.initState();
    AppLogger.info(_tag, 'Screen initialized');
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      setState(() => _isLoading = true);
      
      await _initializeBankStatementDatabase();
      await _loadSavedTransactions();
      startListening();
      
      setState(() => _isLoading = false);
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Initialization failed', e, stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingError = e.toString();
        });
      }
    }
  }

  Future<void> _initializeBankStatementDatabase() async {
    try {
      AppLogger.info(_tag, 'Initializing bank statement database');
      await BankStatementService.initBankStatementTable();
    } catch (e) {
      AppLogger.error(_tag, 'Failed to initialize bank statement table', e);
      rethrow;
    }
  }

  Future<void> _loadSavedTransactions() async {
    try {
      AppLogger.info(_tag, 'Loading saved transactions');
      
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

      // Combine all transactions with duplicate filtering
      final allIncomes = [...smsIncomes, ...bankIncomes];
      
      // Filter duplicates using enhanced parser
      final uniqueIncomes = <ParsedIncome>[];
      for (final income in allIncomes) {
        if (!SmsParser.isDuplicate(income, uniqueIncomes)) {
          uniqueIncomes.add(income);
        }
      }
      
      uniqueIncomes.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;

      setState(() {
        _incomes
          ..clear()
          ..addAll(uniqueIncomes);

        _taxResult =
            _incomes.isEmpty ? null : TaxIntelligence.analyze(_totalIncome);
      });
      
      AppLogger.info(_tag, 'Loaded ${_incomes.length} transactions');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to load saved transactions', e, stackTrace);
      rethrow;
    }
  }

  double _parseAmountString(String value) {
    try {
      return double.tryParse(
            value.replaceAll(',', '').replaceAll('₹', '').trim(),
          ) ??
          0.0;
    } catch (e) {
      AppLogger.warning(_tag, 'Failed to parse amount: $value');
      return 0.0;
    }
  }

  Future<void> _saveIncomeToDatabase(
    ParsedIncome income, {
    String messageBody = 'Parsed SMS income',
  }) async {
    try {
      AppLogger.info(_tag, 'Saving income to database: ${income.source} - ${income.amount}');
      
      await DatabaseService.insertTransaction(
        app_models.Transaction(
          amount: income.amount.toString(),
          sender: income.source,
          messageBody: messageBody,
          transactionType: 'income',
          date: income.date,
        ),
      );
      
      AppLogger.info(_tag, 'Income saved successfully');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to save transaction', e, stackTrace);
    }
  }

  Future<void> _onNewIncome(
    ParsedIncome income, {
    String messageBody = 'Parsed SMS income',
  }) async {
    try {
      setState(() {
        // Use enhanced duplicate detection
        if (!SmsParser.isDuplicate(income, _incomes)) {
          _incomes.insert(0, income);
          _incomes.sort((a, b) => b.date.compareTo(a.date));
        }

        _taxResult = TaxIntelligence.analyze(_totalIncome);
      });

      await _saveIncomeToDatabase(income, messageBody: messageBody);
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Error processing new income', e, stackTrace);
    }
  }

  void startListening() {
    try {
      AppLogger.info(_tag, 'Starting SMS listener');
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          try {
            final parsed = SmsParser.parse(message);
            if (parsed != null) {
              AppLogger.info(_tag, 'Parsed income: ${parsed.source} - ${parsed.amount}');
              await _onNewIncome(
                parsed,
                messageBody: message.body ?? 'Parsed SMS income',
              );
            }
          } catch (e, stackTrace) {
            AppLogger.error(_tag, 'Error in SMS listener', e, stackTrace);
          }
        },
        listenInBackground: false,
      );
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Failed to start SMS listener', e, stackTrace);
    }
  }

  Future<void> _addManualIncome(double amount, String source) async {
    try {
      AppLogger.info(_tag, 'Adding manual income: $source - $amount');
      
      final income = ParsedIncome(
        amount: amount,
        source: source,
        date: DateTime.now(),
      );
      
      await _onNewIncome(income, messageBody: 'Manual income entry');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Income added successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      AppLogger.info(_tag, 'Manual income added successfully');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'Error adding manual income', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  void _showBankStatementUploadDialog() {
    AppLogger.info(_tag, 'Opening bank statement upload');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BankStatementUploadPage(),
      ),
    );
  }

  void _showAddIncomeDialog() {
    AppLogger.info(_tag, 'Opening add income dialog');
    showDialog(
      context: context,
      builder: (context) => AddIncomeDialog(
        onSave: _addManualIncome,
      ),
    );
  }

  Future<void> _retryLoad() async {
    AppLogger.info(_tag, 'Retrying load');
    await _initializeScreen();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return Scaffold(
        appBar: ProductionAppBar(
          title: 'GigTax',
          actions: widget.appBarActions,
        ),
        body: LoadingIndicator(
          message: 'Loading your transactions...',
        ),
      );
    }

    // Show error state
    if (_loadingError != null) {
      return Scaffold(
        appBar: ProductionAppBar(
          title: 'GigTax',
          actions: widget.appBarActions,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorDisplay(
            error: _loadingError!,
            onRetry: _retryLoad,
            padding: const EdgeInsets.all(16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: ProductionAppBar(
        title: 'GigTax Income Tracker',
        actions: widget.appBarActions,
        centerTitle: true,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add_income',
            onPressed: _showAddIncomeDialog,
            tooltip: 'Add Income Manually',
            backgroundColor: Colors.green.shade600,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'bank_statement',
            onPressed: _showBankStatementUploadDialog,
            tooltip: 'Upload Bank Statement',
            backgroundColor: Colors.blue.shade600,
            child: const Icon(Icons.upload_file, color: Colors.white),
          ),
        ],
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
                            'Recent Transactions (${_incomes.length} total)',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ..._incomes.take(10).map((income) {
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
                        if (_incomes.length > 10)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.lg),
                            child: Text(
                              'And ${_incomes.length - 10} more transactions',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
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
    return EmptyStateWidget(
      title: 'No Income Tracked Yet',
      message: 'Start by uploading a bank statement or adding income manually',
      icon: Icons.inbox_outlined,
      onAction: _showBankStatementUploadDialog,
      actionLabel: 'Upload Statement',
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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