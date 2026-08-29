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
      return currentUser.uid;
    }
    
    // ৩. ব্যাকআপ: যদি অথেন্টিকেশন না থাকে কিন্তু admin_uid সেভ করা থাকে
    if (adminUid != null && adminUid.isNotEmpty) {
      return adminUid;
    }
    
    return '';
  }
}
