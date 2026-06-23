import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/tax_profile.dart';
import '../services/tax_engine_v2.dart';
import '../services/app_logger.dart';
import '../utils/file_download_helper.dart'
    if (dart.library.html) '../utils/file_download_helper_web.dart';

class ItrJsonExportService {
  static const String _tag = 'ItrJsonExportService';

  /// Generates the standard JSON format expected by India's income tax offline utility
  static Future<String> createItr4JsonString({
    required double totalIncome,
    required double totalExpenses,
    required TaxProfile profile,
  }) async {
    final double presumptiveProfit = TaxEngineV2.computePresumptiveProfit(totalIncome, profile.businessCategory);
    final calculation = TaxEngineV2.calculateTax(
      grossIncome: totalIncome,
      profile: profile,
      totalExpenses: totalExpenses,
    );

    // Map profile values to schema sections
    final businessReceiptsDigital = profile.businessCategory == '44ad' ? totalIncome : 0.0;
    final businessReceiptsCash = 0.0; // Assume digital for app users (can edit manually)
    final businessPresumptiveIncome = profile.businessCategory == '44ad' ? presumptiveProfit : 0.0;

    final professionalReceipts = profile.businessCategory == '44ada' ? totalIncome : 0.0;
    final professionalPresumptiveIncome = profile.businessCategory == '44ada' ? presumptiveProfit : 0.0;

    final Map<String, dynamic> schema = {
      "creationInfo": {
        "softwareName": "GigTax App",
        "softwareVersion": "v1.0.0",
        "generatedAt": DateTime.now().toIso8601String(),
        "assessmentYear": "2025-26",
        "financialYear": "2024-25"
      },
      "itrForm": "ITR-4",
      "personalInfo": {
        "pan": "XXXXXXXXXX", // Masked placeholder for data privacy
        "name": {
          "firstName": "GigTax",
          "lastName": "User"
        },
        "natureOfEmployment": "OTHERS",
        "filingSection": "139(1)"
      },
      "businessIncome44AD": {
        "isActive": profile.businessCategory == '44ad',
        "natureOfBusiness": profile.businessType,
        "grossReceiptsDigital": businessReceiptsDigital,
        "grossReceiptsCash": businessReceiptsCash,
        "presumptiveIncome": businessPresumptiveIncome,
        "expensesClaimed": totalExpenses
      },
      "professionalIncome44ADA": {
        "isActive": profile.businessCategory == '44ada',
        "natureOfProfession": profile.businessType,
        "grossReceipts": professionalReceipts,
        "presumptiveIncome": professionalPresumptiveIncome
      },
      "deductionsChapterVIA": {
        "section80C": profile.deductions.section80C,
        "section80D": profile.deductions.section80D,
        "section80G": profile.deductions.section80G,
        "npsSection80CCD1B": profile.deductions.npsSection80CCD1B,
        "educationLoan80E": profile.deductions.educationLoanInterest,
        "homeLoan24b": profile.deductions.homeLoanInterest,
        "totalDeductionsApplied": calculation.deductionsApplied
      },
      "taxComputation": {
        "grossTotalIncome": calculation.grossIncome,
        "netTaxableIncome": calculation.netTaxableIncome,
        "taxPayableBeforeCess": calculation.taxBeforeCess,
        "rebate87A": calculation.rebate87A,
        "surcharge": calculation.surcharge,
        "educationCess": calculation.cess,
        "totalTaxDue": calculation.totalTaxDue,
        "regimeSelected": calculation.regimeName
      }
    };

    return const JsonEncoder.withIndent('  ').convert(schema);
  }

  /// Exports the ITR-4 JSON data (directly downloads on Web or shares file on mobile devices)
  static Future<File?> exportItr4Json({
    required double totalIncome,
    required double totalExpenses,
    required TaxProfile profile,
  }) async {
    try {
      final jsonString = await createItr4JsonString(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        profile: profile,
      );
      final bytes = utf8.encode(jsonString);
      final fileName = 'gigtax_itr4_export_${DateTime.now().millisecondsSinceEpoch}.json';

      if (kIsWeb) {
        await downloadFileWeb(bytes, fileName, 'application/json');
        AppLogger.info(_tag, 'JSON downloaded directly on web');
        return null;
      }

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(bytes);

      AppLogger.info(_tag, 'JSON report saved: ${file.path}');
      
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'My pre-filled GigTax ITR-4 Schema Export');
      return file;
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to export ITR4 JSON', e, stack);
      return null;
    }
  }
}
