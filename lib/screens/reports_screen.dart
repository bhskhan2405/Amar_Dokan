import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/translations.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2101),
      locale: const Locale('en', 'US'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get('hisab'), style: const TextStyle(color: Colors.white, fontFamily: 'Bornomala')),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orange,
          tabs: [
            Tab(text: AppTranslations.get('daily_report')),
            Tab(text: AppTranslations.get('monthly_report')),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppTranslations.get('date')}: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white),
                  label: Text(AppTranslations.get('change_date'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SalesListTab(filterType: 'daily', selectedDate: _selectedDate),
                const SalesListTab(filterType: 'month', selectedDate: null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SalesListTab extends StatelessWidget {
  final String filterType;
  final DateTime? selectedDate;
  const SalesListTab({super.key, required this.filterType, this.selectedDate});

  Future<void> _generatePdf(BuildContext context, Map<String, dynamic> saleData, String dateStr) async {
    final pdf = pw.Document();

    final user = FirebaseAuth.instance.currentUser;
    String shopName = AppTranslations.get('app_name');
    String shopAddress = '';
    String shopPhone = '';

    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        shopName = userDoc.data()?['shopName'] ?? 'AMAR DOKAN';
        shopAddress = userDoc.data()?['address'] ?? '';
        shopPhone = userDoc.data()?['phone'] ?? '';
      }
    }

    Map<String, dynamic> itemsMap = {};
    var rawItems = saleData['items'];
    final staffName = saleData['staffName'] ?? 'Admin';
    if (rawItems is Map) {
      itemsMap = rawItems.map((key, value) => MapEntry(key.toString(), value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{}));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  shopName.toUpperCase(),
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (shopAddress.isNotEmpty)
                pw.Center(child: pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 9))),
              if (shopPhone.isNotEmpty)
                pw.Center(child: pw.Text('Phone: $shopPhone', style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              pw.Text('Date & Time: $dateStr', style: const pw.TextStyle(fontSize: 9)),
              pw.Text(staffName == 'Admin' ? 'Sell By: Admin' : 'Sell By: Staff: $staffName', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 5),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),

              // Table Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Item Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 1, child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),

              // Items List
              ...itemsMap.entries.map((entry) {
                final item = entry.value;
                final name = item['name'] ?? '';
                final qty = item['qty'] ?? 1;
                final price = (item['price'] ?? 0.0) is num ? (item['price'] ?? 0.0).toDouble() : 0.0;
                final itemTotal = price * qty;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(name, style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(flex: 1, child: pw.Text('$qty', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text('Tk ${itemTotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 4),

              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL AMOUNT:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Tk ${((saleData['totalAmount'] ?? 0.0) is num ? (saleData['totalAmount'] ?? 0.0).toDouble() : 0.0).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text('Thank you for shopping with us!', style: const pw.TextStyle(fontSize: 8)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Center(child: Text(AppTranslations.get('not_logged_in')));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('sales')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text(AppTranslations.get('no_sales_found')));
        }

        final now = DateTime.now();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final timestamp = data['createdAt'] as Timestamp?;
          if (timestamp == null) return false;
          final date = timestamp.toDate();

          if (filterType == 'daily' && selectedDate != null) {
            return date.year == selectedDate!.year &&
                date.month == selectedDate!.month &&
                date.day == selectedDate!.day;
          } else if (filterType == 'month') {
            return date.year == now.year && date.month == now.month;
          }
          return false;
        }).toList();

        if (docs.isEmpty) {
          return Center(child: Text(AppTranslations.get('no_sales_in_range')));
        }

        double totalSales = 0;
        double totalProfit = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalSales += ((data['totalAmount'] ?? 0.0) is num ? (data['totalAmount'] ?? 0.0).toDouble() : 0.0);
          totalProfit += ((data['profit'] ?? 0.0) is num ? (data['profit'] ?? 0.0).toDouble() : 0.0);
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(AppTranslations.get('total_sales'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Tk ${totalSales.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  Container(height: 30, width: 1, color: Colors.grey.shade400),
                  Column(
                    children: [
                      Text(AppTranslations.get('total_profit'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Tk ${totalProfit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sales History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final amount = (data['totalAmount'] ?? 0.0) is num ? (data['totalAmount'] ?? 0.0).toDouble() : 0.0;
                  final profit = (data['profit'] ?? 0.0) is num ? (data['profit'] ?? 0.0).toDouble() : 0.0;
                  final timestamp = data['createdAt'] as Timestamp?;
                  final dateStr = timestamp != null
                      ? DateFormat('hh:mm a').format(timestamp.toDate())
                      : 'তারিখ নেই';
                  final fullDateStr = timestamp != null
                      ? DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate())
                      : 'তারিখ নেই';

                  Map<String, dynamic> itemsMap = {};
                  var rawItems = data['items'];
                  if (rawItems is Map) {
                    itemsMap = rawItems.map((key, value) => MapEntry(key.toString(), value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{}));
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(side: BorderSide.none),
                      collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${AppTranslations.get('sale_amount')}: Tk ${amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 26),
                            onPressed: () => _generatePdf(context, data, fullDateStr),
                            tooltip: 'PDF ডাউনলোড/প্রিন্ট করুন',
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${AppTranslations.get('time')}: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text('Sell By: ${data['staffName'] ?? 'Admin'}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text('${AppTranslations.get('profit')}: Tk ${profit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
                          ],
                        ),
                      ),
                      children: [
                        const Divider(height: 1, thickness: 1, color: Colors.black12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: itemsMap.length,
                          itemBuilder: (context, itemIndex) {
                            final entry = itemsMap.entries.elementAt(itemIndex);
                            final item = entry.value;
                            final name = item['name'] ?? '';
                            final qty = item['qty'] ?? 1;
                            final price = (item['price'] ?? 0.0) is num ? (item['price'] ?? 0.0).toDouble() : 0.0;
                            return ListTile(
                              dense: true,
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(AppTranslations.get('qty_price').replaceAll('@qty', '$qty').replaceAll('@price', '$price')),
                              trailing: Text('Tk ${(price * qty).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}