import 'package:flutter/material.dart';
import '../../widgets/bank_statement_upload_dialog.dart';
import 'bank_statement_screen.dart';
import '../../services/bank_statement_service.dart';
import 'package:intl/intl.dart';

class BankStatementUploadPage extends StatefulWidget {
  const BankStatementUploadPage({super.key});

  @override
  State<BankStatementUploadPage> createState() =>
      _BankStatementUploadPageState();
}

class _BankStatementUploadPageState extends State<BankStatementUploadPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Bank Statement'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.upload_file_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Import Your Bank Statement',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload a CSV file to track transactions by organization',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Upload Section
              Text(
                'Step 1: Select & Upload File',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Successfully uploaded $count transactions'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            // Navigate to bank statement screen after short delay
                            Future.delayed(const Duration(milliseconds: 500),
                                () {
                              _navigateToBankStatement();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Requirements Section
              Text(
                'File Requirements',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildRequirementItem(
                context,
                Icons.check_circle_outline,
                'CSV Format',
                'File must be in .csv format',
              ),
              _buildRequirementItem(
                context,
                Icons.check_circle_outline,
                'Required Columns',
                'Date, Description, Amount',
              ),
              _buildRequirementItem(
                context,
                Icons.check_circle_outline,
                'Date Format',
                'MM/DD/YYYY or DD/MM/YYYY',
              ),
              _buildRequirementItem(
                context,
                Icons.check_circle_outline,
                'Amount Format',
                'Numeric values (₹ symbol optional)',
              ),
              const SizedBox(height: 24),

              // Supported Organizations Section
              Text(
                'Supported Organizations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildOrganizationChip(context, 'Swiggy'),
              _buildOrganizationChip(context, 'Zomato'),
              _buildOrganizationChip(context, 'Ola'),
              _buildOrganizationChip(context, 'Zepto'),
              const SizedBox(height: 8),
              Text(
                'Select "Others" to add custom organizations',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),

              // Uploaded Transactions Section
              Text(
                'Step 2: View Your Transactions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildUploadedTransactionsPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationChip(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
      child: Chip(
        label: Text(label),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildUploadedTransactionsPreview() {
    return FutureBuilder<List<String>>(
      future: BankStatementService.getUniqueOrganizations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final organizations = snapshot.data ?? [];

        if (organizations.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No transactions uploaded yet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uploaded Organizations',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                ...organizations.map((org) {
                  return FutureBuilder<double>(
                    future:
                        BankStatementService.getTotalIncomeByOrganization(org),
                    builder: (context, incomeSnapshot) {
                      final income = incomeSnapshot.data ?? 0.0;
                      final numFmt = NumberFormat('#,##,##0.00', 'en_IN');

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(org),
                        subtitle: Text(
                          '₹${numFmt.format(income)}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
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
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToBankStatement() {
    // Show bottom sheet to select organization
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.7,
        child: _buildBankStatementBottomSheet(),
      ),
    );
  }

  Widget _buildBankStatementBottomSheet() {
    return FutureBuilder<List<String>>(
      future: BankStatementService.getUniqueOrganizations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final organizations = snapshot.data ?? [];

        if (organizations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(height: 16),
                const Text('No bank statements uploaded yet'),
              ],
            ),
          );
        }

        return Column(
          children: [
            AppBar(
              title: const Text('Select Organization'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: organizations.length,
                itemBuilder: (context, index) {
                  final org = organizations[index];
                  return FutureBuilder<double>(
                    future:
                        BankStatementService.getTotalIncomeByOrganization(org),
                    builder: (context, incomeSnapshot) {
                      final income = incomeSnapshot.data ?? 0.0;
                      final numFmt = NumberFormat('#,##,##0.00', 'en_IN');

                      return ListTile(
                        title: Text(org),
                        subtitle: Text(
                          'Total Income: ₹${numFmt.format(income)}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(context);
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
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
