import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/translations.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'hisab_kitab.dart';
import 'customers_screen.dart';
import 'settings_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  String shopName = '';
  String staffName = 'Staff';
  Map<String, dynamic>? _currentStaffData;
  
  bool canProduct = false;
  bool canPos = false;
  bool canHisab = false;
  bool canCustomer = false;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    final prefs = await SharedPreferences.getInstance();
    final adminUid = prefs.getString('admin_uid') ?? '';
    final username = prefs.getString('staff_saved_username') ?? '';

    setState(() {
      canProduct = prefs.getBool('can_product_list') ?? false;
      canPos = prefs.getBool('can_pos_sale') ?? false;
      canHisab = prefs.getBool('can_accounts') ?? false;
      canCustomer = prefs.getBool('can_customer') ?? false;
    });

    if (adminUid.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(adminUid).get();
        if (doc.exists) {
          setState(() {
            shopName = doc.data()?['shopName'] ?? 'Amar Dokan';
          });
        }
        
        final staffQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(adminUid)
            .collection('staffs')
            .where('username', isEqualTo: username)
            .get();
            
        if (staffQuery.docs.isNotEmpty) {
          setState(() {
            _currentStaffData = staffQuery.docs.first.data();
            _currentStaffData!['id'] = staffQuery.docs.first.id;
            staffName = _currentStaffData!['name'] ?? 'Staff';
          });
        }
      } catch (_) {}
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(AppTranslations.get('app_name') + ' - ' + AppTranslations.get('staff'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String? lang = prefs.getString('language_code');
              await prefs.clear();
              if (lang != null) await prefs.setString('language_code', lang);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.shade200, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.indigo.shade100,
                          child: const Icon(Icons.badge, color: Color(0xFF0D47A1), size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                              Text('${AppTranslations.get('staff')}: $staffName', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(AppTranslations.get('menu_choose'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.1,
                    children: [
                      if (canProduct) _buildCard(AppTranslations.get('products'), Icons.inventory_2_outlined, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsScreen()))),
                      if (canPos) _buildCard(AppTranslations.get('pos'), Icons.point_of_sale, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (context) => POSScreen(currentStaff: _currentStaffData)))),
                      if (canHisab) _buildCard(AppTranslations.get('hisab'), Icons.bar_chart, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HisabKitabPage()))),
                      if (canCustomer) _buildCard(AppTranslations.get('customers'), Icons.people_outline, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerScreen()))),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
