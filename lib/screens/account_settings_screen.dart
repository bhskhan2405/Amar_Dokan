import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../utils/translations.dart';
import '../utils/device_utils.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  bool _isVerifying = false;
  bool _isOldEmailVerified = false;
  String? _pendingField;
  String? _pendingValue;
  Timer? _timer;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        var data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _shopNameController.text = data['shopName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _emailController.text = data['email'] ?? user?.email ?? '';
        });
      }
    }
  }

  void _showPinDialog(Function onConfirm) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('security_confirm_title') ?? 'Confirm PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: InputDecoration(
            labelText: AppTranslations.get('app_pin_label') ?? 'Enter 4 Digit PIN',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel') ?? 'Cancel')),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String savedPin = prefs.getString('app_pin') ?? '1234';
              if (pinController.text.trim() == savedPin) {
                Navigator.pop(context);
                onConfirm();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('wrong_pin_msg') ?? 'Wrong PIN')));
              }
            },
            child: Text(AppTranslations.get('confirm_btn') ?? 'Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateField(String field, String value) async {
    _showPinDialog(() async {
      if (field == 'email' || field == 'phone') {
        _startOldEmailVerificationFlow(field, value);
        return;
      }

      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({field: value});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('info_updated_msg'))));
        _loadUserData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('error_msg').replaceAll('@error', e.toString()))));
      } finally {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _startOldEmailVerificationFlow(String field, String value) async {
    try {
      setState(() {
        _isLoading = true;
        _pendingField = field;
        _pendingValue = value;
      });

      // বর্তমানে সেট করা ইমেইলে ভেরিফিকেশন লিঙ্ক পাঠানো
      await user?.sendEmailVerification();
      
      setState(() {
        _isLoading = false;
        _isVerifying = true;
        _isOldEmailVerified = false;
      });

      // পুরোনো ইমেইল ভেরিফাই হয়েছে কি না তা চেক করার জন্য টাইমার
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        await user?.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;
        if (updatedUser != null && updatedUser.emailVerified) {
          timer.cancel();
          _onOldEmailVerified();
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('verification_link_sent_error').replaceAll('@error', e.toString()))));
    }
  }

  Future<void> _onOldEmailVerified() async {
    if (!mounted) return;
    
    setState(() {
      _isOldEmailVerified = true;
    });

    try {
      if (_pendingField == 'email') {
        // এখন নতুন ইমেইলে ভেরিফিকেশন পাঠানো হবে
        await user?.verifyBeforeUpdateEmail(_pendingValue!);
        // _startVerificationCheck নতুন ইমেইল ভেরিফিকেশন চেক করবে (আগের কোড অনুযায়ী)
        _startNewEmailVerificationCheck();
      } else if (_pendingField == 'phone') {
        // ফোন নম্বর আপডেট করা
        String phone = _pendingValue!;
        String newTempPass = 'Pass_${phone}_${await _getCurrentPin()}';
        await user?.updatePassword(newTempPass);
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
          'phone': phone,
          'tempPassword': newTempPass,
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_phone', phone);
        
        setState(() {
          _isVerifying = false;
          _pendingField = null;
          _pendingValue = null;
        });
        _loadUserData();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('phone_updated_success'))));
      }
    } catch (e) {
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('error_msg').replaceAll('@error', e.toString()))));
    }
  }

  void _startNewEmailVerificationCheck() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await user?.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      // দ্রষ্টব্য: verifyBeforeUpdateEmail ব্যবহারের পর emailVerified সরাসরি true হয় না যতক্ষণ না নতুন লিঙ্ক ক্লিক করা হয়
      // এবং মাঝেমধ্যে Firebase ইমেইল পরিবর্তন না হওয়া পর্যন্ত পুরোনো ইমেইলটিই দেখায়।
      if (updatedUser != null && updatedUser.email == _pendingValue) {
        timer.cancel();
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'email': updatedUser.email});
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _pendingField = null;
            _pendingValue = null;
          });
          _loadUserData();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('email_updated_success'))));
        }
      }
    });
  }



  Future<String> _getCurrentPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_pin') ?? '1234';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(AppTranslations.get('account_details'), style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF0D47A1),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildAccountItem(Icons.person, AppTranslations.get('owner_name'), _nameController, 'name'),
                    _buildAccountItem(Icons.store, AppTranslations.get('shop_name'), _shopNameController, 'shopName'),
                    _buildAccountItem(Icons.phone, AppTranslations.get('phone_label'), _phoneController, 'phone'),
                    _buildAccountItem(Icons.email, AppTranslations.get('email_label'), _emailController, 'email'),
                  ],
                ),
              ),
        ),
        if (_isVerifying)
          Container(
            color: Colors.black.withValues(alpha: 0.8),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOldEmailVerified ? Icons.mark_email_unread_rounded : Icons.mark_email_read_rounded, 
                        size: 64, 
                        color: const Color(0xFF0D47A1)
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isOldEmailVerified ? AppTranslations.get('verify_new_email') : AppTranslations.get('verify_current_email'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isOldEmailVerified 
                          ? AppTranslations.get('new_email_verification_msg').replaceAll('@email', _pendingValue ?? '')
                          : AppTranslations.get('current_email_verification_msg').replaceAll('@email', user?.email ?? ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          _timer?.cancel();
                          setState(() => _isVerifying = false);
                        },
                        child: Text(AppTranslations.get('cancel')),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAccountItem(IconData icon, String label, TextEditingController controller, String field) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0D47A1)),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(controller.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        trailing: IconButton(
          icon: const Icon(Icons.edit_note_rounded, color: Colors.blue),
          onPressed: () {
            _showEditDialog(label, controller, field);
          },
        ),
      ),
    );
  }

  void _showEditDialog(String label, TextEditingController controller, String field) {
    final editController = TextEditingController(text: controller.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppTranslations.get('change')} $label'),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(border: const OutlineInputBorder(), labelText: AppTranslations.get('new_label').replaceAll('@label', label)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateField(field, editController.text.trim());
            },
            child: Text(AppTranslations.get('update')),
          ),
        ],
      ),
    );
  }
}
