import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_parser_basically/models/tax_profile.dart';
import 'package:sms_parser_basically/services/itr_json_export_service.dart';

void main() {
  group('ItrJsonExportService Unit Tests', () {
    test('Generates ITR-4 JSON String with Correct Structure for 44ADA', () async {
      final profile = TaxProfile(
        professionType: 'developer',
        taxRegime: 'new',
        businessCategory: '44ada',
        expectedAnnualIncome: 1200000.0,
        businessType: 'Software Developer',
        deductions: TaxDeductions(section80C: 150000.0),
        updatedAt: DateTime.now(),
      );

      final jsonString = await ItrJsonExportService.createItr4JsonString(
        totalIncome: 1000000.0,
        totalExpenses: 50000.0,
        profile: profile,
      );

      expect(jsonString, isNotEmpty);

      final Map<String, dynamic> schema = json.decode(jsonString);
      
      // Verify root fields
      expect(schema['itrForm'], 'ITR-4');
      expect(schema['creationInfo']['assessmentYear'], '2025-26');
      expect(schema['creationInfo']['financialYear'], '2024-25');

      // Verify Personal Info
      expect(schema['personalInfo']['pan'], 'XXXXXXXXXX');
      expect(schema['personalInfo']['natureOfEmployment'], 'OTHERS');

      // Verify Professional 44ADA Section
      expect(schema['professionalIncome44ADA']['isActive'], true);
      expect(schema['professionalIncome44ADA']['grossReceipts'], 1000000.0);
      expect(schema['professionalIncome44ADA']['presumptiveIncome'], 500000.0); // 50% of 10L

      // Verify Business 44AD Section (should be inactive)
      expect(schema['businessIncome44AD']['isActive'], false);

      // Verify Deductions
      expect(schema['deductionsChapterVIA']['section80C'], 150000.0);
      expect(schema['deductionsChapterVIA']['totalDeductionsApplied'], 0.0); // 0 because New Regime is selected

      // Verify Tax Computation
      expect(schema['taxComputation']['grossTotalIncome'], 1000000.0);
      expect(schema['taxComputation']['netTaxableIncome'], 450000.0); // Presumptive income under 44ADA minus totalExpenses
      expect(schema['taxComputation']['totalTaxDue'], 0.0); // Under New Regime, net taxable income <= 7L has rebate87A making it 0 tax
    });

    test('Generates ITR-4 JSON String with Correct Structure for 44AD', () async {
      final profile = TaxProfile(
        professionType: 'gig',
        taxRegime: 'old',
        businessCategory: '44ad',
        expectedAnnualIncome: 2000000.0,
        businessType: 'Retail Business',
        deductions: TaxDeductions(section80C: 150000.0, section80D: 25000.0),
        updatedAt: DateTime.now(),
      );

      final jsonString = await ItrJsonExportService.createItr4JsonString(
        totalIncome: 1500000.0,
        totalExpenses: 200000.0,
        profile: profile,
      );

      final Map<String, dynamic> schema = json.decode(jsonString);

      // Verify Business 44AD Section
      expect(schema['businessIncome44AD']['isActive'], true);
      expect(schema['businessIncome44AD']['grossReceiptsDigital'], 1500000.0);
      expect(schema['businessIncome44AD']['presumptiveIncome'], 90000.0); // 6% of 15L digital is 90k

      // Verify Professional 44ADA Section (should be inactive)
      expect(schema['professionalIncome44ADA']['isActive'], false);

      // Verify Deductions
      expect(schema['deductionsChapterVIA']['section80C'], 150000.0);
      expect(schema['deductionsChapterVIA']['section80D'], 25000.0);
      expect(schema['deductionsChapterVIA']['totalDeductionsApplied'], 175000.0); // Applied under Old Regime
    });
  });
}
