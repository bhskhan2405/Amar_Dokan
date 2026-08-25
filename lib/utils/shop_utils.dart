import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopUtils {
  static Future<String> getShopId() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    
    if (role == 'staff') {
      final adminUid = prefs.getString('admin_uid');
      if (adminUid != null && adminUid.isNotEmpty) {
        return adminUid;
      }
    }
    
    // যদি রোল 'admin' হয় অথবা কিছু না থাকে, তবে বর্তমান ইউজারের UID ই শপ আইডি
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // নিশ্চিত করা যে রোলটি admin হিসেবে সেট আছে
      if (role == null) {
        await prefs.setString('role', 'admin');
      }
      return currentUser.uid;
    }
    
    return '';
  }
}
