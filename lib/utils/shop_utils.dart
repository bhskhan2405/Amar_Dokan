import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopUtils {
  static Future<String> getShopId() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final adminUid = prefs.getString('admin_uid');
    
    // ১. যদি ইউজার স্টাফ হয়, তবে এডমিনের UID ই শপ আইডি
    if (role == 'staff') {
      if (adminUid != null && adminUid.isNotEmpty) {
        return adminUid;
      }
    }
    
    // ২. বর্তমান ইউজারের UID চেক করা (অ্যাডমিনদের জন্য)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // যদি রোল সেট না থাকে, তবে এডমিন হিসেবে সেট করা
      if (role == null) {
        await prefs.setString('role', 'admin');
      }
      // অফলাইনের জন্য UID ব্যাকআপ হিসেবে সেভ রাখা
      await prefs.setString('admin_uid', currentUser.uid);
      return currentUser.uid;
    }
    
    // ৩. ব্যাকআপ: যদি অথেন্টিকেশন না থাকে কিন্তু admin_uid সেভ করা থাকে
    if (adminUid != null && adminUid.isNotEmpty) {
      return adminUid;
    }
    
    // ৪. এক্সট্রিম ব্যাকআপ (যদি সব ফেইল করে, তবে FirebaseAuth এর লাস্ট সেশন চেক করা)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await prefs.setString('admin_uid', user.uid);
        return user.uid;
      }
    } catch (_) {}
    
    return adminUid ?? '';
  }

  // শপ আইডি সেভ করার জন্য একটি স্ট্যাটিক মেথড (যেকোনো জায়গা থেকে কল করা যাবে)
  static Future<void> saveShopId(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_uid', uid);
  }
}
