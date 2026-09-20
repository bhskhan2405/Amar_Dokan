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

  // --- 2. POS Bill Receipt (80mm) ---

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
              _b(shopInfo['name']!, fontSize: 16, font: fontBold),
              _b('মোবাইল: ${shopInfo['phone']}', fontSize: 9, font: fontRegular),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.5),
              
              if (saleData['customerName'] != null && (saleData['customerName'] as String).isNotEmpty)
                _buildRowBill('কাস্টমার:', saleData['customerName'], fontRegular),
              
              pw.SizedBox(height: 4),
              _b(saleData['type'] == 'sale_due' ? 'বাকি বিক্রয়' : 'নগদ রিসিট', fontSize: 11, font: fontBold),
              _b(formattedDate, fontSize: 7, font: fontRegular),
              pw.Divider(thickness: 0.5),

              if (items.isNotEmpty) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _b('বিবরণ', fontSize: 8, font: fontBold),
                    _b('মোট', fontSize: 8, font: fontBold),
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
                        pw.Expanded(child: _b('${item['name']} ($qty ${item['unit']})', fontSize: 8, font: fontRegular)),
                        _b((price * qty).toStringAsFixed(2), fontSize: 8, font: fontRegular),
                      ],
                    ),
                  );
                }),
                pw.Divider(thickness: 0.5),
              ],

              _buildRowBill('মোট টাকা:', (saleData['totalAmount'] ?? 0.0).toStringAsFixed(2), fontBold),
              _buildRowBill('পরিশোধিত:', (saleData['cashPaid'] ?? 0.0).toStringAsFixed(2), fontBold),
              _buildRowBill('বকেয়া:', (saleData['dueAmount'] ?? 0.0).toStringAsFixed(2), fontBold, isRed: true),

              pw.SizedBox(height: 10),
              _b('ধন্যবাদ, আবার আসবেন!', fontSize: 9, font: fontBold),
              pw.SizedBox(height: 5),
              _b('Powered by Amar Dokan App', fontSize: 6, font: fontRegular, color: PdfColors.grey700),
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

  // --- 3. Customer Statement Report (Professional A4) ---

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

    final dataRows = transactions.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      double total = (data['totalAmount'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
      double paid = (data['paidAmount'] as num?)?.toDouble() ?? (data['cashPaid'] as num?)?.toDouble() ?? 0.0;
      double due = (data['dueAmount'] as num?)?.toDouble() ?? 0.0;

      if (data['type'] == 'জমা' || data['type'] == 'jama' || data['type'] == 'Payment') {
        total = 0.0; paid = (data['amount'] as num?)?.toDouble() ?? 0.0; due = 0.0;
        periodJama += paid;
      } else {
        periodBaki += total; periodJama += paid;
      }

      return [
        data['date'] != null ? DateFormat('dd/MM/yy').format((data['date'] as Timestamp).toDate()) : '',
        data['note'] ?? data['type'] ?? '',
        total > 0 ? total.toStringAsFixed(0) : '-',
        paid > 0 ? paid.toStringAsFixed(0) : '-',
        due > 0 ? due.toStringAsFixed(0) : '-',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              if (logo != null) ...[pw.Image(logo, width: 75, height: 75), pw.SizedBox(width: 20)],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    _b(shopInfo['name']!, fontSize: 32, font: fontBold, color: PdfColors.blue900),
                    if (shopInfo['address']!.isNotEmpty) 
                      _b(shopInfo['address']!, fontSize: 10, font: fontRegular, color: PdfColors.grey900),
                    _b('মোবাইল: ${shopInfo['phone']}', fontSize: 11, font: fontBold),
                  ],
                ),
              ),
              pw.SizedBox(width: 75),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1.5, color: PdfColors.blue900),
          pw.SizedBox(height: 15),
        ]),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _b('কাস্টমার: ${customerData['name']}', fontSize: 12, font: fontBold),
                  _b('মোবাইল: ${customerData['phone']}', fontSize: 9, font: fontRegular),
                  if (customerData['address'] != null && customerData['address'].toString().isNotEmpty)
                    _b('ঠিকানা: ${customerData['address']}', fontSize: 9, font: fontRegular),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _b('হিসাব বিবরণী', fontSize: 15, font: fontBold, color: PdfColors.blue800),
                  _b('সময়সীমা: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}', fontSize: 9, font: fontRegular),
                  pw.SizedBox(height: 5),
                  _b('পিরিয়ড মোট বাকি: ৳${periodBaki.toStringAsFixed(0)}', fontSize: 9, font: fontBold, color: PdfColors.red700),
                  _b('পিরিয়ড মোট জমা: ৳${periodJama.toStringAsFixed(0)}', fontSize: 9, font: fontBold, color: PdfColors.green700),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Karbar Style Table
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
            children: [
              // Table Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _cell('তারিখ', flex: 1, font: fontBold, isHeader: true),
                  _cell('বিবরণ', flex: 3, font: fontBold, isHeader: true),
                  _cell('মোট', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  _cell('জমা', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  _cell('বাকি', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                ],
              ),
              // Table Rows
              ...dataRows.map((row) => pw.TableRow(
                children: [
                  _cell(row[0], flex: 1, font: fontRegular),
                  _cell(row[1], flex: 3, font: fontRegular),
                  _cell(row[2], flex: 1, font: fontRegular, align: pw.TextAlign.right),
                  _cell(row[3], flex: 1, font: fontRegular, align: pw.TextAlign.right),
                  _cell(row[4], flex: 1, font: fontRegular, align: pw.TextAlign.right),
                ],
              )),
            ],
          ),

          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: pw.BoxDecoration(color: PdfColors.blue50, border: pw.Border.all(color: PdfColors.blue900), borderRadius: pw.BorderRadius.circular(5)),
                child: _b('বর্তমান মোট বকেয়া: ৳${customerData['dueAmount']?.toStringAsFixed(2)}', fontSize: 13, font: fontBold, color: PdfColors.red900),
              ),
            ],
          ),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- 4. Accounts Summary Report (Professional A4) ---

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

    final double combinedSalary = totalSalary + totalBonus;
    final double netProfit = totalProfit - totalExpense - combinedSalary;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          _b(shopInfo['name']!, fontSize: 22, font: fontBold, color: PdfColors.blue900),
          _b('হিসাব নিকাশ রিপোর্ট', fontSize: 14, font: fontBold),
          _b('সময়সীমা: ${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}', fontSize: 10, font: fontRegular),
          pw.Divider(thickness: 1, color: PdfColors.blue900),
          pw.SizedBox(height: 10),
        ]),
        build: (context) => [
          _b('দৈনিক লেনদেন সারসংক্ষেপ', fontSize: 12, font: fontBold),
          pw.SizedBox(height: 8),
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _cell('তারিখ', flex: 1, font: fontBold, isHeader: true),
                  _cell('বিক্রি', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  _cell('লাভ', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  _cell('খরচ', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  _cell('বেতন', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  _cell('বাকি', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  _cell('জমা', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                ],
              ),
              ...() {
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
                return sortedKeys.map((date) => pw.TableRow(children: [
                  _cell(date, flex: 1, font: fontRegular),
                  _cell(dailyData[date]![0].toStringAsFixed(0), flex: 1, font: fontRegular, align: pw.TextAlign.right),
                  _cell(dailyData[date]![1].toStringAsFixed(0), flex: 1, font: fontRegular, align: pw.TextAlign.right),
                  _cell(dailyData[date]![2].toStringAsFixed(0), flex: 1, font: fontRegular, align: pw.TextAlign.right),
                  _cell(dailyData[date]![3].toStringAsFixed(0), flex: 1, font: fontRegular, align: pw.TextAlign.right),
                  _cell(dailyData[date]![4].toStringAsFixed(0), flex: 1, font: fontRegular, align: pw.TextAlign.right),
                  _cell(dailyData[date]![5].toStringAsFixed(0), flex: 1, font: fontRegular, align: pw.TextAlign.right),
                ])).toList();
              }(),
            ],
          ),
          pw.SizedBox(height: 30),
          _b('চূড়ান্ত সারসংক্ষেপ', fontSize: 12, font: fontBold),
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryBoxSmallWithFont('মোট বিক্রি', '৳${totalSale.toStringAsFixed(0)}', PdfColors.blue, fontBold),
            _summaryBoxSmallWithFont('মোট লাভ', '৳${totalProfit.toStringAsFixed(0)}', PdfColors.green, fontBold),
            _summaryBoxSmallWithFont('মোট খরচ', '৳${totalExpense.toStringAsFixed(0)}', PdfColors.red, fontBold),
          ]),
          pw.SizedBox(height: 20),
          pw.Center(child: pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(color: netProfit >= 0 ? PdfColors.green50 : PdfColors.red50, border: pw.Border.all(color: netProfit >= 0 ? PdfColors.green : PdfColors.red, width: 2), borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Column(children: [
              _b('নিট লাভ', fontSize: 14, font: fontBold, color: PdfColors.green900),
              _b('৳${netProfit.toStringAsFixed(2)}', fontSize: 20, font: fontBold, color: netProfit >= 0 ? PdfColors.green900 : PdfColors.red900),
            ]),
          )),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- 5. Inventory Summary Report (Professional A4) ---

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

    var sortedDates = dailyLogs.keys.toList()..sort((a, b) => DateFormat('dd/MM/yyyy').parse(b).compareTo(DateFormat('dd/MM/yyyy').parse(a)));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
            if (logo != null) ...[pw.Image(logo, width: 75, height: 75), pw.SizedBox(width: 20)],
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              _b(shopInfo['name']!, fontSize: 28, font: fontBold, color: PdfColors.blue900),
              if (shopInfo['address']!.isNotEmpty) _b(shopInfo['address']!, fontSize: 10, font: fontRegular),
              _b('মোবাইল: ${shopInfo['phone']}', fontSize: 10, font: fontBold),
            ])),
            pw.SizedBox(width: 75),
          ]),
          pw.Divider(thickness: 1.5, color: PdfColors.blue900),
          pw.SizedBox(height: 10),
        ]),
        build: (context) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            _b('স্টক ইনভেন্টরি রিপোর্ট', fontSize: 14, font: fontBold, color: PdfColors.blue800),
            _b('সময়সীমা: $dateRange', fontSize: 9, font: fontRegular),
          ]),
          pw.SizedBox(height: 15),
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _cell('তারিখ', flex: 1, font: fontBold, isHeader: true),
                  _cell('যুক্ত পণ্য', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  _cell('বিনিয়োগ', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  _cell('বিক্রয়মূল্য', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                  _cell('সম্ভাব্য লাভ', flex: 1, font: fontBold, isHeader: true, align: pw.TextAlign.right),
                ],
              ),
              ...sortedDates.map((date) => pw.TableRow(children: [
                _cell(date, flex: 1, font: fontRegular),
                _cell(dailyLogs[date]![0].toStringAsFixed(0), flex: 1, font: fontRegular, align: pw.TextAlign.right),
                _cell(dailyLogs[date]![1].toStringAsFixed(0), flex: 1, font: fontRegular, align: pw.TextAlign.right),
                _cell(dailyLogs[date]![2].toStringAsFixed(0), flex: 1, font: fontRegular, align: pw.TextAlign.right),
                _cell(dailyLogs[date]![3].toStringAsFixed(0), flex: 1, font: fontRegular, align: pw.TextAlign.right),
              ])),
            ],
          ),
          pw.SizedBox(height: 25),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // --- 6. Single Voucher (A4) ---

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
            _b(shopInfo['name']!, fontSize: 22, font: fontBold, color: PdfColors.blue900),
            _b('Mobile: ${shopInfo['phone']}', fontSize: 10, font: fontRegular),
          ]),
          pw.Container(padding: const pw.EdgeInsets.all(10), decoration: const pw.BoxDecoration(color: PdfColors.grey200), child: _b(title.toUpperCase(), fontSize: 12, font: fontBold)),
        ]),
        pw.SizedBox(height: 30), pw.Divider(),
        _buildVoucherRowWithFont('তারিখ:', timeString, fontBold),
        _buildVoucherRowWithFont('ক্যাটাগরি:', isSalary ? 'কর্মচারীর বেতন' : 'দোকান খরচ', fontBold),
        if (isSalary) ...[
          if (data['empName'] != null) _buildVoucherRowWithFont('কর্মচারী:', data['empName'], fontBold),
          if (data['empPhone'] != null && data['empPhone'].toString().isNotEmpty) _buildVoucherRowWithFont('মোবাইল:', data['empPhone'], fontBold),
          _buildVoucherRowWithFont('মূল বেতন:', '৳${basicSalary.toStringAsFixed(2)}', fontBold),
        ],
        _buildVoucherRowWithFont('বিবরণ:', note, fontBold),
        pw.Divider(), pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(padding: const pw.EdgeInsets.all(15), decoration: pw.BoxDecoration(border: pw.Border.all()), child: _b('মোট: ৳${totalAmount.toStringAsFixed(2)}', fontSize: 16, font: fontBold, color: PdfColors.red900)),
        ]),
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [pw.SizedBox(width: 100, child: pw.Divider()), _b('কর্তৃপক্ষ', fontSize: 10, font: fontBold)]),
          pw.Column(children: [pw.SizedBox(width: 100, child: pw.Divider()), _b('প্রাপক', fontSize: 10, font: fontBold)]),
        ]),
      ]),
    ));
    if (isShare) { await Printing.sharePdf(bytes: await pdf.save(), filename: 'Voucher.pdf'); } else { await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save()); }
  }

  // --- Static Helpers ---

  static pw.Widget _b(String text, {required double fontSize, required pw.Font font, PdfColor color = PdfColors.black}) {
    return pw.Text(
      text,
      style: pw.TextStyle(font: font, fontSize: fontSize, color: color),
      textDirection: pw.TextDirection.ltr, // অত্যন্ত গুরুত্বপূর্ণ
    );
  }

  static pw.Widget _cell(String text, {required int flex, required pw.Font font, pw.TextAlign align = pw.TextAlign.left, bool isHeader = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(font: font, fontSize: isHeader ? 10 : 9, color: isHeader ? PdfColors.white : PdfColors.black),
          textDirection: pw.TextDirection.ltr,
        ),
      ),
    );
  }

  static pw.Widget _buildRowBill(String key, String value, pw.Font font, {bool isRed = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      _b(key, fontSize: 8, font: font), _b(value, fontSize: 8, font: font, color: isRed ? PdfColors.red : PdfColors.black),
    ]));
  }

  static pw.Widget _summaryBoxSmallWithFont(String title, String value, PdfColor color, pw.Font font) {
    return pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(color: color), borderRadius: pw.BorderRadius.circular(5)), child: pw.Column(children: [
      _b(title, fontSize: 8, font: font), _b(value, fontSize: 10, font: font, color: color),
    ]));
  }

  static pw.Widget _buildVoucherRowWithFont(String label, String value, pw.Font font) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child: pw.Row(children: [
      pw.SizedBox(width: 90, child: _b(label, fontSize: 10, font: font)), pw.Expanded(child: _b(value, fontSize: 10, font: font)),
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
      pw.SizedBox(height: 20), _buildRowBill('মালিক:', name, fontBold), _buildRowBill('দোকান:', shopName, fontBold), _buildRowBill('মোবাইল:', phone, fontBold),
      pw.Spacer(), _b('Date: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}', fontSize: 9, font: fontRegular),
    ]))));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'subscription_card.pdf');
  }
}
