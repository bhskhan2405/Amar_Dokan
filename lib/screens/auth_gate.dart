import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_register_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0D47A1)),
            ),
          );
        }

        // অ্যাপ ওপেন করলেই প্রতিবার পিন বা ফিঙ্গারপ্রিন্ট ভেরিফিকেশনের জন্য লগইন স্ক্রিন দেখাবে
        return const LoginRegisterScreen();
      },
    );
  }
}