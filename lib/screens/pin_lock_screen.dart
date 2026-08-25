import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'dashboard_screen.dart';
import '../utils/translations.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();

  String? _savedPin;
  bool _isFingerprintEnabled = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndCheckBiometrics();
  }

  // পিন ও বায়োমেট্রিক তথ্য লোড করা
  Future<void> _loadSettingsAndCheckBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPin = prefs.getString('app_pin');
      _isFingerprintEnabled = prefs.getBool('fingerprint_enabled') ?? false;
    });

    bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    setState(() => _canCheckBiometrics = canCheck);

    if (_savedPin != null && _isFingerprintEnabled && _canCheckBiometrics) {
      _authenticateWithFingerprint();
    }
  }

  // ফিঙ্গারপ্রিন্ট অটো ভেরিফিকেশন
  Future<void> _authenticateWithFingerprint() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: AppTranslations.get('open_app_fingerprint'),
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (authenticated && mounted) {
        _goToDashboard();
      }
    } catch (_) {}
  }

  // পিন যাচাই বা নতুন পিন সেভ
  void _verifyOrSavePin() async {
    final inputPin = _pinController.text.trim();
    if (inputPin.length != 4) {
      _showSnackBar(AppTranslations.get('pin_length_msg'));
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (_savedPin == null) {
      // ১. প্রথমবার পিন সেভ
      await prefs.setString('app_pin', inputPin);
      setState(() {
        _savedPin = inputPin;
      });
      _showSnackBar(AppTranslations.get('pin_set_msg'));
      _goToDashboard();
    } else {
      // ২. পরবর্তী সময়ে পিন মিলিয়ে দেখা
      if (inputPin == _savedPin) {
        _goToDashboard();
      } else {
        _showSnackBar(AppTranslations.get('invalid_pin_msg'));
        _pinController.clear();
      }
    }
  }

  // ফিঙ্গারপ্রিন্ট সক্রিয় করার আগে পিন কনফার্মেশন
  void _enableFingerprintWithPinVerification() async {
    final pinVerifyController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTranslations.get('enable_fingerprint')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppTranslations.get('fingerprint_security_msg')),
            const SizedBox(height: 10),
            TextField(
              controller: pinVerifyController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: InputDecoration(hintText: AppTranslations.get('four_digit_pin')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppTranslations.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pinVerifyController.text.trim() == _savedPin) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('fingerprint_enabled', true);
                setState(() => _isFingerprintEnabled = true);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _showSnackBar(AppTranslations.get('fingerprint_enabled_msg'));
              } else {
                _showSnackBar(AppTranslations.get('wrong_pin_short'));
              }
            },
            child: Text(AppTranslations.get('confirm')),
          ),
        ],
      ),
    );
  }

  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    bool isFirstTime = _savedPin == null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 70, color: Color(0xFF0D47A1)),
              const SizedBox(height: 20),
              Text(
                isFirstTime ? AppTranslations.get('set_new_pin') : AppTranslations.get('unlock_with_pin'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 16),
                decoration: const InputDecoration(
                  hintText: '••••',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _verifyOrSavePin,
                child: Text(
                  isFirstTime ? AppTranslations.get('save_pin_enter_app') : AppTranslations.get('unlock'),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),

              if (_canCheckBiometrics && !isFirstTime) ...[
                const SizedBox(height: 20),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppTranslations.get('unlock_with_fingerprint'), style: const TextStyle(fontSize: 15)),
                    Switch(
                      value: _isFingerprintEnabled,
                      onChanged: (val) async {
                        if (val) {
                          _enableFingerprintWithPinVerification();
                        } else {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('fingerprint_enabled', false);
                          setState(() => _isFingerprintEnabled = false);
                        }
                      },
                    ),
                  ],
                ),
                if (_isFingerprintEnabled)
                  IconButton(
                    icon: const Icon(Icons.fingerprint, size: 48, color: Colors.blue),
                    onPressed: _authenticateWithFingerprint,
                  ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}