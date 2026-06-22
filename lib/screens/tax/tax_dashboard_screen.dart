import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tax_provider.dart';
import '../../models/tax_profile.dart';
import '../../models/transaction.dart';
import '../../services/report_generator_service.dart';
import '../../services/tax_engine_v2.dart';
import '../../theme/design_system.dart';

class TaxDashboardScreen extends StatefulWidget {
  const TaxDashboardScreen({super.key});

  @override
  State<TaxDashboardScreen> createState() => _TaxDashboardScreenState();
}

class _TaxDashboardScreenState extends State<TaxDashboardScreen> {
  bool _isDark = true;
  bool _isGeneratingReport = false;
  String _selectedReportType = 'income_summary';

  // Simulator state
  double _simulatedIncome = 1200000.0;
  double _simulated80C = 150000.0;
  double _simulated80D = 25000.0;

  // AI Assistant chat state
  String _assistantAnswer = 'Select a question below to consult the AI Tax Assistant:';

  @override
  void initState() {
    super.initState();
    // Initialize simulator default from profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taxProvider = context.read<TaxProvider>();
      setState(() {
        _simulatedIncome = taxProvider.profile.expectedAnnualIncome;
        _simulated80C = taxProvider.profile.deductions.section80C;
        _simulated80D = taxProvider.profile.deductions.section80D;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<TaxProvider>(
      builder: (context, taxProvider, child) {
        if (taxProvider.loading) {
          return const Center(child: CircularProgressIndicator(color: DesignSystem.primary));
        }

        final transactions = taxProvider.transactions;
        if (transactions.isEmpty) {
          return DesignSystem.emptyState(
            context: context,
            title: 'No Incomes Tracked Yet',
            message: 'Import statements or add transactions to compute presumptive tax projections.',
            icon: Icons.receipt_long_outlined,
            isDark: _isDark,
          );
        }

        return Scaffold(
          backgroundColor: _isDark ? DesignSystem.backgroundDark : DesignSystem.backgroundLight,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesignSystem.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Title & Health Score Row
                  _buildHeaderAndHealthScore(taxProvider),
                  const SizedBox(height: DesignSystem.lg),

                  // Tax Profile Configuration Card
                  _buildTaxProfileCard(taxProvider),
                  const SizedBox(height: DesignSystem.lg),

                  // Real-time calculation summary
                  _buildLiveTaxEstimationCard(taxProvider),
                  const SizedBox(height: DesignSystem.lg),

                  // Regime Comparison (Old vs New Slabs)
                  _buildRegimeComparison(taxProvider),
                  const SizedBox(height: DesignSystem.lg),

                  // Compliance warnings
                  _buildCompliancePanel(taxProvider),
                  const SizedBox(height: DesignSystem.lg),

                  // Advance Tax Obligation deadlines tracker
                  _buildAdvanceTaxTracker(taxProvider),
                  const SizedBox(height: DesignSystem.lg),

                  // Deduction Intelligence Breakdown
                  _buildDeductionsIntelligence(taxProvider),
                  const SizedBox(height: DesignSystem.lg),

                  // Interactive Simulator Card
                  _buildWhatIfSimulatorCard(taxProvider),
                  const SizedBox(height: DesignSystem.lg),

                  // Yearly Tax Timeline
                  _buildTaxTimelineCard(),
                  const SizedBox(height: DesignSystem.lg),

                  // Local AI Rule Assistant Box
                  _buildAiAssistantCard(taxProvider),
                  const SizedBox(height: DesignSystem.lg),

                  // Premium Report Download Matrix
                  _buildReportCenterCard(taxProvider),
                  const SizedBox(height: DesignSystem.xl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 1. Header & Health Score widget
  Widget _buildHeaderAndHealthScore(TaxProvider taxProvider) {
    return FutureBuilder<int>(
      future: taxProvider.getTaxHealthScore(),
      builder: (context, snapshot) {
        final score = snapshot.data ?? 75;
        final status = taxProvider.getHealthStatus(score);
        Color healthColor = DesignSystem.success;
        if (status == 'Needs Attention') healthColor = Colors.orange;
        if (status == 'Critical') healthColor = Colors.red;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tax Intelligence V2',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isDark ? Colors.white : Colors.black87,
                      ),
                ),
                const SizedBox(height: DesignSystem.xs),
                const Text(
                  'Indian Presumptive Taxes & Projections',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            
            // Health Score Ring
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: healthColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: healthColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      value: score / 100.0,
                      strokeWidth: 3.5,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      color: healthColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score: $score/100',
                        style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        status,
                        style: TextStyle(color: healthColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 2. Tax Profile Config Box
  Widget _buildTaxProfileCard(TaxProvider taxProvider) {
    final prof = taxProvider.profile;
    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_pin_outlined, color: DesignSystem.primary, size: 20),
                  SizedBox(width: 8),
                  Text('Legislative Tax Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              TextButton.icon(
                onPressed: () => _openProfileEditorSheet(taxProvider),
                icon: const Icon(Icons.edit_outlined, size: 16, color: DesignSystem.primary),
                label: const Text('Edit Settings', style: TextStyle(color: DesignSystem.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: DesignSystem.xs),
          const Divider(color: Colors.grey, height: 1),
          const SizedBox(height: DesignSystem.md),
          
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildProfileDetailColumn('Profession', prof.professionType.toUpperCase()),
              _buildProfileDetailColumn('Business Type', prof.businessType),
              _buildProfileDetailColumn('Tax Regime', '${prof.taxRegime.toUpperCase()} REGIME'),
              _buildProfileDetailColumn('Section', prof.businessCategory == '44ada' ? 'SEC 44ADA (50% presumptive)' : 'SEC 44AD (6% presumptive)'),
              _buildProfileDetailColumn('Expected Annual', '₹${prof.expectedAnnualIncome.toStringAsFixed(0)}'),
              _buildProfileDetailColumn('Profile version', 'v${prof.version}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailColumn(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 9)),
        const SizedBox(height: 3),
        Text(val, style: TextStyle(color: _isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  // 3. Real-time tax estimations
  Widget _buildLiveTaxEstimationCard(TaxProvider taxProvider) {
    final calc = taxProvider.taxCalculationResult;
    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Real-time Tax Estimation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: DesignSystem.xs),
          const Text('Live computation based on actual tracked digital credits.', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: DesignSystem.md),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBigStatColumn('Tracked Credits', '₹${calc.grossIncome.toStringAsFixed(0)}'),
              _buildBigStatColumn('Taxable Net', '₹${calc.netTaxableIncome.toStringAsFixed(0)}'),
              _buildBigStatColumn('Est. Tax Due', '₹${calc.totalTaxDue.toStringAsFixed(0)}', isHighlight: true),
            ],
          ),
          const SizedBox(height: DesignSystem.md),

          // Monthly reserve advice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignSystem.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, color: DesignSystem.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    calc.totalTaxDue > 0 
                        ? 'Reserve ₹${(calc.totalTaxDue / 12.0).toStringAsFixed(0)} this month for your quarterly taxes.'
                        : 'No tax reserve is needed right now because your net profit is below the minimum slab.',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigStatColumn(String title, String val, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 5),
        Text(
          val,
          style: TextStyle(
            color: isHighlight ? DesignSystem.success : (_isDark ? Colors.white : Colors.black87),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // 4. Regime Comparison Table
  Widget _buildRegimeComparison(TaxProvider taxProvider) {
    final comparison = taxProvider.regimeComparison;
    final newRes = comparison['newRegimeResult'] as TaxCalculationResult;
    final oldRes = comparison['oldRegimeResult'] as TaxCalculationResult;
    final savings = comparison['savings'] as double;
    final recommended = comparison['recommendedRegime'] as String;

    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Old vs New Regime Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: DesignSystem.xs),
          const Text('Comparative projection under Finance Act slabs.', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: DesignSystem.md),

          // Slabs comparison grid
          Table(
            border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.2), width: 0.5),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1)),
                children: [
                  _buildHeaderCell('Parameter'),
                  _buildHeaderCell('New Regime'),
                  _buildHeaderCell('Old Regime'),
                ],
              ),
              TableRow(
                children: [
                  _buildBodyCell('Net Taxable'),
                  _buildBodyCell('₹${newRes.netTaxableIncome.toStringAsFixed(0)}'),
                  _buildBodyCell('₹${oldRes.netTaxableIncome.toStringAsFixed(0)}'),
                ],
              ),
              TableRow(
                children: [
                  _buildBodyCell('Tax Rate (Eff)'),
                  _buildBodyCell('${newRes.effectiveTaxRate.toStringAsFixed(1)}%'),
                  _buildBodyCell('${oldRes.effectiveTaxRate.toStringAsFixed(1)}%'),
                ],
              ),
              TableRow(
                children: [
                  _buildBodyCell('Rebate 87A'),
                  _buildBodyCell('₹${newRes.rebate87A.toStringAsFixed(0)}'),
                  _buildBodyCell('₹${oldRes.rebate87A.toStringAsFixed(0)}'),
                ],
              ),
              TableRow(
                children: [
                  _buildBodyCell('Total Tax'),
                  _buildBodyCell('₹${newRes.totalTaxDue.toStringAsFixed(0)}', isBold: true),
                  _buildBodyCell('₹${oldRes.totalTaxDue.toStringAsFixed(0)}', isBold: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: DesignSystem.md),

          // Detailed Recommendation Explanation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DesignSystem.success.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DesignSystem.success.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: DesignSystem.success, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Recommendation: Use ${recommended.toUpperCase()} Regime',
                      style: const TextStyle(color: DesignSystem.success, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  comparison['explanation'] as String,
                  style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String t) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _buildBodyCell(String t, {bool isBold = false}) => Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 10,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: _isDark ? Colors.white70 : Colors.black87,
      ),
    ),
  );

  // 5. Compliance Warning Card
  Widget _buildCompliancePanel(TaxProvider taxProvider) {
    final check = taxProvider.complianceCheck;
    if (check['isExceeded'] == false) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_outlined, color: Colors.red, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMPLIANCE SLAB EXCEEDED',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  check['message'] as String,
                  style: const TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. Advance Tax Obligations Tracker
  Widget _buildAdvanceTaxTracker(TaxProvider taxProvider) {
    final list = taxProvider.advanceTaxInstallments;
    final totalDue = taxProvider.taxCalculationResult.totalTaxDue;

    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quarterly Advance Tax Obligations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: DesignSystem.xs),
          const Text('Track legal deadline obligations under Section 208/211.', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: DesignSystem.md),

          ...list.map((inst) {
            final isPassed = inst['status'] == 'passed';
            final Color itemColor = isPassed ? Colors.grey : DesignSystem.primary;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inst['installment'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _isDark ? Colors.white70 : Colors.black87)),
                      Text('Due by: ${inst['dueDate']}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '₹${(inst['cumulativeAmount'] as double).toStringAsFixed(0)} (${(inst['percentage'] as double).toStringAsFixed(0)}%)',
                        style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: itemColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPassed ? 'PASSED' : 'UPCOMING',
                          style: TextStyle(color: itemColor, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 7. Deduction Intelligence Card
  Widget _buildDeductionsIntelligence(TaxProvider taxProvider) {
    final prof = taxProvider.profile;
    final total = prof.deductions.getTotalDeductions();

    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Deduction Intelligence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(
                'Total: ₹${total.toStringAsFixed(0)}',
                style: const TextStyle(color: DesignSystem.success, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: DesignSystem.xs),
          const Text('Track personal deductions u/s 80C, 80D, and NPS.', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: DesignSystem.md),

          _buildDeductionRow('Section 80C (PPF, ELSS, PF)', prof.deductions.section80C, 150000.0),
          _buildDeductionRow('Section 80D (Health Premium)', prof.deductions.section80D, 50000.0),
          _buildDeductionRow('Section 80CCD(1B) (NPS)', prof.deductions.npsSection80CCD1B, 50000.0),
          _buildDeductionRow('Section 24b (Home Loan Interest)', prof.deductions.homeLoanInterest, 200000.0),
        ],
      ),
    );
  }

  Widget _buildDeductionRow(String title, double val, double cap) {
    final pct = cap > 0 ? (val / cap) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              Text('₹${val.toStringAsFixed(0)} / ₹${cap.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _isDark ? Colors.white70 : Colors.black87)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: pct > 1.0 ? 1.0 : pct,
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            color: DesignSystem.success,
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  // 8. What-If Simulator Card
  Widget _buildWhatIfSimulatorCard(TaxProvider taxProvider) {
    final simulated = taxProvider.simulateWhatIf(_simulatedIncome, TaxDeductions(section80C: _simulated80C, section80D: _simulated80D));
    final diff = simulated['taxDifference'] as double;
    final recRegime = simulated['recommendedRegime'] as String;

    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What-If Income Simulator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: DesignSystem.xs),
          const Text('Simulate impact of higher income or deductions on tax liability.', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: DesignSystem.md),

          // Sliding inputs
          Text('Simulated Annual Income: ₹${_simulatedIncome.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Slider(
            min: 300000.0,
            max: 3000000.0,
            divisions: 27,
            activeColor: DesignSystem.primary,
            value: _simulatedIncome,
            onChanged: (val) {
              setState(() {
                _simulatedIncome = val;
              });
            },
          ),

          Text('Simulated 80C Deductions: ₹${_simulated80C.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Slider(
            min: 0.0,
            max: 200000.0,
            divisions: 20,
            activeColor: DesignSystem.success,
            value: _simulated80C,
            onChanged: (val) {
              setState(() {
                _simulated80C = val;
              });
            },
          ),

          const SizedBox(height: DesignSystem.md),

          // Simulation outputs
          Table(
            border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.15), width: 0.5),
            children: [
              TableRow(
                children: [
                  _buildBodyCell('Rec. Regime'),
                  _buildBodyCell(recRegime.toUpperCase()),
                ],
              ),
              TableRow(
                children: [
                  _buildBodyCell('Difference'),
                  _buildBodyCell(
                    diff > 0 
                        ? '+₹${diff.toStringAsFixed(0)} (Increase)'
                        : '₹${diff.toStringAsFixed(0)} (Decrease)',
                    isBold: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 9. Tax Timeline Card
  Widget _buildTaxTimelineCard() {
    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tax Timeline & Key Milestones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: DesignSystem.xs),
          const Text('Indian financial year milestones & deadlines.', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: DesignSystem.md),

          _buildTimelineMilestone('April 1', 'Financial Year (FY) Begins', true),
          _buildTimelineMilestone('June 15', '1st Advance Tax Installment (15%)', false),
          _buildTimelineMilestone('September 15', '2nd Advance Tax Installment (45%)', false),
          _buildTimelineMilestone('December 15', '3rd Advance Tax Installment (75%)', false),
          _buildTimelineMilestone('March 15', '4th Advance Tax Installment (100%)', false),
          _buildTimelineMilestone('July 31', 'ITR-4 Filing Deadline', false),
        ],
      ),
    );
  }

  Widget _buildTimelineMilestone(String date, String title, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? DesignSystem.success : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 10),
          Text(
            '$date: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: DesignSystem.primary),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 11, color: _isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // 10. AI Tax Assistant Box
  Widget _buildAiAssistantCard(TaxProvider taxProvider) {
    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.smart_toy_outlined, color: DesignSystem.primary, size: 20),
              SizedBox(width: 8),
              Text('AI Tax Assistant (Local Rules)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: DesignSystem.md),

          // Message Answer box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _assistantAnswer,
              style: TextStyle(color: _isDark ? Colors.white70 : Colors.black87, fontSize: 11, height: 1.4),
            ),
          ),
          const SizedBox(height: DesignSystem.md),

          // Question list buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuestionButton('Explain my estimates?', () {
                final calc = taxProvider.taxCalculationResult;
                setState(() {
                  _assistantAnswer = 'Based on your gross receipts of ₹${calc.grossIncome.toStringAsFixed(0)}, the presumptive profit margin calculates to ₹${calc.netTaxableIncome.toStringAsFixed(0)}. Under the ${calc.regimeName}, slab-wise taxes accumulate to ₹${calc.taxBeforeCess.toStringAsFixed(0)}, plus a 4% Health and Education Cess (₹${calc.cess.toStringAsFixed(0)}), yielding a total tax due of ₹${calc.totalTaxDue.toStringAsFixed(0)}.';
                });
              }),
              _buildQuestionButton('Why this regime?', () {
                final comparison = taxProvider.regimeComparison;
                setState(() {
                  _assistantAnswer = comparison['explanation'] as String;
                });
              }),
              _buildQuestionButton('What are my deductions?', () {
                final prof = taxProvider.profile;
                final total = prof.deductions.getTotalDeductions();
                setState(() {
                  _assistantAnswer = 'Your configured deductions include: 80C (₹${prof.deductions.section80C.toStringAsFixed(0)}), 80D (₹${prof.deductions.section80D.toStringAsFixed(0)}), NPS (₹${prof.deductions.npsSection80CCD1B.toStringAsFixed(0)}), Home Loan Interest (₹${prof.deductions.homeLoanInterest.toStringAsFixed(0)}). Total deductions applied is ₹${total.toStringAsFixed(0)}. Under New Regime, these deductions are ignored u/s 115BAC.';
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionButton(String text, VoidCallback onPressed) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: DesignSystem.primary)),
      backgroundColor: DesignSystem.primary.withValues(alpha: 0.05),
      onPressed: onPressed,
    );
  }

  // 11. Report Center Card
  Widget _buildReportCenterCard(TaxProvider taxProvider) {
    final user = context.watch<AuthProvider>().user;
    final userEmail = user?.email ?? 'freelancer@gigtax.in';

    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tax Report Center (CA-Ready)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: DesignSystem.xs),
          const Text('Download dedicated PDF logs matching your business requirements.', style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: DesignSystem.md),

          // Dropdown selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReportType,
                isExpanded: true,
                dropdownColor: _isDark ? DesignSystem.cardDark : Colors.white,
                items: const [
                  DropdownMenuItem(value: 'income_summary', child: Text('Income Ledger Summary', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'annual_tax', child: Text('Annual Tax Legislative Report', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'quarterly_tax', child: Text('Quarterly Advance Tax Report', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'client_revenue', child: Text('Client Revenue Concentration', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'source_revenue', child: Text('UPI & Channel Contribution', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedReportType = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: DesignSystem.md),

          // Download action
          Center(
            child: DesignSystem.gradientButton(
              text: 'Generate and Download Report',
              isLoading: _isGeneratingReport,
              icon: Icons.download_outlined,
              onPressed: () async {
                setState(() => _isGeneratingReport = true);
                final File? report = await ReportGeneratorService.generatePdfReport(
                  transactions: taxProvider.transactions,
                  userEmail: userEmail,
                  totalIncome: taxProvider.totalIncome,
                  taxableIncome: taxProvider.taxCalculationResult.netTaxableIncome,
                  taxPayable: taxProvider.taxCalculationResult.totalTaxDue,
                  totalExpenses: taxProvider.totalExpenses,
                  reportType: _selectedReportType,
                  taxProfile: taxProvider.profile,
                );
                
                await taxProvider.markReportGenerated();
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

  // Edit Tax Profile Sheet
  void _openProfileEditorSheet(TaxProvider taxProvider) {
    final prof = taxProvider.profile;
    final double expectedIncome = prof.expectedAnnualIncome;
    String profession = prof.professionType;
    String businessCat = prof.businessCategory;
    String regime = prof.taxRegime;
    String businessType = prof.businessType;

    // Deductions controllers
    final controller80C = TextEditingController(text: prof.deductions.section80C.toStringAsFixed(0));
    final controller80D = TextEditingController(text: prof.deductions.section80D.toStringAsFixed(0));
    final controllerNPS = TextEditingController(text: prof.deductions.npsSection80CCD1B.toStringAsFixed(0));
    final controllerHome = TextEditingController(text: prof.deductions.homeLoanInterest.toStringAsFixed(0));
    final controllerExpected = TextEditingController(text: expectedIncome.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? DesignSystem.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Tax Profile & Slabs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: DesignSystem.md),

                    // Expected Annual Income
                    TextField(
                      controller: controllerExpected,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Expected Annual Income (₹)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: DesignSystem.md),

                    // Profession select
                    DropdownButtonFormField<String>(
                      value: profession,
                      decoration: const InputDecoration(labelText: 'Profession Category', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'freelancer', child: Text('Freelancer')),
                        DropdownMenuItem(value: 'consultant', child: Text('Consultant')),
                        DropdownMenuItem(value: 'developer', child: Text('Software Developer')),
                        DropdownMenuItem(value: 'delivery', child: Text('Delivery Partner')),
                        DropdownMenuItem(value: 'gig', child: Text('Gig Worker')),
                        DropdownMenuItem(value: 'self_employed', child: Text('Self Employed')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            profession = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: DesignSystem.md),

                    // Tax Regime select
                    DropdownButtonFormField<String>(
                      value: regime,
                      decoration: const InputDecoration(labelText: 'Tax Regime', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'new', child: Text('New Regime (Default u/s 115BAC)')),
                        DropdownMenuItem(value: 'old', child: Text('Old Regime')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            regime = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: DesignSystem.md),

                    // Business Category (presumptive scheme) select
                    DropdownButtonFormField<String>(
                      value: businessCat,
                      decoration: const InputDecoration(labelText: 'Presumptive Section Code', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: '44ada', child: Text('Section 44ADA (Professional)')),
                        DropdownMenuItem(value: '44ad', child: Text('Section 44AD (Business / Gig)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            businessCat = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: DesignSystem.md),

                    // Business Type name
                    TextField(
                      decoration: const InputDecoration(labelText: 'Business / Service Type', border: OutlineInputBorder()),
                      onChanged: (val) {
                        businessType = val;
                      },
                      controller: TextEditingController(text: businessType),
                    ),
                    const SizedBox(height: DesignSystem.md),

                    // Deductions u/s 80C, 80D, NPS
                    const Text('Deductions Configuration (Old Regime Only)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: DesignSystem.sm),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller80C,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '80C (PPF/ELSS)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: controller80D,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '80D (Health)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignSystem.sm),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controllerNPS,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'NPS (80CCD)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: controllerHome,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Home Loan Int (24b)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignSystem.md),

                    // Save action
                    Center(
                      child: DesignSystem.gradientButton(
                        text: 'Save and Apply Settings',
                        onPressed: () async {
                          final updatedDeductions = TaxDeductions(
                            section80C: double.tryParse(controller80C.text) ?? 0.0,
                            section80D: double.tryParse(controller80D.text) ?? 0.0,
                            npsSection80CCD1B: double.tryParse(controllerNPS.text) ?? 0.0,
                            homeLoanInterest: double.tryParse(controllerHome.text) ?? 0.0,
                          );

                          final updatedProfile = prof.copyWith(
                            professionType: profession,
                            taxRegime: regime,
                            businessCategory: businessCat,
                            expectedAnnualIncome: double.tryParse(controllerExpected.text) ?? 600000.0,
                            businessType: businessType,
                            deductions: updatedDeductions,
                          );

                          await taxProvider.updateProfile(updatedProfile);
                          if (mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
