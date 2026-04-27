import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bank_statement_transaction.dart';
import '../../services/app_logger.dart';
import '../../services/bank_statement_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/error_and_loading_widgets.dart';

class BankStatementScreen extends StatefulWidget {
  final String organization;

  const BankStatementScreen({
    super.key,
    required this.organization,
  });

  @override
  State<BankStatementScreen> createState() => _BankStatementScreenState();
}

class _BankStatementScreenState extends State<BankStatementScreen> {
  static const String _tag = 'BankStatementScreen';
  late Future<List<BankStatementTransaction>> _transactionsFuture;
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');
  final _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    AppLogger.info(_tag, 'Loading organization: ${widget.organization}');
    _transactionsFuture =
        BankStatementService.getTransactionsByOrganization(widget.organization);
  }

  Future<void> _retryLoad() async {
    AppLogger.info(_tag, 'Retry loading for ${widget.organization}');
    setState(() {
      _transactionsFuture =
          BankStatementService.getTransactionsByOrganization(widget.organization);
    });
  }

  double _calculateIncome(List<BankStatementTransaction> transactions) {
    return transactions.fold(
      0.0,
      (sum, transaction) =>
          transaction.transactionType == 'income'
              ? sum + transaction.amount
              : sum,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProductionAppBar(
        title: '${widget.organization} - Bank Statement',
      ),
      body: FutureBuilder<List<BankStatementTransaction>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading transactions...');
          }

          if (snapshot.hasError) {
            AppLogger.error(
              _tag,
              'Failed loading transactions for ${widget.organization}',
              snapshot.error,
            );
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ErrorDisplay(
                error: 'Error loading transactions: ${snapshot.error}',
                onRetry: _retryLoad,
              ),
            );
          }

          final transactions = snapshot.data ?? [];

          if (transactions.isEmpty) {
            return EmptyStateWidget(
              title: 'No transactions found',
              message: 'No payments received from ${widget.organization}',
              icon: Icons.receipt_long_outlined,
              onAction: _retryLoad,
              actionLabel: 'Refresh',
            );
          }

          final totalIncome = _calculateIncome(transactions);

          return SingleChildScrollView(
            child: Column(
              children: [
                // Summary Cards
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      _buildSummaryCard(
                        context,
                        title: 'Total Transactions',
                        value: transactions.length.toString(),
                        color: Colors.blue,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildSummaryCard(
                        context,
                        title: 'Total Income',
                        value: '₹${_numFmt.format(totalIncome)}',
                        color: Colors.green,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Transaction Details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),

                // Transactions List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      return _buildTransactionCard(context, transaction);
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color.withOpacity(0.4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    BankStatementTransaction transaction,
  ) {
    final isIncome = transaction.transactionType == 'income';
    final color = isIncome ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _dateFmt.format(transaction.transactionDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${_numFmt.format(transaction.amount)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isIncome ? 'Income' : 'Expense',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: color,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (transaction.transactionId.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ID: ${transaction.transactionId.substring(0, 20)}...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
