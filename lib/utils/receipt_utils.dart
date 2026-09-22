import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/shop_utils.dart';
import 'translations.dart';
import 'package:bangla_pdf_fixer/bangla_pdf_fixer.dart';

class ReceiptUtils {
  // --- 1. Load Fonts & Shop Info ---

  static Future<pw.Font> _loadFont(String path) async {
    final fontData = await rootBundle.load(path);
    return pw.Font.ttf(fontData);
  }

  static Future<ShapedFont> _loadShapedFont(String path, {required String name}) async {
    return await BanglaFontManager.instance.loadAsset(path, name: name);
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

  // --- 2. POS Bill Receipt (80mm - Absolute Symmetry) ---

  static Future<void> generatePosReceipt({
    required Map<String, dynamic> saleData,
    bool isPrint = true,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await _loadFont("assets/fonts/SolaimanLipi-Normal.ttf");
    final shapedRegular = await _loadShapedFont("assets/fonts/SolaimanLipi-Normal.ttf", name: "SolReg");
    final shapedBold = await _loadShapedFont("assets/fonts/SolaimanLipi-Bold.ttf", name: "SolBold");
    final shopInfo = await getShopInfo();

    await AppTranslations.loadLanguage();

    String formattedDate = DateFormat('d/M/yyyy h:mm a').format(DateTime.now());
    if (saleData['createdAt'] != null && saleData['createdAt'] is Timestamp) {
      formattedDate = DateFormat('d/M/yyyy h:mm a').format((saleData['createdAt'] as Timestamp).toDate());
    }

    final items = saleData['items'] as Map<String, dynamic>? ?? {};
    const divider = '****************************************';
    
    final double dueAmount = (saleData['dueAmount'] ?? 0.0).toDouble();
    final String titleKey = dueAmount > 0 ? 'credit_sale' : 'cash_receipt_title';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 5 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              // 1. Shop Header (Forced Page Center)
              pw.Container(
                width: double.infinity,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    _bt(shopInfo['name']!, font: shapedBold, fontSize: 16, align: ShapedTextAlign.center),
                    if (shopInfo['address']!.isNotEmpty)
                      _bt(shopInfo['address']!, font: shapedRegular, fontSize: 8, color: PdfColors.grey800, align: ShapedTextAlign.center),
                    _bt('${_t('mobile')}: ${shopInfo['phone']}', font: shapedRegular, fontSize: 9, align: ShapedTextAlign.center),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 5),
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),
              
              // 2. Customer Section (Fixed Left Margin)
              if (saleData['customerName'] != null && (saleData['customerName'] as String).isNotEmpty)
                _buildRowLeft(_t('customer'), saleData['customerName'], shapedRegular),
              if (saleData['customerPhone'] != null && (saleData['customerPhone'] as String).isNotEmpty)
                _buildRowLeft(_t('mobile'), saleData['customerPhone'], shapedRegular),
              if (saleData['customerAddress'] != null && (saleData['customerAddress'] as String).isNotEmpty)
                _buildRowLeft(_t('address'), saleData['customerAddress'], shapedRegular),
              
              pw.SizedBox(height: 2),
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),
              
              // 3. Receipt Title & Date (Forced Page Center)
              pw.Container(
                width: double.infinity,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    _bt(_t(titleKey).toUpperCase(), font: shapedBold, fontSize: 11, align: ShapedTextAlign.center),
                    _bt(formattedDate, font: shapedRegular, fontSize: 7, align: ShapedTextAlign.center),
                  ],
                ),
              ),
              
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),

              _buildRowPos(_t('payment_type'), _t(saleData['paymentType']?.toString().toLowerCase() ?? 'cash'), shapedRegular),
              _buildRowPos(_t('sell_by'), saleData['staffName'] ?? 'Admin', shapedRegular),
              
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),

              // 5. Table Headers (Full Width)
              pw.Container(
                width: double.infinity,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 3, child: _bt(_t('description'), font: shapedBold, fontSize: 8, align: ShapedTextAlign.start)),
                    pw.Expanded(flex: 2, child: _bt(_t('discount_label'), font: shapedBold, fontSize: 8, align: ShapedTextAlign.center)),
                    pw.Expanded(flex: 2, child: _bt(_t('total'), font: shapedBold, fontSize: 8, align: ShapedTextAlign.end)),
                  ],
                ),
              ),
              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),

              // 6. Items List
              if (items.isNotEmpty) ...[
                ...items.entries.map((entry) {
                  final item = entry.value;
                  final double qty = (item['qty'] ?? 1.0).toDouble();
                  final unit = item['unit'] ?? 'Pcs';
                  final discountPercent = (item['discount'] ?? 0.0).toDouble();
                  final price = (item['price'] ?? 0.0).toDouble(); 
                  
                  double originalPrice = price / (1 - (discountPercent / 100));
                  double discountAmountTk = originalPrice - price;
                  if (discountPercent <= 0) discountAmountTk = 0;

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: double.infinity,
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Expanded(flex: 3, child: _bt(item['name'] ?? '', font: shapedBold, fontSize: 8, align: ShapedTextAlign.start)),
                              pw.Expanded(flex: 2, child: _bt(discountPercent > 0 ? '${discountPercent.toStringAsFixed(0)}% (${discountAmountTk.toStringAsFixed(0)}tk)' : '-', font: shapedRegular, fontSize: 7, align: ShapedTextAlign.center)),
                              pw.Expanded(flex: 2, child: _bt((price * qty).toStringAsFixed(2), font: shapedBold, fontSize: 8, align: ShapedTextAlign.end)),
                            ],
                          ),
                        ),
                        _bt('${_t('qty_hint')}: $qty $unit', font: shapedRegular, fontSize: 7, color: PdfColors.grey700, align: ShapedTextAlign.start),
                      ],
                    ),
                  );
                }),
                pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),
              ],

              // 7. Totals (Full Width Aligned)
              _buildRowPos(_t('sub_total'), (saleData['subTotal'] ?? saleData['totalAmount'] ?? 0.0).toStringAsFixed(2), shapedRegular),
              if ((saleData['globalDiscountTk'] ?? 0) > 0)
                _buildRowPos(_t('discount_label'), '-${(saleData['globalDiscountTk'] as num).toStringAsFixed(2)}', shapedRegular),
              if ((saleData['vatAmount'] ?? 0) > 0)
                _buildRowPos('${_t('vat')} (${(saleData['vatPercent'] ?? 0).toStringAsFixed(0)}%)', (saleData['vatAmount'] as num).toStringAsFixed(2), shapedRegular),
              _buildRowPos(_t('total_amount'), (saleData['totalAmount'] ?? 0.0).toStringAsFixed(2), shapedBold, isBold: true),
              _buildRowPos(_t('paid_amount'), (saleData['cashPaid'] ?? 0.0).toStringAsFixed(2), shapedRegular),
              _buildRowPos(_t('due'), dueAmount.toStringAsFixed(2), shapedBold),

              pw.Text(divider, style: const pw.TextStyle(fontSize: 8)),
              
              pw.SizedBox(height: 5),
              // 8. Footer (Forced Page Center)
              pw.Container(
                width: double.infinity,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    _bt(_t('thank_you_msg'), font: shapedBold, fontSize: 10, align: ShapedTextAlign.center),
                    _bt(_t('return_policy'), font: shapedRegular, fontSize: 7, color: PdfColors.grey800, align: ShapedTextAlign.center),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 5),
              
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: saleData['customerPhone'] ?? '0123456789',
                  width: 100,
                  height: 30,
                ),
              ),
              
              pw.SizedBox(height: 5),
              pw.Container(
                width: double.infinity,
                alignment: pw.Alignment.center,
                child: pw.Text('Powered by Amar Dokan App', style: pw.TextStyle(fontSize: 5, font: fontRegular, color: PdfColors.grey700)),
              ),
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

  // --- Static Helpers ---

  static String _t(String key) => AppTranslations.get(key);

  static pw.Widget _bt(String text, {required ShapedFont font, required double fontSize, PdfColor color = PdfColors.black, ShapedTextAlign align = ShapedTextAlign.start}) {
    return BanglaText(text, font: font, fontSize: fontSize, color: color, align: align);
  }

  static pw.Widget _cell(String text, {required int flex, required ShapedFont font, ShapedTextAlign align = ShapedTextAlign.start, bool isHeader = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: BanglaText(text, font: font, fontSize: isHeader ? 10 : 9, color: isHeader ? PdfColors.white : PdfColors.black, align: align),
      ),
    );
  }

  static pw.Widget _buildRowPos(String label, String value, ShapedFont font, {bool isBold = false}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _bt(label, font: font, fontSize: 8, align: ShapedTextAlign.start),
          _bt(value, font: font, fontSize: 8, align: ShapedTextAlign.end),
        ],
      ),
    );
  }

  static pw.Widget _buildRowLeft(String label, String value, ShapedFont font) {
    if (value == null || value.isEmpty) return pw.SizedBox();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          pw.SizedBox(width: 65, child: _bt(label, font: font, fontSize: 8, align: ShapedTextAlign.start)),
          _bt(': $value', font: font, fontSize: 8, align: ShapedTextAlign.start),
        ],
      ),
    );
  }
  
  // (Rest of the code like generateCustomerStatement etc. remain with same structure)
}
