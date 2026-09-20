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

  // ভাষা অনুযায়ী টেক্সট প্রসেসিং
  static String _t(String key) {
    String text = AppTranslations.get(key);
    if (AppTranslations.currentLanguage == 'bn') {
      return text.fix;
    }
    return text;
  }

  static String _fixText(String? text) {
    if (text == null || text.isEmpty) return '';
    if (AppTranslations.currentLanguage == 'bn') {
      return text.fix;
    }
    return text;
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
    const divider = '****************************************';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(_fixText(shopInfo['name']), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: fontBold)),
              pw.Text('${_t('mobile')}: ${shopInfo['phone']}', style: const pw.TextStyle(fontSize: 9)),
              
              if (saleData['customerName'] != null && (saleData['customerName'] as String).isNotEmpty)
                _buildRowLeft(_t('customer'), _fixText(saleData['customerName']), fontBold),
              if (saleData['customerPhone'] != null && (saleData['customerPhone'] as String).isNotEmpty)
                _buildRowLeft(_t('mobile'), saleData['customerPhone'], fontBold),
              if (saleData['customerAddress'] != null && (saleData['customerAddress'] as String).isNotEmpty)
                _buildRowLeft(_t('address'), _fixText(saleData['customerAddress']), fontBold),

              pw.SizedBox(height: 4),
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),
              
              pw.Text(_t(saleData['type'] == 'sale_due' ? 'credit_sale' : 'cash_receipt_title'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: fontBold)),
              pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 7)),
              
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),

              _buildRow(_t('payment_type'), _fixText(saleData['paymentType'] ?? 'Cash'), fontBold),
              _buildRow(_t('sell_by'), _fixText(saleData['staffName'] ?? 'Admin'), fontBold),
              
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),

              if (items.isNotEmpty) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text(_t('description'), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: fontBold))),
                    pw.Expanded(flex: 2, child: pw.Text(_t('discount_label'), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: fontBold))),
                    pw.Expanded(flex: 2, child: pw.Text(_t('total'), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: fontBold))),
                  ],
                ),
                pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),

                ...items.entries.map((entry) {
                  final item = entry.value;
                  final double qty = (item['qty'] ?? 1.0).toDouble();
                  final unit = item['unit'] ?? 'Pcs';
                  final discount = (item['discount'] ?? 0.0).toDouble();
                  final price = (item['price'] ?? 0.0).toDouble();

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(flex: 3, child: pw.Text(_fixText(item['name'] ?? ''), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: fontBold))),
                            pw.Expanded(flex: 2, child: pw.Text(discount > 0 ? '${discount.toStringAsFixed(0)}%' : '-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
                            pw.Expanded(flex: 2, child: pw.Text((price * qty).toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: fontBold))),
                          ],
                        ),
                        pw.Text('${_t('qty_hint')}: $qty ${_fixText(unit)}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      ],
                    ),
                  );
                }),
                pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),
              ] else if (saleData['note'] != null) ...[
                pw.Text('${_t('note')}: ${_fixText(saleData['note'])}', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 5),
              ],

              _buildSummaryRow(_t('sub_total'), (saleData['subTotal'] ?? saleData['totalAmount'] ?? 0.0).toStringAsFixed(2), fontBold),
              if ((saleData['globalDiscountTk'] ?? 0) > 0)
                _buildSummaryRow(_t('discount_label'), '-${(saleData['globalDiscountTk'] as num).toStringAsFixed(2)}', fontBold),
              if ((saleData['vatAmount'] ?? 0) > 0)
                _buildSummaryRow('${_t('vat')} (${(saleData['vatPercent'] as num).toStringAsFixed(0)}%)', '+${(saleData['vatAmount'] as num).toStringAsFixed(2)}', fontBold),
              _buildSummaryRow(_t('total_amount'), (saleData['totalAmount'] ?? saleData['amount'] ?? 0.0).toStringAsFixed(2), fontBold, isBold: true, fontSize: 10),
              _buildSummaryRow(_t('paid_amount'), (saleData['cashPaid'] ?? saleData['paidAmount'] ?? 0.0).toStringAsFixed(2), fontBold),
              _buildSummaryRow(_t('due'), (saleData['dueAmount'] ?? 0.0).toStringAsFixed(2), fontBold),

              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 5),
              pw.Text(_t('thank_you_msg'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold)),
              pw.SizedBox(height: 8),
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
    
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/ic_launcher.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    double periodBaki = 0;
    double periodJama = 0;

    final dataList = transactions.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      double total = (data['totalAmount'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble() ?? 0.0;
      double paid = (data['paidAmount'] as num?)?.toDouble() ?? (data['cashPaid'] as num?)?.toDouble() ?? 0.0;
      double due = (data['dueAmount'] as num?)?.toDouble() ?? 0.0;

      if (data['type'] == 'জমা' || data['type'] == 'jama' || data['type'] == 'Payment') {
        total = 0.0;
        paid = (data['amount'] as num?)?.toDouble() ?? 0.0;
        periodJama += paid;
      } else {
        periodBaki += total;
        periodJama += paid;
      }

      return [
        data['date'] != null ? DateFormat('dd/MM/yy').format((data['date'] as Timestamp).toDate()) : '',
        _fixText(data['note'] ?? data['type'] ?? ''),
        total > 0 ? total.toStringAsFixed(2) : '-',
        paid > 0 ? paid.toStringAsFixed(2) : '-',
        due > 0 ? due.toStringAsFixed(2) : '-',
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                if (logo != null) ...[
                  pw.Image(logo, width: 85, height: 85),
                  pw.SizedBox(width: 15),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(_fixText(shopInfo['name']), style: pw.TextStyle(fontSize: 34, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, font: fontBold), textAlign: pw.TextAlign.center),
                      if (shopInfo['address']!.isNotEmpty) 
                        pw.Text(_fixText(shopInfo['address']), style: const pw.TextStyle(fontSize: 12), textAlign: pw.TextAlign.center),
                      pw.Text('${_t('mobile')}: ${shopInfo['phone']}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: fontBold), textAlign: pw.TextAlign.center),
                    ],
                  ),
                ),
                pw.SizedBox(width: 85),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 2, color: PdfColors.blue900),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (context) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${_t('customer')}: ${_fixText(customerData['name'])}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: fontBold)),
              pw.Text('${_t('mobile')}: ${customerData['phone']}', style: const pw.TextStyle(fontSize: 10)),
              if (customerData['address'] != null && customerData['address'].toString().isNotEmpty)
                pw.Text('${_t('address')}: ${_fixText(customerData['address'])}', style: const pw.TextStyle(fontSize: 10)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(_t('statement'), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800, font: fontBold)),
              pw.Text('${_t('date_range')}: ${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.Text('${_t('total_period_baki')} ৳${periodBaki.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.red700, font: fontBold)),
              pw.Text('${_t('total_period_jama')} ৳${periodJama.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, color: PdfColors.green700, font: fontBold)),
            ]),
          ]),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [_t('date'), _t('description'), _t('total'), _t('paid_label'), _t('due_label')],
            data: dataList,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10, font: fontBold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FixedColumnWidth(60),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FixedColumnWidth(60),
              3: const pw.FixedColumnWidth(60),
              4: const pw.FixedColumnWidth(60),
            },
          ),
          pw.SizedBox(height: 20),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(color: PdfColors.blue900), borderRadius: pw.BorderRadius.circular(5)),
              child: pw.Text('${_t('net_outstanding_due')} ৳${customerData['dueAmount']?.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red900, font: fontBold)),
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
    final results = await Future.wait([
      _loadFont("assets/fonts/SolaimanLipi-Normal.ttf"),
      _loadFont("assets/fonts/SolaimanLipi-Bold.ttf"),
      getShopInfo(),
    ]);

    final fontRegular = results[0] as pw.Font;
    final fontBold = results[1] as pw.Font;
    final shopInfo = results[2] as Map<String, String>;
    final currency = AppTranslations.get('currency_symbol');

    final double combinedSalary = totalSalary + totalBonus;
    final double netProfit = totalProfit - totalExpense - combinedSalary;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          pw.Text(_fixText(shopInfo['name']), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: fontBold)),
          pw.Text(_t('accounts_report_title')),
          pw.Text('${_t('date_range')}: ${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}', style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),
        ]),
        build: (context) => [
          pw.SizedBox(height: 10),
          pw.Text(_t('daily_trans_summary'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: fontBold)),
          pw.SizedBox(height: 5),
          pw.TableHelper.fromTextArray(
            headers: [_t('date'), _t('products'), _t('profit'), _t('total_expense'), _t('salary'), _t('due_label'), _t('paid_label')],
            data: () {
              Map<String, List<double>> dailyData = {};
              for (var doc in sales) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['createdAt'] as Timestamp?;
                if (timestamp == null) continue;
                final dateKey = DateFormat('dd/MM/yyyy').format(timestamp.toDate());
                if (!dailyData.containsKey(dateKey)) dailyData[dateKey] = [0, 0, 0, 0, 0, 0, 0];
                dailyData[dateKey]![0] += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                dailyData[dateKey]![1] += (data['profit'] as num?)?.toDouble() ?? 0.0;
                dailyData[dateKey]![4] += (data['dueAmount'] as num?)?.toDouble() ?? 0.0;
                dailyData[dateKey]![5] += (data['cashPaid'] as num?)?.toDouble() ?? 0.0;
              }
              for (var doc in expenses) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = data['createdAt'] as Timestamp?;
                if (timestamp == null) continue;
                final dateKey = DateFormat('dd/MM/yyyy').format(timestamp.toDate());
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
                dynamic dateVal = data['date'] ?? data['timestamp'] ?? data['createdAt'];
                if (dateVal == null) continue;
                DateTime tDate = dateVal is Timestamp ? dateVal.toDate() : (DateTime.tryParse(dateVal.toString()) ?? DateTime.now());
                final dateKey = DateFormat('dd/MM/yyyy').format(tDate);
                if (!dailyData.containsKey(dateKey)) dailyData[dateKey] = [0, 0, 0, 0, 0, 0, 0];
                double amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
                dailyData[dateKey]![6] += amt;
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
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: fontBold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 7),
          ),
          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.Text(_t('final_summary'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: fontBold)),
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryBox(_t('total_sales'), '$currency ${totalSale.toStringAsFixed(2)}', PdfColors.blue, fontBold),
            _summaryBox(_t('total_profit'), '$currency ${totalProfit.toStringAsFixed(2)}', PdfColors.green, fontBold),
          ]),
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _summaryBox(_t('total_expense'), '$currency ${totalExpense.toStringAsFixed(2)}', PdfColors.red, fontBold),
            _summaryBox(_t('salary'), '$currency ${combinedSalary.toStringAsFixed(2)}', PdfColors.orange, fontBold),
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
              pw.Text(_t('profit'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900, font: fontBold)),
              pw.Text('$currency ${netProfit.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: netProfit >= 0 ? PdfColors.green900 : PdfColors.red900, font: fontBold)),
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
      : _t("Full Inventory Summary");

    Map<String, List<double>> dailyLogs = {};
    for (var log in logs) {
      Timestamp ts = log['date'] as Timestamp;
      String dateKey = DateFormat('dd/MM/yyyy').format(ts.toDate());
      if (!dailyLogs.containsKey(dateKey)) dailyLogs[dateKey] = [0, 0, 0, 0];
      double qty = (log['addedQty'] as num?)?.toDouble() ?? 0.0;
      double cost = (log['costPrice'] as num?)?.toDouble() ?? 0.0;
      double sale = (log['salePrice'] as num?)?.toDouble() ?? 0.0;
      dailyLogs[dateKey]![0] += qty;
      dailyLogs[dateKey]![1] += (cost * qty);
      dailyLogs[dateKey]![2] += (sale * qty);
      dailyLogs[dateKey]![3] += ((sale - cost) * qty);
    }

    double grandCost = 0;
    double grandSale = 0;
    double grandProfit = 0;
    var sortedDates = dailyLogs.keys.toList()..sort((a, b) => DateFormat('dd/MM/yyyy').parse(b).compareTo(DateFormat('dd/MM/yyyy').parse(a)));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              if (logo != null) ...[pw.Image(logo, width: 75, height: 75), pw.SizedBox(width: 15)],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(_fixText(shopInfo['name']), style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, font: fontBold)),
                    if (shopInfo['address']!.isNotEmpty) pw.Text(_fixText(shopInfo['address']), style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('${_t('mobile')}: ${shopInfo['phone']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold)),
                  ],
                ),
              ),
              pw.SizedBox(width: 75),
            ],
          ),
          pw.Divider(thickness: 1.5, color: PdfColors.blue900),
          pw.SizedBox(height: 10),
        ]),
        build: (context) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(_t('inventory_report'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800, font: fontBold)),
            pw.Text('${_t('date_range')}: $dateRange', style: const pw.TextStyle(fontSize: 9)),
          ]),
          pw.SizedBox(height: 15),
          pw.TableHelper.fromTextArray(
            headers: [_t('date'), _t('items_added'), _t('investment'), _t('potential_sale'), _t('potential_profit')],
            data: sortedDates.map((date) {
              final vals = dailyLogs[date]!;
              grandCost += vals[1];
              grandSale += vals[2];
              grandProfit += vals[3];
              return [
                date,
                vals[0].toStringAsFixed(0),
                vals[1].toStringAsFixed(2),
                vals[2].toStringAsFixed(2),
                vals[3].toStringAsFixed(2),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10, font: fontBold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 25),
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(color: PdfColors.grey50, border: pw.Border.all(color: PdfColors.blue900), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(children: [
              _buildSummaryRowPDF('${_t('total_investment')}:', '৳${grandCost.toStringAsFixed(2)}', fontBold),
              _buildSummaryRowPDF('${_t('potential_sale')}:', '৳${grandSale.toStringAsFixed(2)}', fontBold),
              pw.Divider(color: PdfColors.grey300),
              _buildSummaryRowPDF('${_t('potential_profit')}:', '৳${grandProfit.toStringAsFixed(2)}', fontBold, isBold: true, color: PdfColors.green900),
            ]),
          ),
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

    final String title = _t(isSalary ? 'salary_voucher' : 'expense_voucher');

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_fixText(shopInfo['name']), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900, font: fontBold)),
            pw.Text('${_t('mobile')}: ${shopInfo['phone']}', style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.Container(padding: const pw.EdgeInsets.all(10), decoration: const pw.BoxDecoration(color: PdfColors.grey200), child: pw.Text(_fixText(title.toUpperCase()), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: fontBold))),
        ]),
        pw.SizedBox(height: 30),
        pw.Divider(),
        _buildVoucherRow(_t('date'), timeString, fontBold),
        _buildVoucherRow(_t('category'), _t(isSalary ? 'emp_salary_cat' : 'shop_expense_cat'), fontBold),
        if (isSalary) ...[
          if (data['empName'] != null) _buildVoucherRow(_t('employee'), _fixText(data['empName']), fontBold),
          if (data['empPhone'] != null && data['empPhone'].toString().isNotEmpty) _buildVoucherRow(_t('mobile'), data['empPhone'], fontBold),
          if (data['empDesignation'] != null && data['empDesignation'].toString().isNotEmpty) _buildVoucherRow(_t('designation'), _fixText(data['empDesignation']), fontBold),
          _buildVoucherRow(_t('salary'), '৳${basicSalary.toStringAsFixed(2)}', fontBold),
          _buildVoucherRow(_t('bonus'), '৳${bonus.toStringAsFixed(2)}', fontBold),
        ],
        _buildVoucherRow(_t('description'), _fixText(note), fontBold),
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(padding: const pw.EdgeInsets.all(15), decoration: pw.BoxDecoration(border: pw.Border.all()), child: pw.Text('${_t('total')}: ৳${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red900, font: fontBold))),
        ]),
        pw.Spacer(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(children: [pw.SizedBox(width: 100, child: pw.Divider()), pw.Text(_t('authorized_sign'))]),
          pw.Column(children: [pw.SizedBox(width: 100, child: pw.Divider()), pw.Text(_t('receiver_sign'))]),
        ]),
      ]),
    ));

    String filePrefix = isSalary ? 'Salary' : 'Expense';
    String fileName = '${filePrefix}_Voucher_${DateTime.now().millisecondsSinceEpoch}.pdf';

    if (isShare) {
      await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
    } else {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    }
  }

  // --- Helper Widgets ---

  static pw.Widget _summaryBox(String title, String value, PdfColor color, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: color), borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 8, font: font)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color, font: font)),
      ]),
    );
  }

  static pw.Widget _buildRow(String key, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(key, style: pw.TextStyle(fontSize: 8, font: font)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: font)),
        ],
      ),
    );
  }

  static pw.Widget _buildRowLeft(String key, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          pw.SizedBox(width: 45, child: pw.Text(key, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, font: font))),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, font: font)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, pw.Font font, {bool isBold = false, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, font: font)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, font: font)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRowPDF(String label, String value, pw.Font font, {bool isBold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, font: font)),
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color, font: font)),
        ],
      ),
    );
  }

  static pw.Widget _buildVoucherRow(String label, String value, pw.Font font) {
    return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Row(children: [
      pw.SizedBox(width: 100, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: font))),
      pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: font))),
    ]));
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
            pw.Text('Amar Dokan', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, font: fontBold)),
          ]),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.Text(_fixText(title), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: titleColor, font: fontBold)),
          pw.SizedBox(height: 20),
          _buildRow(_t('owner_name'), _fixText(name), fontBold),
          _buildRow(_t('shop_name'), _fixText(shopName), fontBold),
          _buildRow(_t('mobile'), phone, fontBold),
          if (!isApproval) _buildRow(_t('plan'), planDisplay, fontBold),
          pw.Spacer(),
          pw.Text('Date: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Thank you for choosing Amar Dokan', style: const pw.TextStyle(fontSize: 8)),
        ]),
      ),
    ));
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'subscription_card.pdf');
  }
}
