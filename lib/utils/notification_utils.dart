import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationUtils {
  static const String ADMIN_ID = "admin";
  static const String TARGET_ALL = "all";

  // নোটিফিকেশন পাঠানো
  static Future<void> sendNotification({
    required String title,
    required String message,
    required String targetUid,
    String? type,
  }) async {
    if (targetUid.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'message': message,
        'targetUid': targetUid,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type ?? 'general',
      });
    } catch (e) {
      // ignore: avoid_print
      print("Notification error: $e");
    }
  }

  // এডমিনকে নোটিফিকেশন পাঠানো
  static Future<void> notifyAdmin({required String title, required String message}) async {
    await sendNotification(title: title, message: message, targetUid: ADMIN_ID, type: 'admin_alert');
  }

  // সব ইউজারকে আপডেট পাঠানো
  static Future<void> sendAppUpdate({required String title, required String message}) async {
    await sendNotification(title: title, message: message, targetUid: TARGET_ALL, type: 'app_update');
  }

  // ইউজারের নোটিফিকেশন স্ট্রিম
  static Stream<QuerySnapshot> getNotificationsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUid', whereIn: [user.uid, TARGET_ALL])
        .orderBy('timestamp', descending: true)
        .snapshots()
        .handleError((error) {
          // ignore: avoid_print
          print("Firestore stream error: $error");
        });
  }

  // এডমিনের নোটিফিকেশন স্ট্রিম
  static Stream<QuerySnapshot> getAdminNotificationsStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUid', isEqualTo: ADMIN_ID)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .handleError((error) {
          // ignore: avoid_print
          print("Admin Firestore stream error: $error");
        });
  }

  // অপঠিত নোটিফিকেশনের সংখ্যা (ইউজার)
  static Stream<int> getUnreadCountStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUid', whereIn: [user.uid, TARGET_ALL])
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // অপঠিত নোটিফিকেশনের সংখ্যা (এডমিন)
  static Stream<int> getAdminUnreadCountStream() {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUid', isEqualTo: ADMIN_ID)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // নোটিফিকেশন পড়া হয়েছে হিসেবে মার্ক করা
  static Future<void> markAsRead(String notifId) async {
    await FirebaseFirestore.instance.collection('notifications').doc(notifId).update({
      'isRead': true,
    });
  }

  // সব নোটিফিকেশন পড়া হয়েছে হিসেবে মার্ক করা
  static Future<void> markAllAsRead(bool isAdmin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && !isAdmin) return;

    final query = isAdmin 
        ? FirebaseFirestore.instance.collection('notifications').where('targetUid', isEqualTo: ADMIN_ID)
        : FirebaseFirestore.instance.collection('notifications').where('targetUid', isEqualTo: user!.uid);

    final snapshot = await query.where('isRead', isEqualTo: false).get();
    
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // নোটিফিকেশন ডিলিট করা
  static Future<void> deleteNotification(String notifId) async {
    await FirebaseFirestore.instance.collection('notifications').doc(notifId).delete();
  }

  // একাধিক নোটিফিকেশন ডিলিট করা
  static Future<void> deleteMultipleNotifications(List<String> notifIds) async {
    final batch = FirebaseFirestore.instance.batch();
    for (String id in notifIds) {
      batch.delete(FirebaseFirestore.instance.collection('notifications').doc(id));
    }
    await batch.commit();
  }

  // সব নোটিফিকেশন ডিলিট করা
  static Future<void> deleteAllNotifications(bool isAdmin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && !isAdmin) return;

    final query = isAdmin 
        ? FirebaseFirestore.instance.collection('notifications').where('targetUid', isEqualTo: ADMIN_ID)
        : FirebaseFirestore.instance.collection('notifications').where('targetUid', isEqualTo: user!.uid);

    final snapshot = await query.get();
    
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
