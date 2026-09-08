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

                if (!context.mounted) return;
                if (dialogContext.mounted) Navigator.pop(dialogContext);
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

                    if (!context.mounted) return;
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('customer_updated_msg'))));
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('wrong_pin'))));
                  }
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.get('error_occurred')} $e')));
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
                    if (dialogContext.mounted) Navigator.pop(dialogContext);

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

                    if (!context.mounted) return;
                    if (context.mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('customer_deleted_success'))));
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('wrong_pin'))));
                  }
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.get('error_occurred')} $e')));
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

                  if (!context.mounted) return;
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
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
    // এখানে আপাতত স্টেটমেন্ট জেনারেটর ব্যবহার করছি
    await ReceiptUtils.generateCustomerStatement(
      customerData: customerData,
      transactions: [
         // ডামি লিস্ট হিসেবে কারেন্ট ট্রানজেকশন পাঠানো হচ্ছে (Firebase format match করার জন্য QueryDocumentSnapshot প্রয়োজন হতে পারে, 
         // কিন্তু ReceiptUtils এ map entry হিসেবে হ্যান্ডেল করলে সুবিধা হতো। 
         // আমি ReceiptUtils এ list of objects সাপোর্ট করার মতো করে আপডেট করবো।)
      ],
      startDate: DateTime.now(),
      endDate: DateTime.now(),
    );
  }

  Future<void> _generateShopStylePdf({
    required Map<String, dynamic> customerData,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(shopId)
        .collection('customers')
        .doc(widget.customerId)
        .collection('transactions')
        .orderBy('date', descending: false)
        .get();

    List<QueryDocumentSnapshot> filteredDocs = [];
    for (var doc in querySnapshot.docs) {
      var t = doc.data() as Map<String, dynamic>;
      Timestamp? ts = _parseDate(t['date']);
      if (ts != null) {
        DateTime tDate = ts.toDate();
        DateTime cleanTDate = DateTime(tDate.year, tDate.month, tDate.day);
        DateTime cleanStart = DateTime(startDate.year, startDate.month, startDate.day);
        DateTime cleanEnd = DateTime(endDate.year, endDate.month, endDate.day);

        if ((cleanTDate.isAtSameMomentAs(cleanStart) || cleanTDate.isAfter(cleanStart)) &&
            (cleanTDate.isAtSameMomentAs(cleanEnd) || cleanTDate.isBefore(cleanEnd))) {
          filteredDocs.add(doc);
        }
      }
    }

    await ReceiptUtils.generateCustomerStatement(
      customerData: customerData,
      transactions: filteredDocs,
      startDate: startDate,
      endDate: endDate,
    );
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('customer_phone_missing'))));
      return;
    }
    String message = AppTranslations.currentLanguage == 'bn' 
      ? 'প্রিয় $customerName, আপনার নিকট আমাদের দোকানের বকেয়া মোট ৳$dueAmount টাকা। দয়া করে বকেয়া পরিশোধ করার সুব্যবস্থা করুন। ধন্যবাদ।'
      : 'Dear $customerName, your total due in our shop is ৳$dueAmount. Please arrange to clear the due. Thank you.';
    final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber, queryParameters: {'body': message});
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('no_due_to_remind'))));
      }
    }
  }

  void _sendInvitation(String phoneNumber, String customerName) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('customer_phone_missing'))));
      return;
    }
    String message = AppTranslations.currentLanguage == 'bn' 
      ? 'প্রিয় $customerName, আমাদের দোকানে আপনাকে স্বাগতম! আমাদের নতুন অফার এবং সেবাসমূহ উপভোগ করতে আমাদের দোকানে আসার আমন্ত্রণ রইল।'
      : 'Dear $customerName, welcome to our shop! We invite you to visit our shop to enjoy our new offers and services.';
    final Uri whatsappUri = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber, queryParameters: {'body': message});
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('no_invitation_needed'))));
      }
    }
  }

  Widget _buildTopActionIcon(IconData icon, String label, {bool isPremium = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade50,
              child: Icon(icon, color: const Color(0xFF0D47A1), size: 20),
            ),
            if (isPremium)
              Positioned(
                top: -2,
                right: -2,
                child: SubscriptionUtils.premiumIcon(size: 14),
              ),
          ],
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
                  ? '${_selectedCustomerIds.length} ${AppTranslations.get('selected')}'
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
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/feature_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
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
                          color: Colors.white.withValues(alpha: 0.9),
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
                            color: Colors.white.withValues(alpha: 0.9),
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
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('${AppTranslations.get('baki_of_date').replaceAll('@date', DateFormat('dd MMM').format(_selectedReportDate!))}: ${AppTranslations.get('currency_symbol')} $customBaki',
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
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.9),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: user == null
                    ? Center(child: Text(AppTranslations.get('not_logged_in'), style: const TextStyle(color: Colors.white)))
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
                      return Center(child: Text(AppTranslations.get('no_customer_found'), style: const TextStyle(color: Colors.white)));
                    }

                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        var doc = filteredDocs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        double dueAmount = (data['dueAmount'] as num?)?.toDouble() ?? 0.0;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          color: _selectedCustomerIds.contains(doc.id) ? Colors.blue.shade50 : Colors.white.withValues(alpha: 0.9),
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
                                    backgroundColor: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                                    child: Text(data['name'] != null ? data['name'][0].toUpperCase() : 'C', style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
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
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/feature_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              children: [
                Container(
                  color: Colors.white.withValues(alpha: 0.9),
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
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('phone_not_found'))));
                              }
                            },
                            child: _buildTopActionIcon(Icons.phone, AppTranslations.get('call')),
                          ),
                          InkWell(
                            onTap: () {
                              if (phoneNum.isNotEmpty) {
                                _sendSms(phoneNum);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('phone_not_found'))));
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
                            child: _buildTopActionIcon(Icons.access_time, AppTranslations.get('reminder'), isPremium: true),
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
                            child: _buildTopActionIcon(Icons.card_giftcard, AppTranslations.get('invitation'), isPremium: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  color: Colors.white.withValues(alpha: 0.9),
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
                        return Center(child: Text(AppTranslations.get('no_transaction_found'), style: const TextStyle(color: Colors.white)));
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
                            color: Colors.white.withValues(alpha: 0.9),
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
