import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/translations.dart';
import '../widgets/custom_banner_ad.dart';
import '../utils/shop_utils.dart';
import '../utils/subscription_utils.dart';
import 'subscription_screen.dart';

class CustomerScreen extends StatefulWidget {
  final String? customerId;
  final String? customerName;
  final String? customerPhone;

  const CustomerScreen({
    super.key,
    this.customerId,
    this.customerName,
    this.customerPhone,
  });

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String searchQuery = '';
  bool _isLoading = false;

  // সিলেকশন মোড ভ্যারিয়েবল
  bool _isSelectionMode = false;
  final Set<String> _selectedCustomerIds = {};
  final Set<String> _selectedCustomerPhones = {};

  // স্টাফ পারমিশন এবং শপ আইডি সম্পর্কিত ভ্যারিয়েবল
  bool _hasPermission = true;
  bool _isCheckingPermission = true;
  String shopId = '';

  @override
  void initState() {
    super.initState();
    shopId = user?.uid ?? '';
    _initializeShopIdAndPermissions();
  }

  Future<void> _initializeShopIdAndPermissions() async {
    try {
      shopId = await ShopUtils.getShopId();
      
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String role = prefs.getString('role') ?? 'admin';

      if (role == 'staff') {
        // পারমিশন চেক করা
        bool staffCustomerPerm = prefs.getBool('can_customer') ?? prefs.getBool('customer') ?? true;

        try {
          DocumentSnapshot staffDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(shopId)
              .collection('staffs')
              .doc(user?.uid)
              .get();

          if (staffDoc.exists) {
            var sData = staffDoc.data() as Map<String, dynamic>?;
            var permissions = sData?['permissions'] as Map<String, dynamic>?;
            if (permissions != null) {
              staffCustomerPerm = permissions['customer'] ?? permissions['can_customer'] ?? true;
            }
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _hasPermission = staffCustomerPerm;
            _isCheckingPermission = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasPermission = true;
            _isCheckingPermission = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
    }
  }

  // নির্দিষ্ট তারিখের হিসাব দেখার জন্য স্টেট ভ্যারিয়েবল
  DateTime? _selectedReportDate;

  // সেফ ডেট পার্সিং ফাংশন (স্ট্রিং বা Timestamp যাই হোক ক্র্যাশ করবে না)
  Timestamp? _parseDate(dynamic value) {
    if (value is Timestamp) return value;
    if (value is String) {
      DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return null;
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTranslations.get('add_customer'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: AppTranslations.get('customer_name'), border: const OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: AppTranslations.get('mobile'), border: const OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: InputDecoration(labelText: AppTranslations.get('address_label'), border: const OutlineInputBorder(), isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('name_required_msg'))));
                return;
              }

              if (shopId.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(shopId)
                    .collection('customers')
                    .add({
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'address': addressController.text.trim(),
                  'dueAmount': 0.0,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('customer_added_msg'))));
              }
            },
            child: Text(AppTranslations.get('save')),
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(Map<String, dynamic> customerData) {
    final nameController = TextEditingController(text: customerData['name'] ?? '');
    final phoneController = TextEditingController(text: customerData['phone'] ?? '');
    final addressController = TextEditingController(text: customerData['address'] ?? '');
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTranslations.get('edit_customer_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: AppTranslations.get('customer_name'), border: const OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: AppTranslations.get('mobile'), border: const OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                decoration: InputDecoration(labelText: AppTranslations.get('address_label'), border: const OutlineInputBorder(), isDense: true),
              ),
              const Divider(height: 20),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: AppTranslations.get('enter_pin_to_confirm'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
            onPressed: () async {
              String enteredPin = pinController.text.trim();
              if (enteredPin.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('please_enter_pin'))));
                return;
              }

              try {
                DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(shopId).get();
                if (!mounted) return;
                if (userDoc.exists) {
                  var uData = userDoc.data() as Map<String, dynamic>?;
                  String savedPin = uData?['pin'] ?? '';

                  if (savedPin == enteredPin) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(shopId)
                        .collection('customers')
                        .doc(widget.customerId)
                        .update({
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'address': addressController.text.trim(),
                    });

                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('customer_updated_msg'))));
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('wrong_pin'))));
                  }
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(AppTranslations.get('update')),
          ),
        ],
      ),
    );
  }

  void _showDeletePinDialog(String customerId) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTranslations.get('security_pin'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppTranslations.get('delete_customer_msg')),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: AppTranslations.get('login_pin'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              String enteredPin = pinController.text.trim();
              if (enteredPin.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('please_enter_pin'))));
                return;
              }

              try {
                DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(shopId).get();
                if (!mounted) return;
                if (userDoc.exists) {
                  var data = userDoc.data() as Map<String, dynamic>?;
                  String savedPin = data?['pin'] ?? '';

                  if (savedPin == enteredPin) {
                    Navigator.pop(dialogContext);

                    var transQuery = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(shopId)
                        .collection('customers')
                        .doc(customerId)
                        .collection('transactions')
                        .get();

                    for (var doc in transQuery.docs) {
                      await doc.reference.delete();
                    }

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(shopId)
                        .collection('customers')
                        .doc(customerId)
                        .delete();

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('customer_deleted_success'))));
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('wrong_pin'))));
                  }
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(AppTranslations.get('delete')),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(String customerId, double currentDue, String type) {
    final amountController = TextEditingController();
    final paidAmountController = TextEditingController();
    final noteController = TextEditingController();
    bool isJama = type == 'jama';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isJama ? AppTranslations.get('take_jama') : AppTranslations.get('new_due_sale'),
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isJama ? Colors.green.shade700 : Colors.red.shade700
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: isJama ? AppTranslations.get('jama_amount_tk') : AppTranslations.get('total_product_price_tk'),
                    border: const OutlineInputBorder(),
                    isDense: true
                ),
              ),
              if (!isJama) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: paidAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: AppTranslations.get('cash_paid_if_any'),
                      border: const OutlineInputBorder(),
                      isDense: true
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(labelText: AppTranslations.get('memo_no_desc'), border: const OutlineInputBorder(), isDense: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () {
                Navigator.pop(dialogContext);
              },
              child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: isJama ? Colors.green.shade700 : Colors.red.shade700,
                  foregroundColor: Colors.white
              ),
              onPressed: _isLoading ? null : () async {
                double amount = double.tryParse(amountController.text) ?? 0.0;
                double paidAmount = double.tryParse(paidAmountController.text) ?? 0.0;

                if (amount <= 0) {
                  return;
                }

                setDialogState(() => _isLoading = true);

                try {
                  double newDue;
                  if (isJama) {
                    newDue = currentDue - amount;
                  } else {
                    double remainingDue = amount - paidAmount;
                    newDue = currentDue + remainingDue;
                  }

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(shopId)
                      .collection('customers')
                      .doc(customerId)
                      .update({'dueAmount': newDue});

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(shopId)
                      .collection('customers')
                      .doc(widget.customerId!)
                      .collection('transactions')
                      .add({
                    'type': isJama ? AppTranslations.get('jama') : AppTranslations.get('due'),
                    'amount': amount,
                    'paidAmount': isJama ? amount : paidAmount,
                    'balance': newDue,
                    'previousDueBeforeTx': currentDue,
                    'note': noteController.text.trim(),
                    'date': FieldValue.serverTimestamp(),
                  });

                  if (!mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('transaction_saved_msg'))));
                } finally {
                  if (mounted) {
                    setDialogState(() => _isLoading = false);
                  }
                }
              },
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(AppTranslations.get('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportFilterDialog(Map<String, dynamic> customerData) async {
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(AppTranslations.get('select_report_range'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('${AppTranslations.get('start_date')}: ${DateFormat('dd MMM yyyy').format(startDate)}'),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() => startDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    title: Text('${AppTranslations.get('end_date')}: ${DateFormat('dd MMM yyyy').format(endDate)}'),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() => endDate = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _generateShopStylePdf(
                      customerData: customerData,
                      startDate: DateTime(startDate.year, startDate.month, startDate.day),
                      endDate: DateTime(endDate.year, endDate.month, endDate.day),
                    );
                  },
                  child: Text(AppTranslations.get('download_share_pdf')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateSingleTransactionPdf(Map<String, dynamic> customerData, Map<String, dynamic> tData) async {
    final pdf = pw.Document();

    pw.Font banglaFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/SolaimanLipi.ttf');
      banglaFont = pw.Font.ttf(fontData);
    } catch (_) {
      banglaFont = await PdfGoogleFonts.notoSansBengaliRegular();
    }

    String shopName = 'Al-Madina Store';
    String shopAddress = '';
    String shopPhone = '';
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(shopId).get();
      if (userDoc.exists) {
        var uData = userDoc.data() as Map<String, dynamic>?;
        if (uData != null) {
          shopName = uData['shopName'] ?? uData['storeName'] ?? uData['name'] ?? 'Al-Madina Store';
          shopAddress = uData['shopAddress'] ?? uData['address'] ?? '';
          shopPhone = uData['phone'] ?? uData['mobile'] ?? '';
        }
      }
    } catch (_) {}

    String type = tData['type'] ?? '';
    bool isJama = (type == 'জমা');

    double amount = (tData['amount'] as num?)?.toDouble() ?? 0.0;
    double paidAmount = (tData['paidAmount'] as num?)?.toDouble() ?? 0.0;
    double dbBalance = (tData['balance'] as num?)?.toDouble() ?? 0.0;
    double prevDue = (tData['previousDueBeforeTx'] as num?)?.toDouble() ?? 0.0;

    String rawNote = (tData['note'] ?? '').toString();
    String descriptionText = rawNote.replaceAll(RegExp(r'POS\s*Sale\s*[:\-]*', caseSensitive: false), '').trim();

    Timestamp? ts = _parseDate(tData['date']);
    String dateStr = ts != null ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate()) : '';

    if (isJama) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(shopName, style: pw.TextStyle(font: banglaFont, fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      if (shopAddress.isNotEmpty) pw.Text(shopAddress, style: pw.TextStyle(font: banglaFont, fontSize: 11, color: PdfColors.grey700)),
                      if (shopPhone.isNotEmpty) pw.Text('Phone: $shopPhone', style: pw.TextStyle(font: banglaFont, fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Divider(thickness: 1.2, color: PdfColors.grey400),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Payment Receipt',
                    style: pw.TextStyle(font: banglaFont, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Customer: ${customerData['name'] ?? ''}', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Phone: ${customerData['phone'] ?? ''}', style: pw.TextStyle(font: banglaFont)),
                        pw.Text('Date: $dateStr', style: pw.TextStyle(font: banglaFont)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Type: Payment', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Description:', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text(descriptionText.isNotEmpty ? descriptionText : 'Cash Payment', style: pw.TextStyle(font: banglaFont, fontSize: 12)),
                      pw.Divider(height: 20),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Previous Due:', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Tk $prevDue', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Payment Given:', style: pw.TextStyle(font: banglaFont)),
                          pw.Text('Tk $amount', style: pw.TextStyle(font: banglaFont)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Current Balance Due:', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Tk $dbBalance', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else {
      // বিক্রয়ের ক্ষেত্রে হিসাব: 
      // ১. Total Price = যদি 'totalAmount' থাকে তবে সেটি, না থাকলে 'amount' + 'paidAmount'
      // ২. Payment = 'paidAmount'
      // ৩. Balance Due = 'dueAmount' বা 'balance'
      
      double totalProductPrice = (tData['totalAmount'] as num?)?.toDouble() ?? (amount + paidAmount);
      double paymentReceived = paidAmount;
      double balanceDue = (tData['dueAmount'] as num?)?.toDouble() ?? (tData['balance'] as num?)?.toDouble() ?? 0.0;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(shopName, style: pw.TextStyle(font: banglaFont, fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      if (shopAddress.isNotEmpty) pw.Text(shopAddress, style: pw.TextStyle(font: banglaFont, fontSize: 11, color: PdfColors.grey700)),
                      if (shopPhone.isNotEmpty) pw.Text('Phone: $shopPhone', style: pw.TextStyle(font: banglaFont, fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Divider(thickness: 1.2, color: PdfColors.grey400),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Memo Receipt',
                    style: pw.TextStyle(font: banglaFont, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Customer: ${customerData['name'] ?? ''}', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Phone: ${customerData['phone'] ?? ''}', style: pw.TextStyle(font: banglaFont)),
                        pw.Text('Date: $dateStr', style: pw.TextStyle(font: banglaFont)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Type: Sale Due', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Purchased Items / Description:', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text(descriptionText.isNotEmpty ? descriptionText : 'N/A', style: pw.TextStyle(font: banglaFont, fontSize: 12)),
                      pw.Divider(height: 20),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Price:', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Tk $totalProductPrice', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Payment:', style: pw.TextStyle(font: banglaFont)),
                          pw.Text('Tk $paymentReceived', style: pw.TextStyle(font: banglaFont)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Balance Due:', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Tk $balanceDue', style: pw.TextStyle(font: banglaFont, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                        ],
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

    await Printing.sharePdf(bytes: await pdf.save(), filename: isJama ? 'payment_receipt.pdf' : 'transaction_receipt.pdf');
  }

  Future<void> _generateShopStylePdf({
    required Map<String, dynamic> customerData,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();

    pw.Font banglaFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/SolaimanLipi.ttf');
      banglaFont = pw.Font.ttf(fontData);
    } catch (_) {
      banglaFont = await PdfGoogleFonts.notoSansBengaliRegular();
    }

    String shopName = 'Al-Madina Store';
    String shopAddress = '';
    String shopPhone = '';
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(shopId).get();
      if (userDoc.exists) {
        var uData = userDoc.data() as Map<String, dynamic>?;
        if (uData != null) {
          shopName = uData['shopName'] ?? uData['storeName'] ?? uData['name'] ?? 'Al-Madina Store';
          shopAddress = uData['shopAddress'] ?? uData['address'] ?? '';
          shopPhone = uData['phone'] ?? uData['mobile'] ?? '';
        }
      }
    } catch (_) {}

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(shopId)
        .collection('customers')
        .doc(widget.customerId)
        .collection('transactions')
        .orderBy('date', descending: false)
        .get();

    double totalBaki = 0;
    double totalJama = 0;

    List<QueryDocumentSnapshot> filteredDocs = [];
    Map<String, Map<String, double>> dailySummary = {};

    for (var doc in querySnapshot.docs) {
      var t = doc.data() as Map<String, dynamic>;
      Timestamp? ts = _parseDate(t['date']);
      if (ts != null) {
        DateTime tDate = ts.toDate();
        DateTime cleanTDate = DateTime(tDate.year, tDate.month, tDate.day);
        DateTime cleanStartDate = DateTime(startDate.year, startDate.month, startDate.day);
        DateTime cleanEndDate = DateTime(endDate.year, endDate.month, endDate.day);

        if ((cleanTDate.isAtSameMomentAs(cleanStartDate) || cleanTDate.isAfter(cleanStartDate)) &&
            (cleanTDate.isAtSameMomentAs(cleanEndDate) || cleanTDate.isBefore(cleanEndDate))) {

          filteredDocs.add(doc);

          String type = (t['type'] ?? '').toString();
          double amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
          double paidAmount = (t['paidAmount'] as num?)?.toDouble() ?? 0.0;

          bool isBakiTransaction = type == 'sale_due' || type == 'বাকি' || type == 'baki' || type == 'Sale';

          if (isBakiTransaction) {
            totalBaki += amount;
            totalJama += paidAmount;
          } else {
            totalJama += amount;
          }

          String dateKey = DateFormat('dd MMM yyyy').format(tDate);
          dailySummary.putIfAbsent(dateKey, () => {'baki': 0.0, 'jama': 0.0});

          if (isBakiTransaction) {
            dailySummary[dateKey]!['baki'] = dailySummary[dateKey]!['baki']! + amount;
            dailySummary[dateKey]!['jama'] = dailySummary[dateKey]!['jama']! + paidAmount;
          } else {
            dailySummary[dateKey]!['jama'] = dailySummary[dateKey]!['jama']! + amount;
          }
        }
      }
    }

    String generationDateTime = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    shopName,
                    style: pw.TextStyle(
                      font: banglaFont,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  if (shopAddress.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(shopAddress, style: pw.TextStyle(font: banglaFont, fontSize: 11, color: PdfColors.grey700)),
                  ],
                  if (shopPhone.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('Phone: $shopPhone', style: pw.TextStyle(font: banglaFont, fontSize: 10, color: PdfColors.grey700)),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1.2, color: PdfColors.grey400),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${customerData['name'] ?? ''} - Party Statement', style: pw.TextStyle(font: banglaFont, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Phone: ${customerData['phone'] ?? ''}', style: pw.TextStyle(font: banglaFont, fontSize: 10)),
                    pw.Text('Address: ${customerData['address'] ?? 'N/A'}', style: pw.TextStyle(font: banglaFont, fontSize: 10)),
                    pw.Text('Period: ${DateFormat('dd/MM/yyyy').format(startDate)} to ${DateFormat('dd/MM/yyyy').format(endDate)}', style: pw.TextStyle(font: banglaFont, fontSize: 9)),
                    pw.Text('Generated: $generationDateTime', style: pw.TextStyle(font: banglaFont, fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  width: 190,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(4)),
                  child: pw.Column(
                    children: [
                      _pdfSummaryRow('Total Amount:', 'Tk $totalBaki', banglaFont),
                      _pdfSummaryRow('Payment:', 'Tk $totalJama', banglaFont),
                      pw.Divider(height: 6),
                      _pdfSummaryRow('Balance Due:', 'Tk ${customerData['dueAmount'] ?? 0.0}', banglaFont, isBold: true),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'Transaction History',
                style: pw.TextStyle(font: banglaFont, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              color: PdfColors.grey200,
              child: pw.Row(
                children: [
                  pw.Expanded(flex: 2, child: pw.Text('Date & Time', style: pw.TextStyle(font: banglaFont, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('Description', style: pw.TextStyle(font: banglaFont, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Total Price', style: pw.TextStyle(font: banglaFont, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 2, child: pw.Text('Payment', style: pw.TextStyle(font: banglaFont, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 2, child: pw.Text('Balance Due', style: pw.TextStyle(font: banglaFont, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
            ),
            ...filteredDocs.map((doc) {
              var t = doc.data() as Map<String, dynamic>;
              String type = (t['type'] ?? '').toString();
              double amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
              double paidAmount = (t['paidAmount'] as num?)?.toDouble() ?? 0.0;
              double txBalance = (t['balance'] ?? t['dueAmount'] as num?)?.toDouble() ?? 0.0;

              String rawNote = (t['note'] ?? '').toString();
              String descriptionText = rawNote
                  .replaceAll(RegExp(r'POS\s*Sale\s*[:\-]*', caseSensitive: false), '')
                  .trim();

              Timestamp? ts = _parseDate(t['date']);
              String tDateTime = ts != null ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate()) : '';

              bool isBakiTransaction = type == 'sale_due' || type == 'বাকি' || type == 'baki' || type == 'Sale';

              String totalPriceStr = isBakiTransaction ? 'Tk $amount' : '--';
              String paymentStr = isBakiTransaction ? 'Tk $paidAmount' : 'Tk $amount';

              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 2, child: pw.Text(tDateTime, style: pw.TextStyle(font: banglaFont, fontSize: 8))),
                    pw.Expanded(flex: 3, child: pw.Text(descriptionText, style: pw.TextStyle(font: banglaFont, fontSize: 8))),
                    pw.Expanded(flex: 2, child: pw.Text(totalPriceStr, style: pw.TextStyle(font: banglaFont, fontSize: 8), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text(paymentStr, style: pw.TextStyle(font: banglaFont, fontSize: 8), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text('Tk $txBalance', style: pw.TextStyle(font: banglaFont, fontSize: 8), textAlign: pw.TextAlign.right)),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 25),
            pw.Text('Daily Summary Report', style: pw.TextStyle(font: banglaFont, fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              color: PdfColors.grey200,
              child: pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Date', style: pw.TextStyle(font: banglaFont, fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('Total Price Added', style: pw.TextStyle(font: banglaFont, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 3, child: pw.Text('Total Payment Given', style: pw.TextStyle(font: banglaFont, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
            ),
            ...dailySummary.entries.map((entry) {
              String dateKeyStr = entry.key;
              double dDue = entry.value['baki'] ?? 0.0;
              double dJama = entry.value['jama'] ?? 0.0;

              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text(dateKeyStr, style: pw.TextStyle(font: banglaFont, fontSize: 9))),
                    pw.Expanded(flex: 3, child: pw.Text('Tk $dDue', style: pw.TextStyle(font: banglaFont, fontSize: 9), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 3, child: pw.Text('Tk $dJama', style: pw.TextStyle(font: banglaFont, fontSize: 9), textAlign: pw.TextAlign.right)),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'statement_${customerData['name']}.pdf');
  }

  void _toggleSelection(String id, String phone) {
    setState(() {
      if (_selectedCustomerIds.contains(id)) {
        _selectedCustomerIds.remove(id);
        _selectedCustomerPhones.remove(phone);
      } else {
        _selectedCustomerIds.add(id);
        _selectedCustomerPhones.add(phone);
      }
      if (_selectedCustomerIds.isEmpty) _isSelectionMode = false;
    });
  }

  void _showMarketingDialog() {
    final messageController = TextEditingController(text: AppTranslations.currentLanguage == 'bn' ? 'প্রিয় কাস্টমার, আমাদের দোকানে আপনাকে স্বাগতম!' : 'Dear Customer, welcome to our shop!');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('marketing')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${AppTranslations.get('selected')}: ${_selectedCustomerIds.length} ${AppTranslations.get('person_count')}'),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: AppTranslations.get('write_message_hint'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 16, color: Colors.white),
            label: Text(AppTranslations.get('send_sms_btn'), style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
            onPressed: () {
              Navigator.pop(context);
              _sendBulkMessages(messageController.text, isWhatsApp: false);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.chat, size: 16, color: Colors.white),
            label: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () {
              Navigator.pop(context);
              _sendBulkMessages(messageController.text, isWhatsApp: true);
            },
          ),
        ],
      ),
    );
  }

  void _sendBulkMessages(String message, {required bool isWhatsApp}) async {
    for (String phone in _selectedCustomerPhones) {
      if (phone.isEmpty) continue;
      
      Uri uri;
      if (isWhatsApp) {
        uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
      } else {
        uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // কাস্টমারদের মধ্যে কিছুটা গ্যাপ রাখার জন্য ছোট ডিলে (অপশনাল)
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('msg_process_started'))));
      setState(() {
        _isSelectionMode = false;
        _selectedCustomerIds.clear();
        _selectedCustomerPhones.clear();
      });
    }
  }

  pw.Widget _pdfSummaryRow(String title, String value, pw.Font font, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  void _sendSms(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'sms', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  void _sendDueReminder(String phoneNumber, String customerName, double dueAmount) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('কাস্টমারের মোবাইল নম্বর পাওয়া যায়নি!')));
      return;
    }
    String message = 'প্রিয় $customerName, আপনার নিকট আমাদের দোকানের বকেয়া মোট ৳$dueAmount টাকা। দয়া করে বকেয়া পরিশোধ করার সুব্যবস্থা করুন। ধন্যবাদ।';
    final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber, queryParameters: {'body': message});
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('রিমাইন্ডার পাঠানোর মতো কোনো অ্যাপ পাওয়া যায়নি!')));
      }
    }
  }

  void _sendInvitation(String phoneNumber, String customerName) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('কাস্টমারের মোবাইল নম্বর পাওয়া যায়নি!')));
      return;
    }
    String message = 'প্রিয় $customerName, আমাদের দোকানে আপনাকে স্বাগতম! আমাদের নতুন অফার এবং সেবাসমূহ উপভোগ করতে আমাদের দোকানে আসার আমন্ত্রণ রইল।';
    final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber, queryParameters: {'body': message});
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('আমন্ত্রণ পাঠানোর মতো কোনো অ্যাপ পাওয়া যায়নি!')));
      }
    }
  }

  Widget _buildTopActionIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: const Color(0xFF0D47A1), size: 20),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermission) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppTranslations.get('customer_list'), style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF0D47A1),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              AppTranslations.get('no_permission'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    if (widget.customerId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
              _isSelectionMode 
                  ? '${_selectedCustomerIds.length} ${AppTranslations.get('selected') ?? 'Selected'}'
                  : AppTranslations.get('customer_list'), 
              style: const TextStyle(color: Colors.white)
          ),
          backgroundColor: _isSelectionMode ? Colors.blueGrey.shade800 : const Color(0xFF0D47A1),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.mark_as_unread_rounded),
                onPressed: _showMarketingDialog,
                tooltip: AppTranslations.get('marketing'),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedCustomerIds.clear();
                    _selectedCustomerPhones.clear();
                  });
                },
              ),
            ]
          ],
        ),
        body: Column(
          children: [
            const CustomBannerAd(),
            if (!_isSelectionMode) ...[
              StreamBuilder<QuerySnapshot>(
              key: const ValueKey('customer_summary_stable_box'),
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(shopId)
                  .collection('customers')
                  .snapshots(),
              builder: (context, customerSnapshot) {
                if (!customerSnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('transactions')
                      .snapshots(),
                  builder: (context, transSnapshot) {
                    double todayTotalBaki = 0.0;
                    double todayTotalJama = 0.0;

                    if (transSnapshot.hasData) {
                      DateTime now = DateTime.now();
                      DateTime todayStart = DateTime(now.year, now.month, now.day);

                      for (var doc in transSnapshot.data!.docs) {
                        var tData = doc.data() as Map<String, dynamic>;
                        Timestamp? ts = _parseDate(tData['date']);

                        if (ts != null) {
                          DateTime tDate = ts.toDate();
                          if (tDate.isAfter(todayStart) || tDate.isAtSameMomentAs(todayStart)) {
                            String type = tData['type'] ?? '';
                            double amount = (tData['amount'] as num?)?.toDouble() ?? 0.0;
                            double paidAmount = (tData['paidAmount'] as num?)?.toDouble() ?? 0.0;

                            if (type == 'বাকি' || type == 'sale_due' || type == 'baki') {
                              todayTotalBaki += amount;
                              todayTotalJama += paidAmount;
                            } else if (type == 'জমা') {
                              todayTotalJama += amount;
                            }
                          }
                        }
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(AppTranslations.get('today_total_baki'), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${AppTranslations.get('currency_symbol')} $todayTotalBaki', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                            ],
                          ),
                          Container(height: 30, width: 1, color: Colors.blue.shade200),
                          Column(
                            children: [
                              Text(AppTranslations.get('today_total_jama'), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${AppTranslations.get('currency_symbol')} $todayTotalJama', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedReportDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            _selectedReportDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedReportDate == null
                                  ? AppTranslations.get('select_date_calendar')
                                  : '${AppTranslations.get('date')}: ${DateFormat('dd MMM yyyy').format(_selectedReportDate!)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: _selectedReportDate == null ? Colors.grey.shade700 : const Color(0xFF0D47A1),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.calendar_month, color: Color(0xFF0D47A1), size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_selectedReportDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _selectedReportDate = null;
                        });
                      },
                      tooltip: AppTranslations.get('reset_filter'),
                    ),
                  ],
                ],
              ),
            ),
            if (_selectedReportDate != null) ...[
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('transactions')
                    .snapshots(),
                builder: (context, snapshot) {
                  double customBaki = 0.0;
                  double customJama = 0.0;

                  if (snapshot.hasData) {
                    DateTime sStart = DateTime(_selectedReportDate!.year, _selectedReportDate!.month, _selectedReportDate!.day);
                    DateTime sEnd = sStart.add(const Duration(days: 1));

                    for (var doc in snapshot.data!.docs) {
                      var tData = doc.data() as Map<String, dynamic>;
                      Timestamp? ts = _parseDate(tData['date']);
                      if (ts != null) {
                        DateTime tDate = ts.toDate();
                        if ((tDate.isAtSameMomentAs(sStart) || tDate.isAfter(sStart)) && tDate.isBefore(sEnd)) {
                          String type = tData['type'] ?? '';
                          double amount = (tData['amount'] as num?)?.toDouble() ?? 0.0;
                          double paidAmount = (tData['paidAmount'] as num?)?.toDouble() ?? 0.0;

                          if (type == 'বাকি' || type == 'sale_due' || type == 'baki') {
                            customBaki += amount;
                            customJama += paidAmount;
                          } else if (type == 'জমা') {
                            customJama += amount;
                          }
                        }
                      }
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(AppTranslations.get('baki_of_date').replaceAll('@date', DateFormat('dd MMM').format(_selectedReportDate!)) + ': ${AppTranslations.get('currency_symbol')} $customBaki',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                        Text('${AppTranslations.get('jama')}: ${AppTranslations.get('currency_symbol')} $customJama',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: TextField(
                onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: AppTranslations.get('search_customer_hint'),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF0D47A1)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: user == null
                  ? const Center(child: Text('লগইন করা নেই!'))
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(shopId)
                    .collection('customers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final phone = (data['phone'] ?? '').toString().toLowerCase();
                    return name.contains(searchQuery) || phone.contains(searchQuery);
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(child: Text(AppTranslations.get('no_customer_found')));
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      var doc = filteredDocs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      double dueAmount = (data['dueAmount'] as num?)?.toDouble() ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: _selectedCustomerIds.contains(doc.id) ? Colors.blue.shade50 : null,
                        child: ListTile(
                          onLongPress: () {
                            setState(() {
                              _isSelectionMode = true;
                              _toggleSelection(doc.id, data['phone'] ?? '');
                            });
                          },
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(doc.id, data['phone'] ?? '');
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CustomerScreen(
                                    customerId: doc.id,
                                    customerName: data['name'],
                                    customerPhone: data['phone'],
                                  ),
                                ),
                              );
                            }
                          },
                          leading: _isSelectionMode
                              ? Checkbox(
                                  value: _selectedCustomerIds.contains(doc.id),
                                  onChanged: (val) => _toggleSelection(doc.id, data['phone'] ?? ''),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(data['name'] != null ? data['name'][0].toUpperCase() : 'C'),
                                ),
                          title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${AppTranslations.get('mobile')}: ${data['phone']}\n${AppTranslations.get('due')}: ${AppTranslations.get('currency_symbol')} $dueAmount'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _isSelectionMode 
            ? null 
            : FloatingActionButton(
                backgroundColor: const Color(0xFF0D47A1),
                onPressed: _showAddCustomerDialog,
                child: const Icon(Icons.person_add, color: Colors.white),
              ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(shopId)
            .collection('customers')
            .doc(widget.customerId)
            .snapshots(),
        builder: (context, customerSnapshot) {
          if (!customerSnapshot.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          var customerData = customerSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          double totalDue = (customerData['dueAmount'] as num?)?.toDouble() ?? 0.0;
          String phoneNum = customerData['phone'] ?? '';
          String custName = customerData['name'] ?? widget.customerName ?? AppTranslations.get('customer');

          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 1,
              iconTheme: const IconThemeData(color: Colors.black87),
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      custName.isNotEmpty ? custName[0].toUpperCase() : 'C',
                      style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(custName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis),
                        Text(AppTranslations.get('tap_to_view_profile'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => _showReportFilterDialog(customerData),
                  icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.red),
                  label: Text(AppTranslations.get('report_pdf'), style: const TextStyle(color: Colors.black87)),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF0D47A1)),
                  onPressed: () => _showEditCustomerDialog(customerData),
                  tooltip: AppTranslations.get('edit_customer_title'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeletePinDialog(widget.customerId!),
                  tooltip: AppTranslations.get('delete'),
                ),
              ],
            ),
          body: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppTranslations.get('settled_due'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text('${AppTranslations.get('currency_symbol')} $totalDue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: totalDue > 0 ? Colors.red : Colors.green)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        InkWell(
                          onTap: () {
                            if (phoneNum.isNotEmpty) {
                              _makePhoneCall(phoneNum);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('phone_not_found') ?? 'Phone not found!')));
                            }
                          },
                          child: _buildTopActionIcon(Icons.phone, AppTranslations.get('call')),
                        ),
                        InkWell(
                          onTap: () {
                            if (phoneNum.isNotEmpty) {
                              _sendSms(phoneNum);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('phone_not_found') ?? 'Phone not found!')));
                            }
                          },
                          child: _buildTopActionIcon(Icons.chat_bubble_outline, AppTranslations.get('message')),
                        ),
                        InkWell(
                          onTap: () async {
                            if (await SubscriptionUtils.isPremium()) {
                              _sendDueReminder(phoneNum, custName, totalDue);
                            } else {
                              if (!mounted) return;
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                            }
                          },
                          child: _buildTopActionIcon(Icons.access_time, AppTranslations.get('reminder')),
                        ),
                        InkWell(
                          onTap: () async {
                            if (await SubscriptionUtils.isPremium()) {
                              _sendInvitation(phoneNum, custName);
                            } else {
                              if (!mounted) return;
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                            }
                          },
                          child: _buildTopActionIcon(Icons.card_giftcard, AppTranslations.get('invitation')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: AppTranslations.get('search_note_hint'),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(shopId)
                      .collection('customers')
                      .doc(widget.customerId)
                      .collection('transactions')
                      .orderBy('date', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final transDocs = snapshot.data!.docs;

                    final filteredTrans = transDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final note = (data['note'] ?? '').toString().toLowerCase();
                      final type = (data['type'] ?? '').toString().toLowerCase();
                      return note.contains(searchQuery) || type.contains(searchQuery);
                    }).toList();

                    if (filteredTrans.isEmpty) {
                      return Center(child: Text(AppTranslations.get('no_transaction_found')));
                    }

                    return ListView.builder(
                      itemCount: filteredTrans.length,
                      itemBuilder: (context, index) {
                        var tData = filteredTrans[index].data() as Map<String, dynamic>;
                        String rawType = tData['type'] ?? '';
                        String type = AppTranslations.get(rawType);
                        double amount = (tData['amount'] as num?)?.toDouble() ?? 0.0;
                        double balance = (tData['balance'] as num?)?.toDouble() ?? 0.0;
                        String note = tData['note'] ?? '';
                        Timestamp? ts = _parseDate(tData['date']);
                        String dateStr = ts != null ? DateFormat('dd MMM yyyy, hh:mm a').format(ts.toDate()) : '';

                        bool isJama = rawType == 'জমা' || rawType == 'jama';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(type, style: TextStyle(fontWeight: FontWeight.bold, color: isJama ? Colors.green : Colors.red)),
                                    Row(
                                      children: [
                                        Text('${AppTranslations.get('currency_symbol')} $amount', style: TextStyle(fontWeight: FontWeight.bold, color: isJama ? Colors.green : Colors.red)),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                                          onPressed: () => _generateSingleTransactionPdf(customerData, tData),
                                          tooltip: AppTranslations.get('report_pdf'),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('${AppTranslations.get('description_optional')}: $note', style: const TextStyle(fontSize: 13)),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${AppTranslations.get('date_label')} $dateStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    Text('${AppTranslations.get('due')}: ${AppTranslations.get('currency_symbol')} $balance', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
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
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                    onPressed: () => _showAddTransactionDialog(widget.customerId!, totalDue, 'baki'),
                    child: Text(AppTranslations.get('give_due')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    onPressed: () => _showAddTransactionDialog(widget.customerId!, totalDue, 'jama'),
                    child: Text(AppTranslations.get('take_jama')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}