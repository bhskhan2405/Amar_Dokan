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
import '../utils/device_utils.dart'; // ডিভাইস ইউটিলিটি ইমপোর্ট করা হলো
import '../widgets/custom_banner_ad.dart';

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
        biometricOnly: true,
        persistAcrossBackgrounding: true,
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

            // Note: Now we allow the user to go to the Dashboard even if not approved,
            // as the Dashboard handles the 'PENDING' overlay.
            /*
            if (!isApproved) {
              _showPendingApprovalDialog(normalized);
              setState(() => isLoading = false);
              return;
            }
            */

            // নতুন ডিভাইস ভেরিফিকেশন চেক (ফিঙ্গারপ্রিন্টের জন্যও)
            String currentDeviceId = await DeviceUtils.getUniqueId();
            List<dynamic> authorizedDevices = userData['authorizedDevices'] ?? [];

            if (authorizedDevices.isNotEmpty && !authorizedDevices.contains(currentDeviceId)) {
              if (!mounted) return;
              _showNewDeviceVerificationDialog(normalized, email, currentDeviceId, querySnapshot.docs.first.id);
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
                // ১. আগে ডায়ালগটি বন্ধ করা হচ্ছে (সঠিক Context ব্যবহার করে)
                if (mounted) Navigator.pop(context); 
                
                // ২. ইউজারের ডাটা সেভ করা হচ্ছে
                await _saveUserDataAfterVerification(updatedUser);
                
                // ৩. এখন সরাসরি ড্যাশবোর্ডে পাঠানো হচ্ছে (স্ক্রিনের Context ব্যবহার করে)
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                    (route) => false, // পেছনের সব রুট ক্লিয়ার করে দেওয়া হলো
                  );
                }
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
                  String maskedEmail = _maskEmail(email);
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  
                  if (!mounted) return;
                  _showRecoveryInstructionDialog(phone, email, maskedEmail);
                } else {
                  _showSnackBar(AppTranslations.get('user_not_found'));
                }
              } catch (e) {
                _showSnackBar(AppTranslations.get('error_msg').replaceAll('@error', e.toString()));
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

  void _showRecoveryInstructionDialog(String phone, String email, String maskedEmail) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.get('forgot_pin'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_rounded, size: 64, color: Color(0xFF0D47A1)),
            const SizedBox(height: 16),
            Text(
              'আপনার ইমেইলে একটি পিন রিসেট লিঙ্ক পাঠানো হয়েছে:',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              maskedEmail,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildInstructionItem(Icons.mail_outline, 'ইমেইল ইনবক্স বা স্প্যাম ফোল্ডার চেক করুন।'),
            _buildInstructionItem(Icons.link, 'লিঙ্কে ক্লিক করে নতুন পাসওয়ার্ড সেট করুন।'),
            _buildInstructionItem(Icons.login, 'পাসওয়ার্ড সেট করা হলে আবার অ্যাপে ফিরে আসুন।'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPasswordLoginDialog(phone, email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1), 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppTranslations.get('password_set_done')),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
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
                _showSnackBar(AppTranslations.get('login_failed_msg'));
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
              decoration: InputDecoration(labelText: AppTranslations.get('new_pin'), counterText: ''),
            ),
            TextField(
              controller: pin2,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: InputDecoration(labelText: AppTranslations.get('confirm_new_pin'), counterText: ''),
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

                    _showSnackBar(AppTranslations.get('pin_changed_success'));
                    if (!mounted) return;
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
                  }
                } catch (e) {
                  _showSnackBar(AppTranslations.get('pin_set_error').replaceAll('@error', e.toString()));
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
                    String message = AppTranslations.get('admin_verify_request_msg').replaceAll('@phone', userPhone);
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.get('help_support_title'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email_rounded, color: Color(0xFF0D47A1)),
              title: Text(AppTranslations.get('email_us')),
              subtitle: const Text("sup.amar.dokan@gmail.com"),
              onTap: () async {
                final Uri url = Uri.parse('mailto:sup.amar.dokan@gmail.com?subject=Support%20Request&body=Hello%20Team,');
                try {
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    // যদি canLaunchUrl ব্যর্থ হয়, তবুও সরাসরি লঞ্চ করার চেষ্টা করা
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  debugPrint("Email error: $e");
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.chat_rounded, color: Colors.green),
              title: Text(AppTranslations.get('whatsapp_label')),
              subtitle: const Text("+8801875787997"),
              onTap: () async {
                final Uri url = Uri.parse('https://wa.me/8801875787997');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
        ],
      ),
    );
  }

  void _showNewDeviceVerificationDialog(String phone, String email, String deviceId, String uid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.get('new_device_title'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phonelink_lock_rounded, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              AppTranslations.get('new_device_msg'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text("${AppTranslations.get('email_label')}: ${_maskEmail(email)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            const SizedBox(height: 16),
            Text(
              AppTranslations.get('verification_instruction'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                User? user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await user.sendEmailVerification();
                  _showSnackBar("ভেরিফিকেশন লিংক আপনার ইমেইলে পাঠানো হয়েছে।");
                }
              } catch (e) {
                _showSnackBar("লিংক পাঠাতে ত্রুটি: $e");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
            child: Text(AppTranslations.get('send_link_btn')),
          ),
          ElevatedButton(
            onPressed: () async {
              User? user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await user.reload();
                if (FirebaseAuth.instance.currentUser!.emailVerified) {
                  // ডিভাইস অথোরাইজ করা
                  await FirebaseFirestore.instance.collection('users').doc(uid).update({
                    'authorizedDevices': FieldValue.arrayUnion([deviceId])
                  });
                  
                  if (!mounted) return;
                  Navigator.pop(context);
                  _submit(); // আবার সাবমিট করলে এবার সফলভাবে লগইন হবে
                } else {
                  _showSnackBar(AppTranslations.get('email_not_verified_msg'));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: Text(AppTranslations.get('verified_label')),
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
      String currentDeviceId = await DeviceUtils.getUniqueId();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'shopName': shopName,
        'name': ownerName,
        'phone': phone,
        'email': email,
        'pin': pin,
        'tempPassword': tempPassword,
        'isApproved': true, // নতুন রেজিস্ট্রেশন এখন অটো-অ্যাপ্রুভ হবে
        'authorizedDevices': [currentDeviceId], // রেজিস্ট্রেশন করা ডিভাইসটি অটো-অ্যাপ্রুভ হবে
        'trialStartDate': FieldValue.serverTimestamp(),
        'subscriptionExpiryDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_pin', pin);
      await prefs.setString('saved_phone', phone);
      await prefs.setBool('remember_phone', true);
      await prefs.setString('role', 'admin'); // রোল সেট করা হলো
      await prefs.setString('trial_start_date', now.toIso8601String());
      await prefs.setString('subscription_expiry_date', now.toIso8601String());

      // রেজিস্ট্রেশনের পর সাইন আউট করা বন্ধ করা হলো যাতে সরাসরি ড্যাশবোর্ডে যাওয়া যায়
      // await FirebaseAuth.instance.signOut();

      // এডমিনকে নতুন রেজিস্ট্রেশন রিকোয়েস্ট জানানো (তথ্য হিসেবে)
      await NotificationUtils.notifyAdmin(
        title: "নতুন ইউজার রেজিস্ট্রেশন (অটো-অ্যাপ্রুভ)",
        message: "$ownerName ($shopName) অ্যাকাউন্ট খুলেছেন। নম্বর: $phone",
      );

      _showSnackBar(AppTranslations.get('account_created_msg'));
      // Note: Navigation to Dashboard is now handled in the verification dialog
      // so we don't show the pending dialog here anymore.
      // _showPendingApprovalDialog(phone);
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
      _showSnackBar(AppTranslations.get('registration_error_msg').replaceAll('@error', e.toString()));
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
          _showSnackBar(AppTranslations.get('phone_not_registered_msg'));
          setState(() => isLoading = false);
          return;
        }

        final userDoc = querySnapshot.docs.first;
        final userData = userDoc.data();
        final savedPin = userData['pin'];
        final email = userData['email'];
        final password = userData['tempPassword'];
        final bool isApproved = userData['isApproved'] ?? true;

        if (pin == savedPin) {
          try {
            // ১. ফায়ারবেসে লগইন (সাইন-ইন) করা হচ্ছে, যাতে পেন্ডিং থাকলেও UID পাওয়া যায়
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );

            // নতুন ডিভাইস ভেরিফিকেশন চেক
            String currentDeviceId = await DeviceUtils.getUniqueId();
            List<dynamic> authorizedDevices = userData['authorizedDevices'] ?? [];

            if (authorizedDevices.isEmpty) {
              // প্রথমবার লগইন করলে এই ডিভাইসটি অটোমেটিক অথোরাইজ হবে
              await FirebaseFirestore.instance.collection('users').doc(userDoc.id).update({
                'authorizedDevices': FieldValue.arrayUnion([currentDeviceId])
              });
            } else if (!authorizedDevices.contains(currentDeviceId)) {
              // নতুন ডিভাইস হলে ভেরিফিকেশন ডায়ালগ দেখানো হবে
              if (!mounted) return;
              _showNewDeviceVerificationDialog(phone, email, currentDeviceId, userDoc.id);
              setState(() => isLoading = false);
              return;
            }

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

            // এখন ড্যাশবোর্ডে পাঠানো হবে, সেখানে _isApproved চেক করে ওভারলে দেখানো হবে
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          } catch (e) {
            _showSnackBar(AppTranslations.get('login_failed_msg'));
          }
        } else {
          _showSnackBar(AppTranslations.get('wrong_pin_msg'));
        }
      } else {
        String shopName = _shopNameController.text.trim();
        String ownerName = _ownerNameController.text.trim();
        String phone = _normalizePhone(_phoneController.text.trim());
        String email = _emailController.text.trim();
        String pin = _pinController.text.trim();
        String confirmPin = _confirmPinController.text.trim();

        if (shopName.isEmpty || ownerName.isEmpty || phone.isEmpty || email.isEmpty) {
          _showSnackBar(email.isEmpty ? AppTranslations.get('email_required_msg') : AppTranslations.get('required_fields_msg'));
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
      _showSnackBar(AppTranslations.get('error_msg').replaceAll('@error', e.toString()));
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
          image: DecorationImage(
            image: AssetImage('assets/images/login_bg.png'),
            fit: BoxFit.cover,
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
                      const CustomBannerAd(),
                      const SizedBox(height: 10),
                      // পুরোনো আইকন ও টেক্সট সরিয়ে নতুন পিকচার বসানো হলো
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/ic_launcher.png',
                      height: 280,
                      width: 280,
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
                            label: AppTranslations.get('enter_4_digit_pin'),
                            icon: Icons.lock_rounded,
                            isPassword: true,
                            maxLength: 4,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _confirmPinController,
                            label: AppTranslations.get('confirm_pin'),
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
                                  label: AppTranslations.get('enter_4_digit_pin'),
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
                      isLogin ? AppTranslations.get('register') : AppTranslations.get('login'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.underline,
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
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _showHelpDialog,
                        icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
                        tooltip: AppTranslations.get('help_support'),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        onPressed: () {
                          final Uri url = Uri.parse('https://bhskhan2405.github.io/Amar_Dokan/');
                          launchUrl(url, mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
                        tooltip: AppTranslations.get('privacy_policy'),
                      ),
                    ],
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

// রেজিস্ট্রেশন পরবর্তী পেন্ডিং মেসেজ পেজ
class RegistrationSuccessPage extends StatelessWidget {
  const RegistrationSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pending_actions_rounded, size: 80, color: Colors.orange),
                    const SizedBox(height: 24),
                    Text(
                      AppTranslations.get('account_pending_msg'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppTranslations.get('please_login_msg'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginRegisterScreen()),
                            (route) => false,
                          );
                        },
                        child: Text(
                          AppTranslations.get('login_now'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}