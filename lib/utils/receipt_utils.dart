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

  // ShapedFont loader for bangla_pdf_fixer 3.x.
  static Future<ShapedFont> _loadShapedFont(
    String path, {
    required String name,
  }) async {
    return await BanglaFontManager.instance.loadAsset(
      path,
      name: name,
    );
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
    
    final shapedRegular = await _loadShapedFont("assets/fonts/SolaimanLipi-Normal.ttf", name: "SolaimanLipi Regular");
    final shapedBold = await _loadShapedFont("assets/fonts/SolaimanLipi-Bold.ttf", name: "SolaimanLipi Bold");
    
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
              BanglaText(shopInfo['name']!, font: shapedBold, fontSize: 16),
              pw.Text('Mobile: ${shopInfo['phone']}', style: pw.TextStyle(fontSize: 9, font: fontRegular)),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.5),
              
              if (saleData['customerName'] != null && (saleData['customerName'] as String).isNotEmpty)
                _buildBillRow('কাস্টমার:', saleData['customerName'], shapedRegular),
              
              pw.SizedBox(height: 4),
              BanglaText(saleData['type'] == 'sale_due' ? 'বাকি বিক্রয়' : 'নগদ রিসিট', font: shapedBold, fontSize: 11),
              pw.Text(formattedDate, style: pw.TextStyle(fontSize: 7, font: fontRegular)),
              pw.Divider(thickness: 0.5),

              if (items.isNotEmpty) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    BanglaText('বিবরণ', font: shapedBold, fontSize: 8),
                    BanglaText('মোট', font: shapedBold, fontSize: 8),
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
                        pw.Expanded(child: BanglaText('${item['name']} ($qty ${item['unit']})', font: shapedRegular, fontSize: 8)),
                        pw.Text((price * qty).toStringAsFixed(2), style: pw.TextStyle(fontSize: 8, font: fontRegular)),
                      ],
                    ),
                  );
                }),
                pw.Divider(thickness: 0.5),
              ],

              _buildBillRow('মোট টাকা:', (saleData['totalAmount'] ?? 0.0).toStringAsFixed(2), shapedBold),
              _buildBillRow('পরিশোধিত:', (saleData['cashPaid'] ?? 0.0).toStringAsFixed(2), shapedBold),
              _buildBillRow('বকেয়া:', (saleData['dueAmount'] ?? 0.0).toStringAsFixed(2), shapedBold, isRed: true),

              pw.SizedBox(height: 10),
              BanglaText('ধন্যবাদ, আবার আসবেন!', font: shapedBold, fontSize: 9),
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
    
    final shapedRegular = await _loadShapedFont("assets/fonts/SolaimanLipi-Normal.ttf", name: "SolaimanLipi Regular");
    final shapedBold = await _loadShapedFont("assets/fonts/SolaimanLipi-Bold.ttf", name: "SolaimanLipi Bold");

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
        header: (context) => pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              if (logo != null) ...[pw.Image(logo, width: 80, height: 80), pw.SizedBox(width: 20)],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    BanglaText(shopInfo['name']!, font: shapedBold, fontSize: 32, color: PdfColors.blue900),
                    if (shopInfo['address']!.isNotEmpty) 
                      BanglaText(shopInfo['address']!, font: shapedRegular, fontSize: 10, color: PdfColors.grey900),
                    BanglaText('মোবাইল: ${shopInfo['phone']}', font: shapedBold, fontSize: 11),
                  ],
                ),
              ),
              pw.SizedBox(width: 80),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 2, color: PdfColors.blue900),
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
                  BanglaText('কাস্টমার: ${customerData['name']}', font: shapedBold, fontSize: 12),
                  pw.Text('Mobile: ${customerData['phone']}', style: pw.TextStyle(fontSize: 10, font: fontRegular)),
                  if (customerData['address'] != null && customerData['address'].toString().isNotEmpty)
                    BanglaText('ঠিকানা: ${customerData['address']}', font: shapedRegular, fontSize: 9),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  BanglaText('হিসাব বিবরণী', font: shapedBold, fontSize: 15, color: PdfColors.blue800),
                  BanglaText('সময়সীমা: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}', font: shapedRegular, fontSize: 9),
                  pw.SizedBox(height: 5),
                  BanglaText('পিরিয়ড মোট বাকি: ৳${periodBaki.toStringAsFixed(0)}', font: shapedBold, fontSize: 9, color: PdfColors.red700),
                  BanglaText('পিরিয়ড মোট জমা: ৳${periodJama.toStringAsFixed(0)}', font: shapedBold, fontSize: 9, color: PdfColors.green700),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _cell('তারিখ', flex: 1, font: shapedBold, isHeader: true),
                  _cell('বিবরণ', flex: 3, font: shapedBold, isHeader: true),
                  _cell('মোট', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                  _cell('জমা', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                  _cell('বাকি', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                ],
              ),
              ...dataRows.map((row) => pw.TableRow(
                children: [
                  _cell(row[0], flex: 1, font: shapedRegular),
                  _cell(row[1], flex: 3, font: shapedRegular),
                  _cell(row[2], flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                  _cell(row[3], flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                  _cell(row[4], flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
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
                decoration: pw.BoxDecoration(color: PdfColors.blue50, border: pw.Border.all(color: PdfColors.blue900, width: 1), borderRadius: pw.BorderRadius.circular(5)),
                child: BanglaText('বর্তমান মোট বকেয়া: ৳${customerData['dueAmount']?.toStringAsFixed(2)}', font: shapedBold, fontSize: 13, color: PdfColors.red900),
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
    
    final shapedRegular = await _loadShapedFont("assets/fonts/SolaimanLipi-Normal.ttf", name: "SolaimanLipi Regular");
    final shapedBold = await _loadShapedFont("assets/fonts/SolaimanLipi-Bold.ttf", name: "SolaimanLipi Bold");

    final shopInfo = await getShopInfo();
    final currency = AppTranslations.get('currency_symbol');

    final double combinedSalary = totalSalary + totalBonus;
    final double netProfit = totalProfit - totalExpense - combinedSalary;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(children: [
          BanglaText(shopInfo['name']!, font: shapedBold, fontSize: 22, color: PdfColors.blue900),
          BanglaText('হিসাব নিকাশ রিপোর্ট', font: shapedBold, fontSize: 14),
          BanglaText('সময়সীমা: ${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}', font: shapedRegular, fontSize: 10),
          pw.Divider(thickness: 1, color: PdfColors.blue900),
          pw.SizedBox(height: 10),
        ]),
        build: (context) => [
          BanglaText('দৈনিক লেনদেন সারসংক্ষেপ', font: shapedBold, fontSize: 12),
          pw.SizedBox(height: 8),
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _cell('তারিখ', flex: 1, font: shapedBold, isHeader: true),
                  _cell('বিক্রি', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                  _cell('লাভ', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                  _cell('খরচ', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                  _cell('বেতন', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                  _cell('বাকি', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                  _cell('জমা', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
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
                  _cell(date, flex: 1, font: shapedRegular),
                  _cell(dailyData[date]![0].toStringAsFixed(0), flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                  _cell(dailyData[date]![1].toStringAsFixed(0), flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                  _cell(dailyData[date]![2].toStringAsFixed(0), flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                  _cell(dailyData[date]![3].toStringAsFixed(0), flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                  _cell(dailyData[date]![4].toStringAsFixed(0), flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                  _cell(dailyData[date]![5].toStringAsFixed(0), flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                ])).toList();
              }(),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryBoxWithFont('মোট বিক্রি', '৳${totalSale.toStringAsFixed(0)}', PdfColors.blue, shapedBold),
            _summaryBoxWithFont('মোট লাভ', '৳${totalProfit.toStringAsFixed(0)}', PdfColors.green, shapedBold),
            _summaryBoxWithFont('মোট খরচ', '৳${totalExpense.toStringAsFixed(0)}', PdfColors.red, shapedBold),
          ]),
          pw.SizedBox(height: 20),
          pw.Center(child: pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(color: netProfit >= 0 ? PdfColors.green50 : PdfColors.red50, border: pw.Border.all(color: netProfit >= 0 ? PdfColors.green : PdfColors.red, width: 2), borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Column(children: [
              BanglaText('নিট লাভ', font: shapedBold, fontSize: 14, color: PdfColors.green900),
              BanglaText('৳${netProfit.toStringAsFixed(2)}', font: shapedBold, fontSize: 20, color: netProfit >= 0 ? PdfColors.green900 : PdfColors.red900),
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
    
    final shapedRegular = await _loadShapedFont("assets/fonts/SolaimanLipi-Normal.ttf", name: "SolaimanLipi Regular");
    final shapedBold = await _loadShapedFont("assets/fonts/SolaimanLipi-Bold.ttf", name: "SolaimanLipi Bold");

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
        header: (context) => pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.start, children: [
            if (logo != null) ...[pw.Image(logo, width: 75, height: 75), pw.SizedBox(width: 20)],
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              BanglaText(shopInfo['name']!, font: shapedBold, fontSize: 28, color: PdfColors.blue900),
              if (shopInfo['address']!.isNotEmpty) BanglaText(shopInfo['address']!, font: shapedRegular, fontSize: 10),
              BanglaText('মোবাইল: ${shopInfo['phone']}', font: shapedBold, fontSize: 10),
            ])),
            pw.SizedBox(width: 75),
          ]),
          pw.Divider(thickness: 1.5, color: PdfColors.blue900),
          pw.SizedBox(height: 10),
        ]),
        build: (context) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            BanglaText('স্টক ইনভেন্টরি রিপোর্ট', font: shapedBold, fontSize: 14, color: PdfColors.blue800),
            BanglaText('সময়সীমা: $dateRange', font: shapedRegular, fontSize: 9),
          ]),
          pw.SizedBox(height: 15),
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _cell('তারিখ', flex: 1, font: shapedBold, isHeader: true),
                  _cell('যুক্ত পণ্য', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                  _cell('বিনিয়োগ', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                  _cell('বিক্রয়মূল্য', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                  _cell('সম্ভাব্য লাভ', flex: 1, font: shapedBold, isHeader: true, align: ShapedTextAlign.right),
                ],
              ),
              ...sortedDates.map((date) => pw.TableRow(children: [
                _cell(date, flex: 1, font: shapedRegular),
                _cell(dailyLogs[date]![0].toStringAsFixed(0), flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                _cell(dailyLogs[date]![1].toStringAsFixed(0), flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                _cell(dailyLogs[date]![2].toStringAsFixed(0), flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
                _cell(dailyLogs[date]![3].toStringAsFixed(0), flex: 1, font: shapedRegular, align: ShapedTextAlign.right),
              ])),
            ],
          ),
          pw.SizedBox(height: 25),
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
    
    final shapedBold = await _loadShapedFont("assets/fonts/SolaimanLipi-Bold.ttf", name: "SolaimanLipi Bold");

    final shopInfo = await getShopInfo();
    final note = data['note'] ?? '';
    final isSalary = note.contains('বেতন') || note.toLowerCase().contains('salary');
    final double basicSalary = (data['basicSalary'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
    final double bonus = (data['bonus'] as num?)?.toDouble() ?? 0.0;
    final double totalAmount = (data['amount'] as num?)?.toDouble() ?? (basicSalary + bonus);
    final String title = isSalary ? 'স্যালারি ভাউচার' : 'খরচ ভাউচার';

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            BanglaText(shopInfo['name']!, font: shapedBold, fontSize: 22, color: PdfColors.blue900),
            pw.Text('Mobile: ${shopInfo['phone']}', style: pw.TextStyle(fontSize: 10, font: fontRegular)),
          ]),
          pw.Container(padding: const pw.EdgeInsets.all(10), decoration: const pw.BoxDecoration(color: PdfColors.grey200), child: BanglaText(title.toUpperCase(), font: shapedBold, fontSize: 12)),
        ]),
        pw.SizedBox(height: 30), pw.Divider(),
        _buildVoucherRowWithFont('তারিখ:', timeString, shapedBold),
        _buildVoucherRowWithFont('ক্যাটাগরি:', isSalary ? 'কর্মচারীর বেতন' : 'দোকান খরচ', shapedBold),
        if (isSalary) ...[
          if (data['empName'] != null) _buildVoucherRowWithFont('কর্মচারী:', data['empName'], shapedBold),
          if (data['empPhone'] != null && data['empPhone'].toString().isNotEmpty) _buildVoucherRowWithFont('মোাবাইল:', data['empPhone'], shapedBold),
          _buildVoucherRowWithFont('মূল বেতন:', '৳${basicSalary.toStringAsFixed(2)}', shapedBold),
        ],
        _buildVoucherRowWithFont('বিবরণ:', note, shapedBold),
        pw.Divider(), pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(padding: const pw.EdgeInsets.all(15), decoration: pw.BoxDecoration(border: pw.Border.all()), child: BanglaText('মোট: ৳${totalAmount.toStringAsFixed(2)}', font: shapedBold, fontSize: 16, color: PdfColors.red900)),
        ]),
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [pw.SizedBox(width: 100, child: pw.Divider()), BanglaText('কর্তৃপক্ষ', font: shapedBold, fontSize: 10)]),
          pw.Column(children: [pw.SizedBox(width: 100, child: pw.Divider()), BanglaText('প্রাপক', font: shapedBold, fontSize: 10)]),
        ]),
      ]),
    ));
    if (isShare) { await Printing.sharePdf(bytes: await pdf.save(), filename: 'Voucher.pdf'); } else { await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save()); }
  }

  // --- Static Helpers ---

  static pw.Widget _cell(String text, {required int flex, required ShapedFont font, ShapedTextAlign align = ShapedTextAlign.left, bool isHeader = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: BanglaText(
          text,
          font: font,
          fontSize: isHeader ? 10 : 9,
          color: isHeader ? PdfColors.white : PdfColors.black,
          align: align,
        ),
      ),
    );
  }

  static pw.Widget _buildBillRow(String key, String value, ShapedFont font, {bool isRed = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 1), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      BanglaText(key, font: font, fontSize: 8), BanglaText(value, font: font, fontSize: 8, color: isRed ? PdfColors.red : PdfColors.black),
    ]));
  }

  static pw.Widget _summaryBoxWithFont(String title, String value, PdfColor color, ShapedFont font) {
    return pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(color: color), borderRadius: pw.BorderRadius.circular(5)), child: pw.Column(children: [
      BanglaText(title, font: font, fontSize: 8), BanglaText(value, font: font, fontSize: 10, color: color),
    ]));
  }

  static pw.Widget _buildVoucherRowWithFont(String label, String value, ShapedFont font) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child: pw.Row(children: [
      pw.SizedBox(width: 90, child: BanglaText(label, font: font, fontSize: 10)), pw.Expanded(child: BanglaText(value, font: font, fontSize: 10)),
    ]));
  }

  static Future<void> shareSubscriptionCard({required String name, required String shopName, required String phone, String? plan, String? txId, String? senderDigits, String? rejectionReason, bool isActivation = false, bool isApproval = false, bool isRejection = false}) async {
    final pdf = pw.Document();
    final fontRegular = await _loadFont("assets/fonts/SolaimanLipi-Normal.ttf");
    final fontBold = await _loadFont("assets/fonts/SolaimanLipi-Bold.ttf");
    
    final shapedRegular = await _loadShapedFont("assets/fonts/SolaimanLipi-Normal.ttf", name: "SolaimanLipi Regular");
    final shapedBold = await _loadShapedFont("assets/fonts/SolaimanLipi-Bold.ttf", name: "SolaimanLipi Bold");

    final imageByte = await rootBundle.load('assets/images/ic_launcher.png');
    final image = pw.MemoryImage(imageByte.buffer.asUint8List());
    String title = isActivation ? 'PREMIUM ACTIVATED' : (isApproval ? 'ACCOUNT APPROVED' : (isRejection ? 'REQUEST CANCELLED' : 'SUBSCRIPTION REQUEST'));
    pdf.addPage(pw.Page(pageFormat: const PdfPageFormat(400, 520, marginAll: 20), build: (context) => pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue900, width: 2), borderRadius: pw.BorderRadius.circular(15)), padding: const pw.EdgeInsets.all(20), child: pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.center, children: [pw.Image(image, width: 40, height: 40), pw.SizedBox(width: 10), BanglaText('Amar Dokan', font: shapedBold, fontSize: 22)]),
      pw.SizedBox(height: 10), pw.Divider(), pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, font: fontBold)),
      pw.SizedBox(height: 20), _buildBillRow('মালিক:', name, shapedBold), _buildBillRow('দোকান:', shopName, shapedBold), _buildBillRow('মোবাইল:', phone, shapedBold),
      pw.Spacer(), BanglaText('Date: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}', font: shapedRegular, fontSize: 9),
    ]))));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'subscription_card.pdf');
  }
}
