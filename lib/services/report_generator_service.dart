import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../models/tax_profile.dart';
import '../services/app_logger.dart';
import '../services/tax_engine_v2.dart';
import 'package:flutter/foundation.dart';
import '../utils/file_download_helper.dart'
    if (dart.library.html) '../utils/file_download_helper_web.dart';

class ReportGeneratorService {
  static const String _tag = 'ReportGeneratorService';

  static Future<File?> generatePdfReport({
    required List<Transaction> transactions,
    required String userEmail,
    required double totalIncome,
    required double taxableIncome,
    required double taxPayable,
    String reportType = 'income_summary',
    TaxProfile? taxProfile,
  }) async {
    try {
      final pdf = pw.Document();
      final String titleText = _getReportTitle(reportType);

      // Client distribution data
      final sourceTotals = <String, double>{};
      final sourceCounts = <String, int>{};
      for (final tx in transactions) {
        final double amt = double.tryParse(
              tx.amount.replaceAll(',', '').replaceAll('INR', '').replaceAll('₹', '').replaceAll('Rs', '').trim(),
            ) ??
            0.0;
        sourceTotals[tx.sender] = (sourceTotals[tx.sender] ?? 0.0) + amt;
        sourceCounts[tx.sender] = (sourceCounts[tx.sender] ?? 0) + 1;
      }

      final sortedSources = sourceTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header Banner
              pw.Container(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF6366F1), // Indigo
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          titleText,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Prepared for: $userEmail',
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Text(
                      DateFormat('dd MMM yyyy').format(DateTime.now()),
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary KPI Cards
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildKpiCard('Gross Receipts', 'INR ${totalIncome.toStringAsFixed(2)}'),
                  _buildKpiCard('Presumptive Profit', 'INR ${taxableIncome.toStringAsFixed(2)}'),
                  _buildKpiCard('Tax Estimate', 'INR ${taxPayable.toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 24),

              // Dynamic content based on reportType
              if (reportType == 'annual_tax' && taxProfile != null)
                ..._buildAnnualTaxReportSection(taxProfile, totalIncome)
              else if (reportType == 'quarterly_tax')
                ..._buildQuarterlyTaxReportSection(taxPayable, transactions)
              else if (reportType == 'client_revenue')
                ..._buildClientRevenueSection(sortedSources, sourceCounts, totalIncome)
              else if (reportType == 'source_revenue')
                ..._buildSourceRevenueSection(transactions, totalIncome)
              else
                ..._buildIncomeSummarySection(sortedSources, transactions, totalIncome),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();

      if (kIsWeb) {
        await downloadFileWeb(pdfBytes, 'gigtax_${reportType}_${DateTime.now().millisecondsSinceEpoch}.pdf');
        AppLogger.info(_tag, 'PDF Report downloaded directly on web');
        return null;
      }

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/gigtax_${reportType}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);
      
      AppLogger.info(_tag, 'PDF Report saved: ${file.path}');
      return file;
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to generate PDF report', e, stack);
      return null;
    }
  }

  static String _getReportTitle(String type) {
    switch (type) {
      case 'annual_tax':
        return 'ANNUAL TAX LEGISLATIVE REPORT';
      case 'quarterly_tax':
        return 'QUARTERLY ADVANCE TAX REPORT';
      case 'client_revenue':
        return 'CLIENT REVENUE MATRIX REPORT';
      case 'source_revenue':
        return 'UPI / BANK SOURCE REVENUE REPORT';
      default:
        return 'INCOME LEDGER SUMMARY';
    }
  }

  /// 1. Annual Tax Report Section
  static List<pw.Widget> _buildAnnualTaxReportSection(TaxProfile profile, double gross) {
    final comparison = TaxEngineV2.compareRegimes(grossIncome: gross, profile: profile);
    final currentResult = profile.taxRegime == 'new' 
        ? comparison['newRegimeResult'] as TaxCalculationResult 
        : comparison['oldRegimeResult'] as TaxCalculationResult;

    final otherResult = profile.taxRegime == 'new' 
        ? comparison['oldRegimeResult'] as TaxCalculationResult 
        : comparison['newRegimeResult'] as TaxCalculationResult;

    return [
      pw.Text('Tax Profile & Legislative Parameters', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(children: [_tableCell('Profession type'), _tableCell(profile.professionType.toUpperCase())]),
          pw.TableRow(children: [_tableCell('Business Category'), _tableCell(profile.businessCategory.toUpperCase())]),
          pw.TableRow(children: [_tableCell('Active Tax Regime'), _tableCell(profile.taxRegime.toUpperCase())]),
          pw.TableRow(children: [_tableCell('Business Type'), _tableCell(profile.businessType)]),
        ],
      ),
      pw.SizedBox(height: 18),
      pw.Text('Regime Comparison', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [_tableHeaderCell('Parameter'), _tableHeaderCell('New Regime'), _tableHeaderCell('Old Regime')],
          ),
          pw.TableRow(children: [
            _tableCell('Net Taxable Income'),
            _tableCell('INR ${(comparison['newRegimeResult'] as TaxCalculationResult).netTaxableIncome.toStringAsFixed(0)}'),
            _tableCell('INR ${(comparison['oldRegimeResult'] as TaxCalculationResult).netTaxableIncome.toStringAsFixed(0)}'),
          ]),
          pw.TableRow(children: [
            _tableCell('Effective Tax Rate'),
            _tableCell('${(comparison['effectiveRateNew'] as double).toStringAsFixed(2)}%'),
            _tableCell('${(comparison['effectiveRateOld'] as double).toStringAsFixed(2)}%'),
          ]),
          pw.TableRow(children: [
            _tableCell('Total Estimated Tax'),
            _tableCell('INR ${(comparison['newRegimeResult'] as TaxCalculationResult).totalTaxDue.toStringAsFixed(0)}'),
            _tableCell('INR ${(comparison['oldRegimeResult'] as TaxCalculationResult).totalTaxDue.toStringAsFixed(0)}'),
          ]),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Text('Recommendation Explanation:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      pw.Text(comparison['explanation'] as String, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 18),
      pw.Text('Detailed Slabs Applied (${profile.taxRegime.toUpperCase()}):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      pw.SizedBox(height: 6),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [_tableHeaderCell('Slab Range'), _tableHeaderCell('Rate %'), _tableHeaderCell('Tax')],
          ),
          ...currentResult.slabsApplied.map((slab) => pw.TableRow(
            children: [
              _tableCell(slab.slabRange),
              _tableCell('${(slab.rate * 100).toStringAsFixed(0)}%'),
              _tableCell('INR ${slab.taxAmount.toStringAsFixed(0)}'),
            ],
          )),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Text('Audit Details:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.Text('Cess (4%): INR ${currentResult.cess.toStringAsFixed(2)} | Surcharge: INR ${currentResult.surcharge.toStringAsFixed(2)} | Rebate: INR ${currentResult.rebate87A.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      pw.Text('Formula: ${currentResult.formulaDescription}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ];
  }

  /// 2. Quarterly Tax Report Section
  static List<pw.Widget> _buildQuarterlyTaxReportSection(double annualTax, List<Transaction> txs) {
    final installments = TaxEngineV2.calculateAdvanceTaxInstallments(annualTax);
    
    // Group transactions by quarter
    double q1 = 0, q2 = 0, q3 = 0, q4 = 0;
    for (final tx in txs) {
      try {
        final date = DateTime.parse(tx.date);
        final amt = double.tryParse(tx.amount.replaceAll(',', '').replaceAll('INR', '').trim()) ?? 0;
        if (date.month >= 4 && date.month <= 6) q1 += amt;
        else if (date.month >= 7 && date.month <= 9) q2 += amt;
        else if (date.month >= 10 && date.month <= 12) q3 += amt;
        else q4 += amt;
      } catch (_) {}
    }

    return [
      pw.Text('Advance Tax Obligation Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [_tableHeaderCell('Installment'), _tableHeaderCell('Due Date'), _tableHeaderCell('Cumulative %'), _tableHeaderCell('Expected Cumulative Amt')],
          ),
          ...installments.map((inst) => pw.TableRow(
            children: [
              _tableCell(inst['installment'] as String),
              _tableCell(inst['dueDate'] as String),
              _tableCell('${(inst['percentage'] as double).toStringAsFixed(0)}%'),
              _tableCell('INR ${(inst['cumulativeAmount'] as double).toStringAsFixed(2)}'),
            ],
          )),
        ],
      ),
      pw.SizedBox(height: 18),
      pw.Text('Quarterly Income Ledger Collections', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [_tableHeaderCell('Quarter'), _tableHeaderCell('Period'), _tableHeaderCell('Total Collected')],
          ),
          pw.TableRow(children: [_tableCell('Q1'), _tableCell('Apr - Jun'), _tableCell('INR ${q1.toStringAsFixed(2)}')]),
          pw.TableRow(children: [_tableCell('Q2'), _tableCell('Jul - Sep'), _tableCell('INR ${q2.toStringAsFixed(2)}')]),
          pw.TableRow(children: [_tableCell('Q3'), _tableCell('Oct - Dec'), _tableCell('INR ${q3.toStringAsFixed(2)}')]),
          pw.TableRow(children: [_tableCell('Q4'), _tableCell('Jan - Mar'), _tableCell('INR ${q4.toStringAsFixed(2)}')]),
        ],
      ),
    ];
  }

  /// 3. Client Revenue Matrix
  static List<pw.Widget> _buildClientRevenueSection(List<MapEntry<String, double>> sources, Map<String, int> counts, double total) {
    return [
      pw.Text('Revenue Concentration Matrix by Client', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [_tableHeaderCell('Client Name'), _tableHeaderCell('Total Receipts'), _tableHeaderCell('Tx Count'), _tableHeaderCell('Avg Ticket Size'), _tableHeaderCell('Share %')],
          ),
          ...sources.map((entry) {
            final count = counts[entry.key] ?? 1;
            final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
            final avg = entry.value / count;
            return pw.TableRow(
              children: [
                _tableCell(entry.key),
                _tableCell('INR ${entry.value.toStringAsFixed(2)}'),
                _tableCell(count.toString()),
                _tableCell('INR ${avg.toStringAsFixed(2)}'),
                _tableCell('${pct.toStringAsFixed(1)}%'),
              ],
            );
          }),
        ],
      ),
    ];
  }

  /// 4. Source Revenue Section
  static List<pw.Widget> _buildSourceRevenueSection(List<Transaction> txs, double total) {
    // Categorize by payment engine
    final engineTotals = <String, double>{};
    for (final tx in txs) {
      final double amt = double.tryParse(
            tx.amount.replaceAll(',', '').replaceAll('INR', '').replaceAll('₹', '').replaceAll('Rs', '').trim(),
          ) ??
          0.0;
      final body = tx.messageBody.toLowerCase();
      String engine = 'Bank Transfer / Other';
      
      if (body.contains('upi') || body.contains('phonepe') || body.contains('gpay') || body.contains('paytm') || body.contains('razorpay') || body.contains('amazonpay')) {
        if (body.contains('phonepe')) engine = 'PhonePe';
        else if (body.contains('gpay') || body.contains('google pay')) engine = 'Google Pay';
        else if (body.contains('paytm')) engine = 'Paytm';
        else if (body.contains('razorpay')) engine = 'Razorpay';
        else if (body.contains('amazonpay')) engine = 'Amazon Pay';
        else engine = 'Generic UPI';
      } else if (tx.sender.toUpperCase().contains('HDFC')) {
        engine = 'HDFC Bank';
      } else if (tx.sender.toUpperCase().contains('SBI')) {
        engine = 'SBI Bank';
      } else if (tx.sender.toUpperCase().contains('ICICI')) {
        engine = 'ICICI Bank';
      } else if (tx.sender.toUpperCase().contains('AXIS')) {
        engine = 'Axis Bank';
      }

      engineTotals[engine] = (engineTotals[engine] ?? 0.0) + amt;
    }

    final sortedEngines = engineTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      pw.Text('Revenue Contribution by Payment Gateway / Bank Channel', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [_tableHeaderCell('Gateway / Channel'), _tableHeaderCell('Total Credited'), _tableHeaderCell('Share %')],
          ),
          ...sortedEngines.map((entry) {
            final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
            return pw.TableRow(
              children: [
                _tableCell(entry.key),
                _tableCell('INR ${entry.value.toStringAsFixed(2)}'),
                _tableCell('${pct.toStringAsFixed(1)}%'),
              ],
            );
          }),
        ],
      ),
    ];
  }

  /// 5. Standard Income Summary Section
  static List<pw.Widget> _buildIncomeSummarySection(List<MapEntry<String, double>> sortedSources, List<Transaction> transactions, double totalIncome) {
    return [
      // Client Breakdown
      pw.Text('Income by Platform/Client', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [_tableHeaderCell('Source / Platform'), _tableHeaderCell('Total Received'), _tableHeaderCell('Share %')],
          ),
          ...sortedSources.take(5).map((entry) {
            final pct = totalIncome > 0 ? (entry.value / totalIncome) * 100 : 0.0;
            return pw.TableRow(
              children: [
                _tableCell(entry.key),
                _tableCell('INR ${entry.value.toStringAsFixed(2)}'),
                _tableCell('${pct.toStringAsFixed(1)}%'),
              ],
            );
          }),
        ],
      ),
      pw.SizedBox(height: 24),

      // Recent Activity
      pw.Text('Recent Transactions Log', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Divider(color: PdfColors.grey300),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            children: [_tableHeaderCell('Date'), _tableHeaderCell('Client'), _tableHeaderCell('Amount'), _tableHeaderCell('Type')],
          ),
          ...transactions.take(15).map((tx) {
            return pw.TableRow(
              children: [
                _tableCell(tx.date.substring(0, 10)),
                _tableCell(tx.sender),
                _tableCell('INR ${tx.amount}'),
                _tableCell(tx.transactionType.toUpperCase()),
              ],
            );
          }),
        ],
      ),
    ];
  }

  static Future<void> shareReport(File file) async {
    try {
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'My GigTax Financial Statement & Tax Estimate Report');
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to share PDF report', e, stack);
    }
  }

  static pw.Widget _buildKpiCard(String title, String value) {
    return pw.Container(
      width: 150,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      ),
    );
  }

  static pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }
}
