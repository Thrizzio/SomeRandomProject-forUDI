import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../services/firestore_service.dart';
import '../../services/database_service.dart';
import '../../theme/design_system.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _activeFilter = 'Year'; // 'Week', 'Month', 'Quarter', 'Year'
  final FirestoreService _firestore = FirestoreService();
  bool _isDark = true;

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
                title: 'Analytics Load Error',
                message: snapshot.error.toString(),
                icon: Icons.analytics_outlined,
                isDark: _isDark,
              );
            }

            final transactions = snapshot.data ?? [];
            if (transactions.isEmpty) {
              return DesignSystem.emptyState(
                context: context,
                title: 'No Data for Analytics',
                message: 'Start adding transactions to see your financial analytics.',
                icon: Icons.bar_chart_outlined,
                isDark: _isDark,
              );
            }

            return _buildAnalyticsContent(transactions);
          },
        ),
      ),
    );
  }

  Future<List<Transaction>> _fetchTransactions() async {
    try {
      final firestoreTxs = await _firestore.getTransactions().timeout(
        const Duration(seconds: 2),
        onTimeout: () => [],
      );
      if (firestoreTxs.isNotEmpty) {
        return _filterTransactions(firestoreTxs);
      }
      final local = await DatabaseService.getAllTransactions();
      return _filterTransactions(local);
    } catch (_) {
      final local = await DatabaseService.getAllTransactions();
      return _filterTransactions(local);
    }
  }

  List<Transaction> _filterTransactions(List<Transaction> original) {
    final now = DateTime.now();
    DateTime cutoff;

    switch (_activeFilter) {
      case 'Week':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        cutoff = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'Quarter':
        cutoff = DateTime(now.year, now.month - 3, now.day);
        break;
      case 'Year':
      default:
        cutoff = DateTime(now.year - 1, now.month, now.day);
        break;
    }

    return original.where((t) {
      final date = DateTime.tryParse(t.date) ?? now;
      return date.isAfter(cutoff);
    }).toList();
  }

  Widget _buildAnalyticsContent(List<Transaction> transactions) {
    // 1. Calculate Monthly trends
    final monthlyData = <int, double>{}; // Month index -> Sum
    final sourceTotals = <String, double>{};
    double totalAmt = 0.0;

    for (final tx in transactions) {
      final double amt = double.tryParse(
            tx.amount.replaceAll(',', '').replaceAll('INR', '').trim(),
          ) ??
          0.0;
      totalAmt += amt;

      final date = DateTime.tryParse(tx.date) ?? DateTime.now();
      monthlyData[date.month] = (monthlyData[date.month] ?? 0.0) + amt;

      final source = tx.sender.isEmpty ? 'Other' : tx.sender;
      sourceTotals[source] = (sourceTotals[source] ?? 0.0) + amt;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignSystem.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          Text(
            'Analytics Center',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isDark ? Colors.white : Colors.black87,
                ),
          ),
          const SizedBox(height: DesignSystem.md),

          // Filters selector row
          _buildFilterRow(),
          const SizedBox(height: DesignSystem.lg),

          // Chart 1: Monthly Income Trend (BarChart)
          _buildCard(
            title: 'Monthly Income Trend (₹)',
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final mIdx = val.toInt();
                          if (mIdx < 1 || mIdx > 12) return const SizedBox();
                          final labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          return Text(labels[mIdx - 1], style: const TextStyle(color: Colors.grey, fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: monthlyData.entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          color: DesignSystem.primary,
                          width: 14,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignSystem.lg),

          // Chart 2 & 3: Source Breakdown (PieChart) & Top Clients
          _buildCard(
            title: 'Income By Source',
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 150,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 30,
                        sections: sourceTotals.entries.map((entry) {
                          final pct = totalAmt > 0 ? (entry.value / totalAmt) * 100 : 0.0;
                          return PieChartSectionData(
                            color: _getSourceColor(entry.key),
                            value: entry.value,
                            title: '${pct.toStringAsFixed(0)}%',
                            radius: 40,
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DesignSystem.md),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: sourceTotals.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, color: _getSourceColor(entry.key)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: _isDark ? Colors.white70 : Colors.black87, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignSystem.lg),

          // Chart 4: Tax Projection Trend (LineChart)
          _buildCard(
            title: 'Tax Liability Projection Trend (₹)',
            child: SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final mIdx = val.toInt();
                          if (mIdx < 1 || mIdx > 12) return const SizedBox();
                          final labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          return Text(labels[mIdx - 1], style: const TextStyle(color: Colors.grey, fontSize: 9));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: monthlyData.entries.map((entry) {
                        // Estimated taxable profit (50%) * 10% tax rate slab projection
                        final profit = entry.value * 0.5;
                        final taxProj = profit > 20000 ? (profit - 20000) * 0.1 : 0.0;
                        return FlSpot(entry.key.toDouble(), taxProj);
                      }).toList(),
                      isCurved: true,
                      color: DesignSystem.warning,
                      barWidth: 4,
                      belowBarData: BarAreaData(
                        show: true,
                        color: DesignSystem.warning.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = ['Week', 'Month', 'Quarter', 'Year'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: filters.map((f) {
        final isActive = _activeFilter == f;
        return GestureDetector(
          onTap: () {
            setState(() {
              _activeFilter = f;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: isActive ? DesignSystem.primaryGradient : null,
              color: isActive ? null : (_isDark ? Colors.white10 : Colors.black12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              f,
              style: TextStyle(
                color: isActive ? Colors.white : (_isDark ? Colors.white70 : Colors.black87),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 20,
      padding: const EdgeInsets.all(DesignSystem.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: DesignSystem.md),
          child,
        ],
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'uber':
        return const Color(0xFF000000);
      case 'ola':
        return const Color(0xFF8EC63F);
      case 'swiggy':
        return const Color(0xFFFC8019);
      case 'zomato':
        return const Color(0xFFE23744);
      case 'zepto':
        return const Color(0xFF7C3AED);
      default:
        return DesignSystem.primary;
    }
  }
}
