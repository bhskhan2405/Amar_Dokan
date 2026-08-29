import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'staff_dashboard_screen.dart';
import 'pos_screen.dart';
import 'hisab_kitab.dart';
import 'products_screen.dart';
import 'customers_screen.dart'; // যদি ফাইলের নাম customers_screen.dart হয়
import '../utils/translations.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopCodeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  bool _rememberShopId = false;
  bool _rememberUsername = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedShopId = prefs.getString('staff_saved_shop_id');
    String? savedUsername = prefs.getString('staff_saved_username');

    setState(() {
      if (savedShopId != null) {
        _shopCodeController.text = savedShopId;
        _rememberShopId = true;
      }
      if (savedUsername != null) {
        _usernameController.text = savedUsername;
        _rememberUsername = true;
      }
    });
  }

  @override
  void dispose() {
    _shopCodeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loginStaff() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String shopCode = _shopCodeController.text.trim();
        String username = _usernameController.text.trim();
        String password = _passwordController.text.trim();

        var staffQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(shopCode)
            .collection('staffs')
            .where('username', isEqualTo: username)
            .where('password', isEqualTo: password)
            .get();

        if (staffQuery.docs.isNotEmpty) {
          var staffData = staffQuery.docs.first.data();
          staffData['id'] = staffQuery.docs.first.id; // ID যোগ করা হলো
          var permissions = staffData['permissions'] ?? {};

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('admin_uid', shopCode);
          await prefs.setString('role', 'staff');
          await prefs.setString('staff_name', staffData['name'] ?? 'Staff');
          await prefs.setString('staff_id', staffData['id'] ?? '');

          bool canProductList = permissions['product_list'] ?? false;
          bool canPosSale = permissions['pos_sale'] ?? false;
          bool canAccounts = permissions['accounts'] ?? false;
          bool canCustomer = permissions['customer'] ?? permissions['can_customer'] ?? false;

          await prefs.setBool('can_product_list', canProductList);
          await prefs.setBool('can_pos_sale', canPosSale);
          await prefs.setBool('can_accounts', canAccounts);
          await prefs.setBool('can_customer', canCustomer);

          // এডমিনের সাবস্ক্রিপশন স্ট্যাটাস সিঙ্ক করা
          try {
            final adminDoc = await FirebaseFirestore.instance.collection('users').doc(shopCode).get();
            if (adminDoc.exists) {
              final adminData = adminDoc.data();
              if (adminData != null) {
                if (adminData.containsKey('trialStartDate')) {
                  await prefs.setString('trial_start_date', (adminData['trialStartDate'] as Timestamp).toDate().toIso8601String());
                }
                if (adminData.containsKey('subscriptionExpiryDate')) {
                  await prefs.setString('subscription_expiry_date', (adminData['subscriptionExpiryDate'] as Timestamp).toDate().toIso8601String());
                }
              }
            }
          } catch (_) {}

          // শপ আইডি এবং ইউজারনেম সেভ করা (Feature: Remember Me)
          if (_rememberShopId) {
            await prefs.setString('staff_saved_shop_id', shopCode);
          } else {
            await prefs.remove('staff_saved_shop_id');
          }

          if (_rememberUsername) {
            await prefs.setString('staff_saved_username', username);
          } else {
            await prefs.remove('staff_saved_username');
          }

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('staff_login_success') ?? 'Staff login successful!')),
          );

          // পারমিশন অনুযায়ী সঠিক স্ক্রিনে রিডাইরেক্ট করা
          int allowedCount = 0;
          if (canProductList) allowedCount++;
          if (canPosSale) allowedCount++;
          if (canAccounts) allowedCount++;
          if (canCustomer) allowedCount++;

          if (allowedCount > 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const StaffDashboardScreen()),
            );
          } else {
            Widget targetScreen;
            if (canPosSale) {
              targetScreen = POSScreen(currentStaff: staffData);
            } else if (canCustomer) {
              targetScreen = const CustomerScreen();
            } else if (canProductList) {
              targetScreen = const ProductsScreen();
            } else if (canAccounts) {
              targetScreen = const HisabKitabPage();
            } else {
              targetScreen = const StaffDashboardScreen();
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => targetScreen),
            );
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('invalid_staff_login') ?? 'Invalid Shop ID, Username or Password!'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ত্রুটি: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get('staff_login_btn'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.store, size: 80, color: Color(0xFF0D47A1)),
                  const SizedBox(height: 20),
                  Text(
                    AppTranslations.get('shop_staff_portal') ?? 'Shop Staff Portal',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _shopCodeController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.get('shop_id_admin') ?? 'Shop ID (Admin UID)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.business),
                          ),
                          validator: (val) => val!.isEmpty ? AppTranslations.get('shop_id_required') ?? 'Enter Shop ID' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Checkbox(
                            value: _rememberShopId,
                            activeColor: const Color(0xFF0D47A1),
                            onChanged: (val) => setState(() => _rememberShopId = val ?? false),
                          ),
                          Text(AppTranslations.get('save'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.get('username'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person),
                          ),
                          validator: (val) => val!.isEmpty ? AppTranslations.get('username_required') : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Checkbox(
                            value: _rememberUsername,
                            activeColor: const Color(0xFF0D47A1),
                            onChanged: (val) => setState(() => _rememberUsername = val ?? false),
                          ),
                          Text(AppTranslations.get('save'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: AppTranslations.get('password_pin'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    validator: (val) => val!.isEmpty ? AppTranslations.get('password_required') : null,
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isLoading ? null : _loginStaff,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(AppTranslations.get('login'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}