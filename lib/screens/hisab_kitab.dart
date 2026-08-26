import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/translations.dart';
import '../utils/shop_utils.dart';
import '../utils/subscription_utils.dart';
import 'subscription_screen.dart';

class HisabKitabPage extends StatefulWidget {
  const HisabKitabPage({super.key});

  @override
  State<HisabKitabPage> createState() => _HisabKitabPageState();
}

class _HisabKitabPageState extends State<HisabKitabPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime selectedDate = DateTime.now();
  String _shopId = '';

  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadShopId();
  }

  Future<void> _loadShopId() async {
    _shopId = await ShopUtils.getShopId();
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _convertToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // বর্তমান লগইন করা ইউজার বা স্টাফের নাম বা আইডি পাওয়ার জন্য হেল্পার মেথড
  Future<String> _getCurrentUserName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Unknown';

    try {
      // প্রথমে চেক করা যাক এটি অ্যাডমিন কি না
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('name')) {
          return data['name'].toString();
        }
      }
    } catch (_) {}

    return AppTranslations.get('staff_user');
  }

  Future<String> _getShopName(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('shopName') && data['shopName'] != null) {
          return data['shopName'].toString();
        }
      }
    } catch (_) {}
    return AppTranslations.get('my_shop');
  }

  Future<pw.Font> _loadBanglaFont() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/SolaimanLipi-Normal.ttf');
      return pw.Font.ttf(fontData);
    } catch (_) {
      final fallbackData = await rootBundle.load('assets/fonts/SolaimanLipi.ttf');
      return pw.Font.ttf(fallbackData);
    }
  }

  Future<bool> _verifyPin(BuildContext context, String userId) async {
    final pinController = TextEditingController();
    bool isVerified = false;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String correctPin = '1234';
    if (userDoc.exists) {
      var data = userDoc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('pin')) {
        correctPin = data['pin'].toString();
      }
    }

    if (!context.mounted) return false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppTranslations.get('security_pin')),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: InputDecoration(labelText: AppTranslations.get('enter_pin')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppTranslations.get('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
              onPressed: () {
                if (pinController.text.trim() == correctPin) {
                  isVerified = true;
                  Navigator.pop(dialogContext);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('invalid_pin_msg')), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(AppTranslations.get('confirm')),
            ),
          ],
        );
      },
    );

    return isVerified;
  }

  void _showEditSaleDialog(BuildContext context, String userId, String saleId, Map<String, dynamic> saleData) async {
    bool authorized = await _verifyPin(context, userId);
    if (!authorized) return;

    final amountController = TextEditingController(text: _convertToDouble(saleData['totalAmount']).toString());
    final profitController = TextEditingController(text: _convertToDouble(saleData['profit']).toString());

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(AppTranslations.get('edit_sale_history') ?? 'Edit Sale Record', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: AppTranslations.get('new_total_sale_tk') ?? 'New Total Sale (Tk)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: profitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: AppTranslations.get('new_profit_tk') ?? 'New Profit (Tk)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppTranslations.get('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
              onPressed: () async {
                double newAmount = double.tryParse(amountController.text) ?? 0.0;
                double newProfit = double.tryParse(profitController.text) ?? 0.0;
                String editorName = await _getCurrentUserName();

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('sales')
                    .doc(saleId)
                    .update({
                  'totalAmount': newAmount,
                  'profit': newProfit,
                  'lastEditedBy': editorName, // মাল্টিপল ইউজার ট্র্যাক করার জন্য
                });

                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppTranslations.get('sale_updated_msg') ?? 'Sale updated successfully!')),
                );
              },
              child: Text(AppTranslations.get('update')),
            ),
          ],
        );
      },
    );
  }

  void _showAddExpenseDialog(BuildContext dialogContext, String userId) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    showDialog(
      context: dialogContext,
      builder: (context) {
        return AlertDialog(
          title: Text(AppTranslations.get('add_expense'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: AppTranslations.get('expense_amount_tk'), hintText: 'e.g. 500'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: InputDecoration(labelText: AppTranslations.get('expense_category_hint')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppTranslations.get('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
              onPressed: () async {
                if (amountController.text.isNotEmpty) {
                  double amount = double.tryParse(amountController.text) ?? 0.0;
                  String note = noteController.text.trim();
                  if (note.isEmpty) note = AppTranslations.get('general_expense');

                  // কে খরচটি এন্ট্রি করল তার নাম সংগ্রহ করা
                  String addedBy = await _getCurrentUserName();

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('expenses')
                      .add({
                    'amount': amount,
                    'note': note,
                    'addedBy': addedBy, // মাল্টিপল ইউজার অপশন
                    'createdAt': Timestamp.now(),
                  });

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('expense_added_msg'))),
                  );
                }
              },
              child: Text(AppTranslations.get('save')),
            ),
          ],
        );
      },
    );
  }

  void _showAddEditEmployeeDialog(BuildContext context, String userId, {String? empId, Map<String, dynamic>? existingData}) async {
    if (empId != null) {
      bool authorized = await _verifyPin(context, userId);
      if (!authorized) return;
    }

    final nameController = TextEditingController(text: existingData?['name'] ?? '');
    final phoneController = TextEditingController(text: existingData?['phone'] ?? '');
    final addressController = TextEditingController(text: existingData?['address'] ?? '');
    final designationController = TextEditingController(text: existingData?['designation'] ?? '');
    final salaryController = TextEditingController(text: existingData != null ? existingData['salary'].toString() : '');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(empId == null ? AppTranslations.get('add_new_employee') : AppTranslations.get('edit_employee_info'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: AppTranslations.get('staff_name')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: designationController,
                  decoration: InputDecoration(labelText: AppTranslations.get('designation_hint')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: AppTranslations.get('mobile')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: AppTranslations.get('address')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: salaryController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: AppTranslations.get('monthly_salary_tk')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppTranslations.get('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  String managerName = await _getCurrentUserName();
                  var dataToSave = {
                    'name': nameController.text.trim(),
                    'designation': designationController.text.trim(),
                    'phone': phoneController.text.trim(),
                    'address': addressController.text.trim(),
                    'salary': double.tryParse(salaryController.text) ?? 0.0,
                    'managedBy': managerName, // মাল্টিপল ইউজার ট্র্যাকিং
                  };

                  if (empId == null) {
                    dataToSave['createdAt'] = Timestamp.now();
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('employees')
                        .add(dataToSave);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('employees')
                        .doc(empId)
                        .update(dataToSave);
                  }

                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('info_saved_msg'))),
                  );
                }
              },
              child: Text(AppTranslations.get('save')),
            ),
          ],
        );
      },
    );
  }

  void _showPaySalaryDialog(BuildContext context, String userId, String employeeId, String empName, double baseSalary) async {
    bool authorized = await _verifyPin(context, userId);
    if (!authorized) return;

    final amountController = TextEditingController(text: baseSalary.toString());
    final noteController = TextEditingController(text: 'মাসিক বেতন পরিশোধ');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${AppTranslations.get('salary_payment_title')}: $empName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: AppTranslations.get('payment_amount_tk')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: InputDecoration(labelText: AppTranslations.get('description_optional')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppTranslations.get('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                double paidAmount = double.tryParse(amountController.text) ?? 0.0;
                if (paidAmount > 0) {
                  String paidBy = await _getCurrentUserName();

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('employees')
                      .doc(employeeId)
                      .collection('payments')
                      .add({
                    'amount': paidAmount,
                    'note': noteController.text.trim(),
                    'paidBy': paidBy, // মাল্টিপল ইউজার অপশন
                    'createdAt': Timestamp.now(),
                  });

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('expenses')
                      .add({
                    'amount': paidAmount,
                    'note': '${AppTranslations.get('salary')}: $empName (${noteController.text.trim()}) [By: $paidBy]',
                    'addedBy': paidBy,
                    'createdAt': Timestamp.now(),
                  });

                  if (!context.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('salary_paid_msg'))),
                  );
                }
              },
              child: Text(AppTranslations.get('salary_payment_confirm')),
            ),
          ],
        );
      },
    );
  }

  void _showEmployeeDetailsAndPdf(BuildContext context, String userId, String empId, Map<String, dynamic> empData) {
    String empName = empData['name'] ?? '';
    String designation = empData['designation'] ?? '';
    String phone = empData['phone'] ?? '';
    String address = empData['address'] ?? '';
    double baseSalary = _convertToDouble(empData['salary']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('employees')
                  .doc(empId)
                  .collection('payments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                List<QueryDocumentSnapshot<Object?>> paymentDocs = snapshot.hasData ? snapshot.data!.docs : [];

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(empName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                                if (designation.isNotEmpty) Text('${AppTranslations.get('designation')}: $designation', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                            tooltip: AppTranslations.get('download_pdf') ?? 'Download PDF',
                            onPressed: () {
                              _generateEmployeePdf(empName, designation, phone, address, baseSalary, paymentDocs, userId);
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      Text('${AppTranslations.get('mobile')}: $phone | ${AppTranslations.get('address')}: $address'),
                      Text('${AppTranslations.get('monthly_salary_tk')}: ৳ ${baseSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 10),
                      Text(AppTranslations.get('salary_payment_history'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 5),
                      Expanded(
                        child: paymentDocs.isEmpty
                            ? Center(child: Text(AppTranslations.get('no_payment_record')))
                            : ListView.builder(
                          controller: scrollController,
                          itemCount: paymentDocs.length,
                          itemBuilder: (context, index) {
                            var pData = paymentDocs[index].data() as Map<String, dynamic>;
                            Timestamp? t = pData['createdAt'];
                            String dateStr = t != null ? DateFormat('dd MMM yyyy, hh:mm a', 'en_US').format(t.toDate()) : '';
                            double amt = _convertToDouble(pData['amount']);
                            String note = pData['note'] ?? '';
                            String paidBy = pData['paidBy'] ?? '';

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                title: Text('${AppTranslations.get('currency_symbol')} ${amt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                subtitle: Text('$note\n${AppTranslations.get('provided_by')}: $paidBy\n${AppTranslations.get('date')}: $dateStr'),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _generateEmployeePdf(
      String empName,
      String designation,
      String phone,
      String address,
      double baseSalary,
      List<QueryDocumentSnapshot<Object?>> payments,
      String userId) async {
    final pdf = pw.Document();
    final banglaFont = await _loadBanglaFont();
    String shopName = await _getShopName(userId);

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: banglaFont, bold: banglaFont),
        build: (pw.Context context) {
          return [
            pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: banglaFont)),
            pw.SizedBox(height: 4),
            pw.Text('Employee Salary Report', style: const pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
            pw.SizedBox(height: 10),
            pw.Text('Name: $empName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: banglaFont)),
            if (designation.isNotEmpty) pw.Text('Designation: $designation', style: pw.TextStyle(fontSize: 12, font: banglaFont)),
            pw.Text('Phone: $phone', style: pw.TextStyle(fontSize: 12, font: banglaFont)),
            pw.Text('Address: $address', style: pw.TextStyle(fontSize: 12, font: banglaFont)),
            pw.Text('Base Salary: BDT ${baseSalary.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: banglaFont)),
            pw.SizedBox(height: 15),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text('PAYMENT HISTORY:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: banglaFont)),
            pw.SizedBox(height: 8),
            ...payments.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              Timestamp? t = data['createdAt'];
              String dateStr = t != null ? DateFormat('yyyy-MM-dd hh:mm a', 'en_US').format(t.toDate()) : '';
              double amt = _convertToDouble(data['amount']);
              String note = data['note'] ?? '';
              String paidBy = data['paidBy'] ?? '';

              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date: $dateStr', style: pw.TextStyle(fontSize: 10, font: banglaFont)),
                    pw.Text('User: $paidBy', style: pw.TextStyle(fontSize: 10, font: banglaFont)),
                    pw.Text('Note: $note', style: pw.TextStyle(fontSize: 10, font: banglaFont)),
                    pw.Text('Amount: BDT ${amt.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: banglaFont)),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get('hisab'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (index) async {
            if (index == 2) {
              if (!(await SubscriptionUtils.isPremium())) {
                _tabController.index = _tabController.previousIndex;
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
              }
            }
          },
          tabs: [
            Tab(text: AppTranslations.get('daily_report')),
            Tab(text: AppTranslations.get('monthly_report')),
            Tab(text: AppTranslations.get('employee')),
          ],
        ),
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        onPressed: () {
          if (_tabController.index == 2) {
            _showAddEditEmployeeDialog(context, _shopId);
          } else {
            _showAddExpenseDialog(context, _shopId);
          }
        },
        icon: Icon(_tabController.index == 2 ? Icons.person_add : Icons.money_off),
        label: Text(_tabController.index == 2 ? AppTranslations.get('add_employee') : AppTranslations.get('add_expense')),
      ),
      body: _shopId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_shopId)
            .collection('sales')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, salesSnapshot) {
          if (salesSnapshot.hasError) {
            return Center(child: Text("Error loading sales: ${salesSnapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
          }
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_shopId)
                .collection('expenses')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, expenseSnapshot) {
              if (expenseSnapshot.hasError) {
                return Center(child: Text("Error loading expenses: ${expenseSnapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
              }
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_shopId)
                    .collection('employees')
                    .snapshots(),
                builder: (context, employeeSnapshot) {
                  if (employeeSnapshot.hasError) {
                    return Center(child: Text("Error loading employees: ${employeeSnapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)));
                  }
                  if (salesSnapshot.connectionState == ConnectionState.waiting ||
                      expenseSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  List<QueryDocumentSnapshot<Object?>> salesDocs = salesSnapshot.hasData ? salesSnapshot.data!.docs : [];
                  List<QueryDocumentSnapshot<Object?>> expenseDocs = expenseSnapshot.hasData ? expenseSnapshot.data!.docs : [];
                  List<QueryDocumentSnapshot<Object?>> employeeDocs = employeeSnapshot.hasData ? employeeSnapshot.data!.docs : [];

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDailyReportView(salesDocs, expenseDocs, _shopId),
                      _buildMonthlyReportView(salesDocs, expenseDocs),
                      _buildEmployeeView(employeeDocs, _shopId),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDatePickerHeader() {
    String dateLabel = startDate != null && endDate != null
        ? 'Range: ${DateFormat('yyyy-MM-dd', 'en_US').format(startDate!)} to ${DateFormat('yyyy-MM-dd', 'en_US').format(endDate!)}'
        : 'Date: ${DateFormat('yyyy-MM-dd', 'en_US').format(selectedDate)}';

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              dateLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              if (startDate != null || endDate != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red, size: 20),
                  tooltip: 'Clear Range',
                  onPressed: () {
                    setState(() {
                      startDate = null;
                      endDate = null;
                    });
                  },
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                    locale: const Locale('en', 'US'),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                      startDate = null;
                      endDate = null;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(AppTranslations.get('specific_date')),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  DateTimeRange? pickedRange = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                    locale: const Locale('en', 'US'),
                    initialDateRange: startDate != null && endDate != null
                        ? DateTimeRange(start: startDate!, end: endDate!)
                        : null,
                  );
                  if (pickedRange != null) {
                    setState(() {
                      startDate = pickedRange.start;
                      endDate = pickedRange.end;
                    });
                  }
                },
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(AppTranslations.get('date_range')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReportView(List<QueryDocumentSnapshot<Object?>> allSales, List<QueryDocumentSnapshot<Object?>> allExpenses, String userId) {
    double totalSale = 0.0;
    double totalProfit = 0.0;
    double totalExpense = 0.0;
    double totalSalary = 0.0;
    List<QueryDocumentSnapshot<Object?>> filteredSales = [];
    List<QueryDocumentSnapshot<Object?>> filteredExpenses = [];

    for (var doc in allSales) {
      var data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      Timestamp? timestamp = data['createdAt'];
      if (timestamp != null) {
        DateTime saleDate = timestamp.toDate();
        if (_isDateMatched(saleDate)) {
          filteredSales.add(doc);
          totalSale += _convertToDouble(data['totalAmount']);
          totalProfit += _convertToDouble(data['profit']);
        }
      }
    }

    for (var doc in allExpenses) {
      var data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      Timestamp? timestamp = data['createdAt'];
      if (timestamp != null) {
        DateTime expenseDate = timestamp.toDate();
        if (_isDateMatched(expenseDate)) {
          filteredExpenses.add(doc);
          String note = data['note'] ?? '';
          if (note.startsWith('বেতন')) {
            totalSalary += _convertToDouble(data['amount']);
          } else {
            totalExpense += _convertToDouble(data['amount']);
          }
        }
      }
    }

    return Column(
      children: [
        _buildDatePickerHeader(),
        if (startDate != null && endDate != null && (filteredSales.isNotEmpty || filteredExpenses.isNotEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                onPressed: () {
                  _generateDateRangePdf(filteredSales, filteredExpenses, totalSale, totalProfit, totalExpense, totalSalary, startDate!, endDate!, userId);
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Download Date Range PDF Report'),
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppTranslations.get('total_sales'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${AppTranslations.get('currency_symbol')} ${totalSale.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppTranslations.get('total_profit'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${AppTranslations.get('currency_symbol')} ${totalProfit.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppTranslations.get('expense_salary'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${AppTranslations.get('currency_symbol')} ${(totalExpense + totalSalary).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (filteredExpenses.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(AppTranslations.get('shop_expenses_salaries'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      var data = filteredExpenses[index].data() as Map<String, dynamic>;
                      Timestamp? t = data['createdAt'];
                      String timeStr = t != null ? DateFormat('dd MMM yyyy, hh:mm a', 'en_US').format(t.toDate()) : '';
                      double amt = _convertToDouble(data['amount']);
                      String note = data['note'] ?? 'Expense';
                      String addedBy = data['addedBy'] ?? 'N/A';
                      bool isSalary = note.startsWith(AppTranslations.get('salary')) || note.startsWith('বেতন');
                      String titleLabel = isSalary ? '${AppTranslations.get('salary')}: ${AppTranslations.get('currency_symbol')} ${amt.toStringAsFixed(2)}' : '${AppTranslations.get('expense') ?? 'Expense'}: ${AppTranslations.get('currency_symbol')} ${amt.toStringAsFixed(2)}';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          title: Text(titleLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          subtitle: Text('Note: $note\n${AppTranslations.get('added_by')}: $addedBy | ${AppTranslations.get('time')}: $timeStr'),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                            onPressed: () {
                              _generateAndPrintExpensePdf(data, timeStr, userId);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${AppTranslations.get('sales_history')}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                filteredSales.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(child: Text(AppTranslations.get('no_record_found'))),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredSales.length,
                  itemBuilder: (context, index) {
                    var doc = filteredSales[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String saleId = doc.id;
                    Timestamp? t = data['createdAt'];
                    String timeString = t != null ? DateFormat('dd MMM yyyy, hh:mm a', 'en_US').format(t.toDate()) : AppTranslations.get('no_record_found');
                    double saleAmount = _convertToDouble(data['totalAmount']);
                    double profitAmount = _convertToDouble(data['profit']);
                    String paymentType = data['paymentType'] ?? 'Cash';
                    String sellerOrUser = data['addedBy'] ?? data['seller'] ?? 'Admin/Staff';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        title: Text('${AppTranslations.get('total_sales')}: ${AppTranslations.get('currency_symbol')} ${saleAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${AppTranslations.get('added_by')}: $sellerOrUser\n${AppTranslations.get('date')} & ${AppTranslations.get('time')}: $timeString\nPayment: $paymentType | ${AppTranslations.get('total_profit')}: ${AppTranslations.get('currency_symbol')} ${profitAmount.toStringAsFixed(2)}'),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue, size: 26),
                              tooltip: AppTranslations.get('edit_pos_tooltip'),
                              onPressed: () {
                                _showEditSaleDialog(context, userId, saleId, data);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                              onPressed: () {
                                _generateAndPrintPdf(data, timeString, userId);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _isDateMatched(DateTime saleDate) {
    if (startDate != null && endDate != null) {
      DateTime normalizedSaleDate = DateTime(saleDate.year, saleDate.month, saleDate.day);
      DateTime normalizedStart = DateTime(startDate!.year, startDate!.month, startDate!.day);
      DateTime normalizedEnd = DateTime(endDate!.year, endDate!.month, endDate!.day);

      return normalizedSaleDate.isAtSameMomentAs(normalizedStart) ||
          normalizedSaleDate.isAtSameMomentAs(normalizedEnd) ||
          (normalizedSaleDate.isAfter(normalizedStart) && normalizedSaleDate.isBefore(normalizedEnd));
    } else {
      return saleDate.year == selectedDate.year &&
          saleDate.month == selectedDate.month &&
          saleDate.day == selectedDate.day;
    }
  }

  Widget _buildMonthlyReportView(List<QueryDocumentSnapshot<Object?>> allSales, List<QueryDocumentSnapshot<Object?>> allExpenses) {
    String currentMonthName = DateFormat('MMMM yyyy', 'en_US').format(selectedDate);
    double monthlyTotalSale = 0.0;
    double monthlyTotalProfit = 0.0;
    double monthlyTotalExpense = 0.0;
    double monthlyTotalSalary = 0.0;
    List<QueryDocumentSnapshot<Object?>> monthlySales = [];

    for (var doc in allSales) {
      var data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      Timestamp? timestamp = data['createdAt'];
      if (timestamp != null) {
        DateTime saleDate = timestamp.toDate();
        if (saleDate.year == selectedDate.year && saleDate.month == selectedDate.month) {
          monthlySales.add(doc);
          monthlyTotalSale += _convertToDouble(data['totalAmount']);
          monthlyTotalProfit += _convertToDouble(data['profit']);
        }
      }
    }

    for (var doc in allExpenses) {
      var data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      Timestamp? timestamp = data['createdAt'];
      if (timestamp != null) {
        DateTime expenseDate = timestamp.toDate();
        if (expenseDate.year == selectedDate.year && expenseDate.month == selectedDate.month) {
          String note = data['note'] ?? '';
          if (note.startsWith('বেতন') || note.startsWith(AppTranslations.get('salary'))) {
            monthlyTotalSalary += _convertToDouble(data['amount']);
          } else {
            monthlyTotalExpense += _convertToDouble(data['amount']);
          }
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '${AppTranslations.get('monthly_report_title')} $currentMonthName',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppTranslations.get('total_sales'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${AppTranslations.get('currency_symbol')} ${monthlyTotalSale.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppTranslations.get('total_profit'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${AppTranslations.get('currency_symbol')} ${monthlyTotalProfit.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppTranslations.get('expense_salary'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${AppTranslations.get('currency_symbol')} ${(monthlyTotalExpense + monthlyTotalSalary).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(AppTranslations.get('sales_list_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                monthlySales.isEmpty
                    ? Padding(padding: const EdgeInsets.all(20), child: Text(AppTranslations.get('no_sales_month')))
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: monthlySales.length,
                  itemBuilder: (context, index) {
                    var data = monthlySales[index].data() as Map<String, dynamic>;
                    Timestamp? t = data['createdAt'];
                    String dateString = t != null ? DateFormat('dd MMM yyyy, hh:mm a', 'en_US').format(t.toDate()) : AppTranslations.get('date_label');
                    double saleAmount = _convertToDouble(data['totalAmount']);
                    String paymentType = data['paymentType'] ?? 'Cash';
                    String sellerOrUser = data['addedBy'] ?? data['seller'] ?? 'N/A';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text('${AppTranslations.get('currency_symbol')} ${saleAmount.toStringAsFixed(2)} ($paymentType)', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${AppTranslations.get('user_staff_label')} $sellerOrUser\n${AppTranslations.get('date_label')} $dateString'),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeView(List<QueryDocumentSnapshot<Object?>> employeeDocs, String userId) {
    if (employeeDocs.isEmpty) {
      return Center(child: Text(AppTranslations.get('no_employee_found')));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: employeeDocs.length,
      itemBuilder: (context, index) {
        var doc = employeeDocs[index];
        var data = doc.data() as Map<String, dynamic>;
        String empId = doc.id;
        String name = data['name'] ?? '';
        String designation = data['designation'] ?? '';
        String phone = data['phone'] ?? '';
        String address = data['address'] ?? '';
        double salary = _convertToDouble(data['salary']);
        String managedBy = data['managedBy'] ?? 'Admin';

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          _showEmployeeDetailsAndPdf(context, userId, empId, data);
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                                  if (designation.isNotEmpty) Text(designation, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 26),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${AppTranslations.get('salary_label')} ${AppTranslations.get('currency_symbol')} ${salary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${AppTranslations.get('mobile_short')}: $phone'),
                Text('${AppTranslations.get('address_short')}: $address'),
                Text('${AppTranslations.get('added_by_label')} $managedBy', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        _showAddEditEmployeeDialog(context, userId, empId: empId, existingData: data);
                      },
                      icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                      label: Text(AppTranslations.get('edit_info'), style: const TextStyle(color: Colors.blue)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                      onPressed: () {
                        _showPaySalaryDialog(context, userId, empId, name, salary);
                      },
                      icon: const Icon(Icons.payment, size: 16),
                      label: Text(AppTranslations.get('pay_salary')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateAndPrintPdf(Map<String, dynamic> data, String timeString, String userId) async {
    final pdf = pw.Document();
    final banglaFont = await _loadBanglaFont();
    String shopName = await _getShopName(userId);

    double saleAmt = _convertToDouble(data['totalAmount']);
    double profitAmt = _convertToDouble(data['profit']);
    String paymentType = data['paymentType'] ?? 'Cash';
    String addedBy = data['staffName'] ?? data['addedBy'] ?? data['seller'] ?? 'N/A';

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: banglaFont, bold: banglaFont),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: banglaFont)),
              pw.SizedBox(height: 4),
              pw.Text('Sales Memo', style: const pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),
              pw.Text('Time: $timeString'),
              pw.Text(addedBy == 'Admin' ? 'Sell By: Admin' : 'Sell By: Staff: $addedBy', style: pw.TextStyle(font: banglaFont)),
              pw.Text('Payment Type: $paymentType'),
              pw.Divider(),
              pw.Text('Total Amount: BDT ${saleAmt.toStringAsFixed(2)}'),
              pw.Text('Profit: BDT ${profitAmt.toStringAsFixed(2)}'),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _generateAndPrintExpensePdf(Map<String, dynamic> data, String timeString, String userId) async {
    final pdf = pw.Document();
    final banglaFont = await _loadBanglaFont();
    String shopName = await _getShopName(userId);

    double expenseAmt = _convertToDouble(data['amount']);
    String note = data['note'] ?? 'General Expense';
    String addedBy = data['addedBy'] ?? 'N/A';
    bool isSalary = note.startsWith('বেতন');

    String memoTitle = isSalary ? 'Salary Memo' : 'Expense Memo';
    String amountLabel = isSalary ? 'Salary Amount' : 'Expense Amount';

    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: banglaFont, bold: banglaFont),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: banglaFont)),
              pw.SizedBox(height: 4),
              pw.Text(memoTitle, style: const pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),
              pw.Text('Time: $timeString'),
              pw.Text('Added By: $addedBy', style: pw.TextStyle(font: banglaFont)),
              pw.Text('Reason / Note: $note', style: pw.TextStyle(font: banglaFont)),
              pw.Divider(),
              pw.Text('$amountLabel: BDT ${expenseAmt.toStringAsFixed(2)}'),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _generateDateRangePdf(
      List<QueryDocumentSnapshot<Object?>> salesDocs,
      List<QueryDocumentSnapshot<Object?>> expenseDocs,
      double totalSale,
      double totalProfit,
      double totalExpense,
      double totalSalary,
      DateTime start,
      DateTime end,
      String userId) async {
    final pdf = pw.Document();
    final banglaFont = await _loadBanglaFont();
    String shopName = await _getShopName(userId);

    Map<String, Map<String, double>> dailySummary = {};

    for (var doc in salesDocs) {
      var data = doc.data() as Map<String, dynamic>;
      Timestamp? t = data['createdAt'];
      if (t != null) {
        String dayKey = DateFormat('yyyy-MM-dd', 'en_US').format(t.toDate());
        double sale = _convertToDouble(data['totalAmount']);
        double profit = _convertToDouble(data['profit']);

        if (!dailySummary.containsKey(dayKey)) {
          dailySummary[dayKey] = {'sale': 0.0, 'profit': 0.0, 'expense': 0.0, 'salary': 0.0};
        }
        dailySummary[dayKey]!['sale'] = dailySummary[dayKey]!['sale']! + sale;
        dailySummary[dayKey]!['profit'] = dailySummary[dayKey]!['profit']! + profit;
      }
    }

    for (var doc in expenseDocs) {
      var data = doc.data() as Map<String, dynamic>;
      Timestamp? t = data['createdAt'];
      if (t != null) {
        String dayKey = DateFormat('yyyy-MM-dd', 'en_US').format(t.toDate());
        double amount = _convertToDouble(data['amount']);
        String note = data['note'] ?? '';

        if (!dailySummary.containsKey(dayKey)) {
          dailySummary[dayKey] = {'sale': 0.0, 'profit': 0.0, 'expense': 0.0, 'salary': 0.0};
        }

        if (note.startsWith('বেতন')) {
          dailySummary[dayKey]!['salary'] = dailySummary[dayKey]!['salary']! + amount;
        } else {
          dailySummary[dayKey]!['expense'] = dailySummary[dayKey]!['expense']! + amount;
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: banglaFont, bold: banglaFont),
        build: (pw.Context context) {
          return [
            pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: banglaFont)),
            pw.SizedBox(height: 4),
            pw.Text('Sales, Expense & Salary Report', style: const pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
            pw.SizedBox(height: 10),
            pw.Text('From: ${DateFormat('yyyy-MM-dd', 'en_US').format(start)} To: ${DateFormat('yyyy-MM-dd', 'en_US').format(end)}',
                style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 15),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text('DAILY BREAKDOWN:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: banglaFont)),
            pw.SizedBox(height: 8),
            ...dailySummary.entries.map((entry) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date: ${entry.key}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Sale: ${entry.value['sale']!.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Profit: ${entry.value['profit']!.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Exp: ${entry.value['expense']!.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Sal: ${entry.value['salary']!.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 15),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text('SUMMARY REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: banglaFont)),
            pw.SizedBox(height: 8),
            pw.Text('Total Sale: BDT ${totalSale.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: banglaFont)),
            pw.Text('Total Profit: BDT ${totalProfit.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: banglaFont)), // এখানে pw.FootWeight এর পরিবর্তে pw.FontWeight হবে
            pw.Text('Total Expense: BDT ${totalExpense.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: banglaFont)),
            pw.Text('Total Salary: BDT ${totalSalary.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: banglaFont)),
            pw.Text('Net Balance (Profit - Expense - Salary): BDT ${(totalProfit - (totalExpense + totalSalary)).toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: banglaFont)),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}