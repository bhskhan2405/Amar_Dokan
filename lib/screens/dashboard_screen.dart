import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/translations.dart';
import '../utils/subscription_utils.dart';
import '../utils/notification_utils.dart';
import '../widgets/custom_banner_ad.dart';
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
  bool _isApproved = true;
  String _userPhone = '';
  String _userName = '';
  String _shopName = '';

  @override
  void initState() {
    super.initState();
    shopName = AppTranslations.get('app_name');
    _loadUserData();
    _checkConnectivity();
    _checkTrialStatus();
    _checkApprovalStatus();
  }

  Future<void> _checkApprovalStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (doc.exists && mounted) {
          setState(() {
            _isApproved = doc.data()?['isApproved'] ?? true; // পুরাতন ইউজারদের জন্য ডিফল্ট true
            _userPhone = doc.data()?['phone'] ?? '';
            _userName = doc.data()?['name'] ?? '';
            _shopName = doc.data()?['shopName'] ?? '';
          });
        }
      });
    }
  }

  Future<void> _checkTrialStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await SubscriptionUtils.syncSubscriptionStatus(user.uid);
      int remaining = await SubscriptionUtils.getTrialDaysRemaining();
      if (mounted) {
        setState(() {
          _trialRemaining = remaining;
        });
      }
    }
  }

  void _checkConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() {
          _isOnline = !results.contains(ConnectivityResult.none);
        });
      }
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
      if (mounted) setState(() => email = user.email ?? '');
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
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
        title: Text('${AppTranslations.get('app_name')} ${AppTranslations.get('dashboard')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const CustomBannerAd(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTrialBanner(),
                      _buildLowStockAlert(),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200, width: 1.5),
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
                                  Text(shopName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                                  const SizedBox(height: 4),
                                  Text('${AppTranslations.get('owner')}: $ownerName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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
                          _buildDashboardCard(context, title: AppTranslations.get('products'), icon: Icons.inventory_2_outlined, iconColor: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsScreen()))),
                          _buildDashboardCard(context, title: AppTranslations.get('pos'), icon: Icons.point_of_sale, iconColor: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const POSScreen()))),
                          _buildDashboardCard(context, title: AppTranslations.get('hisab'), icon: Icons.bar_chart, iconColor: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HisabKitabPage()))),
                          _buildDashboardCard(context, title: AppTranslations.get('customers'), icon: Icons.people_outline, iconColor: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerScreen()))),
                          _buildDashboardCard(
                            context, 
                            title: AppTranslations.get('staff'), 
                            icon: Icons.badge_outlined, 
                            iconColor: Colors.indigo, 
                            isPremium: true,
                            onTap: () async {
                              if (await SubscriptionUtils.isPremium()) {
                                if (!context.mounted) return;
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageStaffsScreen()));
                              } else {
                                if (!context.mounted) return;
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
                              }
                            }
                          ),
                          _buildDashboardCard(context, title: AppTranslations.get('settings'), icon: Icons.settings_outlined, iconColor: Colors.blueGrey, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!_isApproved) _buildPendingOverlay(),
        ],
      ),
    );
  }

  Widget _buildPendingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty_rounded, size: 80, color: Colors.amber),
          const SizedBox(height: 24),
          const Text(
            'অ্যাকাউন্ট অনুমোদনের অপেক্ষায়',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'PENDING',
            style: TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
          const SizedBox(height: 24),
          const Text(
            'আপনার অ্যাকাউন্টটি বর্তমানে আমাদের টিমের পর্যালোচনার অধীনে রয়েছে। ১ ঘণ্টার বেশি হয়ে গেলে নিচের WhatsApp বাটনে ক্লিক করে আমাদের জানান।',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _launchWhatsApp,
            icon: const Icon(Icons.message_rounded),
            label: const Text('WhatsApp-এ যোগাযোগ করুন'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('লগ আউট করুন', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  void _launchWhatsApp() async {
    final message = "আসসালামু আলাইকুম। আমার দোকান অ্যাপে আমি রেজিস্ট্রেশন করেছি, দয়া করে আমার অ্যাকাউন্টটি এপ্রুভ করে দিন।\n\n"
        "দোকানের নাম: $_shopName\n"
        "মালিকের নাম: $_userName\n"
        "মোবাইল নম্বর: $_userPhone";
    
    final encodedMsg = Uri.encodeComponent(message);
    final url = "https://wa.me/${SubscriptionUtils.WHATSAPP_CONTACT}?text=$encodedMsg";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildTrialBanner() {
    return FutureBuilder<List<bool>>(
      future: Future.wait([SubscriptionUtils.isSuperAdmin(), SubscriptionUtils.isPaidPremium()]),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data![0] || snapshot.data![1]) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade300)),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(child: Text(AppTranslations.get('trial_remaining').replaceAll('@days', _trialRemaining.toString()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen())), child: Text(AppTranslations.get('buy_premium'))),
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
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products').snapshots(),
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
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppTranslations.get('low_stock_alert'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Text(AppTranslations.get('low_stock_msg').replaceAll('@count', lowStockProducts.length.toString()), style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                  ],
                ),
              ),
              TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductsScreen())), child: const Text('দেখুন')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required String title, required IconData icon, required Color iconColor, required VoidCallback onTap, bool isPremium = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(icon, size: 40, color: iconColor),
                ),
                if (isPremium) Positioned(top: 0, right: 0, child: SubscriptionUtils.premiumIcon()),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
