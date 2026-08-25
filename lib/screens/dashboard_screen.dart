import 'dart:convert'; // বেসডিকোড ছবির জন্য
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/translations.dart';
import '../utils/subscription_utils.dart';
import '../utils/notification_utils.dart';
import 'subscription_screen.dart';
import 'notifications_screen.dart';

import 'pos_screen.dart';
import 'products_screen.dart';
import 'hisab_kitab.dart';
import 'customers_screen.dart';
import 'settings_screen.dart';
import 'manage_staffs_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String shopName = '';
  String ownerName = 'Admin';
  String email = '';
  String? _base64ImageString;
  bool _isOnline = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  int _trialRemaining = 7;

  @override
  void initState() {
    super.initState();
    shopName = AppTranslations.get('app_name');
    _loadUserData();
    _checkConnectivity();
    _checkTrialStatus();
  }

  Future<void> _checkTrialStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await SubscriptionUtils.syncSubscriptionStatus(user.uid);
      _trialRemaining = await SubscriptionUtils.getTrialDaysRemaining();
      setState(() {});
    }
  }

  void _checkConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      setState(() {
        _isOnline = !results.contains(ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        email = user.email ?? '';
      });
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            setState(() {
              shopName = data['shopName'] ?? data['storeName'] ?? 'B H S COMPUTER';
              ownerName = data['name'] ?? data['ownerName'] ?? 'B H S Khan';
              _base64ImageString = data['photoBase64'];
            });
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    // প্রোফাইল ছবি সেটআপ
    ImageProvider? profileImage;
    if (_base64ImageString != null && _base64ImageString!.isNotEmpty) {
      try {
        profileImage = MemoryImage(base64Decode(_base64ImageString!));
      } catch (_) {
        profileImage = null;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(AppTranslations.get('app_name') + ' ' + AppTranslations.get('dashboard'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        actions: [
          FutureBuilder<bool>(
            future: SubscriptionUtils.isSuperAdmin(),
            builder: (context, adminSnapshot) {
              bool isSuperAdmin = adminSnapshot.data ?? false;
              return StreamBuilder<int>(
                stream: isSuperAdmin 
                    ? NotificationUtils.getAdminUnreadCountStream() 
                    : NotificationUtils.getUnreadCountStream(),
                builder: (context, snapshot) {
                  int unreadCount = snapshot.data ?? 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => NotificationsScreen(isAdmin: isSuperAdmin)),
                          );
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                }
              );
            }
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Chip(
              label: Text(
                _isOnline ? AppTranslations.get('online') : AppTranslations.get('offline'),
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: _isOnline ? Colors.green : Colors.red,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTrialBanner(),
            _buildLowStockAlert(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50, // বক্সের কালার পরিবর্তন করা হয়েছে
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: profileImage,
                    child: profileImage == null
                        ? Text(
                      ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'B',
                      style: const TextStyle(fontSize: 28, color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
                    )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // দোকানের নাম বড় এবং বোল্ড করা হয়েছে
                        Text(
                          shopName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // মালিকের নাম ছোট করা হয়েছে
                        Text(
                          '${AppTranslations.get('owner')}: $ownerName',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppTranslations.get('menu_choose'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.1,
              children: [
              _buildDashboardCard(
                context,
                title: AppTranslations.get('products'),
                icon: Icons.inventory_2_outlined,
                iconColor: Colors.orange.shade800,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProductsScreen()),
                  );
                },
              ),
              _buildDashboardCard(
                context,
                title: AppTranslations.get('pos'),
                icon: Icons.point_of_sale,
                iconColor: Colors.green.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const POSScreen()),
                  );
                },
              ),
              _buildDashboardCard(
                context,
                title: AppTranslations.get('hisab'),
                icon: Icons.bar_chart,
                iconColor: Colors.purple.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HisabKitabPage()),
                  );
                },
              ),
              _buildDashboardCard(
                context,
                title: AppTranslations.get('customers'),
                icon: Icons.people_outline,
                iconColor: Colors.teal.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CustomerScreen()),
                  );
                },
              ),
                _buildDashboardCard(
                  context,
                  title: AppTranslations.get('staff'),
                  icon: Icons.badge_outlined,
                  iconColor: Colors.indigo.shade700,
                  isPremium: true,
                  onTap: () async {
                    if (await SubscriptionUtils.isPremium()) {
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ManageStaffsScreen()),
                      );
                    } else {
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                      );
                    }
                  },
                ),
                _buildDashboardCard(
                  context,
                  title: AppTranslations.get('settings'),
                  icon: Icons.settings_outlined,
                  iconColor: Colors.blueGrey.shade700,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialBanner() {
    return FutureBuilder<List<bool>>(
      future: Future.wait([
        SubscriptionUtils.isSuperAdmin(),
        SubscriptionUtils.isPaidPremium(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        bool isSuperAdmin = snapshot.data![0];
        bool isPaidPremium = snapshot.data![1];

        // সুপার এডমিন বা পেইড মেম্বার হলে ব্যানার দেখানোর দরকার নেই
        if (isSuperAdmin || isPaidPremium) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppTranslations.get('trial_remaining').replaceAll('@days', _trialRemaining.toString()),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                },
                child: Text(AppTranslations.get('buy_premium')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLowStockAlert() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final lowStockProducts = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          double stock = double.tryParse(data['stock'].toString()) ?? 0;
          double limit = double.tryParse((data['lowStockLimit'] ?? 5).toString()) ?? 5;
          return stock <= limit;
        }).toList();

        if (lowStockProducts.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.get('low_stock_alert'),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    Text(
                      AppTranslations.get('low_stock_msg').replaceAll('@count', lowStockProducts.length.toString()),
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProductsScreen()),
                  );
                },
                child: const Text('দেখুন'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color iconColor,
        required VoidCallback onTap,
        bool isPremium = false,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10), // বৃত্ত ছোট করার জন্য প্যাডিং কমানো হলো
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                          border: Border.all(color: Colors.blueGrey.shade300)
                      ),
                      child: Icon(icon, size: 60, color: iconColor), // আইকন বড় করার জন্য সাইজ ৪০ করা হলো
                    ),
                    if (isPremium)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SubscriptionUtils.premiumIcon(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}