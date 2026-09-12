import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // navigatorKey এর জন্য
import '../screens/notification_detail_screen.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. পারমিশন রিকোয়েস্ট (iOS এবং Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // ignore: avoid_print
      print('User granted notification permission');
    }

    // 2. লোকাল নোটিফিকেশন সেটআপ (ফোরগ্রাউন্ডে দেখানোর জন্য)
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // লোকাল নোটিফিকেশন ক্লিক করলে
        _handleNotificationClick(null);
      },
    );

    // অ্যান্ড্রয়েড চ্যানেল তৈরি
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', 
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // 3. ফোরগ্রাউন্ড মেসেজ হ্যান্ডলিং
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });

    // 4. ব্যাকগ্রাউন্ডে মেসেজ ক্লিক করলে অ্যাপ ওপেন হওয়া
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // ৫. অ্যাপ টার্মিনেটেড অবস্থা থেকে ক্লিক করে ওপেন করলে
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationClick(message);
      }
    });

    // 6. টোকেন আপডেট করা (অথ চেঞ্জ হলে অটো আপডেট হবে)
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        updateToken();
      }
    });

    updateToken();
  }

  // FCM টোকেন ফায়ারস্টোরে সেভ করা
  static Future<void> updateToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');
      final adminUid = prefs.getString('admin_uid');
      final staffId = prefs.getString('staff_id');

      final user = FirebaseAuth.instance.currentUser;

      // ১. অ্যাডমিনের জন্য টোকেন সেভ (Firebase Auth)
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } 
      
      // ২. স্টাফের জন্য টোকেন সেভ (Firestore Staff Collection)
      if (role == 'staff' && adminUid != null && staffId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(adminUid)
            .collection('staffs')
            .doc(staffId)
            .set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error updating FCM token: $e");
    }
  }

  // নোটিফিকেশন ক্লিক হ্যান্ডেল করা
  static void _handleNotificationClick(RemoteMessage? message) {
    if (navigatorKey.currentState == null) return;

    Map<String, dynamic> data = {};
    if (message != null) {
      data = {
        'title': message.notification?.title,
        'message': message.notification?.body,
        'timestamp': DateTime.now(),
      };
    }

    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => NotificationDetailScreen(notificationData: data),
      ),
    );
  }
}
