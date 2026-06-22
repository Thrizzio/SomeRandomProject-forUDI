import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/transaction.dart';
import '../../services/firestore_service.dart';
import '../../services/database_service.dart';
import '../../services/insights_engine.dart';
import '../../services/notification_service.dart';
import '../../theme/design_system.dart';
import '../bank_statement/bank_statement_upload_page.dart';
import '../../widgets/suggestion_card.dart';
import '../../services/tax_engine_v2.dart';
import '../../services/tax_profile_service.dart';
import '../../models/tax_profile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  final FirestoreService _firestore = FirestoreService();
  bool _isDark = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController.forward();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Run milestone validation once data has loaded
    final txs = await _fetchTransactions();
    final double total = txs.fold(0.0, (sum, t) {
      return sum + (double.tryParse(t.amount.replaceAll(',', '').replaceAll('INR', '').trim()) ?? 0.0);
    });
    await NotificationService.checkMilestones(total);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<List<Transaction>> _fetchTransactions() async {
    try {
      // Fetch Firestore transactions. Fallback to local SQLite if unavailable/offline.
      final firestoreTxs = await _firestore.getTransactions().timeout(
        const Duration(seconds: 2),
        onTimeout: () => [],
      );
      if (firestoreTxs.isNotEmpty) {
        return firestoreTxs;
      }
      return await DatabaseService.getAllTransactions();
    } catch (_) {
      return await DatabaseService.getAllTransactions();
    }
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    try {
      final transactions = await _fetchTransactions();
      final profile = await TaxProfileService.getProfile();
      return {
        'transactions': transactions,
        'profile': profile,
      };
    } catch (e) {
      return {
        'transactions': <Transaction>[],
        'profile': TaxProfile.defaultProfile(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: _isDark ? DesignSystem.backgroundDark : DesignSystem.backgroundLight,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _fetchDashboardData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: DesignSystem.primary));
            }
            if (snapshot.hasError) {
              return DesignSystem.emptyState(
                context: context,
                title: 'Something went wrong',
                message: snapshot.error.toString(),
                icon: Icons.error_outline,
                isDark: _isDark,
              );
            }

            final data = snapshot.data ?? {};
            final List<Transaction> transactions = data['transactions'] as List<Transaction>? ?? [];
            final TaxProfile profile = data['profile'] as TaxProfile? ?? TaxProfile.defaultProfile();

            if (transactions.isEmpty) {
              return _buildEmptyState();
            }

            return _buildDashboardContent(transactions, profile);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return DesignSystem.emptyState(
      context: context,
      title: 'Track Your First Income',
      message: 'Enable automatic SMS tracking or upload a bank statement to start monitoring your earnings.',
      icon: Icons.account_balance_wallet_outlined,
      actionLabel: 'Upload Bank Statement',
      onAction: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BankStatementUploadPage()),
        ).then((_) => setState(() {}));
      },
      isDark: _isDark,
    );
  }

  Widget _buildDashboardContent(List<Transaction> transactions, TaxProfile profile) {
    final now = DateTime.now();
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    double thisMonthIncome = 0.0;
    double thisYearIncome = 0.0;

    for (final tx in transactions) {
      final double amt = double.tryParse(
            tx.amount.replaceAll(',', '').replaceAll('INR', '').trim(),
          ) ??
          0.0;
      if (tx.transactionType == 'expense') {
        totalExpenses += amt;
      } else {
        totalIncome += amt;

        final txDate = DateTime.tryParse(tx.date) ?? now;
        if (txDate.year == now.year && txDate.month == now.month) {
          thisMonthIncome += amt;
        }
        if (txDate.year == now.year) {
          thisYearIncome += amt;
        }
      }
    }

    // Dynamic Tax Projection using TaxEngineV2 with expense deduction
    final taxResult = TaxEngineV2.calculateTax(
      grossIncome: totalIncome,
      profile: profile,
      totalExpenses: totalExpenses,
    );
    final double estimatedTax = taxResult.totalTaxDue;

    // Monthly Growth Trend (This Month vs Previous Month)
    double lastMonthIncome = 0.0;
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    for (final tx in transactions) {
      if (tx.transactionType == 'expense') continue;
      final txDate = DateTime.tryParse(tx.date) ?? now;
      if ((txDate.isAfter(lastMonthStart) || txDate.isAtSameMomentAs(lastMonthStart)) &&
          txDate.isBefore(lastMonthEnd)) {
        final double amt = double.tryParse(
              tx.amount.replaceAll(',', '').replaceAll('INR', '').trim(),
            ) ??
            0.0;
        lastMonthIncome += amt;
      }
    }

    final double growthPct = lastMonthIncome > 0 
        ? ((thisMonthIncome - lastMonthIncome) / lastMonthIncome) * 100 
        : 0.0;

    // Dynamic Insights from engine
    final insights = InsightsEngine.generateInsights(transactions);

    return FadeTransition(
      opacity: _fadeController,
      child: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(DesignSystem.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              _buildHeader(),
              const SizedBox(height: DesignSystem.lg),

              // KPI Premium Cards Grid
              _buildKpiGrid(totalIncome, totalExpenses, thisMonthIncome, thisYearIncome, estimatedTax, profile),
              const SizedBox(height: DesignSystem.lg),

              // Growth percentage alert
              if (growthPct.abs() > 0) _buildGrowthBanner(growthPct),
              const SizedBox(height: DesignSystem.md),

              // Dynamic Insights section
              if (insights.isNotEmpty) ...[
                Text(
                  'Dynamic Earnings Insights',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isDark ? Colors.white : Colors.black87,
                      ),
                ),
                const SizedBox(height: DesignSystem.sm),
                _buildInsightsCarousel(insights),
                const SizedBox(height: DesignSystem.lg),
              ],

              // Earnings Milestone Goals
              _buildMilestoneGoalTracker(totalIncome),
              const SizedBox(height: DesignSystem.lg),

              // Recent Activity section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Receipts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isDark ? Colors.white : Colors.black87,
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to Transaction center tab
                    },
                    child: const Text('View All', style: TextStyle(color: DesignSystem.primary)),
                  ),
                ],
              ),
              const SizedBox(height: DesignSystem.sm),
              _buildRecentReceiptsList(transactions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = context.watch<AuthProvider>().user;
    final String displayName = user?.email?.split('@')[0] ?? 'Freelancer';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $displayName 👋',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isDark ? Colors.white : Colors.black87,
                  ),
            ),
            const SizedBox(height: DesignSystem.xs),
            const Text(
              'Here is your live earnings dashboard',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh_outlined, color: DesignSystem.primary),
          onPressed: () => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(double total, double totalExpenses, double month, double year, double tax, TaxProfile profile) {
    final comparison = TaxEngineV2.compareRegimes(
      grossIncome: total,
      profile: profile,
      totalExpenses: totalExpenses,
    );

    final otherRegime = profile.taxRegime == 'new' ? 'Old' : 'New';
    final otherTax = profile.taxRegime == 'new' 
        ? comparison['oldRegimeResult'].totalTaxDue 
        : comparison['newRegimeResult'].totalTaxDue;

    return Column(
      children: [
        // Giant primary glassmorphism card
        DesignSystem.glassCard(
          isDark: _isDark,
          borderRadius: 24,
          padding: const EdgeInsets.all(DesignSystem.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.monetization_on_outlined, color: DesignSystem.success),
                  SizedBox(width: 8),
                  Text(
                    'TOTAL TRACKED INCOME',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: DesignSystem.sm),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignSystem.md),
        Row(
          children: [
            Expanded(
              child: _buildSubKpiCard(
                'This Month',
                '₹${month.toStringAsFixed(0)}',
                Icons.calendar_today_outlined,
                DesignSystem.primary,
              ),
            ),
            const SizedBox(width: DesignSystem.md),
            Expanded(
              child: _buildSubKpiCard(
                'Expenses Logged',
                '₹${totalExpenses.toStringAsFixed(0)}',
                Icons.trending_down_outlined,
                DesignSystem.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignSystem.md),
        
        // Interactive Tax Regime Card with Toggle comparison
        DesignSystem.glassCard(
          isDark: _isDark,
          padding: const EdgeInsets.all(DesignSystem.md),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: DesignSystem.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.percent_outlined, color: DesignSystem.warning, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tax Liability (${profile.taxRegime.toUpperCase()})',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: DesignSystem.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () async {
                      final newRegime = profile.taxRegime == 'new' ? 'old' : 'new';
                      final updated = profile.copyWith(taxRegime: newRegime);
                      await TaxProfileService.saveProfile(updated);
                      setState(() {});
                    },
                    child: Text(
                      'Use ${otherRegime} Regime',
                      style: const TextStyle(fontSize: 11, color: DesignSystem.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${tax.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                  Text(
                    '${otherRegime} Regime: ₹${otherTax.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 16),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: DesignSystem.primary, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      comparison['savings'] > 0
                          ? 'Recommendation: Use ${comparison['recommendedRegime'].toString().toUpperCase()} Regime to save ₹${comparison['savings'].toStringAsFixed(0)}!'
                          : 'Both regimes yield the same tax liability.',
                      style: TextStyle(
                        color: comparison['recommendedRegime'] == profile.taxRegime ? DesignSystem.success : DesignSystem.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubKpiCard(String title, String value, IconData icon, Color accent, {bool isFullWidth = false}) {
    return DesignSystem.glassCard(
      isDark: _isDark,
      padding: const EdgeInsets.symmetric(horizontal: DesignSystem.md, vertical: 12),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: DesignSystem.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: _isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthBanner(double growth) {
    final isPositive = growth >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: (isPositive ? DesignSystem.success : DesignSystem.error).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isPositive ? DesignSystem.success : DesignSystem.error).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isPositive ? DesignSystem.success : DesignSystem.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPositive
                  ? 'Your income increased by ${growth.toStringAsFixed(1)}% compared to last month!'
                  : 'Your income decreased by ${growth.abs().toStringAsFixed(1)}% compared to last month.',
              style: TextStyle(
                color: isPositive ? DesignSystem.success : DesignSystem.error,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCarousel(List<DynamicInsight> insights) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: insights.length,
        itemBuilder: (context, index) {
          final insight = insights[index];
          final color = insight.type == 'success'
              ? DesignSystem.success
              : (insight.type == 'warning' ? DesignSystem.warning : DesignSystem.primary);

          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: DesignSystem.md),
            child: DesignSystem.glassCard(
              isDark: _isDark,
              borderRadius: 14,
              padding: const EdgeInsets.all(DesignSystem.md),
              child: Row(
                children: [
                  Icon(
                    insight.type == 'success'
                        ? Icons.check_circle_outline
                        : (insight.type == 'warning' ? Icons.warning_amber_outlined : Icons.info_outline),
                    color: color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      insight.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMilestoneGoalTracker(double totalIncome) {
    const nextGoal = 100000.0;
    final progress = (totalIncome / nextGoal).clamp(0.0, 1.0);

    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Earning Goals',
                style: TextStyle(
                  color: _isDark ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: DesignSystem.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: DesignSystem.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: _isDark ? Colors.white10 : Colors.black12,
              valueColor: const AlwaysStoppedAnimation<Color>(DesignSystem.primary),
            ),
          ),
          const SizedBox(height: DesignSystem.sm),
          Text(
            '₹${totalIncome.toStringAsFixed(0)} / ₹${nextGoal.toStringAsFixed(0)} towards your ₹1 Lakh Milestone!',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReceiptsList(List<Transaction> transactions) {
    final list = transactions.take(5).toList();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final tx = list[index];
        final amount = double.tryParse(tx.amount.replaceAll(',', '').replaceAll('INR', '').trim()) ?? 0.0;

        return Card(
          color: _isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: DesignSystem.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: DesignSystem.primary.withValues(alpha: 0.1),
              child: Text(
                tx.sender.isNotEmpty ? tx.sender[0].toUpperCase() : '?',
                style: const TextStyle(color: DesignSystem.primary, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              tx.sender,
              style: TextStyle(
                color: _isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              tx.date.substring(0, 10),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: Text(
              '+₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(color: DesignSystem.success, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        );
      },
    );
  }
}
