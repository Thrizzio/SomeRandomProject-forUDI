import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../providers/auth_provider.dart';
import '../../models/transaction.dart';
import '../../services/firestore_service.dart';
import '../../services/database_service.dart';
import '../../services/report_generator_service.dart';
import '../../theme/design_system.dart';

class TaxDashboardScreen extends StatefulWidget {
  const TaxDashboardScreen({super.key});

  @override
  State<TaxDashboardScreen> createState() => _TaxDashboardScreenState();
}

class _TaxDashboardScreenState extends State<TaxDashboardScreen> {
  final FirestoreService _firestore = FirestoreService();
  bool _isDark = true;
  bool _isGeneratingReport = false;

  Future<List<Transaction>> _fetchTransactions() async {
    try {
      final firestoreTxs = await _firestore.getTransactions().timeout(
        const Duration(seconds: 2),
        onTimeout: () => [],
      );
      if (firestoreTxs.isNotEmpty) return firestoreTxs;
      return await DatabaseService.getAllTransactions();
    } catch (_) {
      return await DatabaseService.getAllTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _isDark ? DesignSystem.backgroundDark : DesignSystem.backgroundLight,
      body: SafeArea(
        child: FutureBuilder<List<Transaction>>(
          future: _fetchTransactions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: DesignSystem.primary));
            }
            if (snapshot.hasError) {
              return DesignSystem.emptyState(
                context: context,
                title: 'Tax Dashboard Load Error',
                message: snapshot.error.toString(),
                icon: Icons.percent_outlined,
                isDark: _isDark,
              );
            }

            final transactions = snapshot.data ?? [];
            if (transactions.isEmpty) {
              return DesignSystem.emptyState(
                context: context,
                title: 'No Data for Tax Estimate',
                message: 'Start importing invoices or bank receipts to view presumptive tax estimations.',
                icon: Icons.receipt_long_outlined,
                isDark: _isDark,
              );
            }

            return _buildTaxContent(transactions);
          },
        ),
      ),
    );
  }

  Widget _buildTaxContent(List<Transaction> transactions) {
    final user = context.watch<AuthProvider>().user;
    final userEmail = user?.email ?? 'freelancer@gigtax.in';

    double totalIncome = 0.0;
    for (final tx in transactions) {
      final double amt = double.tryParse(
            tx.amount.replaceAll(',', '').replaceAll('INR', '').trim(),
          ) ??
          0.0;
      totalIncome += amt;
    }

    // Presumptive Tax Calculation logic:
    // 1. 44AD (6% presumptive profit margin on digital collections)
    final double profit44ad = totalIncome * 0.06;
    final double tax44ad = profit44ad > 250000 ? (profit44ad - 250000) * 0.05 : 0.0;

    // 2. 44ADA (50% presumptive profit margin for freelancers/professionals)
    final double profit44ada = totalIncome * 0.5;
    final double tax44ada = profit44ada > 250000 ? (profit44ada - 250000) * 0.05 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignSystem.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          Text(
            'Tax Intelligence',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isDark ? Colors.white : Colors.black87,
                ),
          ),
          const SizedBox(height: DesignSystem.xs),
          const Text(
            'India Presumptive Tax Projections',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: DesignSystem.lg),

          // Core calculations cards comparison
          _buildComparisonCards(totalIncome, profit44ad, tax44ad, profit44ada, tax44ada),
          const SizedBox(height: DesignSystem.lg),

          // Detail Slab card explaining 44AD vs 44ADA
          _buildInfoPanel(),
          const SizedBox(height: DesignSystem.lg),

          // Download PDF report block
          _buildReportGeneratorBlock(transactions, userEmail, totalIncome, profit44ada, tax44ada),
        ],
      ),
    );
  }

  Widget _buildComparisonCards(double total, double profitAD, double taxAD, double profitADA, double taxADA) {
    return Column(
      children: [
        // Section 44ADA (Professionals/Freelancers) - Recommended
        DesignSystem.glassCard(
          isDark: _isDark,
          borderRadius: 20,
          border: Border.all(color: DesignSystem.primary.withValues(alpha: 0.3), width: 1.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Section 44ADA (Recommended)',
                    style: TextStyle(color: DesignSystem.primary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignSystem.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Freelancers', style: TextStyle(color: DesignSystem.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: DesignSystem.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCalculationColumn('Gross Receipts', '₹${total.toStringAsFixed(0)}'),
                  _buildCalculationColumn('Presumptive Profit (50%)', '₹${profitADA.toStringAsFixed(0)}'),
                  _buildCalculationColumn('Estimated Tax', '₹${taxADA.toStringAsFixed(0)}', isHighlighted: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignSystem.md),

        // Section 44AD (Gig Delivery / Businesses)
        DesignSystem.glassCard(
          isDark: _isDark,
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Section 44AD',
                    style: TextStyle(color: _isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Gig Delivery', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: DesignSystem.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCalculationColumn('Gross Receipts', '₹${total.toStringAsFixed(0)}'),
                  _buildCalculationColumn('Presumptive Profit (6%)', '₹${profitAD.toStringAsFixed(0)}'),
                  _buildCalculationColumn('Estimated Tax', '₹${taxAD.toStringAsFixed(0)}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalculationColumn(String title, String value, {bool isHighlighted = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 9)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isHighlighted ? DesignSystem.success : (_isDark ? Colors.white : Colors.black87),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(DesignSystem.md),
      decoration: BoxDecoration(
        color: DesignSystem.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignSystem.primary.withValues(alpha: 0.1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: DesignSystem.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Presumptive Taxation Scheme Tip',
                style: TextStyle(color: DesignSystem.primary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: DesignSystem.sm),
          Text(
            'Under section 44ADA (for professional designers, developers, writers), you only need to declare 50% of your earnings as profits, saving you from maintenance of complete accounting logbooks.',
            style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildReportGeneratorBlock(
    List<Transaction> transactions,
    String email,
    double total,
    double taxable,
    double tax,
  ) {
    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Premium PDF Report Center',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: DesignSystem.xs),
          const Text(
            'Generate a signed financial ledger containing full client metrics and tax slab deductions.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: DesignSystem.md),
          Center(
            child: DesignSystem.gradientButton(
              text: 'Download & Share Report',
              isLoading: _isGeneratingReport,
              icon: Icons.share_outlined,
              onPressed: () async {
                setState(() => _isGeneratingReport = true);
                final File? report = await ReportGeneratorService.generatePdfReport(
                  transactions: transactions,
                  userEmail: email,
                  totalIncome: total,
                  taxableIncome: taxable,
                  taxPayable: tax,
                );
                setState(() => _isGeneratingReport = false);

                 if (report != null) {
                  await ReportGeneratorService.shareReport(report);
                } else if (kIsWeb) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report downloaded successfully!')),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report generation failed.')),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
