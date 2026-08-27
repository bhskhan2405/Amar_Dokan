import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ক্লিপবোর্ডের জন্য
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_approval_screen.dart';
import 'subscription_screen.dart';
import 'account_settings_screen.dart'; // নতুন স্ক্রিন ইমপোর্ট
import '../utils/translations.dart';
import '../utils/notification_utils.dart'; // নোটিফিকেশন ইউটিলিটি ইমপোর্ট
import '../utils/subscription_utils.dart';
import '../widgets/custom_banner_ad.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _footerNoteController = TextEditingController();

  File? _selectedImage;
  String? _base64ImageString;
  bool _isFingerprintEnabled = false;
  bool _isLoading = false;

  bool _isAddressEditable = false;
  bool _isNoteEditable = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isFingerprintEnabled = prefs.getBool('fingerprint_enabled') ?? false;
    });

    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        var data = doc.data();
        setState(() {
          _nameController.text = data?['name'] ?? '';
          _shopNameController.text = data?['shopName'] ?? '';
          _phoneController.text = data?['phone'] ?? '';
          _emailController.text = data?['email'] ?? user?.email ?? '';
          _addressController.text = data?['address'] ?? '';
          _footerNoteController.text = data?['footerNote'] ?? '';
          _base64ImageString = data?['photoBase64'];
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 400,
      maxHeight: 400,
    );

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);

      setState(() {
        _selectedImage = imageFile;
        _base64ImageString = base64String;
      });
    }
  }

  void _showPinVerificationDialog() {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTranslations.get('security_confirm_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppTranslations.get('security_confirm_msg')),
            const SizedBox(height: 10),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: AppTranslations.get('app_pin_label'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppTranslations.get('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String? savedPin = prefs.getString('app_pin') ?? '1234';

              if (pinController.text.trim() == savedPin) {
                Navigator.pop(dialogContext);
                _saveSettings();
              } else {
                _showSnackBar(AppTranslations.get('wrong_pin_msg'));
              }
            },
            child: Text(AppTranslations.get('confirm_btn')),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog() {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppTranslations.get('change_pin_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: InputDecoration(labelText: AppTranslations.get('old_pin')),
            ),
            TextField(
              controller: newPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: InputDecoration(labelText: AppTranslations.get('new_pin_4_digit')),
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
              final prefs = await SharedPreferences.getInstance();
              String? savedPin = prefs.getString('app_pin') ?? '1234';

              if (oldPinController.text.trim() == savedPin) {
                if (newPinController.text.trim().length == 4) {
                  await prefs.setString('app_pin', newPinController.text.trim());
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _showSnackBar(AppTranslations.get('pin_changed_msg'));
                } else {
                  _showSnackBar(AppTranslations.get('pin_must_4_digit'));
                }
              } else {
                _showSnackBar(AppTranslations.get('old_pin_wrong'));
              }
            },
            child: Text(AppTranslations.get('save_settings_btn')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
          'address': _addressController.text.trim(),
          'footerNote': _footerNoteController.text.trim(),
          'photoBase64': _base64ImageString,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        setState(() {
          _selectedImage = null;
          _isAddressEditable = false;
          _isNoteEditable = false;
        });

        _showSnackBar(AppTranslations.get('settings_saved_msg'));
      }
    } catch (e) {
      _showSnackBar('${AppTranslations.get('error_occurred')} $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAccountDeleteDialog() {
    final pinController = TextEditingController();
    final reasonController = TextEditingController();
    String? selectedReason;
    final List<String> reasons = [
      "অপ্রয়োজনীয় মনে হচ্ছে",
      "অন্য অ্যাপ ব্যবহার করছি",
      "অতিরিক্ত জটিল মনে হচ্ছে",
      "ব্যক্তিগত কারণ",
      "অন্যান্য"
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Account?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("আপনি কি নিশ্চিত? অ্যাকাউন্ট ডিলিট করলে আপনার সব ডাটা চিরতরে মুছে যাবে।", style: TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(labelText: "কেন ডিলিট করতে চান? (ঐচ্ছিক)", border: OutlineInputBorder()),
                  items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setDialogState(() => selectedReason = val),
                ),
                if (selectedReason == "অন্যান্য") ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: "আপনার কারণ লিখুন", border: OutlineInputBorder()),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: AppTranslations.get('app_pin_label'),
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppTranslations.get('cancel'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                String savedPin = prefs.getString('app_pin') ?? '1234';

                if (pinController.text.trim() == savedPin) {
                  Navigator.pop(dialogContext);
                  _deleteAccount(selectedReason ?? "No reason", reasonController.text.trim());
                } else {
                  _showSnackBar(AppTranslations.get('wrong_pin_msg'));
                }
              },
              child: const Text("Delete Forever"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(String reason, String otherReason) async {
    setState(() => _isLoading = true);
    try {
      if (user != null) {
        String finalReason = reason == "অন্যান্য" ? otherReason : reason;
        String userPhone = _phoneController.text;
        String shopName = _shopNameController.text;

        await NotificationUtils.notifyAdmin(
          title: "ইউজার অ্যাকাউন্ট ডিলিট করেছেন",
          message: "ইউজার: $shopName ($userPhone)\nকারণ: $finalReason",
        );

        await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();

        try {
          await user!.delete();
        } catch (authError) {
          debugPrint("Auth Delete Error: $authError");
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          _showSnackBar("আপনার অ্যাকাউন্টটি সফলভাবে মুছে ফেলা হয়েছে।");
        }
      }
    } catch (e) {
      _showSnackBar("ডিলিট করতে ত্রুটি হয়েছে: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? profileImage;
    if (_selectedImage != null) {
      profileImage = FileImage(_selectedImage!);
    } else if (_base64ImageString != null && _base64ImageString!.isNotEmpty) {
      try {
        profileImage = MemoryImage(base64Decode(_base64ImageString!));
      } catch (_) {
        profileImage = null;
      }
    }

    final String adminUid = user?.uid ?? 'UID পাওয়া যায়নি';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get('app_settings'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
            children: [
              const CustomBannerAd(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.blue.shade100,
                                backgroundImage: profileImage,
                                child: profileImage == null
                                    ? const Icon(Icons.store, size: 50, color: Color(0xFF0D47A1))
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: _pickImage,
                                  child: const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Color(0xFF0D47A1),
                                    child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppTranslations.get('shop_id_label'),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      adminUid,
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, color: Color(0xFF0D47A1), size: 20),
                                    tooltip: AppTranslations.get('copy_id_tooltip'),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: adminUid));
                                      _showSnackBar(AppTranslations.get('copy_id_msg'));
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text('👤 Account & Shop Settings', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.account_circle_outlined, color: Color(0xFF0D47A1)),
                          title: Text(AppTranslations.get('account_settings') ?? 'Account Settings'),
                          subtitle: Text(_nameController.text.isEmpty ? 'Manage name, phone & email' : _nameController.text),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AccountSettingsScreen()),
                            ).then((_) => _loadUserData());
                          },
                        ),
                        const SizedBox(height: 20),

                        Text('📋 ${AppTranslations.get('shop_info_label') ?? 'Shop Info'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _addressController,
                          readOnly: !_isAddressEditable,
                          decoration: InputDecoration(
                            labelText: AppTranslations.get('address'),
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isAddressEditable ? Icons.lock_open : Icons.edit,
                                color: _isAddressEditable ? Colors.green : Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isAddressEditable = !_isAddressEditable;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _footerNoteController,
                          readOnly: !_isNoteEditable,
                          decoration: InputDecoration(
                            labelText: AppTranslations.get('footer_note'),
                            prefixIcon: const Icon(Icons.note_alt_outlined),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isNoteEditable ? Icons.lock_open : Icons.edit,
                                color: _isNoteEditable ? Colors.green : Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isNoteEditable = !_isNoteEditable;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Divider(),
                        Text('💎 ${AppTranslations.get('subscriptions')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
                          title: Text(AppTranslations.get('buy_premium')),
                          subtitle: FutureBuilder<bool>(
                            future: SubscriptionUtils.isPaidPremium(),
                            builder: (context, snapshot) {
                              if (snapshot.data == true) {
                                return const Text('Active Premium Plan', style: TextStyle(color: Colors.green, fontSize: 12));
                              }
                              return const Text('Check your subscription status', style: TextStyle(fontSize: 12));
                            },
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                            );
                          },
                        ),

                        const Divider(),
                        Text('🔐 ${AppTranslations.get('security_settings')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        if (_phoneController.text == "01828424364") ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                            title: Text(AppTranslations.get('user_approval')),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              final pinController = TextEditingController();
                              showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: Text(AppTranslations.get('security_pin')),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('সুপার এডমিন প্যানেলে প্রবেশ করতে পিন দিন:'),
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: pinController,
                                        keyboardType: TextInputType.number,
                                        obscureText: true,
                                        maxLength: 4,
                                        decoration: InputDecoration(
                                          labelText: AppTranslations.get('app_pin_label'),
                                          border: const OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppTranslations.get('cancel'))),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final prefs = await SharedPreferences.getInstance();
                                        String savedPin = prefs.getString('app_pin') ?? '1234';
                                        if (pinController.text.trim() == savedPin) {
                                          Navigator.pop(dialogContext);
                                          if (!mounted) return;
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => const UserApprovalScreen()),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('wrong_pin_msg'))));
                                        }
                                      },
                                      child: Text(AppTranslations.get('confirm_btn')),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock_reset, color: Color(0xFF0D47A1)),
                          title: Text(AppTranslations.get('change_pin')),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _showChangePinDialog,
                        ),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.fingerprint, color: Color(0xFF0D47A1)),
                          title: Text(AppTranslations.get('fingerprint')),
                          value: _isFingerprintEnabled,
                          onChanged: (val) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('fingerprint_enabled', val);
                            setState(() => _isFingerprintEnabled = val);
                          },
                        ),

                        const SizedBox(height: 24),

                        const Divider(),
                        Text('🌐 ${AppTranslations.get('language')}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.language, color: Color(0xFF0D47A1)),
                          title: Text(AppTranslations.get('select_language')),
                          trailing: DropdownButton<String>(
                            value: AppTranslations.currentLanguage,
                            items: const [
                              DropdownMenuItem(value: 'en', child: Text('English')),
                              DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                            ],
                            onChanged: (val) async {
                              if (val != null) {
                                await AppTranslations.saveLanguage(val);
                                if (mounted) {
                                  MyApp.setLocale(context, Locale(val));
                                }
                              }
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: _showPinVerificationDialog,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: Text(AppTranslations.get('save_settings'), style: const TextStyle(color: Colors.white, fontSize: 16)),
                        ),

                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            minimumSize: const Size(double.infinity, 50),
                            side: BorderSide(color: Colors.red.shade200),
                          ),
                          onPressed: _showAccountDeleteDialog,
                          icon: const Icon(Icons.delete_forever_rounded),
                          label: const Text("Delete Account", style: TextStyle(fontSize: 16)),
                        ),

                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            minimumSize: const Size(double.infinity, 50),
                            side: const BorderSide(color: Colors.red),
                          ),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            String? currentLang = prefs.getString('language_code');
                            await prefs.clear();
                            if (currentLang != null) {
                              await prefs.setString('language_code', currentLang);
                            }
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: Text(AppTranslations.get('logout'), style: const TextStyle(fontSize: 16)),
                        ),

                        const SizedBox(height: 20),
                        const Center(
                          child: Text('App Version: 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
