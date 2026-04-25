import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_logger.dart';
import '../../services/bank_statement_service.dart';
import '../../widgets/bank_statement_upload_dialog.dart';
import '../../widgets/error_and_loading_widgets.dart';
import 'bank_statement_screen.dart';

class BankStatementUploadPage extends StatefulWidget {
  const BankStatementUploadPage({super.key});

  @override
  State<BankStatementUploadPage> createState() =>
      _BankStatementUploadPageState();
}

class _BankStatementUploadPageState extends State<BankStatementUploadPage> {
  static const String _tag = 'BankStatementUploadPage';

  Future<void> _retryLoad() async {
    if (mounted) setState(() {});
  }

  void _navigateToBankStatement() {
    AppLogger.info(_tag, 'Returning to previous screen after upload');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProductionAppBar(
        title: 'Upload Bank Statement',
        onBack: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.upload_file_rounded,
                        size: 40,
                        color: Colors.deepPurple.shade600,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Import Your Bank Statement',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload a CSV file to track transactions by organization',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Step 1: Select & Upload File',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 48,
                        color: Colors.deepPurple.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Click below to select and upload your bank statement CSV file',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      BankStatementUploadDialog(
                        onUploadComplete: (count) {
                          if (count > 0) {
                            AppLogger.info(_tag, 'Uploaded $count transactions');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Successfully uploaded $count transactions',
                                ),
                                backgroundColor: Colors.green.shade600,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              _navigateToBankStatement,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Step 2: View Your Transactions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildUploadedTransactionsPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadedTransactionsPreview() {
    return FutureBuilder<List<String>>(
      future: BankStatementService.getUniqueOrganizations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator(message: 'Loading organizations...');
        }

        if (snapshot.hasError) {
          AppLogger.error(_tag, 'Error loading organizations', snapshot.error);
          return ErrorDisplay(
            error: 'Failed to load organizations: ${snapshot.error}',
            onRetry: _retryLoad,
          );
        }

        final organizations = snapshot.data ?? [];

        if (organizations.isEmpty) {
          return const EmptyStateWidget(
            title: 'No Transactions Uploaded Yet',
            message: 'Upload a bank statement CSV file to get started',
            icon: Icons.inbox_outlined,
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uploaded Organizations (${organizations.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                ...organizations.map((org) {
                  return FutureBuilder<double>(
                    future: BankStatementService.getTotalIncomeByOrganization(org),
                    builder: (context, incomeSnapshot) {
                      final income = incomeSnapshot.data ?? 0.0;
                      final numFmt = NumberFormat('#,##,##0.00', 'en_IN');

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(org),
                        subtitle: Text(
                          '₹${numFmt.format(income)}',
                          style: TextStyle(
                            color: Colors.deepPurple.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          AppLogger.info(_tag, 'Viewing org: $org');
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BankStatementScreen(organization: org),
                            ),
                          );
                        },
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
