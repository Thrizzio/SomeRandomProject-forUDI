import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../services/app_logger.dart';
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
  }) async {
    try {
      final pdf = pw.Document();

      // Client distribution data
      final sourceTotals = <String, double>{};
      for (final tx in transactions) {
        final double amt = double.tryParse(
              tx.amount.replaceAll(',', '').replaceAll('INR', '').trim(),
            ) ??
            0.0;
        sourceTotals[tx.sender] = (sourceTotals[tx.sender] ?? 0.0) + amt;
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
                          'GIGTAX FINANCIAL REPORT',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 20,
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
                  _buildKpiCard('Gross Income', 'INR ${totalIncome.toStringAsFixed(2)}'),
                  _buildKpiCard('Taxable Income', 'INR ${taxableIncome.toStringAsFixed(2)}'),
                  _buildKpiCard('Estimated Tax', 'INR ${taxPayable.toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 24),

              // Section: Client Breakdown Table
              pw.Text(
                'Income by Platform/Client',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _tableHeaderCell('Source / Platform'),
                      _tableHeaderCell('Total Received'),
                      _tableHeaderCell('Share %'),
                    ],
                  ),
                  ...sortedSources.map((entry) {
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

              // Section: Recent Activity List
              pw.Text(
                'Recent Transactions',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _tableHeaderCell('Date'),
                      _tableHeaderCell('Client'),
                      _tableHeaderCell('Amount'),
                      _tableHeaderCell('Type'),
                    ],
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
          },
        ),
      );

      final pdfBytes = await pdf.save();

      if (kIsWeb) {
        await downloadFileWeb(pdfBytes, 'gigtax_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
        AppLogger.info(_tag, 'PDF Report downloaded directly on web');
        return null;
      }

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/gigtax_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);
      
      AppLogger.info(_tag, 'PDF Report saved: ${file.path}');
      return file;
    } catch (e, stack) {
      AppLogger.error(_tag, 'Failed to generate PDF report', e, stack);
      return null;
    }
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
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
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
