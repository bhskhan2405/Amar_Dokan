import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReceiptUtils {
  static Future<void> shareSubscriptionCard({
    required String name,
    required String shopName,
    required String phone,
    String? plan,
    String? txId,
    String? senderDigits,
    bool isActivation = false,
    bool isApproval = false,
  }) async {
    final pdf = pw.Document();

    // লোগো লোড করা
    final imageByte = await rootBundle.load('assets/images/ic_launcher.png');
    final image = pw.MemoryImage(imageByte.buffer.asUint8List());

    // বাংলা ফন্ট লোড করা
    pw.Font? banglaFont;
    try {
      final fontData = await rootBundle.load("assets/fonts/SolaimanLipi-Normal.ttf");
      banglaFont = pw.Font.ttf(fontData);
    } catch (_) {}

    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    final planDisplay = plan?.replaceAll('_', ' ').toUpperCase() ?? 'N/A';
    String title = 'SUBSCRIPTION REQUEST';
    PdfColor titleColor = PdfColors.orange900;
    PdfColor borderColor = PdfColors.blue900;

    if (isActivation) {
      title = 'PREMIUM ACTIVATED';
      titleColor = PdfColors.green700;
      borderColor = PdfColors.green900;
    } else if (isApproval) {
      title = 'ACCOUNT APPROVED';
      titleColor = PdfColors.blue700;
      borderColor = PdfColors.blue900;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(400, 520, marginAll: 20),
        theme: banglaFont != null ? pw.ThemeData.withFont(base: banglaFont, bold: banglaFont) : null,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: borderColor, width: 2),
              borderRadius: pw.BorderRadius.circular(15),
              color: PdfColors.white,
            ),
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header with Logo
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Image(image, width: 40, height: 40),
                    pw.SizedBox(width: 10),
                    pw.Text('Amar Dokan', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: isActivation ? PdfColors.green800 : PdfColors.blue800)),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),

                // Title
                pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: titleColor),
                ),
                pw.SizedBox(height: 20),

                // Details Table
                _buildRow('Owner Name', name),
                _buildRow('Shop Name', shopName),
                _buildRow('Mobile', phone),
                if (!isApproval) ...[
                  _buildRow('Plan', planDisplay),
                  _buildRow('Transaction ID', txId ?? 'N/A'),
                  if (senderDigits != null) _buildRow('Sender Last 4', senderDigits),
                ],
                
                if (isActivation) ...[
                  pw.SizedBox(height: 15),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.green50, borderRadius: pw.BorderRadius.circular(5)),
                    child: pw.Text(
                      'Congratulations! Your premium features are now active. Enjoy managing your business with Amar Dokan.',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.green900),
                    ),
                  ),
                ] else if (isApproval) ...[
                  pw.SizedBox(height: 15),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(5)),
                    child: pw.Text(
                      'Congratulations! Your account is now approved. Welcome to Amar Dokan family.',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue900),
                    ),
                  ),
                ],

                pw.Spacer(),

                // Footer with Date and Time
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('Time: $timeStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text('Thank you for choosing Amar Dokan', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
          );
        },
      ),
    );

    String fileName = 'card_${now.millisecondsSinceEpoch}.pdf';
    if (isActivation) fileName = 'activation_card_$txId.pdf';
    else if (isApproval) fileName = 'approval_card_$phone.pdf';
    else if (txId != null) fileName = 'subscription_receipt_$txId.pdf';

    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
  }


  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Flexible(
            child: pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          ),
        ],
      ),
    );
  }
}
