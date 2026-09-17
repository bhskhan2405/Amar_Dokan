import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_register_screen.dart';
import 'dashboard_screen.dart';
import 'staff_dashboard_screen.dart';
import 'pos_screen.dart';
import 'customers_screen.dart';
import 'products_screen.dart';
import 'hisab_kitab.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;

    if (!isLoggedIn) {
      return const LoginRegisterScreen();
    }

    String role = prefs.getString('role') ?? 'admin';

    if (role == 'admin') {
      return const DashboardScreen();
    } else {
      // স্টাফের জন্য পারমিশন এবং ডাটা চেক করা
      bool canProductList = prefs.getBool('can_product_list') ?? false;
      bool canPosSale = prefs.getBool('can_pos_sale') ?? false;
      bool canAccounts = prefs.getBool('can_accounts') ?? false;
      bool canCustomer = prefs.getBool('can_customer') ?? false;

      // স্টাফের প্রয়োজনীয় তথ্য রিকভার করা (লগইন ছাড়াই)
      final adminUid = prefs.getString('admin_uid') ?? '';
      final staffId = prefs.getString('staff_id') ?? '';
      final staffName = prefs.getString('staff_name') ?? 'Staff';
      
      Map<String, dynamic> staffData = {
        'id': staffId,
        'name': staffName,
        'permissions': {
          'product_list': canProductList,
          'pos_sale': canPosSale,
          'accounts': canAccounts,
          'customer': canCustomer,
        }
      };

      int allowedCount = 0;
      if (canProductList) allowedCount++;
      if (canPosSale) allowedCount++;
      if (canAccounts) allowedCount++;
      if (canCustomer) allowedCount++;

      if (allowedCount > 1) {
        return const StaffDashboardScreen();
      } else {
        if (canPosSale) {
          return POSScreen(currentStaff: staffData);
        } else if (canCustomer) {
          return const CustomerScreen();
        } else if (canProductList) {
          return const ProductsScreen();
        } else if (canAccounts) {
          return const HisabKitabPage();
        } else {
          return const StaffDashboardScreen();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _checkLoginStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
            ),
          );
        }
        return snapshot.data ?? const LoginRegisterScreen();
      },
    );
  }
}