import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/translations.dart';
import '../utils/shop_utils.dart';
import '../utils/subscription_utils.dart';
import 'subscription_screen.dart';

class POSScreen extends StatefulWidget {
  final Map<String, dynamic>? currentStaff;

  const POSScreen({super.key, this.currentStaff});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  String searchQuery = '';
  late String selectedCategory;
  final Map<String, Map<String, dynamic>> _cart = {};

  bool _showProfitInfo = true;

  // পেমেন্ট ও হিসাব বিবরণী বক্স সম্পূর্ণ টগল করার জন্য
  bool _isPaymentBoxExpanded = true;

  String _selectedPaymentType = 'Cash';
  bool _isDefaultPaymentType = true;

  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();

  final TextEditingController _globalDiscountPercentController = TextEditingController();
  final TextEditingController _globalDiscountTkController = TextEditingController();
  final TextEditingController _cashPaidController = TextEditingController();

  double _globalDiscountPercent = 0.0;
  double _globalDiscountTk = 0.0;
  bool _isCashManuallyEdited = false;
  String _shopId = '';

  @override
  void initState() {
    super.initState();
    selectedCategory = AppTranslations.get('all');
    _loadShopId();
  }

  Future<void> _loadShopId() async {
    _shopId = await ShopUtils.getShopId();
    setState(() {});
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _globalDiscountPercentController.dispose();
    _globalDiscountTkController.dispose();
    _cashPaidController.dispose();
    super.dispose();
  }

  void _openScanner(List<QueryDocumentSnapshot> allProducts) {
    bool isScanned = false;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(AppTranslations.get('scan_barcode'), style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF0D47A1),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  if (isScanned) return;
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                      isScanned = true;
                      final scannedCode = barcode.rawValue!.trim();

                      SystemSound.play(SystemSoundType.click);
                      HapticFeedback.mediumImpact();

                      try {
                        final matchedProduct = allProducts.firstWhere((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return (data['barcode'] ?? '').toString().trim() == scannedCode;
                        });

                        final pData = matchedProduct.data() as Map<String, dynamic>;
                        _addToCart(matchedProduct.id, pData);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${AppTranslations.get('barcode')}: $scannedCode - ${AppTranslations.get('no_product_found')}')),
                        );
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                      break;
                    }
                  }
                },
              ),
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.80,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.redAccent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Text(
                  AppTranslations.get('barcode_box_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, backgroundColor: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addToCart(String productId, Map<String, dynamic> product) {
    final originalPrice = (product['price'] ?? 0.0) as double;
    final discountPercent = (product['discount'] ?? 0.0) as double;

    final effectivePrice = discountPercent > 0
        ? originalPrice - ((originalPrice * discountPercent) / 100)
        : originalPrice;

    setState(() {
      if (_cart.containsKey(productId)) {
        double currentQty = (_cart[productId]!['qty'] ?? 1.0).toDouble();
        double stock = (product['stock'] ?? 0).toDouble();
        if (currentQty < stock) {
          _cart[productId]!['qty'] = currentQty + 1.0;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('no_stock_msg')), duration: const Duration(milliseconds: 800)),
          );
        }
      } else {
        double stock = (product['stock'] ?? 0).toDouble();
        if (stock > 0) {
          _cart[productId] = {
            'name': product['name'] ?? '',
            'price': effectivePrice,
            'originalPrice': originalPrice,
            'discount': discountPercent,
            'costPrice': product['costPrice'] ?? 0.0,
            'unit': product['unit'] ?? 'Pcs',
            'size': product['size'] ?? '',
            'qty': 1.0,
            'stock': stock,
          };
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('stock_out_msg')), duration: const Duration(milliseconds: 800)),
          );
        }
      }
      if (!_isCashManuallyEdited) {
        _cashPaidController.text = _finalTotalAmount.toStringAsFixed(2);
      }
    });
  }

  void _updateQty(String productId, double delta) {
    setState(() {
      if (_cart.containsKey(productId)) {
        double currentQty = (_cart[productId]!['qty'] as num).toDouble();
        double stock = (_cart[productId]!['stock'] as num).toDouble();
        double newQty = currentQty + delta;

        if (newQty > 0 && newQty <= stock) {
          _cart[productId]!['qty'] = newQty;
        } else if (newQty <= 0) {
          _cart.remove(productId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('stock_limit_msg')), duration: const Duration(milliseconds: 800)),
          );
        }
      }
      if (!_isCashManuallyEdited) {
        _cashPaidController.text = _finalTotalAmount.toStringAsFixed(2);
      }
    });
  }

  void _editQuantityDialog(String productId, double currentQty, double stock) {
    final TextEditingController qtyController = TextEditingController(text: currentQty.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('change_qty'), style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: qtyController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(labelText: AppTranslations.get('qty_hint'), border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              double? newQty = double.tryParse(qtyController.text.trim());
              if (newQty != null) {
                if (newQty > 0 && newQty <= stock) {
                  setState(() {
                    _cart[productId]!['qty'] = newQty;
                    if (!_isCashManuallyEdited) {
                      _cashPaidController.text = _finalTotalAmount.toStringAsFixed(2);
                    }
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('invalid_qty_msg')), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(AppTranslations.get('save')),
          ),
        ],
      ),
    );
  }

  void _editDiscountDialog(String productId) {
    final item = _cart[productId];
    if (item == null) return;

    final double originalPrice = item['originalPrice'] ?? item['price'];
    final double currentDiscountPercent = item['discount'] ?? 0.0;
    final double currentDiscountTk = (originalPrice * currentDiscountPercent) / 100;

    final TextEditingController percentController = TextEditingController(
      text: currentDiscountPercent > 0 ? currentDiscountPercent.toStringAsFixed(0) : '',
    );
    final TextEditingController tkController = TextEditingController(
      text: currentDiscountTk > 0 ? currentDiscountTk.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppTranslations.get('edit_discount'), style: const TextStyle(fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: percentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: AppTranslations.get('discount_percent'),
                  border: const OutlineInputBorder(),
                  suffixText: '%',
                ),
                onChanged: (value) {
                  double? percent = double.tryParse(value);
                  if (percent != null && originalPrice > 0) {
                    double tk = (originalPrice * percent) / 100;
                    tkController.text = tk.toStringAsFixed(1);
                  } else {
                    tkController.text = '';
                  }
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tkController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: AppTranslations.get('discount_tk'),
                  border: const OutlineInputBorder(),
                  suffixText: 'Tk',
                ),
                onChanged: (value) {
                  double? tk = double.tryParse(value);
                  if (tk != null && originalPrice > 0) {
                    double percent = (tk / originalPrice) * 100;
                    percentController.text = percent.toStringAsFixed(1);
                  } else {
                    percentController.text = '';
                  }
                  setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppTranslations.get('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                double? newPercent = double.tryParse(percentController.text.trim());
                newPercent ??= 0.0;

                if (newPercent >= 0 && newPercent <= 100) {
                  final updatedEffectivePrice = newPercent > 0
                      ? originalPrice - ((originalPrice * newPercent) / 100)
                      : originalPrice;

                  setState(() {
                    _cart[productId]!['discount'] = newPercent;
                    _cart[productId]!['price'] = updatedEffectivePrice;
                    if (!_isCashManuallyEdited) {
                      _cashPaidController.text = _finalTotalAmount.toStringAsFixed(2);
                    }
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('invalid_discount_msg')), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(AppTranslations.get('confirm')),
            ),
          ],
        ),
      ),
    );
  }

  double get _subTotalAmount {
    double sum = 0;
    _cart.forEach((key, value) {
      double price = (value['price'] as num).toDouble();
      double qty = (value['qty'] as num).toDouble();
      sum += price * qty;
    });
    return sum;
  }

  double get _finalTotalAmount {
    double sub = _subTotalAmount;
    double finalAmt = sub - _globalDiscountTk;
    return finalAmt < 0 ? 0 : finalAmt;
  }

  double get _dueAmount {
    double total = _finalTotalAmount;
    double paid = double.tryParse(_cashPaidController.text.trim()) ?? 0.0;
    double due = total - paid;
    return due < 0 ? 0 : due;
  }

  Future<void> _generateAndPrintBill({required bool isPrint, required Map<String, dynamic> saleData}) async {
    if (_shopId.isEmpty) return;

    String shopName = 'SHOP NAME';
    String address = 'Address: Not Provided';
    String phone = '0000000000';

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_shopId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          shopName = data['shopName'] ?? data['storeName'] ?? 'SHOP NAME';
          address = data['address'] ?? 'Address: Not Provided';
          phone = data['phone'] ?? data['mobile'] ?? '0000000000';
        }
      }
    } catch (_) {}

    final pdf = pw.Document();

    pw.Font? banglaFontRegular;
    pw.Font? banglaFontBold;
    try {
      final regData = await rootBundle.load("assets/fonts/SolaimanLipi-Normal.ttf");
      banglaFontRegular = pw.Font.ttf(regData);

      final boldData = await rootBundle.load("assets/fonts/SolaimanLipi-Bold.ttf");
      banglaFontBold = pw.Font.ttf(boldData);
    } catch (_) {
      try {
        final fontData = await rootBundle.load("assets/fonts/SolaimanLipi-Thin.ttf");
        banglaFontRegular = pw.Font.ttf(fontData);
        banglaFontBold = pw.Font.ttf(fontData);
      } catch (_) {}
    }

    final tTheme = banglaFontRegular != null
        ? pw.ThemeData.withFont(base: banglaFontRegular, bold: banglaFontBold ?? banglaFontRegular)
        : null;

    String formattedDateTime = '';
    if (saleData['createdAt'] != null && saleData['createdAt'] is Timestamp) {
      DateTime dt = (saleData['createdAt'] as Timestamp).toDate();
      int hour12 = dt.hour % 12;
      if (hour12 == 0) hour12 = 12;
      String period = dt.hour >= 12 ? 'PM' : 'AM';
      formattedDateTime = '${dt.day}/${dt.month}/${dt.year} $hour12:${dt.minute.toString().padLeft(2, '0')} $period';
    } else {
      DateTime now = DateTime.now();
      int hour12 = now.hour % 12;
      if (hour12 == 0) hour12 = 12;
      String period = now.hour >= 12 ? 'PM' : 'AM';
      formattedDateTime = '${now.day}/${now.month}/${now.year} $hour12:${now.minute.toString().padLeft(2, '0')} $period';
    }

    final customerName = saleData['customerName'] ?? '';
    final customerPhone = saleData['customerPhone'] ?? '';
    final customerAddress = saleData['customerAddress'] ?? '';
    final paymentType = saleData['paymentType'] ?? 'Cash';
    final subTotal = saleData['subTotal'] ?? 0.0;
    final totalAmount = saleData['totalAmount'] ?? 0.0;
    final discountPercent = saleData['globalDiscountPercent'] ?? 0.0;
    final discountTk = saleData['globalDiscountTk'] ?? 0.0;
    final cashPaid = saleData['cashPaid'] ?? 0.0;
    final dueAmount = saleData['dueAmount'] ?? 0.0;
    final staffName = saleData['staffName'] ?? 'Admin';
    final items = saleData['items'] as Map<String, dynamic>? ?? {};

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 8 * PdfPageFormat.mm),
        theme: tTheme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(shopName, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(address, style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Telp. $phone', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 6),

              if (customerName.isNotEmpty || customerPhone.isNotEmpty || customerAddress.isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (customerName.isNotEmpty)
                        pw.Text('Customer: $customerName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      if (customerPhone.isNotEmpty)
                        pw.Text('Mobile: $customerPhone', style: const pw.TextStyle(fontSize: 8)),
                      if (customerAddress.isNotEmpty)
                        pw.Text('Address: $customerAddress', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
              ],

              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),

              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('CASH RECEIPT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      formattedDateTime,
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Type:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(paymentType, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sold By:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(staffName == 'Admin' ? 'Admin' : 'Staff: $staffName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Description', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Discount', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),

              ...items.entries.map((entry) {
                final item = entry.value;
                final name = item['name'] ?? '';
                final originalPrice = item['originalPrice'] ?? item['price'] ?? 0.0;
                final singlePrice = item['price'] ?? 0.0;
                final discount = item['discount'] ?? 0.0;
                final itemDiscountTk = discount > 0 ? (originalPrice * discount) / 100 : 0.0;
                final double qty = (item['qty'] ?? 1.0).toDouble();
                final unit = item['unit'] ?? 'Pcs';
                final size = item['size'] ?? '';
                final totalPrice = singlePrice * qty;

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              name,
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              discount > 0 ? '${discount.toStringAsFixed(0)}% (${itemDiscountTk.toStringAsFixed(0)}tk)' : '-',
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              totalPrice.toStringAsFixed(2),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            size.isNotEmpty ? 'Qty: $qty $unit | Size: $size' : 'Qty: $qty $unit',
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(subTotal.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              if (discountTk > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cart Discount', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('${discountPercent.toStringAsFixed(1)}% (-${discountTk.toStringAsFixed(2)})', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Amount', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(totalAmount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Paid', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(cashPaid.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Due', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(dueAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('THANK YOU!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 6),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: List.generate(24, (index) => pw.Container(
                  width: index % 2 == 0 ? 2 : 4,
                  height: 20,
                  color: PdfColors.black,
                  margin: const pw.EdgeInsets.symmetric(horizontal: 1),
                )),
              ),
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

  void _showSuccessPopup(Map<String, dynamic> saleData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('sale_success'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: Text(AppTranslations.get('print_share_question')),
        actions: [
          FutureBuilder<bool>(
            future: SubscriptionUtils.isPremium(),
            builder: (context, snapshot) {
              bool isPremium = snapshot.data ?? true;
              if (isPremium) {
                return Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      icon: const Icon(Icons.share, size: 18),
                      label: Text(AppTranslations.get('share')),
                      onPressed: () {
                        Navigator.pop(context);
                        _generateAndPrintBill(isPrint: false, saleData: saleData);
                      },
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                      icon: const Icon(Icons.print, size: 18),
                      label: Text(AppTranslations.get('print')),
                      onPressed: () {
                        Navigator.pop(context);
                        _generateAndPrintBill(isPrint: true, saleData: saleData);
                      },
                    ),
                  ],
                );
              } else {
                return TextButton.icon(
                  onPressed: () => _showAdUnlockDialog(saleData),
                  icon: const Icon(Icons.play_circle_fill, color: Colors.orange),
                  label: Text(AppTranslations.get('watch_ad')),
                );
              }
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showAdUnlockDialog(Map<String, dynamic> saleData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('watch_ad')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppTranslations.get('watch_ad_to_unlock')),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            const Text('Loading Ad...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

    // ডামি অ্যাড ডিলে (৩ সেকেন্ড)
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context); // অ্যাড ডায়ালগ বন্ধ
      _generateAndPrintBill(isPrint: false, saleData: saleData);
    });
  }

  void _showConfirmationDialog() {
    if (_cart.isEmpty) return;

    if (_dueAmount > 0) {
      String name = _customerNameController.text.trim();
      String phone = _customerPhoneController.text.trim();
      String address = _customerAddressController.text.trim();

      if (name.isEmpty || phone.isEmpty || address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.get('due_sale_required_msg')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('sale_confirmation')),
        content: Text(AppTranslations.get('sale_confirm_question')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.get('no'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _confirmSaleAndSaveToDatabase();
            },
            child: Text(AppTranslations.get('yes')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSaleAndSaveToDatabase() async {
    if (_shopId.isEmpty || _cart.isEmpty) return;

    double totalCost = 0;
    double totalRevenue = _finalTotalAmount;

    _cart.forEach((key, value) {
      double costPrice = (value['costPrice'] as num).toDouble();
      double qty = (value['qty'] as num).toDouble();
      totalCost += costPrice * qty;
    });

    double profit = totalRevenue - totalCost;
    final timestamp = Timestamp.now();

    final cName = _customerNameController.text.trim();
    final cPhone = _customerPhoneController.text.trim();
    final cAddress = _customerAddressController.text.trim();
    final double currentDue = _dueAmount;
    final double paidAmount = double.tryParse(_cashPaidController.text.trim()) ?? 0.0;

    List<String> productNames = [];
    _cart.forEach((key, value) {
      productNames.add(value['name'] ?? 'Item');
    });
    String descText = 'POS Sale: ${productNames.join(", ")}';

    final saleMapData = {
      'customerName': cName,
      'customerPhone': cPhone,
      'customerAddress': cAddress,
      'paymentType': _selectedPaymentType,
      'items': _cart.map((key, value) => MapEntry(key, value)),
      'subTotal': _subTotalAmount,
      'globalDiscountPercent': _globalDiscountPercent,
      'globalDiscountTk': _globalDiscountTk,
      'totalAmount': totalRevenue,
      'cashPaid': paidAmount,
      'dueAmount': currentDue,
      'totalCost': totalCost,
      'profit': profit,
      'createdAt': timestamp,
      'staffId': widget.currentStaff != null ? widget.currentStaff!['id'] : null,
      'staffName': widget.currentStaff != null ? widget.currentStaff!['name'] : 'Admin',
    };

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final salesRef = firestore.collection('users').doc(_shopId).collection('sales').doc();
    batch.set(salesRef, saleMapData);

    for (var entry in _cart.entries) {
      String productId = entry.key;
      double soldQty = (entry.value['qty'] as num).toDouble();
      double currentStock = (entry.value['stock'] as num).toDouble();

      final productRef = firestore.collection('users').doc(_shopId).collection('products').doc(productId);
      batch.update(productRef, {'stock': currentStock - soldQty});
    }

    if (cPhone.isNotEmpty && currentDue > 0) {
      final customerQuery = await firestore
          .collection('users')
          .doc(_shopId)
          .collection('customers')
          .where('phone', isEqualTo: cPhone)
          .get();

      if (customerQuery.docs.isNotEmpty) {
        final customerDoc = customerQuery.docs.first;
        final customerRef = customerDoc.reference;

        double existingDue = (customerDoc.data()['dueAmount'] ?? 0.0).toDouble();
        double updatedDue = existingDue + currentDue;

        batch.update(customerRef, {
          'dueAmount': updatedDue,
          'name': cName.isNotEmpty ? cName : customerDoc.data()['name'],
          'address': cAddress.isNotEmpty ? cAddress : customerDoc.data()['address'],
        });

        final txnRef = customerRef.collection('transactions').doc();
        batch.set(txnRef, {
          'type': 'sale_due',
          'amount': totalRevenue,
          'paidAmount': paidAmount,
          'dueAmount': currentDue,
          'note': descText,
          'staffName': widget.currentStaff != null ? widget.currentStaff!['name'] : 'Admin',
          'date': timestamp,
        });
      } else if (cName.isNotEmpty) {
        final newCustomerRef = firestore.collection('users').doc(_shopId).collection('customers').doc();
        batch.set(newCustomerRef, {
          'name': cName,
          'phone': cPhone,
          'address': cAddress,
          'dueAmount': currentDue,
          'createdAt': timestamp,
        });

        final txnRef = newCustomerRef.collection('transactions').doc();
        batch.set(txnRef, {
          'type': 'sale_due',
          'amount': totalRevenue,
          'paidAmount': paidAmount,
          'dueAmount': currentDue,
          'note': descText,
          'staffName': widget.currentStaff != null ? widget.currentStaff!['name'] : 'Admin',
          'date': timestamp,
        });
      }
    }

    await batch.commit();

    setState(() {
      _cart.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customerAddressController.clear();
      _globalDiscountPercentController.clear();
      _globalDiscountTkController.clear();
      _cashPaidController.clear();
      _globalDiscountPercent = 0.0;
      _globalDiscountTk = 0.0;
      _isCashManuallyEdited = false;
      if (!_isDefaultPaymentType) {
        _selectedPaymentType = 'Cash';
      }
    });

    if (mounted) {
      _showSuccessPopup(saleMapData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.currentStaff != null
              ? '${AppTranslations.get('pos')} - ${widget.currentStaff!['name']}'
              : AppTranslations.get('pos'),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: AppTranslations.get('history'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SalesHistoryScreen(currentStaff: widget.currentStaff)),
              );
            },
          ),
        ],
      ),
      body: _shopId.isEmpty 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_shopId)
            .collection('products')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProducts = snapshot.data!.docs;

          Set<String> categories = {AppTranslations.get('all')};
          for (var doc in allProducts) {
            final data = doc.data() as Map<String, dynamic>;
            final cat = (data['category'] ?? '').toString().trim();
            if (cat.isNotEmpty) {
              categories.add(cat);
            }
          }

          final filteredProducts = allProducts.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final barcode = (data['barcode'] ?? '').toString().toLowerCase();
            final category = (data['category'] ?? '').toString().trim();

            final matchesSearch = name.contains(searchQuery) || barcode.contains(searchQuery);
            final matchesCategory = selectedCategory == AppTranslations.get('all') || category == selectedCategory;

            return matchesSearch && matchesCategory;
          }).toList();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                                decoration: InputDecoration(
                                  hintText: AppTranslations.get('search_product'),
                                  prefixIcon: const Icon(Icons.search, color: Color(0xFF0D47A1)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () async {
                                if (await SubscriptionUtils.isPremium()) {
                                  _openScanner(allProducts);
                                } else {
                                  if (!mounted) return;
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                                }
                              },
                              icon: Stack(
                                children: [
                                  const Icon(Icons.camera_alt, color: Colors.white),
                                  SubscriptionUtils.premiumIcon(),
                                ],
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF0D47A1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        height: 45,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: categories.map((category) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(category),
                                selected: selectedCategory == category,
                                selectedColor: const Color(0xFF0D47A1),
                                labelStyle: TextStyle(
                                  color: selectedCategory == category ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (bool selected) {
                                  setState(() {
                                    selectedCategory = category;
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 4),

                      SizedBox(
                        height: 180,
                        child: filteredProducts.isEmpty
                            ? Center(child: Text(AppTranslations.get('no_product_found')))
                            : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            var doc = filteredProducts[index];
                            var data = doc.data() as Map<String, dynamic>;

                            final double price = (data['price'] ?? 0.0) as double;
                            final double discount = (data['discount'] ?? 0.0) as double;
                            final double effectivePrice = discount > 0 ? price - ((price * discount) / 100) : price;
                            final stock = data['stock'] ?? 0;
                            final String unit = data['unit'] ?? 'Pcs';
                            final String productSize = (data['size'] ?? '').toString().trim();
                            final String? imageBase64 = data['imageBase64'] ?? data['image'];

                            return GestureDetector(
                              onTap: () => _addToCart(doc.id, data),
                              child: Container(
                                width: 140,
                                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: imageBase64 != null && imageBase64.isNotEmpty
                                              ? Image.memory(
                                            base64Decode(imageBase64),
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 70, color: Colors.grey),
                                          )
                                              : Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.shopping_bag, size: 40, color: Color(0xFF0D47A1)),
                                          ),
                                        ),
                                        if (discount > 0)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${discount.toStringAsFixed(0)}% ${AppTranslations.get('discount')}',
                                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      data['name'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        if (discount > 0)
                                          Text(
                                            '${AppTranslations.get('currency_symbol')}${price.toStringAsFixed(0)} ',
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 9,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        Text(
                                          '${AppTranslations.get('currency_symbol')} ${effectivePrice.toStringAsFixed(0)} / $unit',
                                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${AppTranslations.get('stock')}: $stock',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: stock > 0 ? Colors.grey.shade700 : Colors.red,
                                      ),
                                    ),
                                    if (productSize.isNotEmpty) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        '${AppTranslations.get('size')}: $productSize',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const Divider(height: 1),

                      ExpansionTile(
                        title: Text(AppTranslations.get('customer_info'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _customerNameController,
                                  decoration: InputDecoration(
                                    labelText: AppTranslations.get('customer_name'),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user?.uid)
                                      .collection('customers')
                                      .snapshots(),
                                  builder: (context, customerSnapshot) {
                                    List<QueryDocumentSnapshot> matchedCustomers = [];
                                    String queryText = _customerPhoneController.text.trim();

                                    if (customerSnapshot.hasData && queryText.isNotEmpty) {
                                      matchedCustomers = customerSnapshot.data!.docs.where((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final phone = (data['phone'] ?? '').toString().trim();

                                        if (phone == queryText) return true;
                                        if (phone.length >= 4 && phone.endsWith(queryText)) return true;
                                        if (phone.contains(queryText)) return true;

                                        return false;
                                      }).toList();
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextField(
                                          controller: _customerPhoneController,
                                          keyboardType: TextInputType.phone,
                                          decoration: InputDecoration(
                                            labelText: '${AppTranslations.get('customer')} ${AppTranslations.get('mobile')} (${AppTranslations.get('all')} ${AppTranslations.get('or')} ${AppTranslations.get('last')} 4 ${AppTranslations.get('digit')})',
                                            border: const OutlineInputBorder(),
                                            isDense: true,
                                            prefixIcon: const Icon(Icons.phone),
                                          ),
                                          onChanged: (val) {
                                            setState(() {});
                                          },
                                        ),
                                        if (matchedCustomers.isNotEmpty)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            constraints: const BoxConstraints(maxHeight: 150),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(color: Colors.blue.shade300),
                                              borderRadius: BorderRadius.circular(6),
                                              boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)],
                                            ),
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: matchedCustomers.length,
                                              itemBuilder: (context, index) {
                                                final cData = matchedCustomers[index].data() as Map<String, dynamic>;
                                                final name = cData['name'] ?? '';
                                                final phone = cData['phone'] ?? '';
                                                final address = cData['address'] ?? '';

                                                return ListTile(
                                                  dense: true,
                                                  title: Text('$name ($phone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  subtitle: Text(address.isNotEmpty ? address : AppTranslations.get('no_record_found')),
                                                  onTap: () {
                                                    setState(() {
                                                      _customerNameController.text = name;
                                                      _customerPhoneController.text = phone;
                                                      _customerAddressController.text = address;
                                                    });
                                                    FocusManager.instance.primaryFocus?.unfocus();
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),

                                TextField(
                                  controller: _customerAddressController,
                                  decoration: InputDecoration(
                                    labelText: '${AppTranslations.get('customer')} ${AppTranslations.get('address')} (Address)',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                        ],
                      ),

                      Container(
                        color: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppTranslations.get('cart'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                SubscriptionUtils.premiumIcon(),
                                Text(_showProfitInfo ? AppTranslations.get('hide_profit') : AppTranslations.get('show_profit'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                Switch(
                                  value: _showProfitInfo,
                                  onChanged: (val) async {
                                    if (await SubscriptionUtils.isPremium()) {
                                      setState(() {
                                        _showProfitInfo = val;
                                      });
                                    } else {
                                      if (!mounted) return;
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                                    }
                                  },
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 4),
                                Text(AppTranslations.get('qty_price_header'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      _cart.isEmpty
                          ? Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(child: Text(AppTranslations.get('no_product_in_cart'))),
                      )
                          : Column(
                        children: _cart.keys.map((productId) {
                          var item = _cart[productId]!;
                          final double originalPrice = item['originalPrice'] ?? item['price'];
                          final double singlePrice = item['price'] ?? 0.0;
                          final double costPrice = item['costPrice'] ?? 0.0;
                          final double discount = item['discount'] ?? 0.0;
                          final double discountTk = discount > 0 ? (originalPrice * discount) / 100 : 0.0;
                          final double qty = (item['qty'] ?? 1.0).toDouble();
                          final double stock = (item['stock'] ?? 0.0).toDouble();
                          final String unit = item['unit'] ?? 'Pcs';
                          final String size = item['size'] ?? '';
                          final double itemTotalPrice = singlePrice * qty;

                          final double itemTotalCost = costPrice * qty;
                          final double itemProfit = itemTotalPrice - itemTotalCost;

                          return ListTile(
                            title: Text(
                              size.isNotEmpty ? '${item['name']} (${AppTranslations.get('size')}: $size)' : item['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${AppTranslations.get('price')}: ${AppTranslations.get('currency_symbol')} ${itemTotalPrice.toStringAsFixed(1)} ($qty $unit)'),
                                if (_showProfitInfo)
                                  Text(
                                    '${AppTranslations.get('profit')}: ${AppTranslations.get('currency_symbol')} ${itemProfit.toStringAsFixed(1)}',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                InkWell(
                                  onTap: () => _editDiscountDialog(productId),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Text(
                                      discount > 0
                                          ? '${AppTranslations.get('discount')}: ${discount.toStringAsFixed(0)}% (${AppTranslations.get('currency_symbol')} ${discountTk.toStringAsFixed(1)} ${AppTranslations.get('cancel') == 'Cancel' ? 'Off' : 'ছাড়'}) [${AppTranslations.get('edit')}]'
                                          : '${AppTranslations.get('add_discount')} [+]',
                                      style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => _updateQty(productId, unit == 'Kg' || unit == 'Gram' ? -0.5 : -1.0),
                                ),
                                GestureDetector(
                                  onTap: () => _editQuantityDialog(productId, qty, stock),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('$qty $unit', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: () => _updateQty(productId, unit == 'Kg' || unit == 'Gram' ? 0.5 : 1.0),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // সম্পূর্ণ পেমেন্ট সেকশন টগল সিস্টেম (হেডারে ক্লিক করলে সম্পূর্ণ বক্সটি নিচে চলে যাবে বা হাইড হবে)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isPaymentBoxExpanded = !_isPaymentBoxExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        color: Colors.grey.shade200,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppTranslations.get('payment_info'),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Icon(
                              _isPaymentBoxExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    ),

                    AnimatedCrossFade(
                      firstChild: Container(),
                      secondChild: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppTranslations.get('payment_type_label'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    DropdownButton<String>(
                                      value: _selectedPaymentType,
                                      items: const [
                                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                        DropdownMenuItem(value: 'bKash', child: Text('bKash')),
                                        DropdownMenuItem(value: 'Card', child: Text('Card')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedPaymentType = val;
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _isDefaultPaymentType,
                                          onChanged: (val) {
                                            setState(() {
                                              _isDefaultPaymentType = val ?? false;
                                            });
                                          },
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        Text(AppTranslations.get('default'), style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${AppTranslations.get('total_amount')}:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                Text('${AppTranslations.get('currency_symbol')} ${_subTotalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),

                            Row(
                              children: [
                                Text(AppTranslations.get('discount_label'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                SubscriptionUtils.premiumIcon(),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _globalDiscountPercentController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onTap: () async {
                                        if (!(await SubscriptionUtils.isPremium())) {
                                          if (!mounted) return;
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                                        }
                                      },
                                      decoration: const InputDecoration(
                                        hintText: '%',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        double? percent = double.tryParse(val);
                                        double sub = _subTotalAmount;
                                        setState(() {
                                          if (percent != null && sub > 0) {
                                            _globalDiscountPercent = percent;
                                            _globalDiscountTk = (sub * percent) / 100;
                                            _globalDiscountTkController.text = _globalDiscountTk.toStringAsFixed(1);
                                          } else {
                                            _globalDiscountPercent = 0.0;
                                            _globalDiscountTk = 0.0;
                                            _globalDiscountTkController.text = '';
                                          }
                                          if (!_isCashManuallyEdited) {
                                            _cashPaidController.text = _finalTotalAmount.toStringAsFixed(2);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _globalDiscountTkController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onTap: () async {
                                        if (!(await SubscriptionUtils.isPremium())) {
                                          if (!mounted) return;
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                                        }
                                      },
                                      decoration: InputDecoration(
                                        hintText: AppTranslations.get('currency_symbol'),
                                        border: const OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        double? tk = double.tryParse(val);
                                        double sub = _subTotalAmount;
                                        setState(() {
                                          if (tk != null && sub > 0) {
                                            _globalDiscountTk = tk;
                                            _globalDiscountPercent = (tk / sub) * 100;
                                            _globalDiscountPercentController.text = _globalDiscountPercent.toStringAsFixed(1);
                                          } else {
                                            _globalDiscountTk = 0.0;
                                            _globalDiscountPercent = 0.0;
                                            _globalDiscountPercentController.text = '';
                                          }
                                          if (!_isCashManuallyEdited) {
                                            _cashPaidController.text = _finalTotalAmount.toStringAsFixed(2);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            Row(
                              children: [
                                Text('${AppTranslations.get('cash')}:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 28),
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _cashPaidController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        hintText: AppTranslations.get('enter_cash_paid'),
                                        border: const OutlineInputBorder(),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _isCashManuallyEdited = true;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${AppTranslations.get('due')}:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                                Text('${AppTranslations.get('currency_symbol')} ${_dueAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                              ],
                            ),
                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: _cart.isEmpty ? null : _showConfirmationDialog,
                                child: Text(AppTranslations.get('confirm_sale'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: _isPaymentBoxExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ],
                ),
              ),
            ],
          );

        },
      ),
    );
  }
}

class SalesHistoryScreen extends StatefulWidget {
  final Map<String, dynamic>? currentStaff;

  const SalesHistoryScreen({super.key, this.currentStaff});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  String historySearchQuery = '';
  String _shopId = '';

  @override
  void initState() {
    super.initState();
    _loadShopId();
  }

  Future<void> _loadShopId() async {
    _shopId = await ShopUtils.getShopId();
    if (mounted) setState(() {});
  }

  void _verifyPinAndDelete(String saleDocId) async {
    if (_shopId.isEmpty) return;

    final TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('delete_confirm_title')),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: AppTranslations.get('login_pin'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              String enteredPin = pinController.text.trim();
              if (enteredPin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppTranslations.get('please_enter_pin')), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(_shopId).get();
                if (userDoc.exists) {
                  final data = userDoc.data();

                  String savedPin = '';
                  if (widget.currentStaff != null) {
                    savedPin = (widget.currentStaff!['pin'] ?? '').toString();
                  } else {
                    savedPin = (data?['pin'] ?? data?['userPin'] ?? '').toString();
                  }

                  if (savedPin.isNotEmpty && savedPin == enteredPin) {
                    Navigator.pop(context);

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_shopId)
                        .collection('sales')
                        .doc(saleDocId)
                        .delete();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppTranslations.get('sale_updated_msg')), backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppTranslations.get('wrong_pin')), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${AppTranslations.get('error_occurred')} $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(AppTranslations.get('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get('sales_history'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (val) => setState(() => historySearchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: AppTranslations.get('search_customer_hint'),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0D47A1)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _shopId.isEmpty 
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_shopId)
                  .collection('sales')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('কোনো বিক্রির ইতিহাস পাওয়া যায়নি।'));
                }

                final docs = snapshot.data!.docs;

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final customerName = (data['customerName'] ?? '').toString().toLowerCase();
                  final customerPhone = (data['customerPhone'] ?? '').toString().toLowerCase();
                  return customerName.contains(historySearchQuery) || customerPhone.contains(historySearchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('মিলিসম্পন্ন কোনো ইতিহাস পাওয়া যায়নি'));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final customerName = data['customerName'] ?? 'সাধারণ কাস্টমার';
                    final customerPhone = data['customerPhone'] ?? '';
                    final totalAmount = data['totalAmount'] ?? 0.0;
                    final paymentType = data['paymentType'] ?? 'Cash';
                    final staffName = data['staffName'] ?? 'Admin';
                    final items = data['items'] as Map<String, dynamic>? ?? {};

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: ListTile(
                        title: Text(
                          customerName.isEmpty ? 'সাধারণ কাস্টমার' : customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${customerPhone.isNotEmpty ? 'মোবাইল: $customerPhone\n' : ''}পেমেন্ট টাইপ: $paymentType\nবিক্রেতা: $staffName\nপণ্য সংখ্যা: ${items.length} টি\nমোট বিল: Tk $totalAmount',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FutureBuilder<bool>(
                              future: SubscriptionUtils.isPremium(),
                              builder: (context, snapshot) {
                                bool isPremium = snapshot.data ?? true;
                                if (isPremium) {
                                  return Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.share, color: Colors.orange, size: 22),
                                        tooltip: 'শেয়ার করুন',
                                        onPressed: () {
                                          _processReceipt(data, isPrint: false);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.print, color: Color(0xFF0D47A1), size: 22),
                                        tooltip: 'প্রিন্ট করুন',
                                        onPressed: () {
                                          _processReceipt(data, isPrint: true);
                                        },
                                      ),
                                    ],
                                  );
                                } else {
                                  return IconButton(
                                    icon: const Icon(Icons.play_circle_fill, color: Colors.orange, size: 22),
                                    onPressed: () {
                                      _showAdUnlockInHistory(data);
                                    },
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 22),
                              tooltip: 'ডিলিট করুন',
                              onPressed: () {
                                _verifyPinAndDelete(doc.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAdUnlockInHistory(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('watch_ad')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppTranslations.get('watch_ad_to_unlock')),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            const Text('Loading Ad...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context);
      _processReceipt(data, isPrint: false);
    });
  }

  static void _processReceipt(Map<String, dynamic> data, {required bool isPrint}) async {
    String shopId = await ShopUtils.getShopId();
    if (shopId.isEmpty) return;

    String shopName = 'SHOP NAME';
    String address = 'Address: Not Provided';
    String phone = '0000000000';

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(shopId).get();
      if (userDoc.exists) {
        final d = userDoc.data();
        if (d != null) {
          shopName = d['shopName'] ?? d['storeName'] ?? 'SHOP NAME';
          address = d['address'] ?? 'Address: Not Provided';
          phone = d['phone'] ?? d['mobile'] ?? '0000000000';
        }
      }
    } catch (_) {}

    final pdf = pw.Document();

    pw.Font? banglaFontRegular;
    pw.Font? banglaFontBold;
    try {
      final regData = await rootBundle.load("assets/fonts/SolaimanLipi-Normal.ttf");
      banglaFontRegular = pw.Font.ttf(regData);

      final boldData = await rootBundle.load("assets/fonts/SolaimanLipi-Bold.ttf");
      banglaFontBold = pw.Font.ttf(boldData);
    } catch (_) {
      try {
        final fontData = await rootBundle.load("assets/fonts/SolaimanLipi-Thin.ttf");
        banglaFontRegular = pw.Font.ttf(fontData);
        banglaFontBold = pw.Font.ttf(fontData);
      } catch (_) {}
    }

    final tTheme = banglaFontRegular != null
        ? pw.ThemeData.withFont(base: banglaFontRegular, bold: banglaFontBold ?? banglaFontRegular)
        : null;

    String formattedDateTime = '';
    if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
      DateTime dt = (data['createdAt'] as Timestamp).toDate();
      int hour12 = dt.hour % 12;
      if (hour12 == 0) hour12 = 12;
      String period = dt.hour >= 12 ? 'PM' : 'AM';
      formattedDateTime = '${dt.day}/${dt.month}/${dt.year} $hour12:${dt.minute.toString().padLeft(2, '0')} $period';
    } else {
      DateTime now = DateTime.now();
      int hour12 = now.hour % 12;
      if (hour12 == 0) hour12 = 12;
      String period = now.hour >= 12 ? 'PM' : 'AM';
      formattedDateTime = '${now.day}/${now.month}/${now.year} $hour12:${now.minute.toString().padLeft(2, '0')} $period';
    }

    final customerName = data['customerName'] ?? '';
    final customerPhone = data['customerPhone'] ?? '';
    final customerAddress = data['customerAddress'] ?? '';
    final paymentType = data['paymentType'] ?? 'Cash';
    final subTotal = data['subTotal'] ?? 0.0;
    final totalAmount = data['totalAmount'] ?? 0.0;
    final discountPercent = data['globalDiscountPercent'] ?? 0.0;
    final discountTk = data['globalDiscountTk'] ?? 0.0;
    final cashPaid = data['cashPaid'] ?? 0.0;
    final dueAmount = data['dueAmount'] ?? 0.0;
    final staffName = data['staffName'] ?? 'Admin';
    final items = data['items'] as Map<String, dynamic>? ?? {};

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 8 * PdfPageFormat.mm),
        theme: tTheme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(shopName, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(address, style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Telp. $phone', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 6),

              if (customerName.isNotEmpty || customerPhone.isNotEmpty || customerAddress.isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (customerName.isNotEmpty)
                        pw.Text('Customer: $customerName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      if (customerPhone.isNotEmpty)
                        pw.Text('Mobile: $customerPhone', style: const pw.TextStyle(fontSize: 8)),
                      if (customerAddress.isNotEmpty)
                        pw.Text('Address: $customerAddress', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
              ],

              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),

              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('CASH RECEIPT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      formattedDateTime,
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Type:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(paymentType, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sold By:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text(staffName == 'Admin' ? 'Admin' : 'Staff: $staffName', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Description', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Discount', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),

              ...items.entries.map((entry) {
                final item = entry.value;
                final name = item['name'] ?? '';
                final originalPrice = item['originalPrice'] ?? item['price'] ?? 0.0;
                final singlePrice = item['price'] ?? 0.0;
                final discount = item['discount'] ?? 0.0;
                final itemDiscountTk = discount > 0 ? (originalPrice * discount) / 100 : 0.0;
                final double qty = (item['qty'] ?? 1.0).toDouble();
                final unit = item['unit'] ?? 'Pcs';
                final size = item['size'] ?? '';
                final totalPrice = singlePrice * qty;

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              name,
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              discount > 0 ? '${discount.toStringAsFixed(0)}% (${itemDiscountTk.toStringAsFixed(0)}tk)' : '-',
                              textAlign: pw.TextAlign.center,
                              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              totalPrice.toStringAsFixed(2),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            size.isNotEmpty ? 'Qty: $qty $unit | Size: $size' : 'Qty: $qty $unit',
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(subTotal.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              if (discountTk > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cart Discount', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('${discountPercent.toStringAsFixed(1)}% (-${discountTk.toStringAsFixed(2)})', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Amount', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(totalAmount.toStringAsFixed(2), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 1),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Paid', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(cashPaid.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Due', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(dueAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.Text('****************************************', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('THANK YOU!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 6),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: List.generate(24, (index) => pw.Container(
                  width: index % 2 == 0 ? 2 : 4,
                  height: 20,
                  color: PdfColors.black,
                  margin: const pw.EdgeInsets.symmetric(horizontal: 1),
                )),
              ),
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
}