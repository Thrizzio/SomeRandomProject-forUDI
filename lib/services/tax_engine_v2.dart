import '../models/transaction.dart';
import '../models/tax_profile.dart';
import 'app_logger.dart';

class SlabBreakdown {
  final String slabRange;
  final double rate;
  final double taxAmount;

  SlabBreakdown({
    required this.slabRange,
    required this.rate,
    required this.taxAmount,
  });

  Map<String, dynamic> toJson() => {
    'slabRange': slabRange,
    'rate': rate,
    'taxAmount': taxAmount,
  };
}

class TaxCalculationResult {
  final double grossIncome;
  final double presumptiveProfit;
  final double deductionsApplied;
  final double netTaxableIncome;
  final double taxBeforeCess;
  final double rebate87A;
  final double surcharge;
  final double cess;
  final double totalTaxDue;
  final List<SlabBreakdown> slabsApplied;
  final String formulaDescription;
  final String regimeName;
  final DateTime timestamp;

  TaxCalculationResult({
    required this.grossIncome,
    required this.presumptiveProfit,
    required this.deductionsApplied,
    required this.netTaxableIncome,
    required this.taxBeforeCess,
    required this.rebate87A,
    required this.surcharge,
    required this.cess,
    required this.totalTaxDue,
    required this.slabsApplied,
    required this.formulaDescription,
    required this.regimeName,
    required this.timestamp,
  });

  double get effectiveTaxRate => grossIncome > 0 ? (totalTaxDue / grossIncome) * 100 : 0.0;
}

class TaxEngineV2 {
  static const String _tag = 'TaxEngineV2';

  /// Calculate Tax under New Regime (FY 2024-25 / AY 2025-26)
  /// Revised in Budget 2024:
  /// - Up to 3,00,000: Nil
  /// - 3,00,001 to 7,00,000: 5%
  /// - 7,00,001 to 10,00,000: 10%
  /// - 10,00,001 to 12,00,000: 15%
  /// - 12,00,001 to 15,00,000: 20%
  /// - Above 15,00,000: 30%
  /// - Rebate u/s 87A: If Net Taxable Income <= 7,00,000, 100% rebate (tax = 0)
  static TaxCalculationResult calculateNewRegime({
    required double grossIncome,
    required double presumptiveProfit,
    double totalExpenses = 0.0,
  }) {
    final netTaxable = (presumptiveProfit - totalExpenses) < 0.0 ? 0.0 : (presumptiveProfit - totalExpenses);
    
    final List<SlabBreakdown> slabs = [];
    double tempIncome = netTaxable;
    double tax = 0.0;

    // Slab 1: Up to 3,00,000 (0%)
    final slab1Taxable = tempIncome > 300000.0 ? 300000.0 : tempIncome;
    slabs.add(SlabBreakdown(slabRange: '0 - 3,00,000', rate: 0.0, taxAmount: 0.0));
    tempIncome -= slab1Taxable;

    // Slab 2: 3,00,001 to 7,00,000 (5%)
    if (netTaxable > 300000.0) {
      final taxableAmount = netTaxable > 700000.0 ? 400000.0 : (netTaxable - 300000.0);
      final slabTax = taxableAmount * 0.05;
      tax += slabTax;
      slabs.add(SlabBreakdown(slabRange: '3,00,001 - 7,00,000', rate: 5.0, taxAmount: slabTax));
    }

    // Slab 3: 7,00,001 to 10,00,000 (10%)
    if (netTaxable > 700000.0) {
      final taxableAmount = netTaxable > 1000000.0 ? 300000.0 : (netTaxable - 700000.0);
      final slabTax = taxableAmount * 0.10;
      tax += slabTax;
      slabs.add(SlabBreakdown(slabRange: '7,00,001 - 10,00,000', rate: 10.0, taxAmount: slabTax));
    }

    // Slab 4: 10,00,001 to 12,00,000 (15%)
    if (netTaxable > 1000000.0) {
      final taxableAmount = netTaxable > 1200000.0 ? 200000.0 : (netTaxable - 1000000.0);
      final slabTax = taxableAmount * 0.15;
      tax += slabTax;
      slabs.add(SlabBreakdown(slabRange: '10,00,001 - 12,00,000', rate: 15.0, taxAmount: slabTax));
    }

    // Slab 5: 12,00,001 to 15,00,000 (20%)
    if (netTaxable > 1200000.0) {
      final taxableAmount = netTaxable > 1500000.0 ? 300000.0 : (netTaxable - 1200000.0);
      final slabTax = taxableAmount * 0.20;
      tax += slabTax;
      slabs.add(SlabBreakdown(slabRange: '12,00,001 - 15,00,000', rate: 20.0, taxAmount: slabTax));
    }

    // Slab 6: Above 15,00,000 (30%)
    if (netTaxable > 1500000.0) {
      final taxableAmount = netTaxable - 1500000.0;
      final slabTax = taxableAmount * 0.30;
      tax += slabTax;
      slabs.add(SlabBreakdown(slabRange: 'Above 15,00,000', rate: 30.0, taxAmount: slabTax));
    }

    // Rebate u/s 87A (New Regime)
    double rebate = 0.0;
    if (netTaxable <= 700000.0) {
      rebate = tax; // Full rebate up to 20,000 (since max tax on 7L is 20,000: 4L * 5% = 20,000)
    }

    final taxAfterRebate = tax - rebate;

    // Surcharge
    double surcharge = 0.0;
    if (netTaxable > 5000000.0 && netTaxable <= 10000000.0) {
      surcharge = taxAfterRebate * 0.10;
    } else if (netTaxable > 10000000.0) {
      surcharge = taxAfterRebate * 0.15; // Max surcharge is 15% under New Regime
    }

    final cess = (taxAfterRebate + surcharge) * 0.04;
    final totalDue = taxAfterRebate + surcharge + cess;

    final formula = 'Slabs: 3L-7L (5%), 7L-10L (10%), 10L-12L (15%), 12L-15L (20%), >15L (30%). Rebate u/s 87A if income <= 7L. Cess 4%.';

    return TaxCalculationResult(
      grossIncome: grossIncome,
      presumptiveProfit: presumptiveProfit,
      deductionsApplied: 0.0,
      netTaxableIncome: netTaxable,
      taxBeforeCess: tax,
      rebate87A: rebate,
      surcharge: surcharge,
      cess: cess,
      totalTaxDue: totalDue,
      slabsApplied: slabs,
      formulaDescription: formula,
      regimeName: 'New Regime',
      timestamp: DateTime.now(),
    );
  }

  /// Calculate Tax under Old Regime (FY 2024-25 / AY 2025-26)
  /// Slabs:
  /// - Up to 2,50,000: Nil
  /// - 2,50,001 to 5,00,000: 5%
  /// - 5,00,001 to 10,00,000: 20%
  /// - Above 10,00,000: 30%
  /// - Rebate u/s 87A: If Net Taxable Income <= 5,00,000, 100% rebate (up to 12,500)
  static TaxCalculationResult calculateOldRegime({
    required double grossIncome,
    required double presumptiveProfit,
    required TaxDeductions deductions,
    double totalExpenses = 0.0,
  }) {
    final double totalDeductions = deductions.getTotalDeductions();
    final double netTaxable = (presumptiveProfit - totalExpenses - totalDeductions) < 0.0 ? 0.0 : (presumptiveProfit - totalExpenses - totalDeductions);

    final List<SlabBreakdown> slabs = [];
    double tax = 0.0;

    // Slab 1: Up to 2,50,000 (0%)
    slabs.add(SlabBreakdown(slabRange: '0 - 2,50,000', rate: 0.0, taxAmount: 0.0));

    // Slab 2: 2,50,001 to 5,00,000 (5%)
    if (netTaxable > 250000.0) {
      final taxableAmount = netTaxable > 500000.0 ? 250000.0 : (netTaxable - 250000.0);
      final slabTax = taxableAmount * 0.05;
      tax += slabTax;
      slabs.add(SlabBreakdown(slabRange: '2,50,001 - 5,00,000', rate: 5.0, taxAmount: slabTax));
    }

    // Slab 3: 5,00,001 to 10,00,000 (20%)
    if (netTaxable > 500000.0) {
      final taxableAmount = netTaxable > 1000000.0 ? 500000.0 : (netTaxable - 500000.0);
      final slabTax = taxableAmount * 0.20;
      tax += slabTax;
      slabs.add(SlabBreakdown(slabRange: '5,00,001 - 10,00,000', rate: 20.0, taxAmount: slabTax));
    }

    // Slab 4: Above 10,00,000 (30%)
    if (netTaxable > 1000000.0) {
      final taxableAmount = netTaxable - 1000000.0;
      final slabTax = taxableAmount * 0.30;
      tax += slabTax;
      slabs.add(SlabBreakdown(slabRange: 'Above 10,00,000', rate: 30.0, taxAmount: slabTax));
    }

    // Rebate u/s 87A (Old Regime)
    double rebate = 0.0;
    if (netTaxable <= 500000.0) {
      rebate = tax; // Full rebate up to 12,500
    }

    final taxAfterRebate = tax - rebate;

    // Surcharge
    double surcharge = 0.0;
    if (netTaxable > 5000000.0 && netTaxable <= 10000000.0) {
      surcharge = taxAfterRebate * 0.10;
    } else if (netTaxable > 10000000.0 && netTaxable <= 20000000.0) {
      surcharge = taxAfterRebate * 0.15;
    } else if (netTaxable > 20000000.0 && netTaxable <= 50000000.0) {
      surcharge = taxAfterRebate * 0.25;
    } else if (netTaxable > 50000000.0) {
      surcharge = taxAfterRebate * 0.37;
    }

    final cess = (taxAfterRebate + surcharge) * 0.04;
    final totalDue = taxAfterRebate + surcharge + cess;

    final formula = 'Slabs: 2.5L-5L (5%), 5L-10L (20%), >10L (30%). Rebate u/s 87A if income <= 5L. Cess 4%. Deductions (80C, 80D, etc.) allowed.';

    return TaxCalculationResult(
      grossIncome: grossIncome,
      presumptiveProfit: presumptiveProfit,
      deductionsApplied: totalDeductions,
      netTaxableIncome: netTaxable,
      taxBeforeCess: tax,
      rebate87A: rebate,
      surcharge: surcharge,
      cess: cess,
      totalTaxDue: totalDue,
      slabsApplied: slabs,
      formulaDescription: formula,
      regimeName: 'Old Regime',
      timestamp: DateTime.now(),
    );
  }

  /// Master calculation method
  static TaxCalculationResult calculateTax({
    required double grossIncome,
    required TaxProfile profile,
    double totalExpenses = 0.0,
  }) {
    final double presumptiveProfit = computePresumptiveProfit(grossIncome, profile.businessCategory);
    
    if (profile.taxRegime == 'new') {
      return calculateNewRegime(
        grossIncome: grossIncome,
        presumptiveProfit: presumptiveProfit,
        totalExpenses: totalExpenses,
      );
    } else {
      return calculateOldRegime(
        grossIncome: grossIncome,
        presumptiveProfit: presumptiveProfit,
        deductions: profile.deductions,
        totalExpenses: totalExpenses,
      );
    }
  }

  /// Compute presumptive profit based on business category (ITR-4 Section 44AD/ADA)
  static double computePresumptiveProfit(double grossIncome, String businessCategory) {
    if (businessCategory == '44ada') {
      // 50% presumptive profit for professionals/freelancers
      return grossIncome * 0.50;
    } else if (businessCategory == '44ad') {
      // 6% presumptive profit for digital gig workers/delivery
      return grossIncome * 0.06;
    } else {
      // Regular tax filing (100% of receipts treated as income, minus deductions)
      return grossIncome;
    }
  }

  /// Checks if presumptive receipts exceed legislative limits
  /// - 44ADA limit: 75 Lakhs
  /// - 44AD limit: 3 Crores
  static Map<String, dynamic> checkComplianceLimits(double grossIncome, String businessCategory) {
    bool isExceeded = false;
    double limit = 0.0;
    String section = '';

    if (businessCategory == '44ada') {
      limit = 7500000.0;
      section = 'Section 44ADA';
      if (grossIncome > limit) isExceeded = true;
    } else if (businessCategory == '44ad') {
      limit = 30000000.0;
      section = 'Section 44AD';
      if (grossIncome > limit) isExceeded = true;
    }

    return {
      'isExceeded': isExceeded,
      'limit': limit,
      'section': section,
      'message': isExceeded 
          ? 'Warning: Your gross receipts ($grossIncome) exceed the legislative threshold ($limit) for $section. You must file regular ITR-3/ITR-4 with detailed books of accounts.'
          : 'Compliant: Receipts are within $section limits.',
    };
  }

  /// Compares both regimes and returns detailed recommendation
  static Map<String, dynamic> compareRegimes({
    required double grossIncome,
    required TaxProfile profile,
    double totalExpenses = 0.0,
  }) {
    final double presumptiveProfit = computePresumptiveProfit(grossIncome, profile.businessCategory);
    
    final newResult = calculateNewRegime(grossIncome: grossIncome, presumptiveProfit: presumptiveProfit, totalExpenses: totalExpenses);
    final oldResult = calculateOldRegime(grossIncome: grossIncome, presumptiveProfit: presumptiveProfit, deductions: profile.deductions, totalExpenses: totalExpenses);

    final double savings = (oldResult.totalTaxDue - newResult.totalTaxDue).abs();
    final String recommendedRegime = newResult.totalTaxDue < oldResult.totalTaxDue ? 'new' : 'old';
    
    String explanation = '';
    if (newResult.totalTaxDue < oldResult.totalTaxDue) {
      explanation = 'The New Tax Regime is more beneficial by ₹${savings.toStringAsFixed(0)}. Under the New Regime, slab rates are lower and the zero-tax rebate threshold is higher (up to ₹7,00,000), making it better since you have lower personal deductions (80C, 80D, etc.).';
    } else if (oldResult.totalTaxDue < newResult.totalTaxDue) {
      explanation = 'The Old Tax Regime is more beneficial by ₹${savings.toStringAsFixed(0)}. Your total deductions of ₹${profile.deductions.getTotalDeductions().toStringAsFixed(0)} (including 80C/80D/Home Loan interest) lower your taxable income under the Old Regime enough to outweigh the lower rates of the New Regime.';
    } else {
      explanation = 'Both regimes result in the exact same tax liability. You can choose either, though the New Regime requires no deduction declarations.';
    }

    return {
      'newRegimeResult': newResult,
      'oldRegimeResult': oldResult,
      'savings': savings,
      'recommendedRegime': recommendedRegime,
      'explanation': explanation,
      'effectiveRateNew': newResult.effectiveTaxRate,
      'effectiveRateOld': oldResult.effectiveTaxRate,
    };
  }

  /// Get quarterly advance tax dates and expected payments
  static List<Map<String, dynamic>> calculateAdvanceTaxInstallments(double annualTaxDue) {
    // If annual tax due is less than 10,000, no advance tax is payable in India
    final bool isMandatory = annualTaxDue >= 10000.0;
    
    return [
      {
        'installment': '1st Installment',
        'dueDate': 'June 15',
        'percentage': 15.0,
        'cumulativeAmount': isMandatory ? annualTaxDue * 0.15 : 0.0,
        'status': 'passed',
      },
      {
        'installment': '2nd Installment',
        'dueDate': 'September 15',
        'percentage': 45.0,
        'cumulativeAmount': isMandatory ? annualTaxDue * 0.45 : 0.0,
        'status': 'passed',
      },
      {
        'installment': '3rd Installment',
        'dueDate': 'December 15',
        'percentage': 75.0,
        'cumulativeAmount': isMandatory ? annualTaxDue * 0.75 : 0.0,
        'status': 'upcoming',
      },
      {
        'installment': '4th Installment',
        'dueDate': 'March 15',
        'percentage': 100.0,
        'cumulativeAmount': isMandatory ? annualTaxDue : 0.0,
        'status': 'upcoming',
      },
    ];
  }
}
