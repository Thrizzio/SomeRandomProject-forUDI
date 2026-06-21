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
                title: 'Something went wrong',
                message: snapshot.error.toString(),
                icon: Icons.error_outline,
                isDark: _isDark,
              );
            }

            final transactions = snapshot.data ?? [];
            if (transactions.isEmpty) {
              return _buildEmptyState();
            }

            return _buildDashboardContent(transactions);
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

  Widget _buildDashboardContent(List<Transaction> transactions) {
    final now = DateTime.now();
    double totalIncome = 0.0;
    double thisMonthIncome = 0.0;
    double thisYearIncome = 0.0;

    for (final tx in transactions) {
      final double amt = double.tryParse(
            tx.amount.replaceAll(',', '').replaceAll('INR', '').trim(),
          ) ??
          0.0;
      totalIncome += amt;

      final txDate = DateTime.tryParse(tx.date) ?? now;
      if (txDate.year == now.year && txDate.month == now.month) {
        thisMonthIncome += amt;
      }
      if (txDate.year == now.year) {
        thisYearIncome += amt;
      }
    }

    // Dynamic Tax Projection Heuristic: 44ADA (Freelancers in India can declare 50% as taxable profit)
    final double presumptiveTaxableProfit = totalIncome * 0.5;
    // Calculate simple slab tax (assuming flat 10% for basic illustration)
    final double estimatedTax = presumptiveTaxableProfit > 250000 
        ? (presumptiveTaxableProfit - 250000) * 0.1 
        : 0.0;

    // Monthly Growth Trend (This Month vs Previous Month)
    double lastMonthIncome = 0.0;
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    for (final tx in transactions) {
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
              _buildKpiGrid(totalIncome, thisMonthIncome, thisYearIncome, estimatedTax),
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

  Widget _buildKpiGrid(double total, double month, double year, double tax) {
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
                'This Year',
                '₹${year.toStringAsFixed(0)}',
                Icons.analytics_outlined,
                DesignSystem.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignSystem.md),
        _buildSubKpiCard(
          'Estimated Tax Liability (Presumptive 44ADA)',
          '₹${tax.toStringAsFixed(2)}',
          Icons.percent_outlined,
          DesignSystem.warning,
          isFullWidth: true,
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
