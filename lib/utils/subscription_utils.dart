import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionUtils {
  static const String SUPER_ADMIN_PHONE = "01828424364";
  static const String WHATSAPP_CONTACT = "8801875787997";

  static Future<bool> isSuperAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    String phone = prefs.getString('saved_phone') ?? '';
    
    if (phone.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          phone = doc.data()?['phone'] ?? '';
          await prefs.setString('saved_phone', phone);
        }
      }
    }
    return phone == SUPER_ADMIN_PHONE || phone == "01828424364";
  }

  static Future<bool> isPaidPremium() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryDateStr = prefs.getString('subscription_expiry_date');

    if (expiryDateStr != null) {
      try {
        DateTime expiry = DateTime.parse(expiryDateStr);
        if (DateTime.now().isBefore(expiry)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  static Future<bool> isPremium() async {
    // সুপার এডমিন বা পেইড মেম্বার হলে প্রিমিয়াম
    if (await isSuperAdmin()) return true;
    if (await isPaidPremium()) return true;

    // ট্রায়াল অফ করে দেওয়া হয়েছে
    return false;
  }

  static Future<int> getTrialDaysRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    
    // সুপার এডমিন বা পেইড মেম্বার হলে ট্রায়ালের হিসাব দরকার নেই
    if (await isSuperAdmin() || await isPaidPremium()) return 0;

    final trialStartDateStr = prefs.getString('trial_start_date');
    if (trialStartDateStr == null) return 0;

    try {
      DateTime trialStart = DateTime.parse(trialStartDateStr);
      int daysUsed = DateTime.now().difference(trialStart).inDays;
      int remaining = 7 - daysUsed;
      return remaining < 0 ? 0 : remaining;
    } catch (_) {
      return 0;
    }
  }

  // ফায়ারস্টোর থেকে সাবস্ক্রিপশন ডাটা সিঙ্ক করা
  static Future<void> syncSubscriptionStatus(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        final prefs = await SharedPreferences.getInstance();
        
        if (data != null) {
          if (data.containsKey('trialStartDate')) {
            await prefs.setString('trial_start_date', (data['trialStartDate'] as Timestamp).toDate().toIso8601String());
          }
          if (data.containsKey('subscriptionExpiryDate')) {
            await prefs.setString('subscription_expiry_date', (data['subscriptionExpiryDate'] as Timestamp).toDate().toIso8601String());
          }
        }
      }
    } catch (_) {}
  }

  static Widget premiumIcon() {
    return FutureBuilder<bool>(
      future: isPremium(),
      builder: (context, snapshot) {
        // লোডিং হওয়ার সময় বা প্রিমিয়াম ইউজার হলে আইকন দেখানোর দরকার নেই
        if (!snapshot.hasData || snapshot.data == true) return const SizedBox.shrink();
        
        return const Padding(
          padding: EdgeInsets.only(left: 4.0),
          child: Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 16),
        );
      },
    );
  }
}
