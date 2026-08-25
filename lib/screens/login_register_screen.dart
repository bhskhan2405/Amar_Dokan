import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_screen.dart';
import '../main.dart';
import 'staff_login_screen.dart'; // স্টাফ লগইন স্ক্রিন ইমপোর্ট করা হলো[cite: 6]
import '../utils/translations.dart';
import '../utils/notification_utils.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  // কন্ট্রোলারসমূহ
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _loginPhoneController = TextEditingController();
  final _loginPinController = TextEditingController();

  static const String ADMIN_PHONE = "8801875787997"; // কান্ট্রি কোডসহ হোয়াটসঅ্যাপ নম্বর

  bool isLogin = true;
  bool isLoading = false;
  bool _rememberPhone = false;
  final LocalAuthentication auth = LocalAuthentication();

  // OTP ভেরিফিকেশন ভেরিয়েবল
  String _verificationId = "";
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  // ফোন নম্বর নরমালাইজ করা (যেমন: +88018... থেকে শুধু 018... করা)
  String _normalizePhone(String phone) {
    phone = phone.trim();
    if (phone.startsWith('+88')) {
      phone = phone.substring(3);
    }
    if (!phone.startsWith('0') && phone.length == 10) {
      phone = '0$phone';
    }
    return phone;
  }

  // ইমেইল মাস্ক করা (যেমন: bh****an@gmail.com)
  String _maskEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return email;
    
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 4) {
      return '${name[0]}**@$domain';
    }

    final firstTwo = name.substring(0, 2);
    final lastTwo = name.substring(name.length - 2);
    return '$firstTwo****$lastTwo@$domain';
  }

  // সংরক্ষিত মোবাইল নম্বর লোড করা
  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedPhone = prefs.getString('saved_phone');
    bool remember = prefs.getBool('remember_phone') ?? false;

    if (remember && savedPhone != null) {
      setState(() {
        _loginPhoneController.text = _normalizePhone(savedPhone);
        _rememberPhone = true;
      });
    }
  }

  // ফিঙ্গারপ্রিন্ট বা বায়োমেট্রিক অথেন্টিকেশন
  Future<void> _authenticateWithFingerprint() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isDeviceSupported = await auth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        _showSnackBar(AppTranslations.get('biometric_not_supported') ?? 'Biometric not supported');
        return;
      }

      bool didAuthenticate = await auth.authenticate(
        localizedReason: AppTranslations.get('biometric_reason') ?? 'Scan your fingerprint to enter Dashboard',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        final prefs = await SharedPreferences.getInstance();
        String? savedPhone = prefs.getString('saved_phone');

        if (savedPhone == null || savedPhone.isEmpty) {
          savedPhone = _loginPhoneController.text.trim();
        }

        if (savedPhone != null && savedPhone.isNotEmpty) {
          String normalized = _normalizePhone(savedPhone);
          
          setState(() => isLoading = true);

          // প্রথমে এই নম্বর দিয়ে ইউজার খোঁজা
          final querySnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('phone', isEqualTo: normalized)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            final userData = querySnapshot.docs.first.data();
            String email = userData['email'];
            String password = userData['tempPassword'];
            bool isApproved = userData['isApproved'] ?? true; // পুরোনো ইউজারদের জন্য true

            if (!isApproved) {
              _showPendingApprovalDialog(normalized);
              setState(() => isLoading = false);
              return;
            }

            try {
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email,
                password: password,
              );

              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            } catch (e) {
              _showSnackBar('লগইন ত্রুটি: আপনার পাসওয়ার্ড বা পিন রিসেট করা প্রয়োজন।');
            }
          } else {
            _showSnackBar('ইউজার ডেটা পাওয়া যায়নি, একবার পিন দিয়ে লগইন করুন।');
          }
        } else {
          _showSnackBar('সংরক্ষিত নম্বর পাওয়া যায়নি, একবার পিন দিয়ে লগইন করুন।');
        }
      }
    } catch (e) {
      _showSnackBar('ফিঙ্গারপ্রিন্ট ত্রুটি: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // OTP পাঠানো (পুরোনো - এখন আর ব্যবহৃত হচ্ছে না)
  Future<void> _sendOTP() async {
    _showSnackBar("পুরোনো ফোন ওটিপি মেথড বন্ধ রাখা হয়েছে।");
  }

  // ইমেইল ভেরিফিকেশন ডায়ালগ
  void _showVerificationDialog(User user) {
    String maskedEmail = _maskEmail(_emailController.text.trim());
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.get('verify_email_title'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_rounded, size: 56, color: Color(0xFF0D47A1)),
            const SizedBox(height: 12),
            Text(AppTranslations.get('verification_sent_to'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text(maskedEmail, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            const SizedBox(height: 16),
            Text(AppTranslations.get('verify_email_msg'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                AppTranslations.get('spam_instruction'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await user.sendEmailVerification();
              _showSnackBar(AppTranslations.get('otp_sent'));
            },
            child: Text(AppTranslations.get('resend_link')),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => isLoading = true);
              await user.reload();
              final updatedUser = FirebaseAuth.instance.currentUser;
              if (updatedUser != null && updatedUser.emailVerified) {
                Navigator.pop(context);
                await _saveUserDataAfterVerification(updatedUser);
              } else {
                setState(() => isLoading = false);
                _showSnackBar(AppTranslations.get('email_not_verified'));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
            child: Text(AppTranslations.get('verified_btn')),
          ),
        ],
      ),
    );
  }

  // পিন ভুলে গেলে ইমেইল রিকভারি লজিক
  void _showForgotPinDialog() {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('forgot_pin')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppTranslations.get('enter_phone_recovery')),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppTranslations.get('mobile'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          ElevatedButton(
            onPressed: () async {
              String phone = _normalizePhone(phoneController.text.trim());
              if (phone.isEmpty) return;

              Navigator.pop(context);
              setState(() => isLoading = true);

              try {
                final query = await FirebaseFirestore.instance
                    .collection('users')
                    .where('phone', isEqualTo: phone)
                    .get();

                if (query.docs.isNotEmpty) {
                  String email = query.docs.first.data()['email'];
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  _showSnackBar(AppTranslations.get('reset_link_sent'));
                  _showRecoveryInstructionDialog(phone, email);
                } else {
                  _showSnackBar(AppTranslations.get('user_not_found'));
                }
              } catch (e) {
                _showSnackBar('ত্রুটি: $e');
              } finally {
                setState(() => isLoading = false);
              }
            },
            child: Text(AppTranslations.get('confirm')),
          ),
        ],
      ),
    );
  }

  void _showRecoveryInstructionDialog(String phone, String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('forgot_pin')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_rounded, size: 64, color: Color(0xFF0D47A1)),
            const SizedBox(height: 16),
            Text(AppTranslations.get('recovery_instructions'), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPasswordLoginDialog(phone, email);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
            child: Text(AppTranslations.get('password_set_done')),
          ),
        ],
      ),
    );
  }

  void _showPasswordLoginDialog(String phone, String email) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('login_with_password')),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppTranslations.get('enter_password'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          ElevatedButton(
            onPressed: () async {
              String password = passwordController.text.trim();
              if (password.isEmpty) return;

              Navigator.pop(context);
              setState(() => isLoading = true);

              try {
                UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: email,
                  password: password,
                );
                
                if (cred.user != null) {
                  _showSetNewPinDialog(phone);
                }
              } catch (e) {
                _showSnackBar('লগইন ব্যর্থ: $e');
              } finally {
                setState(() => isLoading = false);
              }
            },
            child: Text(AppTranslations.get('login')),
          ),
        ],
      ),
    );
  }

  void _showSetNewPinDialog(String phone) {
    final pin1 = TextEditingController();
    final pin2 = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('set_new_pin_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pin1,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New PIN', counterText: ''),
            ),
            TextField(
              controller: pin2,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New PIN', counterText: ''),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (pin1.text.length == 4 && pin1.text == pin2.text) {
                String newPin = pin1.text;
                Navigator.pop(context);
                setState(() => isLoading = true);

                try {
                  String newTempPass = 'Pass_${phone}_$newPin';
                  User? user = FirebaseAuth.instance.currentUser;
                  
                  if (user != null) {
                    // ১. ফায়ারবেস পাসওয়ার্ড আপডেট
                    await user.updatePassword(newTempPass);
                    
                    // ২. ফায়ারস্টোর আপডেট
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                      'pin': newPin,
                      'tempPassword': newTempPass,
                    });

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('app_pin', newPin);
                    await prefs.setString('saved_phone', phone);

                    _showSnackBar('পিন সফলভাবে পরিবর্তন হয়েছে!');
                    if (!mounted) return;
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
                  }
                } catch (e) {
                  _showSnackBar('পিন সেট করতে ত্রুটি: $e');
                } finally {
                  setState(() => isLoading = false);
                }
              } else {
                _showSnackBar(AppTranslations.get('pin_mismatch_msg'));
              }
            },
            child: Text(AppTranslations.get('save')),
          ),
        ],
      ),
    );
  }

  void _showPendingApprovalDialog(String userPhone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.get('pending_approval_title'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock_rounded, size: 56, color: Colors.orange),
            const SizedBox(height: 16),
            Text(AppTranslations.get('pending_approval_msg'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            const Text('Admin WhatsApp:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            InkWell(
              onTap: () async {
                final Uri url = Uri.parse('https://wa.me/$ADMIN_PHONE?text=${Uri.encodeComponent("আমার অ্যাকাউন্টটি ভেরিফাই করুন।")}');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
              child: Text(
                '+$ADMIN_PHONE',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 18, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 16),
            Text('${AppTranslations.get('mobile')}: $userPhone', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse('tel:+$ADMIN_PHONE');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                  icon: const Icon(Icons.phone),
                  label: Text(AppTranslations.get('call_admin'), style: const TextStyle(fontSize: 12)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    String message = "আমার অ্যাকাউন্টটি ভেরিফাই করুন। নম্বর: $userPhone";
                    final Uri url = Uri.parse('https://wa.me/$ADMIN_PHONE?text=${Uri.encodeComponent(message)}');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                  icon: const Icon(Icons.chat),
                  label: Text(AppTranslations.get('whatsapp_admin'), style: const TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          const Divider(),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppTranslations.get('cancel')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUserDataAfterVerification(User user) async {
    try {
      String shopName = _shopNameController.text.trim();
      String ownerName = _ownerNameController.text.trim();
      String phone = _normalizePhone(_phoneController.text.trim());
      String email = _emailController.text.trim();
      String pin = _pinController.text.trim();
      String tempPassword = 'Pass_${phone}_$pin';
      DateTime now = DateTime.now();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'shopName': shopName,
        'name': ownerName,
        'phone': phone,
        'email': email,
        'pin': pin,
        'tempPassword': tempPassword,
        'isApproved': false, // নতুন রেজিস্ট্রেশন পেন্ডিং থাকবে
        'trialStartDate': FieldValue.serverTimestamp(),
        'subscriptionExpiryDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_pin', pin);
      await prefs.setString('saved_phone', phone);
      await prefs.setBool('remember_phone', true);
      await prefs.setString('trial_start_date', now.toIso8601String());
      await prefs.setString('subscription_expiry_date', now.toIso8601String());

      // এডমিনকে নতুন রেজিস্ট্রেশন রিকোয়েস্ট জানানো
      await NotificationUtils.notifyAdmin(
        title: "নতুন ইউজার রেজিস্ট্রেশন",
        message: "$ownerName ($shopName) অ্যাকাউন্ট অনুমোদনের জন্য আবেদন করেছেন। নম্বর: $phone",
      );

      _showSnackBar(AppTranslations.get('account_created_msg'));
      if (!mounted) return;
      _showPendingApprovalDialog(phone);
    } catch (e) {
      _showSnackBar('ডেটা সেভ করতে ত্রুটি: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ইমেইল OTP পাঠানো (বাতিল করা হয়েছে)
  Future<void> _sendEmailOTP() async {
    // এটি আর ব্যবহৃত হচ্ছে না
  }

  // OTP ইনপুট ডায়ালগ (বাতিল করা হয়েছে)
  void _showOTPDialog({bool isEmail = false}) {
    // এটি আর ব্যবহৃত হচ্ছে না
  }

  // রেজিস্ট্রেশন সম্পন্ন করা (লিংক পাঠানোর জন্য আপডেট করা হয়েছে)
  Future<void> _completeRegistration(PhoneAuthCredential? credential) async {
    try {
      String shopName = _shopNameController.text.trim();
      String ownerName = _ownerNameController.text.trim();
      String phone = _normalizePhone(_phoneController.text.trim());
      String email = _emailController.text.trim();
      String pin = _pinController.text.trim();
      String tempPassword = 'Pass_${phone}_$pin';

      // ১. ইমেইল পাসওয়ার্ড দিয়ে ইউজার তৈরি
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );

      // ২. ভেরিফিকেশন লিংক পাঠানো
      await userCredential.user!.sendEmailVerification();

      // ৩. ডায়ালগ দেখানো
      if (!mounted) return;
      _showVerificationDialog(userCredential.user!);

    } catch (e) {
      _showSnackBar('রেজিস্ট্রেশন ত্রুটি: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // লগইন বা রেজিস্ট্রেশন সাবমিট ফাংশন
  Future<void> _submit() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        String phone = _normalizePhone(_loginPhoneController.text.trim());
        String pin = _loginPinController.text.trim();

        if (phone.isEmpty || pin.length != 4) {
          _showSnackBar(AppTranslations.get('invalid_login_msg'));
          setState(() => isLoading = false);
          return;
        }

        // লগইনের জন্য ইউজার খোঁজা
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phone)
            .get();

        if (querySnapshot.docs.isEmpty) {
          _showSnackBar('এই ফোন নম্বর দিয়ে কোনো অ্যাকাউন্ট পাওয়া যায়নি। দয়া করে নম্বর চেক করুন।');
          setState(() => isLoading = false);
          return;
        }

        final userDoc = querySnapshot.docs.first;
        final userData = userDoc.data();
        final savedPin = userData['pin'];
        final email = userData['email'];
        final password = userData['tempPassword'];
        final bool isApproved = userData['isApproved'] ?? true;

        if (!isApproved) {
          _showPendingApprovalDialog(phone);
          setState(() => isLoading = false);
          return;
        }

        if (pin == savedPin) {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('saved_phone', phone);
            await prefs.setString('role', 'admin'); // এডমিন রোল সেট করা হলো
            
            if (_rememberPhone) {
              await prefs.setBool('remember_phone', true);
            } else {
              await prefs.setBool('remember_phone', false);
            }
            await prefs.setString('app_pin', pin);

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          } catch (e) {
            _showSnackBar('লগইন ব্যর্থ: পাসওয়ার্ড ভেরিফিকেশন ফেইল করেছে। এরর: $e');
          }
        } else {
          _showSnackBar('ভুল পিন (PIN) দিয়েছেন। দয়া করে সঠিক পিন দিয়ে আবার চেষ্টা করুন।');
        }
      } else {
        String shopName = _shopNameController.text.trim();
        String ownerName = _ownerNameController.text.trim();
        String phone = _normalizePhone(_phoneController.text.trim());
        String email = _emailController.text.trim();
        String pin = _pinController.text.trim();
        String confirmPin = _confirmPinController.text.trim();

        if (shopName.isEmpty || ownerName.isEmpty || phone.isEmpty || email.isEmpty) {
          _showSnackBar(email.isEmpty ? "ইমেইল দেওয়া আবশ্যক!" : AppTranslations.get('required_fields_msg'));
          setState(() => isLoading = false);
          return;
        }

        if (pin.length != 4 || pin != confirmPin) {
          _showSnackBar(AppTranslations.get('pin_mismatch_msg'));
          setState(() => isLoading = false);
          return;
        }

        final phoneCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phone)
            .get();

        if (phoneCheck.docs.isNotEmpty) {
          _showSnackBar(AppTranslations.get('phone_exists_msg'));
          setState(() => isLoading = false);
          return;
        }

        // সব ঠিক থাকলে এখন ভেরিফিকেশন লিংক পাঠানো হবে
        await _completeRegistration(null);
      }
    } catch (e) {
      _showSnackBar('ত্রুটি: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _loginPhoneController.dispose();
    _loginPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ভাষা পরিবর্তন বাটন
              Positioned(
                top: 10,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: AppTranslations.currentLanguage,
                      icon: const Icon(Icons.language, color: Colors.white, size: 18),
                      dropdownColor: const Color(0xFF1565C0),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                      ],
                      onChanged: (val) async {
                        if (val != null) {
                          await AppTranslations.saveLanguage(val);
                          if (mounted) {
                            MyApp.setLocale(context, Locale(val));
                            setState(() {}); // লোকাল স্টেট আপডেট
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // পুরোনো আইকন ও টেক্সট সরিয়ে নতুন পিকচার বসানো হলো
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/ic_launcher.png',
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isLogin ? AppTranslations.get('login_title') : AppTranslations.get('register_title'),
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isLogin) ...[
                          _buildTextField(
                            controller: _shopNameController,
                            label: AppTranslations.get('shop_name'),
                            icon: Icons.store_rounded,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _ownerNameController,
                            label: AppTranslations.get('owner_name'),
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _phoneController,
                            label: AppTranslations.get('mobile'),
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _emailController,
                            label: AppTranslations.get('email'),
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _pinController,
                            label: '4 Digit PIN',
                            icon: Icons.lock_rounded,
                            isPassword: true,
                            maxLength: 4,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _confirmPinController,
                            label: 'Confirm PIN',
                            icon: Icons.lock_outline_rounded,
                            isPassword: true,
                            maxLength: 4,
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _loginPhoneController,
                                  label: AppTranslations.get('mobile'),
                                  icon: Icons.phone_rounded,
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                children: [
                                  Checkbox(
                                    value: _rememberPhone,
                                    activeColor: const Color(0xFF0D47A1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    onChanged: (val) {
                                      setState(() {
                                        _rememberPhone = val ?? false;
                                      });
                                    },
                                  ),
                                  Text(
                                    AppTranslations.get('remember_phone'),
                                    style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _loginPinController,
                                  label: '4 Digit PIN',
                                  icon: Icons.lock_rounded,
                                  isPassword: true,
                                  maxLength: 4,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _authenticateWithFingerprint,
                                icon: const Icon(Icons.fingerprint_rounded, size: 32, color: Color(0xFF0D47A1)),
                                tooltip: AppTranslations.get('biometric'),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPinDialog,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                              child: Text(
                                AppTranslations.get('forgot_pin'),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0D47A1), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        isLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)))
                            : ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFF0D47A1).withValues(alpha: 0.4),
                          ),
                          child: Text(
                            isLogin ? AppTranslations.get('login') : AppTranslations.get('register'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin ? AppTranslations.get('new_account_question') : AppTranslations.get('already_have_account_question'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  // স্টাফ লগইন বাটন
                  const SizedBox(height: 5),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StaffLoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                    label: Text(
                      AppTranslations.get('staff_login_btn'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
}

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF0D47A1), size: 22),
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 1.5),
        ),
      ),
    );
  }
}