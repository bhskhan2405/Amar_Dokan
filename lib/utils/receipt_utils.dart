import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'translations.dart';

class ReceiptUtils {
  // --- ফন্ট ও শপ ইনফো ---

  static Future<pw.Font> loadBengaliFont() async {
    try {
      final fontData = await rootBundle.load("assets/fonts/SolaimanLipi-Normal.ttf");
      return pw.Font.ttf(fontData);
    } catch (e) {
      return await PdfGoogleFonts.notoSansBengaliRegular();
    }
  }

  static Future<pw.Font> loadBengaliFontBold() async {
    try {
      final fontData = await rootBundle.load("assets/fonts/SolaimanLipi-Bold.ttf");
      return pw.Font.ttf(fontData);
    } catch (e) {
      return await PdfGoogleFonts.notoSansBengaliBold();
    }
  }

  static Future<Map<String, String>> getShopInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'name': 'Amar Dokan', 'address': '', 'phone': ''};

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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

  // --- POS বিল রিসিট (Image 1 এর মতো নিখুঁত ডিজাইন) ---

  static Future<void> generatePosReceipt({required Map<String, dynamic> saleData}) async {
    final pdf = pw.Document();
    final fontRegular = await loadBengaliFont();
    final fontBold = await loadBengaliFontBold();
    final shopInfo = await getShopInfo();

    // অনুবাদিত টেক্সট
    final labelTelp = AppTranslations.currentLanguage == 'bn' ? 'মোবাইল' : 'Telp.';
    final labelCashReceipt = AppTranslations.get('cash_receipt');
    final labelPaymentType = AppTranslations.get('payment_type');
    final labelSellBy = AppTranslations.get('sell_by');
    final labelDescription = AppTranslations.get('description');
    final labelDiscount = AppTranslations.get('discount');
    final labelPrice = AppTranslations.get('price');
    final labelTotal = AppTranslations.get('total');
    final labelTotalAmount = AppTranslations.get('total_revenue');
    final labelPaid = AppTranslations.get('paid_amount');
    final labelDue = AppTranslations.get('due');
    final labelQty = AppTranslations.get('qty') ?? 'Qty';
    final labelThankYou = AppTranslations.get('thank_you_msg');
    final currency = AppTranslations.get('currency_symbol');

    String formattedDateTime = '';
    if (saleData['createdAt'] != null && saleData['createdAt'] is Timestamp) {
      formattedDateTime = DateFormat('d/M/yyyy h:mm a').format((saleData['createdAt'] as Timestamp).toDate());
    } else {
      formattedDateTime = DateFormat('d/M/yyyy h:mm a').format(DateTime.now());
    }

    final items = saleData['items'] as Map<String, dynamic>? ?? {};
    const stars = '****************************************';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // দোকান নাম ও ফোন
              pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('$labelTelp: ${shopInfo['phone']}', style: const pw.TextStyle(fontSize: 9)),
              
              pw.SizedBox(height: 5),
              pw.Text(stars, style: const pw.TextStyle(fontSize: 8)),
              
              // টাইটেল (Upper Case শুধুমাত্র ইংরেজির জন্য)
              pw.Text(
                AppTranslations.currentLanguage == 'en' ? labelCashReceipt.toUpperCase() : labelCashReceipt, 
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)
              ),
              pw.Text(formattedDateTime, style: const pw.TextStyle(fontSize: 7)),
              
              pw.Text(stars, style: const pw.TextStyle(fontSize: 8)),

              // পেমেন্ট ও বিক্রেতা তথ্য
              _buildKeyValueRow('$labelPaymentType:', saleData['paymentType'] ?? 'Cash'),
              _buildKeyValueRow('$labelSellBy:', saleData['staffName'] ?? 'Admin'),
              
              pw.Text(stars, style: const pw.TextStyle(fontSize: 8)),

              // টেবিল হেডার
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 3, child: pw.Text(labelDescription, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text(labelDiscount, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text(labelPrice, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              
              pw.Text(stars, style: const pw.TextStyle(fontSize: 8)),

              // আইটেম লিস্ট
              ...items.entries.map((entry) {
                final item = entry.value;
                final double qty = (item['qty'] ?? 1.0).toDouble();
                final unit = item['unit'] ?? 'Pcs';
                final discount = (item['discount'] ?? 0.0).toDouble();
                final price = (item['price'] ?? 0.0).toDouble();
                final originalPrice = (item['originalPrice'] ?? price).toDouble();
                final itemDiscountTk = (originalPrice * discount) / 100;

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(flex: 3, child: pw.Text(item['name'] ?? '', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(flex: 2, child: pw.Text(discount > 0 ? '${discount.toStringAsFixed(0)}% (${itemDiscountTk.toStringAsFixed(0)})' : '-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
                          pw.Expanded(flex: 2, child: pw.Text((price * qty).toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      pw.Text('$labelQty: $qty $unit', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                    ],
                  ),
                );
              }),

              pw.Text(stars, style: const pw.TextStyle(fontSize: 8)),

              // হিসাব নিকাশ
              _buildSummaryRow(labelTotal, (saleData['subTotal'] ?? 0.0).toStringAsFixed(2)),
              _buildSummaryRow(labelTotalAmount, (saleData['totalAmount'] ?? 0.0).toStringAsFixed(2), isBold: true, fontSize: 10),
              _buildSummaryRow(labelPaid, (saleData['cashPaid'] ?? 0.0).toStringAsFixed(2)),
              _buildSummaryRow(labelDue, (saleData['dueAmount'] ?? 0.0).toStringAsFixed(2)),

              pw.Text(stars, style: const pw.TextStyle(fontSize: 8)),
              
              pw.SizedBox(height: 5),
              pw.Text(
                AppTranslations.currentLanguage == 'en' ? labelThankYou.toUpperCase() : labelThankYou, 
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)
              ),
              pw.SizedBox(height: 10),
              
              // বারকোড (Image 1 এর মতো)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: List.generate(24, (index) => pw.Container(
                  width: index % 3 == 0 ? 3 : (index % 2 == 0 ? 1 : 2),
                  height: 25,
                  color: PdfColors.black,
                  margin: const pw.EdgeInsets.symmetric(horizontal: 0.5),
                )),
              ),
              
              pw.SizedBox(height: 5),
              pw.Text('Powered by Amar Dokan App', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- হেল্পার উইজেটস (রিসিটের জন্য) ---

  static pw.Widget _buildKeyValueRow(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(key, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  // --- অন্যান্য রিপোর্ট (Statement, Accounts) ---

  static Future<void> generateCustomerStatement({
    required Map<String, dynamic> customerData,
    required List<QueryDocumentSnapshot> transactions,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await loadBengaliFont();
    final fontBold = await loadBengaliFontBold();
    final shopInfo = await getShopInfo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          if (shopInfo['address']!.isNotEmpty) pw.Text(shopInfo['address']!, style: const pw.TextStyle(fontSize: 10)),
          pw.Text('${AppTranslations.get('mobile')}: ${shopInfo['phone']}', style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
          pw.SizedBox(height: 10),
        ]),
        build: (context) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${AppTranslations.get('customer')}: ${customerData['name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('${AppTranslations.get('mobile')}: ${customerData['phone']}', style: const pw.TextStyle(fontSize: 10)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(AppTranslations.get('statement'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}', style: const pw.TextStyle(fontSize: 9)),
            ]),
          ]),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _tableCell(AppTranslations.get('date'), isBold: true),
                  _tableCell(AppTranslations.get('description'), isBold: true),
                  _tableCell(AppTranslations.get('amount'), isBold: true, align: pw.TextAlign.right),
                  _tableCell(AppTranslations.get('balance'), isBold: true, align: pw.TextAlign.right),
                ],
              ),
              ...transactions.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isJama = (data['type'] == 'জমা' || data['type'] == 'jama' || data['type'] == 'Payment');
                return pw.TableRow(children: [
                  _tableCell(data['date'] != null ? DateFormat('dd/MM/yy').format((data['date'] as Timestamp).toDate()) : ''),
                  _tableCell(data['note'] ?? data['type'] ?? ''),
                  _tableCell('${AppTranslations.get('currency_symbol')} ${(data['amount'] as num?)?.toDouble() ?? 0.0}', color: isJama ? PdfColors.green : PdfColors.red, align: pw.TextAlign.right),
                  _tableCell('${AppTranslations.get('currency_symbol')} ${(data['balance'] as num?)?.toDouble() ?? 0.0}', align: pw.TextAlign.right),
                ]);
              }),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue)),
              child: pw.Text('${AppTranslations.get('total_due')}: ${AppTranslations.get('currency_symbol')} ${customerData['dueAmount']?.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            )
          ]),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateAccountsReport({
    required List<QueryDocumentSnapshot> sales,
    required List<QueryDocumentSnapshot> expenses,
    required double totalSale,
    required double totalProfit,
    required double totalExpense,
    required DateTime start,
    required DateTime end,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await loadBengaliFont();
    final fontBold = await loadBengaliFontBold();
    final shopInfo = await getShopInfo();
    final currency = AppTranslations.get('currency_symbol');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('${AppTranslations.get('accounts')} ${AppTranslations.get('report')}'),
          pw.Text('${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}', style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
        ]),
        build: (context) => [
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryBox(AppTranslations.get('total_sale'), '$currency ${totalSale.toStringAsFixed(2)}', PdfColors.blue),
            _summaryBox(AppTranslations.get('total_profit'), '$currency ${totalProfit.toStringAsFixed(2)}', PdfColors.green),
            _summaryBox(AppTranslations.get('total_expense'), '$currency ${totalExpense.toStringAsFixed(2)}', PdfColors.red),
          ]),
          pw.SizedBox(height: 20),
          pw.Text(AppTranslations.get('recent_sales'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: [
                _tableCell(AppTranslations.get('date'), isBold: true),
                _tableCell(AppTranslations.get('customer'), isBold: true),
                _tableCell(AppTranslations.get('amount'), isBold: true, align: pw.TextAlign.right),
              ]),
              ...sales.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return pw.TableRow(children: [
                  _tableCell(data['createdAt'] != null ? DateFormat('dd/MM').format((data['createdAt'] as Timestamp).toDate()) : ''),
                  _tableCell(data['customerName'] ?? 'Cash'),
                  _tableCell('$currency ${(data['totalAmount'] as num?)?.toDouble() ?? 0.0}', align: pw.TextAlign.right),
                ]);
              }),
            ],
          ),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateSingleAccountPdf({required Map<String, dynamic> data, required String timeString, bool isExpense = false}) async {
    final pdf = pw.Document();
    final fontRegular = await loadBengaliFont();
    final fontBold = await loadBengaliFontBold();
    final shopInfo = await getShopInfo();
    final currency = AppTranslations.get('currency_symbol');
    final note = data['note'] ?? '';
    final isSalary = note.contains('বেতন') || note.toLowerCase().contains('salary');
    String title = isExpense ? (isSalary ? AppTranslations.get('salary') : AppTranslations.get('expense')) : AppTranslations.get('sale');

    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (context) => pw.Column(children: [
        pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text(timeString, style: const pw.TextStyle(fontSize: 7)),
        pw.Divider(),
        if (!isExpense) ...[
          _buildSummaryRow(AppTranslations.get('total_amount'), '$currency ${data['totalAmount'] ?? 0.0}'),
          _buildSummaryRow(AppTranslations.get('payment_type'), '${data['paymentType'] ?? 'Cash'}'),
        ] else ...[
          _buildSummaryRow(AppTranslations.get('amount'), '$currency ${data['amount'] ?? 0.0}'),
          if (note.isNotEmpty) pw.Text('${AppTranslations.get('description')}: $note', style: const pw.TextStyle(fontSize: 8)),
        ],
        pw.SizedBox(height: 10),
        pw.Text('Generated by Amar Dokan', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> shareSubscriptionCard({required String name, required String shopName, required String phone, String? plan, String? txId, String? senderDigits, String? rejectionReason, bool isActivation = false, bool isApproval = false, bool isRejection = false}) async {
    final pdf = pw.Document();
    final fontRegular = await loadBengaliFont();
    final fontBold = await loadBengaliFontBold();
    final imageByte = await rootBundle.load('assets/images/ic_launcher.png');
    final image = pw.MemoryImage(imageByte.buffer.asUint8List());
    final planDisplay = plan?.replaceAll('_', ' ').toUpperCase() ?? 'N/A';
    String title = isActivation ? 'PREMIUM ACTIVATED' : (isApproval ? 'ACCOUNT APPROVED' : (isRejection ? 'REQUEST CANCELLED' : 'SUBSCRIPTION REQUEST'));
    PdfColor titleColor = isRejection ? PdfColors.red700 : (isActivation ? PdfColors.green700 : PdfColors.orange900);

    pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(400, 520, marginAll: 20),
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (context) => pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue900, width: 2), borderRadius: pw.BorderRadius.circular(15)),
        padding: const pw.EdgeInsets.all(20),
        child: pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            pw.Image(image, width: 40, height: 40),
            pw.SizedBox(width: 10),
            pw.Text('Amar Dokan', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: titleColor)),
          pw.SizedBox(height: 20),
          _buildDetailsRow('Owner Name', name),
          _buildDetailsRow('Shop Name', shopName),
          _buildDetailsRow('Mobile', phone),
          if (!isApproval) ...[
            _buildDetailsRow('Plan', planDisplay),
            _buildDetailsRow('Transaction ID', txId ?? 'N/A'),
          ],
          pw.Spacer(),
          pw.Text('Date: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Thank you for choosing Amar Dokan', style: const pw.TextStyle(fontSize: 8)),
        ]),
      ),
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'subscription_card.pdf');
  }

  // --- Static Helper Widgets ---

  static pw.Widget _tableCell(String text, {bool isBold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
    );
  }

  static pw.Widget _summaryBox(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: color), borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 8)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
      ]),
    );
  }

  static pw.Widget _buildDetailsRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }
}
