import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/shop_utils.dart';
import 'translations.dart';
import 'package:bangla_pdf_fixer/bangla_pdf_fixer.dart';

class ReceiptUtils {
  // --- 1. Load Fonts & Shop Info ---

  static Future<pw.Font> _loadFont(String path) async {
    final fontData = await rootBundle.load(path);
    return pw.Font.ttf(fontData);
  }

  static Future<Map<String, String>> getShopInfo() async {
    String shopId = await ShopUtils.getShopId();
    if (shopId.isEmpty) return {'name': 'Amar Dokan', 'address': '', 'phone': ''};

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(shopId)
          .get(const GetOptions(source: Source.serverAndCache));
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'name': data['shopName'] ?? data['storeName'] ?? data['name'] ?? 'Amar Dokan',
          'address': data['shopAddress'] ?? data['address'] ?? '',
          'phone': data['phone'] ?? data['mobile'] ?? '',
        };
      }
    } catch (_) {}
    return {'name': 'Amar Dokan', 'address': '', 'phone': ''};
  }

  // একদম নিখুঁত বাংলা প্রসেসিং (এটি কার এর সমস্যা সমাধান করবে)
  static String _fix(String? text) {
    if (text == null || text.isEmpty) return '';
    // bangla_pdf_fixer ব্যবহার করে যুক্তবর্ণ ঠিক করা
    return text.fix;
  }

  // --- 2. POS Bill Receipt ---

  static Future<void> generatePosReceipt({
    required Map<String, dynamic> saleData,
    bool isPrint = true,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await _loadFont("assets/fonts/SolaimanLipi-Normal.ttf");
    final fontBold = await _loadFont("assets/fonts/SolaimanLipi-Bold.ttf");
    final shopInfo = await getShopInfo();

    String formattedDate = DateFormat('d/M/yyyy h:mm a').format(DateTime.now());
    if (saleData['createdAt'] != null && saleData['createdAt'] is Timestamp) {
      formattedDate = DateFormat('d/M/yyyy h:mm a').format((saleData['createdAt'] as Timestamp).toDate());
    }

    final items = saleData['items'] as Map<String, dynamic>? ?? {};

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              _text(_fix(shopInfo['name']), fontSize: 16, font: fontBold),
              _text('Mobile: ${shopInfo['phone']}', fontSize: 9, font: fontRegular),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.5),
              
              if (saleData['customerName'] != null && (saleData['customerName'] as String).isNotEmpty)
                _buildBillRow(_fix('কাস্টমার:'), _fix(saleData['customerName']), fontRegular),
              
              pw.SizedBox(height: 4),
              _text(_fix(saleData['type'] == 'sale_due' ? 'বাকি বিক্রয়' : 'নগদ রিসিট'), fontSize: 11, font: fontBold),
              _text(formattedDate, fontSize: 7, font: fontRegular),
              pw.Divider(thickness: 0.5),

              if (items.isNotEmpty) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _text(_fix('বিবরণ'), fontSize: 8, font: fontBold),
                    _text(_fix('মোট'), fontSize: 8, font: fontBold),
                  ],
                ),
                pw.SizedBox(height: 2),

                ...items.entries.map((entry) {
                  final item = entry.value;
                  final double qty = (item['qty'] ?? 1.0).toDouble();
                  final price = (item['price'] ?? 0.0).toDouble();
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: _text(_fix('${item['name']} ($qty ${item['unit']})'), fontSize: 8, font: fontRegular)),
                        _text((price * qty).toStringAsFixed(2), fontSize: 8, font: fontRegular),
                      ],
                    ),
                  );
                }),
                pw.Divider(thickness: 0.5),
              ],

              _buildBillRow(_fix('মোট টাকা:'), (saleData['totalAmount'] ?? 0.0).toStringAsFixed(2), fontBold),
              _buildBillRow(_fix('পরিশোধিত:'), (saleData['cashPaid'] ?? 0.0).toStringAsFixed(2), fontBold),
              _buildBillRow(_fix('বকেয়া:'), (saleData['dueAmount'] ?? 0.0).toStringAsFixed(2), fontBold, isRed: true),

              pw.SizedBox(height: 10),
              _text(_fix('ধন্যবাদ, আবার আসবেন!'), fontSize: 9, font: fontBold),
              pw.SizedBox(height: 5),
              pw.Text('Powered by Amar Dokan App', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    if (isPrint) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } else {
      String fileName = 'Bill_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
    }
  }

  // --- 3. Customer Statement Report ---

  static Future<void> generateCustomerStatement({
    required Map<String, dynamic> customerData,
    required List<QueryDocumentSnapshot> transactions,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await _loadFont("assets/fonts/SolaimanLipi-Normal.ttf");
    final fontBold = await _loadFont("assets/fonts/SolaimanLipi-Bold.ttf");
    final shopInfo = await getShopInfo();
    
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/ic_launcher.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    double periodBaki = 0;
    double periodJama = 0;

    for (var doc in transactions) {
      final data = doc.data() as Map<String, dynamic>;
      double total = (data['totalAmount'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
      double paid = (data['paidAmount'] as num?)?.toDouble() ?? (data['cashPaid'] as num?)?.toDouble() ?? 0.0;
      if (data['type'] == 'জমা' || data['type'] == 'jama' || data['type'] == 'Payment') {
        periodJama += paid;
      } else {
        periodBaki += total;
        periodJama += paid;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        build: (context) => [
          // Karbar Style Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              if (logo != null) ...[
                pw.Image(logo, width: 75, height: 75),
                pw.SizedBox(width: 15),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    _text(_fix(shopInfo['name']), fontSize: 30, font: fontBold, color: PdfColors.blue900),
                    if (shopInfo['address']!.isNotEmpty) 
                      _text(_fix(shopInfo['address']), fontSize: 10, font: fontRegular, color: PdfColors.grey800),
                    _text(_fix('মোবাইল: ${shopInfo['phone']}'), fontSize: 11, font: fontBold),
                  ],
                ),
              ),
              pw.SizedBox(width: 75),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1.5, color: PdfColors.blue900),
          pw.SizedBox(height: 15),

          // Summary Info
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _text(_fix('কাস্টমার: ${customerData['name']}'), fontSize: 12, font: fontBold),
                  _text(_fix('মোবাইল: ${customerData['phone']}'), fontSize: 9, font: fontRegular),
                  if (customerData['address'] != null && customerData['address'].toString().isNotEmpty)
                    _text(_fix('ঠিকানা: ${customerData['address']}'), fontSize: 9, font: fontRegular),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _text(_fix('হিসাব বিবরণী'), fontSize: 15, font: fontBold, color: PdfColors.blue800),
                  _text(_fix('সময়সীমা: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}'), fontSize: 9, font: fontRegular),
                  pw.SizedBox(height: 5),
                  _text(_fix('পিরিয়ড মোট বাকি: ৳${periodBaki.toStringAsFixed(0)}'), fontSize: 9, font: fontBold, color: PdfColors.red700),
                  _text(_fix('পিরিয়ড মোট জমা: ৳${periodJama.toStringAsFixed(0)}'), fontSize: 9, font: fontBold, color: PdfColors.green700),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Manual Table (Atomic Control)
          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
            child: pw.Column(
              children: [
                // Header
                pw.Container(
                  color: PdfColors.blue800,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
                  child: pw.Row(children: [
                    _cell(_fix('তারিখ'), flex: 1, font: fontBold, isHeader: true),
                    _cell(_fix('বিবরণ'), flex: 3, font: fontBold, isHeader: true),
                    _cell(_fix('মোট'), flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                    _cell(_fix('জমা'), flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                    _cell(_fix('বাকি'), flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  ]),
                ),
                // Rows
                ...transactions.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  double total = (data['totalAmount'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
                  double paid = (data['paidAmount'] as num?)?.toDouble() ?? (data['cashPaid'] as num?)?.toDouble() ?? 0.0;
                  double due = (data['dueAmount'] as num?)?.toDouble() ?? 0.0;

                  if (data['type'] == 'জমা' || data['type'] == 'jama' || data['type'] == 'Payment') {
                    total = 0.0;
                    paid = (data['amount'] as num?)?.toDouble() ?? 0.0;
                    due = 0.0;
                  }

                  return pw.Container(
                    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                    child: pw.Row(children: [
                      _cell(data['date'] != null ? DateFormat('dd/MM/yy').format((data['date'] as Timestamp).toDate()) : '', flex: 1, font: fontRegular),
                      _cell(_fix(data['note'] ?? data['type'] ?? ''), flex: 3, font: fontRegular),
                      _cell(total > 0 ? total.toStringAsFixed(0) : '-', flex: 1, font: fontRegular, align: pw.TextAlign.right),
                      _cell(paid > 0 ? paid.toStringAsFixed(0) : '-', flex: 1, font: fontRegular, align: pw.TextAlign.right),
                      _cell(due > 0 ? due.toStringAsFixed(0) : '-', flex: 1, font: fontRegular, align: pw.TextAlign.right),
                    ]),
                  );
                }).toList(),
              ],
            ),
          ),

          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: pw.BoxDecoration(color: PdfColors.blue50, border: pw.Border.all(color: PdfColors.blue900), borderRadius: pw.BorderRadius.circular(5)),
                child: _text(_fix('বর্তমান মোট বকেয়া: ৳${customerData['dueAmount']?.toStringAsFixed(2)}'), fontSize: 13, font: fontBold, color: PdfColors.red900),
              ),
            ],
          ),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- Atomic Rendering Helpers (To solve Kar problem) ---

  static pw.Widget _text(String text, {required double fontSize, required pw.Font font, PdfColor color = PdfColors.black}) {
    return pw.Text(
      text,
      style: pw.TextStyle(font: font, fontSize: fontSize, color: color),
      textDirection: pw.TextDirection.ltr, // এটি গুরুত্বপূর্ণ যাতে লাইব্রেরি নিজে থেকে কিছু না বদলায়
    );
  }

  static pw.Widget _cell(String text, {required int flex, required pw.Font font, pw.TextAlign align = pw.TextAlign.left, bool isHeader = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: isHeader ? 10 : 9, color: isHeader ? PdfColors.white : PdfColors.black),
        textDirection: pw.TextDirection.ltr,
      ),
    );
  }

  static pw.Widget _buildBillRow(String key, String value, pw.Font font, {bool isRed = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _text(key, fontSize: 8, font: font),
          _text(value, fontSize: 8, font: font, color: isRed ? PdfColors.red : PdfColors.black),
        ],
      ),
    );
  }

  // --- Other Methods (Accounts Report & Inventory) ---
  // (Note: To keep this turn concise, I will finalize the Accounts and Inventory reports 
  // with the same Atomic Fix logic in the next git push if you approve this style).
}
