import 'package:intl/intl.dart';
import '../models/transaction.dart';

class DynamicInsight {
  final String text;
  final String type; // 'success', 'warning', 'info'
  final String category; // 'income', 'source', 'tax', 'milestone'

  DynamicInsight({
    required this.text,
    required this.type,
    required this.category,
  });
}

class InsightsEngine {
  static List<DynamicInsight> generateInsights(List<Transaction> transactions) {
    final insights = <DynamicInsight>[];
    if (transactions.isEmpty) return insights;

    final parsedTxs = transactions.where((t) => t.transactionType != 'expense').map((t) {
      final double amt = double.tryParse(
            t.amount.replaceAll(',', '').replaceAll('INR', '').trim(),
          ) ??
          0.0;
      final date = DateTime.tryParse(t.date) ?? DateTime.now();
      return _TempTx(amount: amt, date: date, sender: t.sender);
    }).toList();

    final totalIncome = parsedTxs.fold(0.0, (sum, tx) => sum + tx.amount);
    if (totalIncome == 0.0) return insights;

    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    // 1. Month-over-Month calculation
    double thisMonthIncome = 0.0;
    double lastMonthIncome = 0.0;

    for (final tx in parsedTxs) {
      if (tx.date.isAfter(thisMonthStart) || tx.date.isAtSameMomentAs(thisMonthStart)) {
        thisMonthIncome += tx.amount;
      } else if ((tx.date.isAfter(lastMonthStart) || tx.date.isAtSameMomentAs(lastMonthStart)) &&
          tx.date.isBefore(lastMonthEnd)) {
        lastMonthIncome += tx.amount;
      }
    }

    if (lastMonthIncome > 0) {
      final pct = ((thisMonthIncome - lastMonthIncome) / lastMonthIncome) * 100;
      if (pct > 0) {
        insights.add(DynamicInsight(
          text: 'Income increased ${pct.toStringAsFixed(0)}% compared to last month',
          type: 'success',
          category: 'income',
        ));
      } else if (pct < 0) {
        insights.add(DynamicInsight(
          text: 'Income decreased ${pct.abs().toStringAsFixed(0)}% compared to last month',
          type: 'warning',
          category: 'income',
        ));
      }
    }

    // 2. Source distribution check
    final sourceTotals = <String, double>{};
    for (final tx in parsedTxs) {
      sourceTotals[tx.sender] = (sourceTotals[tx.sender] ?? 0.0) + tx.amount;
    }

    String? topSource;
    double maxSourceAmt = 0.0;
    sourceTotals.forEach((source, amt) {
      if (amt > maxSourceAmt) {
        maxSourceAmt = amt;
        topSource = source;
      }
    });

    if (topSource != null && totalIncome > 0) {
      final sourcePct = (maxSourceAmt / totalIncome) * 100;
      insights.add(DynamicInsight(
        text: '$topSource generated ${sourcePct.toStringAsFixed(0)}% of your total income',
        type: 'info',
        category: 'source',
      ));
    }

    // 3. Tax warnings & tips
    // Dynamic India Section 87A rebate and thresholds
    if (totalIncome > 700000) {
      insights.add(DynamicInsight(
        text: 'Tax liability may increase next month. Plan tax deductions under 80C/80D.',
        type: 'warning',
        category: 'tax',
      ));
    } else {
      insights.add(DynamicInsight(
        text: 'Gross income is within ₹7L. You qualify for full tax rebate under Section 87A!',
        type: 'success',
        category: 'tax',
      ));
    }

    if (totalIncome > 1000000) {
      insights.add(DynamicInsight(
        text: 'Advance Tax Obligation: Since estimated tax exceeds ₹10,000, you are legally required to make quarterly Advance Tax payments.',
        type: 'warning',
        category: 'tax',
      ));
    }

    // 4. Peak Earning Week Identification
    final weeklyTotals = <String, double>{};
    for (final tx in parsedTxs) {
      final monthName = DateFormat('MMMM').format(tx.date);
      final weekNo = ((tx.date.day - 1) / 7).floor() + 1;
      final weekKey = '$monthName Week $weekNo';
      weeklyTotals[weekKey] = (weeklyTotals[weekKey] ?? 0.0) + tx.amount;
    }

    String? bestWeek;
    double maxWeekAmt = 0.0;
    weeklyTotals.forEach((week, amt) {
      if (amt > maxWeekAmt) {
        maxWeekAmt = amt;
        bestWeek = week;
      }
    });

    if (bestWeek != null) {
      insights.add(DynamicInsight(
        text: 'Highest earning period was $bestWeek (₹${maxWeekAmt.toStringAsFixed(0)})',
        type: 'success',
        category: 'milestone',
      ));
    }

    return insights;
  }
}

class _TempTx {
  final double amount;
  final DateTime date;
  final String sender;

  _TempTx({
    required this.amount,
    required this.date,
    required this.sender,
  });
}
