import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'translations.dart';

class ReceiptUtils {
  // --- ১. উইজেট থেকে ইমেজ তৈরি করার মূল লজিক (Error Fixed) ---
  
  static Future<Uint8List> captureWidget(Widget widget) async {
    final RenderRepaintBoundary boundary = RenderRepaintBoundary();
    final buildOwner = BuildOwner(focusManager: FocusManager());
    final pipelineOwner = PipelineOwner();

    pipelineOwner.rootNode = boundary;
    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Material(child: widget),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    // রেজোলিউশন বাড়ানোর জন্য pixelRatio ব্যবহার করা হয়েছে
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // --- ২. POS রিসিট উইজেট ডিজাইন (Image 1 এর স্টাইল) ---

  static Widget buildPosReceiptWidget(Map<String, dynamic> saleData, Map<String, String> shopInfo) {
    final items = saleData['items'] as Map<String, dynamic>? ?? {};
    
    String formattedDate = '';
    if (saleData['createdAt'] != null && saleData['createdAt'] is Timestamp) {
      formattedDate = DateFormat('d/M/yyyy h:mm a').format((saleData['createdAt'] as Timestamp).toDate());
    } else {
      formattedDate = DateFormat('d/M/yyyy h:mm a').format(DateTime.now());
    }

    const divider = '**********************************************';

    return Container(
      width: 350, 
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(shopInfo['name']!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'SolaimanLipi')),
          Text('${AppTranslations.currentLanguage == 'bn' ? 'মোবাইল' : 'Telp.'}: ${shopInfo['phone']}', style: const TextStyle(fontSize: 16, color: Colors.black, fontFamily: 'SolaimanLipi')),
          const SizedBox(height: 10),
          const Text(divider, style: TextStyle(fontSize: 12, color: Colors.black)),
          
          Text(AppTranslations.get('cash_receipt').toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black, fontFamily: 'SolaimanLipi')),
          Text(formattedDate, style: const TextStyle(fontSize: 14, color: Colors.black)),
          const Text(divider, style: TextStyle(fontSize: 12, color: Colors.black)),

          _buildFlutterRow('${AppTranslations.get('payment_type')}:', saleData['paymentType'] ?? 'Cash'),
          _buildFlutterRow('${AppTranslations.get('sell_by')}:', saleData['staffName'] ?? 'Admin'),
          const Text(divider, style: TextStyle(fontSize: 12, color: Colors.black)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(flex: 3, child: Text(AppTranslations.get('description'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'SolaimanLipi'))),
              Expanded(flex: 2, child: Text(AppTranslations.get('discount'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'SolaimanLipi'))),
              Expanded(flex: 2, child: Text(AppTranslations.get('price'), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'SolaimanLipi'))),
            ],
          ),
          const Text(divider, style: TextStyle(fontSize: 12, color: Colors.black)),

          ...items.entries.map((entry) {
            final item = entry.value;
            final double qty = (item['qty'] ?? 1.0).toDouble();
            final price = (item['price'] ?? 0.0).toDouble();
            final discount = (item['discount'] ?? 0.0).toDouble();
            final originalPrice = (item['originalPrice'] ?? price).toDouble();
            final itemDiscountTk = (originalPrice * discount) / 100;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(flex: 3, child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'SolaimanLipi'))),
                      Expanded(flex: 2, child: Text(discount > 0 ? '${discount.toStringAsFixed(0)}% (${itemDiscountTk.toStringAsFixed(0)})' : '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                      Expanded(flex: 2, child: Text((price * qty).toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  Text('Qty: $qty ${item['unit'] ?? 'Pcs'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontFamily: 'SolaimanLipi')),
                ],
              ),
            );
          }),

          const Text(divider, style: TextStyle(fontSize: 12, color: Colors.black)),
          _buildFlutterSummary(AppTranslations.get('total'), (saleData['subTotal'] ?? 0.0).toStringAsFixed(2)),
          _buildFlutterSummary(AppTranslations.get('total_revenue'), (saleData['totalAmount'] ?? 0.0).toStringAsFixed(2), isBold: true, fontSize: 18),
          _buildFlutterSummary(AppTranslations.get('paid_amount'), (saleData['cashPaid'] ?? 0.0).toStringAsFixed(2)),
          _buildFlutterSummary(AppTranslations.get('due'), (saleData['dueAmount'] ?? 0.0).toStringAsFixed(2), color: Colors.red),
          const Text(divider, style: TextStyle(fontSize: 12, color: Colors.black)),

          const SizedBox(height: 10),
          Text(AppTranslations.get('thank_you_msg').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'SolaimanLipi')),
          const SizedBox(height: 20),

          // বারকোড ডিজাইন
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(35, (index) => Container(
              width: index % 3 == 0 ? 5 : (index % 2 == 0 ? 1 : 2),
              height: 40,
              color: Colors.black,
              margin: const EdgeInsets.symmetric(horizontal: 1),
            )),
          ),
          const SizedBox(height: 10),
          const Text('Powered by Amar Dokan App', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  static Widget _buildFlutterRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontFamily: 'SolaimanLipi')),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'SolaimanLipi')),
        ],
      ),
    );
  }

  static Widget _buildFlutterSummary(String label, String value, {bool isBold = false, double fontSize = 15, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color, fontFamily: 'SolaimanLipi')),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  // --- ৩. ইমেজ জেনারেশন ও পিডিএফ এক্সপোর্ট ---

  static Future<void> generatePosReceipt({required Map<String, dynamic> saleData}) async {
    final user = FirebaseAuth.instance.currentUser;
    Map<String, String> shopInfo = {'name': 'Amar Dokan', 'address': '', 'phone': ''};
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        shopInfo = {
          'name': data['shopName'] ?? data['storeName'] ?? data['name'] ?? 'Amar Dokan',
          'address': data['shopAddress'] ?? data['address'] ?? '',
          'phone': data['phone'] ?? data['mobile'] ?? '',
        };
      }
    }

    final receiptWidget = buildPosReceiptWidget(saleData, shopInfo);
    final Uint8List imageBytes = await captureWidget(receiptWidget);

    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 0),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(image),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // কাস্টমার স্টেটমেন্ট এবং একাউন্টস রিপোর্টের জন্য আমরা আপাতত টেক্সট-বেজড সিস্টেমটিই ফিক্স করে দিচ্ছি
  // কারণ স্টেটমেন্ট অনেক বড় হতে পারে যা ইমেজ মেথডে মেমোরি ইস্যু তৈরি করতে পারে।
  // তবে POS এর জন্য ইমেজ মেথডটিই সেরা।

  static Future<void> generateCustomerStatement({
    required Map<String, dynamic> customerData,
    required List<QueryDocumentSnapshot> transactions,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();
    
    // বাংলা ফন্ট সরাসরি লোড করা
    final fontData = await rootBundle.load("assets/fonts/SolaimanLipi-Normal.ttf");
    final banglaFont = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load("assets/fonts/SolaimanLipi-Bold.ttf");
    final banglaFontBold = pw.Font.ttf(fontBoldData);
    
    final shopInfo = await getShopInfo();
    final currency = AppTranslations.get('currency_symbol');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: banglaFont, bold: banglaFontBold),
        header: (context) => pw.Column(children: [
          pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Divider(),
        ]),
        build: (context) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('${AppTranslations.get('customer')}: ${customerData['name']}'),
            pw.Text(AppTranslations.get('statement'), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [AppTranslations.get('date'), AppTranslations.get('description'), AppTranslations.get('amount')],
            data: transactions.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return [
                data['date'] != null ? DateFormat('dd/MM/yy').format((data['date'] as Timestamp).toDate()) : '',
                data['note'] ?? data['type'] ?? '',
                '$currency ${data['amount']}',
              ];
            }).toList(),
          ),
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
    final fontData = await rootBundle.load("assets/fonts/SolaimanLipi-Normal.ttf");
    final banglaFont = pw.Font.ttf(fontData);
    final shopInfo = await getShopInfo();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: banglaFont, bold: banglaFont),
        build: (context) => [
          pw.Text(shopInfo['name']!, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text('${AppTranslations.get('accounts')} ${AppTranslations.get('report')}'),
          pw.Divider(),
          pw.Text('${AppTranslations.get('total_sale')}: $totalSale'),
          pw.Text('${AppTranslations.get('total_profit')}: $totalProfit'),
          pw.Text('${AppTranslations.get('total_expense')}: $totalExpense'),
        ],
      )
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateSingleAccountPdf({required Map<String, dynamic> data, required String timeString, bool isExpense = false}) async {
     // POS এর মতো ইমেজ মেথড এখানেও কল করা যেতে পারে
     await generatePosReceipt(saleData: data); 
  }

  static Future<void> shareSubscriptionCard({required String name, required String shopName, required String phone, String? plan, String? txId, String? senderDigits, String? rejectionReason, bool isActivation = false, bool isApproval = false, bool isRejection = false}) async {
    // সাবস্ক্রিপশন কার্ড জেনারেশন (আগের কোড)
  }
}
