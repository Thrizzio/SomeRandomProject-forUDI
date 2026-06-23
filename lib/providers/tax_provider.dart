import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tax_profile.dart';
import '../models/transaction.dart';
import '../services/tax_profile_service.dart';
import '../services/tax_engine_v2.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/app_logger.dart';

class TaxProvider extends ChangeNotifier {
  static const String _tag = 'TaxProvider';

  final FirestoreService _firestore = FirestoreService();

  TaxProfile _profile = TaxProfile.defaultProfile();
  List<Transaction> _transactions = [];
  bool _loading = false;

  TaxProfile get profile => _profile;
  List<Transaction> get transactions => _transactions;
  bool get loading => _loading;

  double get totalIncome {
    double sum = 0.0;
    for (final tx in _transactions) {
      if (tx.transactionType.toLowerCase() == 'income' || tx.transactionType.toLowerCase() == 'credit' || tx.transactionType.isEmpty) {
        final double amt = double.tryParse(
              tx.amount.replaceAll(',', '').replaceAll('INR', '').replaceAll('₹', '').replaceAll('Rs', '').trim(),
            ) ??
            0.0;
        sum += amt;
      }
    }
    return sum;
  }

  double get totalExpenses {
    double sum = 0.0;
    for (final tx in _transactions) {
      if (tx.transactionType.toLowerCase() == 'expense' || tx.transactionType.toLowerCase() == 'debit') {
        final double amt = double.tryParse(
              tx.amount.replaceAll(',', '').replaceAll('INR', '').replaceAll('₹', '').replaceAll('Rs', '').trim(),
            ) ??
            0.0;
        sum += amt;
      }
    }
    return sum;
  }

  /// Load tax profile and transactions
  Future<void> init() async {
    _loading = true;
    notifyListeners();

    try {
      _profile = await TaxProfileService.getProfile();
      await fetchTransactions();
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to initialize TaxProvider', e, stack);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetch transactions from Firestore (with local database fallback)
  Future<void> fetchTransactions() async {
    try {
      final firestoreTxs = await _firestore.getTransactions().timeout(
        const Duration(seconds: 2),
        onTimeout: () => [],
      );
      if (firestoreTxs.isNotEmpty) {
        _transactions = firestoreTxs;
      } else {
        _transactions = await DatabaseService.getAllTransactions();
      }
    } catch (_) {
      _transactions = await DatabaseService.getAllTransactions();
    }
    notifyListeners();
  }

  /// Update tax profile
  Future<void> updateProfile(TaxProfile updated) async {
    _profile = updated;
    await TaxProfileService.saveProfile(updated);
    notifyListeners();
  }

  /// Reset tax profile
  Future<void> resetProfile() async {
    await TaxProfileService.resetProfile();
    _profile = TaxProfile.defaultProfile();
    notifyListeners();
  }

  /// Live tax calculation result
  TaxCalculationResult get taxCalculationResult {
    return TaxEngineV2.calculateTax(
      grossIncome: totalIncome,
      profile: _profile,
      totalExpenses: totalExpenses,
    );
  }

  /// Live old vs new regime comparison
  Map<String, dynamic> get regimeComparison {
    return TaxEngineV2.compareRegimes(
      grossIncome: totalIncome,
      profile: _profile,
      totalExpenses: totalExpenses,
    );
  }

  /// Compliance checks (presumptive limits)
  Map<String, dynamic> get complianceCheck {
    return TaxEngineV2.checkComplianceLimits(
      totalIncome,
      _profile.businessCategory,
    );
  }

  /// Live advance tax installments
  List<Map<String, dynamic>> get advanceTaxInstallments {
    return TaxEngineV2.calculateAdvanceTaxInstallments(taxCalculationResult.totalTaxDue);
  }

  /// What-If Simulator calculator
  Map<String, dynamic> simulateWhatIf(double simulatedIncome, TaxDeductions simulatedDeductions) {
    final tempProfile = _profile.copyWith(deductions: simulatedDeductions);
    final comparison = TaxEngineV2.compareRegimes(
      grossIncome: simulatedIncome,
      profile: tempProfile,
    );

    final currentResult = taxCalculationResult;
    final recommendedRegime = comparison['recommendedRegime'] as String;
    final recommendedResult = recommendedRegime == 'new' 
        ? comparison['newRegimeResult'] as TaxCalculationResult 
        : comparison['oldRegimeResult'] as TaxCalculationResult;

    final taxDifference = (recommendedResult.totalTaxDue - currentResult.totalTaxDue);

    return {
      'recommendedResult': recommendedResult,
      'taxDifference': taxDifference,
      'savings': comparison['savings'],
      'recommendedRegime': recommendedRegime,
      'explanation': comparison['explanation'],
    };
  }

  /// Track if user has generated a report
  Future<void> markReportGenerated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('report_generated_${_profile.updatedAt.millisecondsSinceEpoch}', true);
      notifyListeners();
    } catch (_) {}
  }

  /// Calculate Tax Health Score (0-100)
  Future<int> getTaxHealthScore() async {
    int score = 0;

    // 1. Profile Setup & Regime Choice (30 points)
    if (_profile.businessType.isNotEmpty && _profile.professionType.isNotEmpty) {
      score += 30;
    }

    // 2. Transaction Records Completeness (30 points)
    if (_transactions.isNotEmpty) {
      int complete = 0;
      for (final tx in _transactions) {
        if (tx.sender.isNotEmpty && tx.sender != 'Unknown' && tx.messageBody.isNotEmpty) {
          complete++;
        }
      }
      final double ratio = complete / _transactions.length;
      score += (ratio * 30).round();
    } else {
      score += 15; // default half points if empty but no bad records
    }

    // 3. Income Consistency across FY months (20 points)
    if (_transactions.isNotEmpty) {
      final Set<int> months = {};
      for (final tx in _transactions) {
        try {
          final dt = DateTime.parse(tx.date);
          months.add(dt.month);
        } catch (_) {}
      }
      // Out of 12 months, if they track in at least 4 months they get full points
      final double monthRatio = months.length >= 4 ? 1.0 : (months.length / 4.0);
      score += (monthRatio * 20).round();
    } else {
      score += 10;
    }

    // 4. Report Preparedness (20 points)
    final prefs = await SharedPreferences.getInstance();
    final bool reportGen = prefs.getKeys().any((key) => key.startsWith('report_generated_'));
    if (reportGen) {
      score += 20;
    } else {
      score += 5;
    }

    // 5. Compliance Penalty
    final compliance = complianceCheck;
    if (compliance['isExceeded'] == true) {
      score -= 15;
    }

    if (score > 100) score = 100;
    if (score < 0) score = 0;
    return score;
  }

  /// Get status label for Health Score
  String getHealthStatus(int score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Needs Attention';
    return 'Critical';
  }

  /// Dynamic intelligent tax insights
  List<String> getDynamicInsights() {
    final List<String> insights = [];

    // 1. Regime savings recommendation
    final comparison = regimeComparison;
    final savings = comparison['savings'] as double;
    final recommended = comparison['recommendedRegime'] as String;
    if (savings > 0) {
      insights.add('Switching to ${recommended.toUpperCase()} regime could save you ₹${savings.toStringAsFixed(0)}.');
    }

    // 2. Presumptive tax savings
    if (_profile.businessCategory == 'regular') {
      insights.add('You may save significant taxes by opting for presumptive scheme Section 44ADA (Freelancers) or 44AD (Gig Delivery).');
    }

    // 3. Tax Reserve recommendation
    final currentTax = taxCalculationResult.totalTaxDue;
    if (currentTax > 0) {
      final double monthlyReserve = currentTax / 12.0;
      insights.add('We recommend reserving ₹${monthlyReserve.toStringAsFixed(0)} this month for your upcoming tax obligations.');
    } else {
      insights.add('Your current taxable income is below the taxable threshold. Keep tracking to monitor your status.');
    }

    // 4. Higher Tax Slab check
    final double netTaxable = taxCalculationResult.netTaxableIncome;
    if (_profile.taxRegime == 'new') {
      if (netTaxable > 500000.0 && netTaxable < 700000.0) {
        insights.add('You are nearing the ₹7,00,000 threshold. Exceeding it will remove Section 87A rebate and trigger taxes.');
      } else if (netTaxable > 1200000.0 && netTaxable < 1500000.0) {
        insights.add('Your taxable income is close to the 20% slab. Planning business expenses can keep you in a lower bracket.');
      }
    }

    // 5. Compliance limit checks
    final compliance = complianceCheck;
    if (compliance['isExceeded'] == true) {
      insights.add('ALERT: You have exceeded the gross receipts limit for presumptive tax (${compliance['section']}). Contact your CA.');
    }

    // 6. Quarterly advance tax reminder
    if (currentTax >= 10000.0) {
      insights.add('Your estimated tax exceeds ₹10,000. You are legally required to make quarterly Advance Tax payments.');
    }

    return insights;
  }
}
