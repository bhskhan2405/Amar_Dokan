import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/translations.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String customerAddress;

  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String shopName = 'আমার দোকান';
  String shopPhone = '';

  @override
  void initState() {
    super.initState();
    _loadShopInfo();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // দোকানের তথ্য লোড
  Future<void> _loadShopInfo() async {
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          shopName = doc.data()?['shopName'] ?? 'আমার দোকান';
          shopPhone = doc.data()?['phone'] ?? '';
        });
      }
    }
  }

  // কল করা
  Future<void> _makeCall() async {
    if (widget.customerPhone.isEmpty) return;
    final Uri url = Uri.parse('tel:${widget.customerPhone}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // এসএমএস পাঠানো
  Future<void> _sendSms(double due) async {
    if (widget.customerPhone.isEmpty) return;
    String message = AppTranslations.get('due_reminder_msg')
        .replaceAll('@name', widget.customerName)
        .replaceAll('@shop', shopName)
        .replaceAll('@due', due.toStringAsFixed(2));
    final Uri url = Uri.parse('sms:${widget.customerPhone}?body=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // পেমেন্ট জমা বা নতুন বাকির লেনদেন যোগ
  void _addTransaction(String type, double currentDue) {
    _amountController.clear();
    _noteController.clear();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        title: Text(
          type == 'PAYMENT' ? AppTranslations.get('receive_payment') : AppTranslations.get('add_new_due'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  children: [
                    Text(AppTranslations.get('current_total_due'), style: const TextStyle(color: Colors.red, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '৳${currentDue.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                decoration: InputDecoration(
                  labelText: AppTranslations.get('amount_tk'),
                  labelStyle: const TextStyle(color: Colors.grey),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF0D47A1), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                decoration: InputDecoration(
                  labelText: AppTranslations.get('description_optional'),
                  labelStyle: const TextStyle(color: Colors.grey),
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF0D47A1), width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: type == 'PAYMENT' ? Colors.green : Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              double amount = double.tryParse(_amountController.text.trim()) ?? 0;
              if (amount <= 0) return;

              double newDue = type == 'PAYMENT' ? currentDue - amount : currentDue + amount;

              // ১. কাস্টমার ব্যালেন্স আপডেট
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('customers')
                  .doc(widget.customerId)
                  .update({'dueAmount': newDue});

              // ২. লেনদেনের বিবরণ সেভ
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('customers')
                  .doc(widget.customerId)
                  .collection('transactions')
                  .add({
                'type': type,
                'amount': amount,
                'note': _noteController.text.trim().isEmpty
                    ? (type == 'PAYMENT' ? AppTranslations.get('payment_received') : AppTranslations.get('new_due'))
                    : _noteController.text.trim(),
                'timestamp': FieldValue.serverTimestamp(),
              });

              _amountController.clear();
              _noteController.clear();
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: Text(AppTranslations.get('save'), style: const TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),
    );
  }

  // PDF জেনারেট ও শেয়ার অপশন
  Future<void> _generateAndSharePdf(List<QueryDocumentSnapshot> docs, double currentDue) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(15),
                decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      shopName,
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                    if (shopPhone.isNotEmpty)
                      pw.Text('Mobile: $shopPhone', style: const pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                    pw.Text('Customer Statement / Ledger', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Customer Name: ${widget.customerName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text('Phone: ${widget.customerPhone}'),
                      pw.Text('Address: ${widget.customerAddress}'),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                    child: pw.Column(
                      children: [
                        pw.Text('Current Due', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(
                          'TK. ${currentDue.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Text('Transaction History:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: const ['Type', 'Note', 'Amount (TK)'],
                data: docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return [
                    data['type'] == 'PAYMENT' ? 'Paid' : 'Due/Sale',
                    data['note'] ?? '',
                    '${data['amount']}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Thank you for your business!', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: '${widget.customerName}_statement.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customerName, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('customers')
            .doc(widget.customerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var customerData = snapshot.data?.data() as Map<String, dynamic>?;
          double currentDue = (customerData?['dueAmount'] ?? 0).toDouble();

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(12),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('📞 ${widget.customerPhone}'),
                                Text('📍 ${widget.customerAddress}'),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: [
                                Text(AppTranslations.get('total_due'), style: const TextStyle(color: Colors.red, fontSize: 12)),
                                Text(
                                  '৳${currentDue.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: _makeCall,
                            icon: const Icon(Icons.call, color: Colors.white, size: 18),
                            label: Text(AppTranslations.get('call'), style: const TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            onPressed: () => _sendSms(currentDue),
                            icon: const Icon(Icons.message, color: Colors.white, size: 18),
                            label: Text(AppTranslations.get('sms_reminder'), style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        onPressed: () => _addTransaction('PAYMENT', currentDue),
                        child: Text('💵 ${AppTranslations.get('jama_cash')}', style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () => _addTransaction('DUE', currentDue),
                        child: Text('➕ ${AppTranslations.get('add_due')}', style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('📜 ${AppTranslations.get('transaction_history_ledger')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                      tooltip: 'PDF শেয়ার করুন',
                      onPressed: () async {
                        var transDocs = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user?.uid)
                            .collection('customers')
                            .doc(widget.customerId)
                            .collection('transactions')
                            .orderBy('timestamp', descending: true)
                            .get();
                        _generateAndSharePdf(transDocs.docs, currentDue);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .collection('customers')
                      .doc(widget.customerId)
                      .collection('transactions')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, transSnapshot) {
                    if (!transSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var docs = transSnapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(child: Text(AppTranslations.get('no_transaction_history')));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        bool isPayment = data['type'] == 'PAYMENT';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPayment ? Colors.green.shade100 : Colors.red.shade100,
                            child: Icon(
                              isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isPayment ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(data['note'] ?? ''),
                          subtitle: Text(isPayment ? AppTranslations.get('jama_given') : AppTranslations.get('baki_taken')),
                          trailing: Text(
                            '৳${data['amount']}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isPayment ? Colors.green : Colors.red,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }
}