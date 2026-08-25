import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/translations.dart';

class ManageStaffsScreen extends StatefulWidget {
  const ManageStaffsScreen({super.key});

  @override
  State<ManageStaffsScreen> createState() => _ManageStaffsScreenState();
}

class _ManageStaffsScreenState extends State<ManageStaffsScreen> {
  final _isLoadingNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isLoadingNotifier.dispose();
    super.dispose();
  }

  // নতুন স্টাফ ফায়ারস্টোরে যোগ করার ফাংশন
  void _addStaff(BuildContext context, String adminUid, GlobalKey<FormState> formKey, TextEditingController nameCtrl, TextEditingController phoneCtrl, TextEditingController usernameCtrl, TextEditingController passwordCtrl, bool pList, bool pSale, bool accounts, bool customer) async {
    if (formKey.currentState!.validate()) {
      _isLoadingNotifier.value = true;

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(adminUid)
            .collection('staffs')
            .add({
          'name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'username': usernameCtrl.text.trim(),
          'password': passwordCtrl.text.trim(),
          'role': 'staff',
          'permissions': {
            'product_list': pList,
            'pos_sale': pSale,
            'accounts': accounts,
            'customer': customer,
            'can_customer': customer, // কোডের সামঞ্জস্যতার জন্য উভয় কি (key) সেভ করা হলো
          },
          'createdAt': Timestamp.now(),
        });

        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.get('staff_added_msg'))),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppTranslations.get('error_msg').replaceAll('@error', '')} $e'), backgroundColor: Colors.red),
        );
      } finally {
        _isLoadingNotifier.value = false;
      }
    }
  }

  // স্টাফের তথ্য ও পারমিশন আপডেট (এডিট) করার ফাংশন
  void _updateStaff(BuildContext context, String adminUid, String staffId, GlobalKey<FormState> formKey, TextEditingController nameCtrl, TextEditingController phoneCtrl, TextEditingController usernameCtrl, TextEditingController passwordCtrl, bool pList, bool pSale, bool accounts, bool customer) async {
    if (formKey.currentState!.validate()) {
      _isLoadingNotifier.value = true;

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(adminUid)
            .collection('staffs')
            .doc(staffId)
            .update({
          'name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'username': usernameCtrl.text.trim(),
          'password': passwordCtrl.text.trim(),
          'permissions': {
            'product_list': pList,
            'pos_sale': pSale,
            'accounts': accounts,
            'customer': customer,
            'can_customer': customer, // কোডের সামঞ্জস্যতার জন্য উভয় কি (key) আপডেট করা হলো
          },
          'updatedAt': Timestamp.now(),
        });

        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.get('staff_updated_msg'))),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppTranslations.get('error_msg').replaceAll('@error', '')} $e'), backgroundColor: Colors.red),
        );
      } finally {
        _isLoadingNotifier.value = false;
      }
    }
  }

  // স্টাফ যোগ বা এডিট করার ডায়ালগ বক্স
  void _showStaffDialog(BuildContext context, String adminUid, {Map<String, dynamic>? staffData, String? staffId}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: staffData?['name'] ?? '');
    final phoneController = TextEditingController(text: staffData?['phone'] ?? '');
    final usernameController = TextEditingController(text: staffData?['username'] ?? '');
    final passwordController = TextEditingController(text: staffData?['password'] ?? '');

    var permissions = staffData?['permissions'] ?? {};
    bool canProductList = permissions['product_list'] ?? true;
    bool canPosSale = permissions['pos_sale'] ?? true;
    bool canAccounts = permissions['accounts'] ?? false;
    bool canCustomer = permissions['customer'] ?? permissions['can_customer'] ?? true;

    bool isEditing = staffId != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? AppTranslations.get('edit_staff_access') : AppTranslations.get('new_staff_access'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: AppTranslations.get('staff_name')),
                        validator: (val) => val!.isEmpty ? AppTranslations.get('name_required') : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(labelText: AppTranslations.get('mobile')),
                        validator: (val) => val!.isEmpty ? AppTranslations.get('mobile_required') ?? 'Mobile required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: usernameController,
                        decoration: InputDecoration(labelText: AppTranslations.get('username_login')),
                        validator: (val) => val!.isEmpty ? AppTranslations.get('username_required') : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(labelText: AppTranslations.get('password_pin')),
                        validator: (val) => val!.isEmpty ? AppTranslations.get('password_required') : null,
                      ),
                      const Divider(height: 25, thickness: 1),
                      Text(AppTranslations.get('feature_permissions'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                      CheckboxListTile(
                        title: Text(AppTranslations.get('product_list_perm')),
                        value: canProductList,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => canProductList = val ?? true),
                      ),
                      CheckboxListTile(
                        title: Text(AppTranslations.get('pos_sale_perm')),
                        value: canPosSale,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => canPosSale = val ?? true),
                      ),
                      CheckboxListTile(
                        title: Text(AppTranslations.get('accounts_perm')),
                        value: canAccounts,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => canAccounts = val ?? false),
                      ),
                      CheckboxListTile(
                        title: Text(AppTranslations.get('customer_perm')),
                        value: canCustomer,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => canCustomer = val ?? true),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppTranslations.get('cancel')),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _isLoadingNotifier,
                  builder: (context, isLoading, child) {
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
                      onPressed: isLoading
                          ? null
                          : () {
                        if (isEditing) {
                          _updateStaff(context, adminUid, staffId, formKey, nameController, phoneController, usernameController, passwordController, canProductList, canPosSale, canAccounts, canCustomer);
                        } else {
                          _addStaff(context, adminUid, formKey, nameController, phoneController, usernameController, passwordController, canProductList, canPosSale, canAccounts, canCustomer);
                        }
                      },
                      child: isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEditing ? AppTranslations.get('update') : AppTranslations.get('save')),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // স্টাফ ডিলিট করার ফাংশন
  void _deleteStaff(BuildContext context, String adminUid, String staffId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('delete_confirm_title')),
        content: Text(AppTranslations.get('delete_staff_msg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppTranslations.get('no'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppTranslations.get('yes_delete')),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUid)
          .collection('staffs')
          .doc(staffId)
          .delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('staff_deleted_msg'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text(AppTranslations.get('not_logged_in'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get('staff'), style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        onPressed: () => _showStaffDialog(context, user.uid),
        icon: const Icon(Icons.person_add),
        label: Text(AppTranslations.get('add_new_staff')),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('staffs')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                AppTranslations.get('no_staff_added'),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          var staffDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: staffDocs.length,
            itemBuilder: (context, index) {
              var staffData = staffDocs[index].data() as Map<String, dynamic>;
              String staffId = staffDocs[index].id;
              String name = staffData['name'] ?? '';
              String phone = staffData['phone'] ?? '';
              String username = staffData['username'] ?? '';

              var permissions = staffData['permissions'] ?? {};
              List<String> allowedFeatures = [];
              if (permissions['product_list'] == true) allowedFeatures.add(AppTranslations.get('product_list_perm'));
              if (permissions['pos_sale'] == true) allowedFeatures.add(AppTranslations.get('pos_sale_label'));
              if (permissions['accounts'] == true) allowedFeatures.add(AppTranslations.get('hisab'));
              if (permissions['customer'] == true || permissions['can_customer'] == true) allowedFeatures.add(AppTranslations.get('customer'));

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.person, color: Color(0xFF0D47A1)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${AppTranslations.get('username_label')} $username\n${AppTranslations.get('mobile_short')}: $phone\n${AppTranslations.get('access_label')} ${allowedFeatures.join(', ')}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // এডিট বাটন
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: AppTranslations.get('edit'),
                        onPressed: () => _showStaffDialog(context, user.uid, staffData: staffData, staffId: staffId),
                      ),
                      // ডিলিট বাটন
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: AppTranslations.get('delete'),
                        onPressed: () => _deleteStaff(context, user.uid, staffId),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}