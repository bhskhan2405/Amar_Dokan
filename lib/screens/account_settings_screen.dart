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
      setState(() => _isLoading = true);
      try {
        if (field == 'email') {
          await user?.verifyBeforeUpdateEmail(value);
          _startVerificationCheck();
        } else if (field == 'phone') {
          String newTempPass = 'Pass_${value}_${await _getCurrentPin()}';
          await user?.updatePassword(newTempPass);
          await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
            'phone': value,
            'tempPassword': newTempPass,
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_phone', value);
        } else {
          await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({field: value});
        }
        
        if (field != 'email') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('তথ্য সফলভাবে আপডেট হয়েছে')));
          _loadUserData();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<String> _getCurrentPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_pin') ?? '1234';
  }

  void _startVerificationCheck() {
    setState(() => _isVerifying = true);
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await user?.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      if (updatedUser != null && updatedUser.emailVerified) {
        timer.cancel();
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'email': updatedUser.email});
        if (mounted) {
          setState(() => _isVerifying = false);
          _loadUserData();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ইমেইল সফলভাবে ভেরিফাই হয়েছে!')));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Account Details', style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF0D47A1),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildAccountItem(Icons.person, 'Owner Name', _nameController, 'name'),
                    _buildAccountItem(Icons.store, 'Shop Name', _shopNameController, 'shopName'),
                    _buildAccountItem(Icons.phone, 'Phone Number', _phoneController, 'phone'),
                    _buildAccountItem(Icons.email, 'Email Address', _emailController, 'email'),
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
                      const Icon(Icons.mark_email_read_rounded, size: 64, color: Color(0xFF0D47A1)),
                      const SizedBox(height: 16),
                      const Text(
                        'ইমেইল ভেরিফিকেশন প্রয়োজন',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'আপনার নতুন ইমেইলে একটি ভেরিফিকেশন লিঙ্ক পাঠানো হয়েছে। দয়া করে লিঙ্কটিতে ক্লিক করুন। ভেরিফিকেশন শেষ না হওয়া পর্যন্ত আপনি অ্যাপ ব্যবহার করতে পারবেন না।',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          _timer?.cancel();
                          setState(() => _isVerifying = false);
                        },
                        child: const Text('বাতিল করুন'),
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
        title: Text('Change $label'),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(border: const OutlineInputBorder(), labelText: 'New $label'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateField(field, editController.text.trim());
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
