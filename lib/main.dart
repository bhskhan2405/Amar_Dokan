import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ফায়ারবেস অথ ইমপোর্ট করা হলো
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ফায়ারস্টোর ইমপোর্ট করা হলো
import 'screens/auth_gate.dart';
import 'utils/translations.dart';

// গ্লোবাল হেল্পার ফাংশন: এটি চেক করবে ইউজার নিজে দোকানদার নাকি কোনো স্টাফ।
// স্টাফ হলে মূল দোকানদারের shopId রিটার্ন করবে, নতুবা নিজের uid রিটার্ন করবে।
Future<String> getEffectiveShopId() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return '';

  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      var data = userDoc.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('shopId') && data['shopId'] != null) {
        return data['shopId'].toString();
      }
    }
  } catch (_) {}

  return user.uid;
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  HttpOverrides.global = MyHttpOverrides();

  // ফায়ারবেস ইনিশিয়ালাইজ করা হলো
  await Firebase.initializeApp();

  // অফলাইন সাপোর্ট চালু করা হলো (Feature 2)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  // ভাষা লোড করা
  await AppTranslations.loadLanguage();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _updateLocale();
  }

  void _updateLocale() {
    String langCode = AppTranslations.currentLanguage;
    _locale = langCode == 'bn' ? const Locale('bn', 'BD') : const Locale('en', 'US');
  }

  void setLocale(Locale locale) {
    setState(() {
      AppTranslations.currentLanguage = locale.languageCode;
      _updateLocale();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppTranslations.get('app_name'),
      theme: ThemeData(primarySwatch: Colors.blue),
      locale: _locale,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('bn', 'BD'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
      // লগআউটের পর রিডাইরেক্ট হওয়ার জন্য রাউট যোগ করা হলো
      routes: {
        '/login': (context) => const AuthGate(),
      },
    );
  }
}
