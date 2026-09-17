import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopUtils {
  static const String KEY_SHOP_NAME = 'cached_shop_name';
  static const String KEY_OWNER_NAME = 'cached_owner_name';
  static const String KEY_EMAIL = 'cached_email';
  static const String KEY_PHOTO = 'cached_photo';

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

  // শপের বিস্তারিত তথ্য লোকাল মেমোরিতে সেভ করা
  static Future<void> saveShopDetails({
    required String name,
    required String owner,
    required String email,
    String? photoBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(KEY_SHOP_NAME, name);
    await prefs.setString(KEY_OWNER_NAME, owner);
    await prefs.setString(KEY_EMAIL, email);
    if (photoBase64 != null) {
      await prefs.setString(KEY_PHOTO, photoBase64);
    }
  }

  // লোকাল মেমোরি থেকে শপ ডিটেইলস পড়া
  static Future<Map<String, String>> getCachedShopDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(KEY_SHOP_NAME) ?? '',
      'owner': prefs.getString(KEY_OWNER_NAME) ?? 'Admin',
      'email': prefs.getString(KEY_EMAIL) ?? '',
      'photo': prefs.getString(KEY_PHOTO) ?? '',
    };
  }
}
