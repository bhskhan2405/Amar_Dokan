import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'translations.dart';

class ReceiptUtils {
  // বাংলা ফন্ট লোড করার কমন মেথড
  static Future<pw.Font> loadBengaliFont() async {
    try {
      final fontData = await rootBundle.load("assets/fonts/SolaimanLipi-Normal.ttf");
      return pw.Font.ttf(fontData);
    } catch (e) {
      // যদি ফাইল না পায় তবে গুগল ফন্ট ব্যবহার করবে (ইন্টারনেট লাগবে)
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

  // দোকান বা ইউজারের ডিটেইলস নিয়ে আসার মেথড
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

  // ১. POS বিল রিসিট জেনারেটর
  static Future<void> generatePosReceipt({
    required Map<String, dynamic> saleData,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await loadBengaliFont();
    final fontBold = await loadBengaliFontBold();
    final shopInfo = await getShopInfo();

    // অনুবাদিত টেক্সট
    final labelCustomer = AppTranslations.get('customer');
    final labelMobile = AppTranslations.get('mobile');
    final labelAddress = AppTranslations.get('address_label');
    final labelCashReceipt = AppTranslations.get('cash_receipt');
    final labelPaymentType = AppTranslations.get('payment_type');
    final labelSellBy = AppTranslations.get('sell_by');
    final labelDescription = AppTranslations.get('description');
    final labelDiscount = AppTranslations.get('discount');
    final labelPrice = AppTranslations.get('price');
    final labelSubTotal = AppTranslations.get('sub_total');
    final labelTotal = AppTranslations.get('total_revenue');
    final labelPaid = AppTranslations.get('paid_amount');
    final labelDue = AppTranslations.get('due');
    final currency = AppTranslations.get('currency_symbol');

    String formattedDateTime = '';
    if (saleData['createdAt'] != null && saleData['createdAt'] is Timestamp) {
      formattedDateTime = DateFormat('dd/MM/yyyy hh:mm a').format((saleData['createdAt'] as Timestamp).toDate());
    } else {
      formattedDateTime = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());
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
              pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              if (shopInfo['address']!.isNotEmpty) pw.Text(shopInfo['address']!, style: const pw.TextStyle(fontSize: 8)),
              if (shopInfo['phone']!.isNotEmpty) pw.Text('${AppTranslations.get('mobile')}: ${shopInfo['phone']}', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 5),

              if (saleData['customerName']?.isNotEmpty == true) ...[
                pw.Container(
                  width: double.infinity,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('$labelCustomer: ${saleData['customerName']}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      if (saleData['customerPhone']?.isNotEmpty == true)
                        pw.Text('$labelMobile: ${saleData['customerPhone']}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
              ],

              pw.Text('------------------------------------------------', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(labelCashReceipt.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text(formattedDateTime, style: const pw.TextStyle(fontSize: 7)),
              pw.Text('------------------------------------------------', style: const pw.TextStyle(fontSize: 8)),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('$labelPaymentType:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(saleData['paymentType'] ?? 'Cash', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('$labelSellBy:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(saleData['staffName'] ?? 'Admin', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 5),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 3, child: pw.Text(labelDescription, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text(labelPrice, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(thickness: 0.5),

              ...items.entries.map((entry) {
                final item = entry.value;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(item['name'] ?? '', style: const pw.TextStyle(fontSize: 8))),
                      pw.Expanded(flex: 1, child: pw.Text('${item['qty']}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                      pw.Expanded(flex: 2, child: pw.Text('$currency ${(item['price'] * item['qty']).toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                    ],
                  ),
                );
              }).toList(),

              pw.Divider(thickness: 0.5),
              _buildPosRow(labelSubTotal, '$currency ${saleData['subTotal']?.toStringAsFixed(2) ?? '0.00'}'),
              if ((saleData['globalDiscountTk'] ?? 0) > 0)
                _buildPosRow(labelDiscount, '- $currency ${saleData['globalDiscountTk']?.toStringAsFixed(2)}'),
              _buildPosRow(labelTotal, '$currency ${saleData['totalAmount']?.toStringAsFixed(2) ?? '0.00'}', isBold: true),
              _buildPosRow(labelPaid, '$currency ${saleData['cashPaid']?.toStringAsFixed(2) ?? '0.00'}'),
              if ((saleData['dueAmount'] ?? 0) > 0)
                _buildPosRow(labelDue, '$currency ${saleData['dueAmount']?.toStringAsFixed(2)}', isBold: true, color: PdfColors.red),
              
              pw.SizedBox(height: 10),
              pw.Text(AppTranslations.get('thank_you_msg') ?? 'Thank you for shopping!', style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
              pw.SizedBox(height: 2),
              pw.Text('Powered by Amar Dokan App', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildPosRow(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.black)),
        ],
      ),
    );
  }

  // ২. কাস্টমার স্টেটমেন্ট (Statement) জেনারেটর
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

    final labelStatement = AppTranslations.get('statement');
    final labelDate = AppTranslations.get('date');
    final labelDescription = AppTranslations.get('description');
    final labelAmount = AppTranslations.get('amount');
    final labelBalance = AppTranslations.get('balance');
    final labelTotalDue = AppTranslations.get('total_due');
    final currency = AppTranslations.get('currency_symbol');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        header: (context) => pw.Column(
          children: [
            pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.Text(shopInfo['address']!, style: const pw.TextStyle(fontSize: 10)),
            pw.Text('${AppTranslations.get('mobile')}: ${shopInfo['phone']}', style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(),
            pw.SizedBox(height: 10),
          ]
        ),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${AppTranslations.get('customer')}: ${customerData['name']}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${AppTranslations.get('mobile')}: ${customerData['phone']}', style: const pw.TextStyle(fontSize: 10)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(labelStatement, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}', style: const pw.TextStyle(fontSize: 9)),
                  ]
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // টেবিল হেডার
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell(labelDate, isBold: true),
                    _tableCell(labelDescription, isBold: true),
                    _tableCell(labelAmount, isBold: true, align: pw.TextAlign.right),
                    _tableCell(labelBalance, isBold: true, align: pw.TextAlign.right),
                  ],
                ),
                ...transactions.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = data['date'] != null ? DateFormat('dd/MM/yy').format((data['date'] as Timestamp).toDate()) : '';
                  final note = data['note'] ?? data['type'] ?? '';
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                  final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
                  final type = data['type'] ?? '';
                  final isJama = type == 'জমা' || type == 'jama' || type == 'Payment';

                  return pw.TableRow(
                    children: [
                      _tableCell(date),
                      _tableCell(note),
                      _tableCell('$currency ${amount.toStringAsFixed(2)}', color: isJama ? PdfColors.green : PdfColors.red, align: pw.TextAlign.right),
                      _tableCell('$currency ${balance.toStringAsFixed(2)}', align: pw.TextAlign.right),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue)),
                  child: pw.Text('$labelTotalDue: $currency ${customerData['dueAmount']?.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.red)),
                )
              ]
            ),
          ];
        },
        footer: (context) => pw.Column(
          children: [
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by Amar Dokan App', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              ]
            )
          ]
        )
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _tableCell(String text, {bool isBold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, textAlign: align, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
    );
  }

  // ৩. হিসাব-কিতাব (Accounts) রিপোর্ট জেনারেটর
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
        header: (context) => pw.Column(
          children: [
            pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('${AppTranslations.get('accounts')} ${AppTranslations.get('report')}', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}', style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(),
          ]
        ),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryBox(AppTranslations.get('total_sale'), '$currency ${totalSale.toStringAsFixed(2)}', PdfColors.blue),
                _summaryBox(AppTranslations.get('total_profit'), '$currency ${totalProfit.toStringAsFixed(2)}', PdfColors.green),
                _summaryBox(AppTranslations.get('total_expense'), '$currency ${totalExpense.toStringAsFixed(2)}', PdfColors.red),
              ]
            ),
            pw.SizedBox(height: 20),

            pw.Text(AppTranslations.get('recent_sales'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell(AppTranslations.get('date'), isBold: true),
                    _tableCell(AppTranslations.get('customer'), isBold: true),
                    _tableCell(AppTranslations.get('amount'), isBold: true, align: pw.TextAlign.right),
                    _tableCell(AppTranslations.get('profit'), isBold: true, align: pw.TextAlign.right),
                  ]
                ),
                ...sales.map((doc) {
                   final data = doc.data() as Map<String, dynamic>;
                   final date = data['createdAt'] != null ? DateFormat('dd/MM').format((data['createdAt'] as Timestamp).toDate()) : '';
                   return pw.TableRow(
                     children: [
                       _tableCell(date),
                       _tableCell(data['customerName'] ?? 'Cash'),
                       _tableCell('$currency ${(data['totalAmount'] as num?)?.toDouble() ?? 0.0}', align: pw.TextAlign.right),
                       _tableCell('$currency ${(data['profit'] as num?)?.toDouble() ?? 0.0}', align: pw.TextAlign.right),
                     ]
                   );
                }).toList(),
              ]
            ),

            pw.SizedBox(height: 20),
            pw.Text(AppTranslations.get('recent_expenses'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell(AppTranslations.get('date'), isBold: true),
                    _tableCell(AppTranslations.get('description'), isBold: true),
                    _tableCell(AppTranslations.get('amount'), isBold: true, align: pw.TextAlign.right),
                  ]
                ),
                ...expenses.map((doc) {
                   final data = doc.data() as Map<String, dynamic>;
                   final date = data['createdAt'] != null ? DateFormat('dd/MM').format((data['createdAt'] as Timestamp).toDate()) : '';
                   return pw.TableRow(
                     children: [
                       _tableCell(date),
                       _tableCell(data['note'] ?? ''),
                       _tableCell('$currency ${(data['amount'] as num?)?.toDouble() ?? 0.0}', align: pw.TextAlign.right),
                     ]
                   );
                }).toList(),
              ]
            ),
          ];
        }
      )
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ৪. সিঙ্গেল একাউন্ট রেকর্ড (Sale/Expense) PDF
  static Future<void> generateSingleAccountPdf({
    required Map<String, dynamic> data,
    required String timeString,
    bool isExpense = false,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await loadBengaliFont();
    final fontBold = await loadBengaliFontBold();
    final shopInfo = await getShopInfo();

    final currency = AppTranslations.get('currency_symbol');
    final note = data['note'] ?? '';
    final isSalary = note.contains('বেতন') || note.toLowerCase().contains('salary');
    
    String title = isExpense 
        ? (isSalary ? AppTranslations.get('salary') : AppTranslations.get('expense'))
        : AppTranslations.get('sale');

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text(timeString, style: const pw.TextStyle(fontSize: 7)),
              pw.Divider(),
              
              if (!isExpense) ...[
                 _buildPosRow(AppTranslations.get('total_amount'), '$currency ${data['totalAmount'] ?? 0.0}'),
                 _buildPosRow(AppTranslations.get('profit'), '$currency ${data['profit'] ?? 0.0}'),
                 _buildPosRow(AppTranslations.get('payment_type'), '${data['paymentType'] ?? 'Cash'}'),
              ] else ...[
                 _buildPosRow(AppTranslations.get('amount'), '$currency ${data['amount'] ?? 0.0}'),
                 if (note.isNotEmpty) pw.Text('${AppTranslations.get('description')}: $note', style: const pw.TextStyle(fontSize: 8)),
              ],
              
              pw.SizedBox(height: 10),
              pw.Text('Generated by Amar Dokan', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // সাবস্ক্রিপশন কার্ড (আগের কোডটি এখানেও কাজ করবে, কিন্তু উপরের মতো ক্লিনআপ করে দিলাম)
  static Future<void> shareSubscriptionCard({
    required String name,
    required String shopName,
    required String phone,
    String? plan,
    String? txId,
    String? senderDigits,
    String? rejectionReason,
    bool isActivation = false,
    bool isApproval = false,
    bool isRejection = false,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await loadBengaliFont();
    final fontBold = await loadBengaliFontBold();

    final imageByte = await rootBundle.load('assets/images/ic_launcher.png');
    final image = pw.MemoryImage(imageByte.buffer.asUint8List());

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
    } else if (isRejection) {
      title = 'REQUEST CANCELLED';
      titleColor = PdfColors.red700;
      borderColor = PdfColors.red900;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(400, 520, marginAll: 20),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor, width: 2), borderRadius: pw.BorderRadius.circular(15)),
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Image(image, width: 40, height: 40),
                    pw.SizedBox(width: 10),
                    pw.Text('Amar Dokan', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: titleColor)),
                pw.SizedBox(height: 20),
                _buildDetailsRow('Owner Name', name),
                _buildDetailsRow('Shop Name', shopName),
                _buildDetailsRow('Mobile', phone),
                if (!isApproval) ...[
                  _buildDetailsRow('Plan', planDisplay),
                  _buildDetailsRow('Transaction ID', txId ?? 'N/A'),
                  if (senderDigits != null) _buildDetailsRow('Sender Last 4', senderDigits),
                ],
                pw.Spacer(),
                pw.Text('Date: ${DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 5),
                pw.Text('Thank you for choosing Amar Dokan', style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'subscription_card.pdf');
  }

  static pw.Widget _buildDetailsRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
