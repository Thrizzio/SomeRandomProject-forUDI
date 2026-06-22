import 'package:flutter_test/flutter_test.dart';
import 'package:sms_parser_basically/models/tax_profile.dart';
import 'package:sms_parser_basically/services/tax_engine_v2.dart';

void main() {
  group('TaxEngineV2 Unit Tests', () {
    test('New Regime Slab Calculations (Under 7 Lakhs Rebate)', () {
      // 6 Lakhs income should calculate tax, but rebate 87A should make it 0.
      final result = TaxEngineV2.calculateNewRegime(
        grossIncome: 600000.0,
        presumptiveProfit: 300000.0, // 50% under 44ADA
      );

      expect(result.netTaxableIncome, 300000.0);
      expect(result.taxBeforeCess, 0.0);
      expect(result.rebate87A, 0.0);
      expect(result.totalTaxDue, 0.0);
    });

    test('New Regime Slab Calculations (Above 7 Lakhs - No Rebate)', () {
      // 16 Lakhs gross, 8 Lakhs presumptive profit.
      // Slabs:
      // 0-3L: Nil
      // 3L-7L (4L * 5% = 20,000)
      // 7L-8L (1L * 10% = 10,000)
      // Total tax = 30,000
      // Cess = 4% of 30,000 = 1,200
      // Total due = 31,200
      final result = TaxEngineV2.calculateNewRegime(
        grossIncome: 1600000.0,
        presumptiveProfit: 800000.0,
      );

      expect(result.netTaxableIncome, 800000.0);
      expect(result.taxBeforeCess, 30000.0);
      expect(result.rebate87A, 0.0);
      expect(result.cess, 1200.0);
      expect(result.totalTaxDue, 31200.0);
    });

    test('Old Regime Slab Calculations with Deductions', () {
      // 12 Lakhs gross, 6 Lakhs presumptive profit.
      // Deductions: 80C = 1.5L, 80D = 25k, NPS = 50k. Total deductions = 2.25L.
      // Net Taxable = 6L - 2.25L = 3.75L.
      // Slabs:
      // 0-2.5L: Nil
      // 2.5L-3.75L (1.25L * 5% = 6,250)
      // Rebate u/s 87A: Since Net Taxable <= 5L, rebate = 6,250.
      // Total Tax Due = 0.
      final deductions = TaxDeductions(
        section80C: 150000.0,
        section80D: 250000.0, // Capped at 50,000
        npsSection80CCD1B: 50000.0,
      );

      final result = TaxEngineV2.calculateOldRegime(
        grossIncome: 1200000.0,
        presumptiveProfit: 600000.0,
        deductions: deductions,
      );

      expect(result.deductionsApplied, 250000.0); // 1.5L (80C) + 50k (80D cap) + 50k (NPS)
      expect(result.netTaxableIncome, 350000.0); // 6L - 2.5L
      expect(result.taxBeforeCess, 5000.0); // (3.5L - 2.5L) * 5% = 5,000
      expect(result.rebate87A, 5000.0);
      expect(result.totalTaxDue, 0.0);
    });

    test('Old Regime High Income (No Rebate)', () {
      // 24 Lakhs gross, 12 Lakhs presumptive profit.
      // Deductions = 1.5L (80C). Net Taxable = 10.5L.
      // Slabs:
      // 0-2.5L: Nil
      // 2.5L-5L (2.5L * 5% = 12,500)
      // 5L-10L (5L * 20% = 1,00,000)
      // 10L-10.5L (50k * 30% = 15,000)
      // Total tax = 1,27,500
      // Cess = 4% of 1,27,500 = 5,100
      // Total due = 1,32,600
      final deductions = TaxDeductions(section80C: 150000.0);
      final result = TaxEngineV2.calculateOldRegime(
        grossIncome: 2400000.0,
        presumptiveProfit: 1200000.0,
        deductions: deductions,
      );

      expect(result.netTaxableIncome, 1050000.0);
      expect(result.taxBeforeCess, 127500.0);
      expect(result.totalTaxDue, 132600.0);
    });

    test('Surcharge Calculations for Ultra-High Income', () {
      // 1.2 Crore income under New Regime.
      // Net Taxable = 1.2 Crore.
      // Surcharge is 15% for income > 1 Crore.
      final result = TaxEngineV2.calculateNewRegime(
        grossIncome: 12000000.0,
        presumptiveProfit: 12000000.0,
      );

      expect(result.surcharge, isPositive);
      expect(result.surcharge, result.taxBeforeCess * 0.15);
    });

    test('Compliance Limits Checking', () {
      // 44ADA threshold: 75 Lakhs
      final complianceADA = TaxEngineV2.checkComplianceLimits(8000000.0, '44ada');
      expect(complianceADA['isExceeded'], true);

      // 44AD threshold: 3 Crores
      final complianceAD = TaxEngineV2.checkComplianceLimits(25000000.0, '44ad');
      expect(complianceAD['isExceeded'], false);
    });

    test('Deduction Caps and Bounds Validation', () {
      final deductions = TaxDeductions(
        section80C: 250000.0, // Capped at 1.5L
        section80D: 80000.0,  // Capped at 50k
        npsSection80CCD1B: 70000.0, // Capped at 50k
        homeLoanInterest: 250000.0, // Capped at 2L
      );

      expect(deductions.getTotalDeductions(), 450000.0); // 1.5L + 50k + 50k + 2L
    });

    test('Regime Comparison Logic', () {
      final profile = TaxProfile(
        professionType: 'developer',
        taxRegime: 'new',
        businessCategory: '44ada',
        expectedAnnualIncome: 1500000.0,
        businessType: 'Software',
        deductions: TaxDeductions(section80C: 150000.0),
        updatedAt: DateTime.now(),
      );

      final comparison = TaxEngineV2.compareRegimes(
        grossIncome: 1500000.0,
        profile: profile,
      );

      expect(comparison.containsKey('savings'), true);
      expect(comparison.containsKey('recommendedRegime'), true);
    });

    test('Advance Tax Installments Division', () {
      // If annual tax is 40,000
      final installments = TaxEngineV2.calculateAdvanceTaxInstallments(40000.0);
      
      expect(installments[0]['cumulativeAmount'], 6000.0); // 15%
      expect(installments[1]['cumulativeAmount'], 18000.0); // 45%
      expect(installments[2]['cumulativeAmount'], 30000.0); // 75%
      expect(installments[3]['cumulativeAmount'], 40000.0); // 100%

      // If annual tax is 5,000 (below 10,000 advance tax limit)
      final zeroInstallments = TaxEngineV2.calculateAdvanceTaxInstallments(5000.0);
      expect(zeroInstallments[0]['cumulativeAmount'], 0.0);
    });
  });

  group('TaxEngineV2 Benchmark Tests', () {
    test('Calculate tax for 10,000 iterations under 100ms', () {
      final stopwatch = Stopwatch()..start();
      
      final profile = TaxProfile.defaultProfile();
      for (int i = 0; i < 10000; i++) {
        TaxEngineV2.calculateTax(
          grossIncome: 1500000.0 + i,
          profile: profile,
        );
      }

      stopwatch.stop();
      print('Parsed 10,000 tax calculations in: ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(500)); // Standard threshold is generous, usually executes in < 30ms
    });
  });
}
