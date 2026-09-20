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

          pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
            child: pw.Column(
              children: [
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
                ...transactions.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  double total = (data['totalAmount'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
                  double paid = (data['paidAmount'] as num?)?.toDouble() ?? (data['cashPaid'] as num?)?.toDouble() ?? 0.0;
                  double due = (data['dueAmount'] as num?)?.toDouble() ?? 0.0;
                  if (data['type'] == 'জমা' || data['type'] == 'jama' || data['type'] == 'Payment') {
                    total = 0.0; paid = (data['amount'] as num?)?.toDouble() ?? 0.0; due = 0.0;
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

  // --- 4. Accounts Summary Report ---

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

    final double combinedSalary = totalSalary + totalBonus;
    final double netProfit = totalProfit - totalExpense - combinedSalary;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          _text(_fix(shopInfo['name']), fontSize: 22, font: fontBold, color: PdfColors.blue900),
          _text(_fix('হিসাব নিকাশ রিপোর্ট'), fontSize: 14, font: fontBold),
          _text('${_fix('সময়সীমা:')} ${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}', fontSize: 10, font: fontRegular),
          pw.Divider(thickness: 1, color: PdfColors.blue900),
          pw.SizedBox(height: 10),
        ]),
        build: (context) => [
          _text(_fix('দৈনিক লেনদেন সারসংক্ষেপ'), fontSize: 12, font: fontBold),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: [_fix('তারিখ'), _fix('বিক্রি'), _fix('লাভ'), _fix('খরচ'), _fix('বেতন'), _fix('বাকি'), _fix('জমা')],
            data: () {
              Map<String, List<double>> dailyData = {};
              for (var doc in sales) {
                final data = doc.data() as Map<String, dynamic>;
                final dateKey = DateFormat('dd/MM/yyyy').format((data['createdAt'] as Timestamp).toDate());
                if (!dailyData.containsKey(dateKey)) dailyData[dateKey] = [0, 0, 0, 0, 0, 0, 0];
                dailyData[dateKey]![0] += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                dailyData[dateKey]![1] += (data['profit'] as num?)?.toDouble() ?? 0.0;
                dailyData[dateKey]![4] += (data['dueAmount'] as num?)?.toDouble() ?? 0.0;
                dailyData[dateKey]![5] += (data['cashPaid'] as num?)?.toDouble() ?? 0.0;
              }
              for (var doc in expenses) {
                final data = doc.data() as Map<String, dynamic>;
                final dateKey = DateFormat('dd/MM/yyyy').format((data['createdAt'] as Timestamp).toDate());
                if (!dailyData.containsKey(dateKey)) dailyData[dateKey] = [0, 0, 0, 0, 0, 0, 0];
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
                final ts = data['date'] ?? data['timestamp'] ?? data['createdAt'];
                if (ts == null) continue;
                final dateKey = DateFormat('dd/MM/yyyy').format((ts as Timestamp).toDate());
                if (!dailyData.containsKey(dateKey)) dailyData[dateKey] = [0, 0, 0, 0, 0, 0, 0];
                dailyData[dateKey]![6] += (data['amount'] as num?)?.toDouble() ?? 0.0;
              }
              var sortedKeys = dailyData.keys.toList()..sort((a, b) => DateFormat('dd/MM/yyyy').parse(b).compareTo(DateFormat('dd/MM/yyyy').parse(a)));
              return sortedKeys.map((date) => [
                date, dailyData[date]![0].toStringAsFixed(0), dailyData[date]![1].toStringAsFixed(0),
                dailyData[date]![2].toStringAsFixed(0), dailyData[date]![3].toStringAsFixed(0),
                dailyData[date]![4].toStringAsFixed(0), dailyData[date]![5].toStringAsFixed(0),
              ]).toList();
            }(),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: fontBold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: pw.TextStyle(fontSize: 7, font: fontRegular),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
          pw.SizedBox(height: 30),
          _text(_fix('চূড়ান্ত সারসংক্ষেপ'), fontSize: 12, font: fontBold),
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryBoxWithFont(_fix('মোট বিক্রি'), '৳${totalSale.toStringAsFixed(0)}', PdfColors.blue, fontBold),
            _summaryBoxWithFont(_fix('মোট লাভ'), '৳${totalProfit.toStringAsFixed(0)}', PdfColors.green, fontBold),
            _summaryBoxWithFont(_fix('মোট খরচ'), '৳${totalExpense.toStringAsFixed(0)}', PdfColors.red, fontBold),
          ]),
          pw.SizedBox(height: 20),
          pw.Center(child: pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(color: netProfit >= 0 ? PdfColors.green50 : PdfColors.red50, border: pw.Border.all(color: netProfit >= 0 ? PdfColors.green : PdfColors.red, width: 2), borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Column(children: [
              _text(_fix('নিট লাভ'), fontSize: 14, font: fontBold, color: PdfColors.green900),
              _text('৳${netProfit.toStringAsFixed(2)}', fontSize: 20, font: fontBold, color: netProfit >= 0 ? PdfColors.green900 : PdfColors.red900),
            ]),
          )),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- 5. Inventory Summary Report ---

  static Future<void> generateInventoryReport({
    required List<Map<String, dynamic>> logs,
    required DateTime? start,
    required DateTime? end,
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

    String dateRange = (start != null && end != null) 
      ? (start == end ? DateFormat('dd/MM/yyyy').format(start) : "${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}")
      : "Full Inventory Summary";

    Map<String, List<double>> dailyLogs = {};
    for (var log in logs) {
      String dateKey = DateFormat('dd/MM/yyyy').format((log['date'] as Timestamp).toDate());
      if (!dailyLogs.containsKey(dateKey)) dailyLogs[dateKey] = [0, 0, 0, 0];
      double qty = (log['addedQty'] as num?)?.toDouble() ?? 0.0;
      double cost = (log['costPrice'] as num?)?.toDouble() ?? 0.0;
      double sale = (log['salePrice'] as num?)?.toDouble() ?? 0.0;
      dailyLogs[dateKey]![0] += qty; dailyLogs[dateKey]![1] += (cost * qty);
      dailyLogs[dateKey]![2] += (sale * qty); dailyLogs[dateKey]![3] += ((sale - cost) * qty);
    }

    double grandCost = 0; double grandSale = 0; double grandProfit = 0;
    var sortedDates = dailyLogs.keys.toList()..sort((a, b) => DateFormat('dd/MM/yyyy').parse(b).compareTo(DateFormat('dd/MM/yyyy').parse(a)));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
            if (logo != null) ...[pw.Image(logo, width: 75, height: 75), pw.SizedBox(width: 15)],
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              _text(_fix(shopInfo['name']), fontSize: 28, font: fontBold, color: PdfColors.blue900),
              if (shopInfo['address']!.isNotEmpty) _text(_fix(shopInfo['address']), fontSize: 10, font: fontRegular),
              _text(_fix('মোবাইল: ${shopInfo['phone']}'), fontSize: 10, font: fontBold),
            ])),
            pw.SizedBox(width: 75),
          ]),
          pw.Divider(thickness: 1.5, color: PdfColors.blue900),
          pw.SizedBox(height: 10),
        ]),
        build: (context) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            _text(_fix('স্টক ইনভেন্টরি রিপোর্ট'), fontSize: 14, font: fontBold, color: PdfColors.blue800),
            _text(_fix('সময়সীমা: $dateRange'), fontSize: 9, font: fontRegular),
          ]),
          pw.SizedBox(height: 15),
          pw.TableHelper.fromTextArray(
            headers: [_fix('তারিখ'), _fix('যুক্ত পণ্য'), _fix('বিনিয়োগ'), _fix('বিক্রয়মূল্য'), _fix('সম্ভাব্য লাভ')],
            data: sortedDates.map((date) {
              final vals = dailyLogs[date]!; grandCost += vals[1]; grandSale += vals[2]; grandProfit += vals[3];
              return [date, vals[0].toStringAsFixed(0), vals[1].toStringAsFixed(0), vals[2].toStringAsFixed(0), vals[3].toStringAsFixed(0)];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10, font: fontBold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: pw.TextStyle(fontSize: 9, font: fontRegular),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
          pw.SizedBox(height: 25),
          pw.Container(padding: const pw.EdgeInsets.all(15), decoration: pw.BoxDecoration(color: PdfColors.grey50, border: pw.Border.all(color: PdfColors.blue900), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(children: [
              _buildSummaryRowPDFWithFont(_fix('মোট পিরিয়ড বিনিয়োগ:'), '৳${grandCost.toStringAsFixed(0)}', fontBold),
              _buildSummaryRowPDFWithFont(_fix('মোট পিরিয়ড বিক্রয়মূল্য:'), '৳${grandSale.toStringAsFixed(0)}', fontBold),
              pw.Divider(color: PdfColors.grey300),
              _buildSummaryRowPDFWithFont(_fix('মোট সম্ভাব্য নিট লাভ:'), '৳${grandProfit.toStringAsFixed(0)}', fontBold, isBold: true, color: PdfColors.green900),
            ])),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- 6. Single Voucher ---

  static Future<void> generateSingleAccountPdf({
    required Map<String, dynamic> data, 
    required String timeString, 
    bool isExpense = false,
    bool isShare = false,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await _loadFont("assets/fonts/SolaimanLipi-Normal.ttf");
    final fontBold = await _loadFont("assets/fonts/SolaimanLipi-Bold.ttf");
    final shopInfo = await getShopInfo();
    final note = data['note'] ?? '';
    final isSalary = note.contains('বেতন') || note.toLowerCase().contains('salary');
    final double basicSalary = (data['basicSalary'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
    final double bonus = (data['bonus'] as num?)?.toDouble() ?? 0.0;
    final double totalAmount = (data['amount'] as num?)?.toDouble() ?? (basicSalary + bonus);
    final String title = isSalary ? 'স্যালারি ভাউচার' : 'খরচ ভাউচার';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _text(_fix(shopInfo['name']), fontSize: 22, font: fontBold, color: PdfColors.blue900),
            _text('Mobile: ${shopInfo['phone']}', fontSize: 10, font: fontRegular),
          ]),
          pw.Container(padding: const pw.EdgeInsets.all(10), decoration: const pw.BoxDecoration(color: PdfColors.grey200), child: _text(_fix(title.toUpperCase()), fontSize: 12, font: fontBold)),
        ]),
        pw.SizedBox(height: 30), pw.Divider(),
        _buildVoucherRowWithFont(_fix('তারিখ:'), timeString, fontBold),
        _buildVoucherRowWithFont(_fix('ক্যাটাগরি:'), _fix(isSalary ? 'কর্মচারীর বেতন' : 'দোকান খরচ'), fontBold),
        if (isSalary) ...[
          if (data['empName'] != null) _buildVoucherRowWithFont(_fix('কর্মচারী:'), _fix(data['empName']), fontBold),
          if (data['empPhone'] != null && data['empPhone'].toString().isNotEmpty) _buildVoucherRowWithFont(_fix('মোবাইল:'), data['empPhone'], fontBold),
          if (data['empDesignation'] != null && data['empDesignation'].toString().isNotEmpty) _buildVoucherRowWithFont(_fix('পদবী:'), _fix(data['empDesignation']), fontBold),
          _buildVoucherRowWithFont(_fix('মূল বেতন:'), '৳${basicSalary.toStringAsFixed(2)}', fontBold),
          _buildVoucherRowWithFont(_fix('বোনাস:'), '৳${bonus.toStringAsFixed(2)}', fontBold),
        ],
        _buildVoucherRowWithFont(_fix('বিবরণ:'), _fix(note), fontBold),
        pw.Divider(), pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(padding: const pw.EdgeInsets.all(15), decoration: pw.BoxDecoration(border: pw.Border.all()), child: _text('${_fix('মোট:')} ৳${totalAmount.toStringAsFixed(2)}', fontSize: 16, font: fontBold, color: PdfColors.red900)),
        ]),
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [pw.SizedBox(width: 100, child: pw.Divider()), _text(_fix('কর্তৃপক্ষ'), fontSize: 10, font: fontBold)]),
          pw.Column(children: [pw.SizedBox(width: 100, child: pw.Divider()), _text(_fix('প্রাপক'), fontSize: 10, font: fontBold)]),
        ]),
      ]),
    ));
    if (isShare) { await Printing.sharePdf(bytes: await pdf.save(), filename: 'Voucher.pdf'); } else { await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save()); }
  }

  // --- Static Helpers ---

  static pw.Widget _text(String text, {required double fontSize, required pw.Font font, PdfColor color = PdfColors.black}) {
    return pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize, color: color), textDirection: pw.TextDirection.ltr);
  }

  static pw.Widget _cell(String text, {required int flex, required pw.Font font, pw.TextAlign align = pw.TextAlign.left, bool isHeader = false}) {
    return pw.Expanded(flex: flex, child: pw.Text(text, textAlign: align, style: pw.TextStyle(font: font, fontSize: isHeader ? 10 : 9, color: isHeader ? PdfColors.white : PdfColors.black), textDirection: pw.TextDirection.ltr));
  }

  static pw.Widget _buildBillRow(String key, String value, pw.Font font, {bool isRed = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      _text(key, fontSize: 8, font: font), _text(value, fontSize: 8, font: font, color: isRed ? PdfColors.red : PdfColors.black),
    ]));
  }

  static pw.Widget _summaryBoxWithFont(String title, String value, PdfColor color, pw.Font font) {
    return pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(color: color), borderRadius: pw.BorderRadius.circular(5)), child: pw.Column(children: [
      _text(title, fontSize: 8, font: font), _text(value, fontSize: 10, font: font, color: color),
    ]));
  }

  static pw.Widget _buildSummaryRowPDFWithFont(String label, String value, pw.Font font, {bool isBold = false, PdfColor color = PdfColors.black}) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      _text(label, fontSize: 10, font: font), _text(value, fontSize: 11, font: font, color: color),
    ]);
  }

  static pw.Widget _buildVoucherRowWithFont(String label, String value, pw.Font font) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child: pw.Row(children: [
      pw.SizedBox(width: 90, child: _text(label, fontSize: 10, font: font)), pw.Expanded(child: _text(value, fontSize: 10, font: font)),
    ]));
  }

  static Future<void> shareSubscriptionCard({required String name, required String shopName, required String phone, String? plan, String? txId, String? senderDigits, String? rejectionReason, bool isActivation = false, bool isApproval = false, bool isRejection = false}) async {
    final pdf = pw.Document();
    final fontRegular = await _loadFont("assets/fonts/SolaimanLipi-Normal.ttf");
    final fontBold = await _loadFont("assets/fonts/SolaimanLipi-Bold.ttf");
    final imageByte = await rootBundle.load('assets/images/ic_launcher.png');
    final image = pw.MemoryImage(imageByte.buffer.asUint8List());
    String title = isActivation ? 'PREMIUM ACTIVATED' : (isApproval ? 'ACCOUNT APPROVED' : (isRejection ? 'REQUEST CANCELLED' : 'SUBSCRIPTION REQUEST'));
    pdf.addPage(pw.Page(pageFormat: const PdfPageFormat(400, 520, marginAll: 20), theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold), build: (context) => pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue900, width: 2), borderRadius: pw.BorderRadius.circular(15)), padding: const pw.EdgeInsets.all(20), child: pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [pw.Image(image, width: 40, height: 40), pw.SizedBox(width: 10), pw.Text('Amar Dokan', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, font: fontBold))]),
      pw.SizedBox(height: 10), pw.Divider(), pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, font: fontBold)),
      pw.SizedBox(height: 20), _buildBillRow(_fix('মালিক:'), _fix(name), fontBold), _buildBillRow(_fix('দোকান:'), _fix(shopName), fontBold), _buildBillRow(_fix('মোবাইল:'), phone, fontBold),
      pw.Spacer(), _text('Date: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}', fontSize: 9, font: fontRegular),
    ]))));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'subscription_card.pdf');
  }
}
