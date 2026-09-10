import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'translations.dart';

class ReceiptUtils {
  // --- 1. Load Fonts & Shop Info ---

  static Future<pw.Font> _loadFont(String path) async {
    final fontData = await rootBundle.load(path);
    return pw.Font.ttf(fontData);
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

  // --- 2. POS Bill Receipt (English UI, Bengali Content Support) ---

  static Future<void> generatePosReceipt({
    required Map<String, dynamic> saleData,
    bool isPrint = true,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await _loadFont("assets/fonts/SolaimanLipi-Normal.ttf");
    final fontBold = await _loadFont("assets/fonts/SolaimanLipi-Bold.ttf");
    final shopInfo = await getShopInfo();

    String formattedDate = '';
    if (saleData['createdAt'] != null && saleData['createdAt'] is Timestamp) {
      formattedDate = DateFormat('d/M/yyyy h:mm a').format((saleData['createdAt'] as Timestamp).toDate());
    } else if (saleData['date'] != null && saleData['date'] is Timestamp) {
      formattedDate = DateFormat('d/M/yyyy h:mm a').format((saleData['date'] as Timestamp).toDate());
    } else {
      formattedDate = DateFormat('d/M/yyyy h:mm a').format(DateTime.now());
    }

    final items = saleData['items'] as Map<String, dynamic>? ?? {};
    const divider = '****************************************';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Mobile: ${shopInfo['phone']}', style: const pw.TextStyle(fontSize: 9)),
              
              pw.SizedBox(height: 4),
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),
              
              pw.Text(saleData['type'] == 'sale_due' ? 'CREDIT SALE' : 'CASH RECEIPT', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 7)),
              
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),

              _buildRow('Payment Type:', saleData['paymentType'] ?? 'Cash'),
              _buildRow('Sell By:', saleData['staffName'] ?? 'Admin'),
              
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),

              if (items.isNotEmpty) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text('Description', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text('Discount', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text('Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),

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
                        pw.Text('Qty: $qty $unit', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      ],
                    ),
                  );
                }),
                pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),
              ] else if (saleData['note'] != null) ...[
                pw.Text('Note: ${saleData['note']}', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 5),
              ],

              _buildSummaryRow('Total Amount', (saleData['totalAmount'] ?? saleData['amount'] ?? 0.0).toStringAsFixed(2), isBold: true, fontSize: 10),
              _buildSummaryRow('Paid', (saleData['cashPaid'] ?? saleData['paidAmount'] ?? 0.0).toStringAsFixed(2)),
              _buildSummaryRow('Due', (saleData['dueAmount'] ?? 0.0).toStringAsFixed(2)),

              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),
              
              pw.SizedBox(height: 5),
              pw.Text('THANK YOU!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text('Sold items are not returnable.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
              pw.SizedBox(height: 8),
              
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

    if (isPrint) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'bill_${DateTime.now().millisecondsSinceEpoch}.pdf');
    }
  }

  static pw.Widget _buildRow(String key, String value) {
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

  // --- 3. Customer Statement Report (A4) ---

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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          if (shopInfo['address']!.isNotEmpty) pw.Text(shopInfo['address']!, style: const pw.TextStyle(fontSize: 10)),
          pw.Text('Mobile: ${shopInfo['phone']}', style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
          pw.SizedBox(height: 10),
        ]),
        build: (context) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Customer: ${customerData['name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Mobile: ${customerData['phone']}', style: const pw.TextStyle(fontSize: 10)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('STATEMENT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}', style: const pw.TextStyle(fontSize: 9)),
            ]),
          ]),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Description', 'Total', 'Paid', 'Due'],
            data: transactions.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              double total = (data['totalAmount'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
              double paid = (data['paidAmount'] as num?)?.toDouble() ?? (data['cashPaid'] as num?)?.toDouble() ?? 0.0;
              double due = (data['dueAmount'] as num?)?.toDouble() ?? 0.0;

              if (data['type'] == 'জমা' || data['type'] == 'jama' || data['type'] == 'Payment') {
                total = 0.0;
                paid = (data['amount'] as num?)?.toDouble() ?? 0.0;
                due = 0.0;
              }

              return [
                data['date'] != null ? DateFormat('dd/MM/yy').format((data['date'] as Timestamp).toDate()) : '',
                data['note'] ?? data['type'] ?? '',
                total > 0 ? total.toStringAsFixed(2) : '-',
                paid > 0 ? paid.toStringAsFixed(2) : '-',
                due > 0 ? due.toStringAsFixed(2) : '-',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 20),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue)),
              child: pw.Text('Total Due: Tk ${customerData['dueAmount']?.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            )
          ]),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- 4. Accounts Summary Report (A4) ---

  static Future<void> generateAccountsReport({
    required List<QueryDocumentSnapshot> sales,
    required List<QueryDocumentSnapshot> expenses,
    required List<QueryDocumentSnapshot> customerTransactions,
    required double totalSale,
    required double totalProfit,
    required double totalExpense,
    required double totalSalary,
    required double totalBonus,
    required DateTime start,
    required DateTime end,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await _loadFont("assets/fonts/SolaimanLipi-Normal.ttf");
    final fontBold = await _loadFont("assets/fonts/SolaimanLipi-Bold.ttf");
    final shopInfo = await getShopInfo();
    final currency = AppTranslations.get('currency_symbol');

    final double netProfit = totalProfit - totalExpense - totalSalary - totalBonus;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('ACCOUNTS REPORT'),
          pw.Text('Period: ${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}', style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
        ]),
        build: (context) => [
          pw.SizedBox(height: 10),
          pw.Text('Daily Transaction Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Sale', 'Profit', 'Exp.', 'Salary', 'Due', 'Due Pmt.'],
            data: () {
              Map<String, List<double>> dailyData = {};
              
              for (var doc in sales) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['createdAt'] as Timestamp?;
                if (timestamp == null) continue;
                final dateKey = DateFormat('dd/MM/yyyy').format(timestamp.toDate());
                if (!dailyData.containsKey(dateKey)) dailyData[dateKey] = [0, 0, 0, 0, 0, 0];
                dailyData[dateKey]![0] += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                dailyData[dateKey]![1] += (data['profit'] as num?)?.toDouble() ?? 0.0;
              }

              for (var doc in expenses) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['createdAt'] as Timestamp?;
                if (timestamp == null) continue;
                final dateKey = DateFormat('dd/MM/yyyy').format(timestamp.toDate());
                if (!dailyData.containsKey(dateKey)) dailyData[dateKey] = [0, 0, 0, 0, 0, 0];
                double amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
                String note = (data['note'] ?? '').toString().toLowerCase();
                if (note.contains('বেতন') || note.contains('salary') || note.contains('bonus') || note.contains('বোনাস')) {
                  dailyData[dateKey]![3] += amt;
                } else {
                  dailyData[dateKey]![2] += amt;
                }
              }

              for (var doc in customerTransactions) {
                final data = doc.data() as Map<String, dynamic>;
                dynamic dateVal = data['date'] ?? data['timestamp'] ?? data['createdAt'];
                if (dateVal == null) continue;
                DateTime tDate = dateVal is Timestamp ? dateVal.toDate() : (DateTime.tryParse(dateVal.toString()) ?? DateTime.now());
                final dateKey = DateFormat('dd/MM/yyyy').format(tDate);
                if (!dailyData.containsKey(dateKey)) dailyData[dateKey] = [0, 0, 0, 0, 0, 0];
                String type = (data['type'] ?? '').toString();
                if (type == 'sale_due' || type == 'baki') {
                  dailyData[dateKey]![4] += (data['amount'] as num?)?.toDouble() ?? 0.0;
                  dailyData[dateKey]![5] += (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
                } else {
                  dailyData[dateKey]![5] += (data['amount'] as num?)?.toDouble() ?? 0.0;
                }
              }

              var sortedKeys = dailyData.keys.toList()..sort((a, b) => DateFormat('dd/MM/yyyy').parse(b).compareTo(DateFormat('dd/MM/yyyy').parse(a)));
              return sortedKeys.map((date) => [
                date,
                dailyData[date]![0].toStringAsFixed(0),
                dailyData[date]![1].toStringAsFixed(0),
                dailyData[date]![2].toStringAsFixed(0),
                dailyData[date]![3].toStringAsFixed(0),
                dailyData[date]![4].toStringAsFixed(0),
                dailyData[date]![5].toStringAsFixed(0),
              ]).toList();
            }(),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
          
          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.Text('Final Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryBox('Total Sale', '$currency ${totalSale.toStringAsFixed(2)}', PdfColors.blue),
            _summaryBox('Gross Profit', '$currency ${totalProfit.toStringAsFixed(2)}', PdfColors.green),
          ]),
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryBox('Total Expense', '$currency ${totalExpense.toStringAsFixed(2)}', PdfColors.red),
            _summaryBox('Salary & Bonus', '$currency ${(totalSalary + totalBonus).toStringAsFixed(2)}', PdfColors.orange),
          ]),
          pw.SizedBox(height: 20),
          
          pw.Center(child: pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: netProfit >= 0 ? PdfColors.green50 : PdfColors.red50,
              border: pw.Border.all(color: netProfit >= 0 ? PdfColors.green : PdfColors.red, width: 2),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(children: [
              pw.Text('NET PROFIT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: netProfit >= 0 ? PdfColors.green900 : PdfColors.red900)),
              pw.Text('$currency ${netProfit.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: netProfit >= 0 ? PdfColors.green900 : PdfColors.red900)),
            ]),
          )),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- 5. Single Voucher (A4) ---

  static Future<void> generateSingleAccountPdf({required Map<String, dynamic> data, required String timeString, bool isExpense = false}) async {
    final pdf = pw.Document();
    final fontRegular = await _loadFont("assets/fonts/SolaimanLipi-Normal.ttf");
    final fontBold = await _loadFont("assets/fonts/SolaimanLipi-Bold.ttf");
    final shopInfo = await getShopInfo();
    
    final note = data['note'] ?? '';
    final isSalary = note.contains('বেতন') || note.toLowerCase().contains('salary');
    final String title = isSalary ? 'Salary Voucher' : 'Expense Voucher';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.Text('Mobile: ${shopInfo['phone']}', style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.Container(padding: const pw.EdgeInsets.all(10), decoration: const pw.BoxDecoration(color: PdfColors.grey200), child: pw.Text(title.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ]),
        pw.SizedBox(height: 30),
        pw.Divider(),
        _buildVoucherRow('Date:', timeString),
        _buildVoucherRow('Description:', note),
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(padding: const pw.EdgeInsets.all(15), decoration: pw.BoxDecoration(border: pw.Border.all()), child: pw.Text('TOTAL: Tk ${(data['amount'] ?? 0.0).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red900))),
        ]),
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [pw.Divider(width: 100), pw.Text('Authorized')]),
          pw.Column(children: [pw.Divider(width: 100), pw.Text('Receiver')]),
        ]),
      ]),
    ));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- Helper Widgets ---

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

  static pw.Widget _buildVoucherRow(String label, String value) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Row(children: [
      pw.SizedBox(width: 100, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      pw.Expanded(child: pw.Text(value)),
    ]));
  }

  static pw.Widget _tableCell(String text, {bool isBold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) {
    return pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)));
  }

  static Future<void> shareSubscriptionCard({required String name, required String shopName, required String phone, String? plan, String? txId, String? senderDigits, String? rejectionReason, bool isActivation = false, bool isApproval = false, bool isRejection = false}) async {
    final pdf = pw.Document();
    final fontRegular = await _loadFont("assets/fonts/SolaimanLipi-Normal.ttf");
    final fontBold = await _loadFont("assets/fonts/SolaimanLipi-Bold.ttf");
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
          _buildRow('Owner Name', name),
          _buildRow('Shop Name', shopName),
          _buildRow('Mobile', phone),
          if (!isApproval) _buildRow('Plan', planDisplay),
          pw.Spacer(),
          pw.Text('Date: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Thank you for choosing Amar Dokan', style: const pw.TextStyle(fontSize: 8)),
        ]),
      ),
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'subscription_card.pdf');
  }
}
