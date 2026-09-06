import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_screen.dart';
import '../main.dart';
import 'staff_login_screen.dart';
import '../utils/translations.dart';
import '../utils/notification_utils.dart';
import '../utils/device_utils.dart';
import '../widgets/custom_banner_ad.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _loginPhoneController = TextEditingController();
  final _loginPinController = TextEditingController();

  static const String ADMIN_PHONE = "8801875787997";

  bool isLogin = true;
  bool isLoading = false;
  bool _rememberPhone = false;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

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

  String _maskEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 4) return '${name[0]}**@$domain';
    return '${name.substring(0, 2)}****${name.substring(name.length - 2)}@$domain';
  }

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

  Future<void> _authenticateWithFingerprint() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      bool isDeviceSupported = await auth.isDeviceSupported();
      if (!canCheckBiometrics && !isDeviceSupported) {
        _showSnackBar(AppTranslations.get('biometric_not_supported'));
        return;
      }
      bool didAuthenticate = await auth.authenticate(
        localizedReason: AppTranslations.get('biometric_reason'),
        biometricOnly: true,
      );
      if (didAuthenticate) {
        final prefs = await SharedPreferences.getInstance();
        String? savedPhone = prefs.getString('saved_phone');
        if (savedPhone != null && savedPhone.isNotEmpty) {
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
          }
        } else {
          _showSnackBar(AppTranslations.get('phone_not_saved'));
        }
      }
    } catch (e) {
      _showSnackBar(AppTranslations.get('biometric_error').replaceAll('@error', e.toString()));
    }
  }

  void _showVerificationDialog(User user) {
    String maskedEmail = _maskEmail(_emailController.text.trim());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.get('verify_email_title'), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_rounded, size: 56, color: Color(0xFF0D47A1)),
            const SizedBox(height: 12),
            Text(AppTranslations.get('verification_sent_to'), style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text(maskedEmail, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
            const SizedBox(height: 16),
            Text(AppTranslations.get('verify_email_msg'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
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
                await _saveUserDataAfterVerification(updatedUser);
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const DashboardScreen()), (route) => false);
                }
              } else {
                setState(() => isLoading = false);
                _showSnackBar(AppTranslations.get('email_not_verified'));
              }
            },
            child: Text(AppTranslations.get('verified_btn')),
          ),
        ],
      ),
    );
  }

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
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: AppTranslations.get('mobile'), border: const OutlineInputBorder())),
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
                final query = await FirebaseFirestore.instance.collection('users').where('phone', isEqualTo: phone).get();
                if (query.docs.isNotEmpty) {
                  String email = query.docs.first.data()['email'];
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (mounted) _showRecoveryInstructionDialog(phone, email, _maskEmail(email));
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
        title: Text(AppTranslations.get('forgot_pin')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_rounded, size: 64, color: Color(0xFF0D47A1)),
            const SizedBox(height: 16),
            Text(AppTranslations.get('verify_email_msg'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(maskedEmail, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showPasswordLoginDialog(phone, email);
            },
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
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('login_with_password')),
        content: TextField(controller: passwordController, obscureText: true, decoration: InputDecoration(labelText: AppTranslations.get('enter_password'), border: const OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          ElevatedButton(
            onPressed: () async {
              setState(() => isLoading = true);
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: passwordController.text.trim());
                Navigator.pop(context);
                _showSetNewPinDialog(phone);
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
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('set_new_pin_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pin1, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, decoration: InputDecoration(labelText: AppTranslations.get('new_pin'))),
            TextField(controller: pin2, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, decoration: InputDecoration(labelText: AppTranslations.get('confirm_new_pin'))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (pin1.text.length == 4 && pin1.text == pin2.text) {
                setState(() => isLoading = true);
                try {
                  String newPass = 'Pass_${phone}_${pin1.text}';
                  await FirebaseAuth.instance.currentUser!.updatePassword(newPass);
                  await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({'pin': pin1.text, 'tempPassword': newPass});
                  Navigator.pop(context);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
                } catch (e) {
                  _showSnackBar('ত্রুটি: $e');
                } finally {
                  setState(() => isLoading = false);
                }
              }
            },
            child: Text(AppTranslations.get('save')),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('help_support_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email Us'),
              onTap: () async {
                final url = Uri.parse('mailto:sup.amar.dokan@gmail.com');
                if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('WhatsApp'),
              onTap: () async {
                final url = Uri.parse('https://wa.me/8801875787997');
                if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel')))],
      ),
    );
  }

  void _showNewDeviceVerificationDialog(String phone, String email, String deviceId, String uid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('new_device_title')),
        content: Text(AppTranslations.get('new_device_msg')),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.currentUser!.sendEmailVerification();
              _showSnackBar(AppTranslations.get('link_sent'));
            },
            child: Text(AppTranslations.get('send_link_btn')),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseAuth.instance.currentUser!.reload();
              if (FirebaseAuth.instance.currentUser!.emailVerified) {
                await FirebaseFirestore.instance.collection('users').doc(uid).update({'authorizedDevices': FieldValue.arrayUnion([deviceId])});
                Navigator.pop(context);
                _submit();
              }
            },
            child: Text(AppTranslations.get('verified_label')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUserDataAfterVerification(User user) async {
    try {
      String phone = _normalizePhone(_phoneController.text.trim());
      String pin = _pinController.text.trim();
      String deviceId = await DeviceUtils.getUniqueId();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'shopName': _shopNameController.text.trim(),
        'name': _ownerNameController.text.trim(),
        'phone': phone,
        'email': _emailController.text.trim(),
        'pin': pin,
        'tempPassword': 'Pass_${phone}_$pin',
        'isApproved': true,
        'authorizedDevices': [deviceId],
        'createdAt': FieldValue.serverTimestamp(),
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_phone', phone);
      await prefs.setString('app_pin', pin);
      await prefs.setString('role', 'admin');
    } catch (e) {
      _showSnackBar('ডাটা সেভ ত্রুটি: $e');
    }
  }

  Future<void> _submit() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        String phone = _normalizePhone(_loginPhoneController.text.trim());
        String pin = _loginPinController.text.trim();
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString('saved_phone') == phone && prefs.getString('app_pin') == pin) {
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
          return;
        }
        final query = await FirebaseFirestore.instance.collection('users').where('phone', isEqualTo: phone).get(const GetOptions(source: Source.serverAndCache));
        if (query.docs.isEmpty) {
          _showSnackBar(AppTranslations.get('phone_not_registered_msg'));
          return;
        }
        final userData = query.docs.first.data();
        if (pin == userData['pin']) {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(email: userData['email'], password: userData['tempPassword']);
            _proceedToDashboard(phone, pin, userData, query.docs.first.id, userData['email']);
          } catch (e) {
            try {
              await FirebaseAuth.instance.signInWithEmailAndPassword(email: userData['email'], password: 'Pass_${phone}_$pin');
              _proceedToDashboard(phone, pin, userData, query.docs.first.id, userData['email']);
            } catch (inner) {
              _showSnackBar(AppTranslations.get('login_failed_msg'));
            }
          }
        } else {
          _showSnackBar(AppTranslations.get('wrong_pin_msg'));
        }
      } else {
        await _completeRegistration();
      }
    } catch (e) {
      _showSnackBar('ত্রুটি: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _proceedToDashboard(String phone, String pin, Map<String, dynamic> userData, String docId, String email) async {
    String deviceId = await DeviceUtils.getUniqueId();
    List authorized = userData['authorizedDevices'] ?? [];
    if (authorized.isEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({'authorizedDevices': [deviceId]});
    } else if (!authorized.contains(deviceId)) {
      _showNewDeviceVerificationDialog(phone, email, deviceId, docId);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_phone', phone);
    await prefs.setString('app_pin', pin);
    await prefs.setString('role', 'admin');
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
  }

  Future<void> _completeRegistration() async {
    try {
      String phone = _normalizePhone(_phoneController.text.trim());
      String pin = _pinController.text.trim();
      UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: 'Pass_${phone}_$pin');
      await cred.user!.sendEmailVerification();
      _showVerificationDialog(cred.user!);
    } catch (e) {
      _showSnackBar('রেজিস্ট্রেশন ত্রুটি: $e');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/login_bg.png'), fit: BoxFit.cover)),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 10,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: AppTranslations.currentLanguage,
                      icon: const Icon(Icons.language, color: Colors.white, size: 18),
                      dropdownColor: const Color(0xFF1565C0),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      items: const [DropdownMenuItem(value: 'en', child: Text('English')), DropdownMenuItem(value: 'bn', child: Text('বাংলা'))],
                      onChanged: (val) async {
                        if (val != null) {
                          await AppTranslations.saveLanguage(val);
                          MyApp.setLocale(context, Locale(val));
                          setState(() {});
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
                      ClipRRect(borderRadius: BorderRadius.circular(22), child: Image.asset('assets/images/ic_launcher.png', height: 280, width: 280, fit: BoxFit.cover)),
                      const SizedBox(height: 16),
                      Text(isLogin ? AppTranslations.get('login_title') : AppTranslations.get('register_title'), style: const TextStyle(fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 25, offset: const Offset(0, 10))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isLogin) ...[
                              _buildTextField(controller: _shopNameController, label: AppTranslations.get('shop_name'), icon: Icons.store),
                              const SizedBox(height: 14),
                              _buildTextField(controller: _ownerNameController, label: AppTranslations.get('owner_name'), icon: Icons.person),
                              const SizedBox(height: 14),
                              _buildTextField(controller: _phoneController, label: AppTranslations.get('mobile'), icon: Icons.phone, keyboardType: TextInputType.phone),
                              const SizedBox(height: 14),
                              _buildTextField(controller: _emailController, label: AppTranslations.get('email'), icon: Icons.email, keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 14),
                              _buildTextField(controller: _pinController, label: AppTranslations.get('enter_4_digit_pin'), icon: Icons.lock, isPassword: true, maxLength: 4),
                              const SizedBox(height: 14),
                              _buildTextField(controller: _confirmPinController, label: AppTranslations.get('confirm_pin'), icon: Icons.lock_outline, isPassword: true, maxLength: 4),
                            ] else ...[
                              Row(children: [
                                Expanded(child: _buildTextField(controller: _loginPhoneController, label: AppTranslations.get('mobile'), icon: Icons.phone, keyboardType: TextInputType.phone)),
                                const SizedBox(width: 8),
                                Column(children: [
                                  Checkbox(value: _rememberPhone, activeColor: const Color(0xFF0D47A1), onChanged: (val) => setState(() => _rememberPhone = val ?? false)),
                                  Text(AppTranslations.get('remember_phone'), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                ]),
                              ]),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(child: _buildTextField(controller: _loginPinController, label: AppTranslations.get('enter_4_digit_pin'), icon: Icons.lock, isPassword: true, maxLength: 4)),
                                const SizedBox(width: 8),
                                IconButton(onPressed: _authenticateWithFingerprint, icon: const Icon(Icons.fingerprint, size: 32, color: Color(0xFF0D47A1))),
                              ]),
                              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _showForgotPinDialog, child: Text(AppTranslations.get('forgot_pin'), style: const TextStyle(fontSize: 13, color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)))),
                            ],
                            const SizedBox(height: 24),
                            isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text(isLogin ? AppTranslations.get('login') : AppTranslations.get('register'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? AppTranslations.get('register') : AppTranslations.get('login'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, decoration: TextDecoration.underline))),
                      const SizedBox(height: 5),
                      TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffLoginScreen())), icon: const Icon(Icons.badge, color: Colors.white, size: 20), label: Text(AppTranslations.get('staff_login_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.underline))),
                      const SizedBox(height: 30),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        IconButton(onPressed: _showHelpDialog, icon: const Icon(Icons.help_outline, color: Colors.white70)),
                        const SizedBox(width: 20),
                        IconButton(onPressed: () => launchUrl(Uri.parse('https://bhskhan2405.github.io/Amar_Dokan/'), mode: LaunchMode.externalApplication), icon: const Icon(Icons.privacy_tip_outlined, color: Colors.white70)),
                      ]),
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

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType keyboardType = TextInputType.text, bool isPassword = false, int? maxLength}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF0D47A1)),
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }
}

class RegistrationSuccessPage extends StatelessWidget {
  const RegistrationSuccessPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text("Success")));
  }
}
