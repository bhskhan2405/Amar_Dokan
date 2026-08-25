import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/notification_utils.dart';
import '../utils/translations.dart';

class UserApprovalScreen extends StatefulWidget {
  const UserApprovalScreen({super.key});

  @override
  State<UserApprovalScreen> createState() => _UserApprovalScreenState();
}

class _UserApprovalScreenState extends State<UserApprovalScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // হোয়াটসঅ্যাপে নোটিফিকেশন পাঠানোর হেল্পার
  Future<void> _sendWhatsAppNotification(String phone, String message) async {
    String formattedPhone = phone.trim();
    if (!formattedPhone.startsWith('88')) {
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '88$formattedPhone';
      } else {
        formattedPhone = '880$formattedPhone';
      }
    }
    
    final Uri url = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showApprovePinDialog(String uid, {bool isSubscription = false, String? requestId, String? plan, String? userPhone}) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          isSubscription ? AppTranslations.get('confirm_payment') : AppTranslations.get('verify_pin_to_approve'), 
          style: const TextStyle(color: Colors.white, fontSize: 16)
        ),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: AppTranslations.get('app_pin_label'),
            labelStyle: const TextStyle(color: Colors.grey),
            border: const OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(AppTranslations.get('cancel'))),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              String savedPin = prefs.getString('app_pin') ?? '1234';
              if (pinController.text.trim() == savedPin) {
                Navigator.pop(dialogContext);
                if (isSubscription) {
                  _confirmSubscription(uid, requestId!, plan!, userPhone!);
                } else {
                  _approveUser(uid, userPhone!);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('wrong_pin_msg'))));
              }
            },
            child: Text(AppTranslations.get('confirm_btn')),
          ),
        ],
      ),
    );
  }

  void _approveUser(String uid, String userPhone) async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isApproved': true,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.get('user_approved_msg')), backgroundColor: Colors.green),
        );

        String msg = "Congratulations! Your Amar Dokan account has been approved. You can now login and manage your shop.\n\n"
            "অভিনন্দন! আপনার আমার দোকান অ্যাকাউন্টটি অনুমোদিত হয়েছে। এখন আপনি লগইন করে আপনার দোকান পরিচালনা করতে পারেন।";
        _sendWhatsAppNotification(userPhone, msg);

        await NotificationUtils.sendNotification(
          title: "অ্যাকাউন্ট অনুমোদিত হয়েছে",
          message: "অভিনন্দন! আপনার অ্যাকাউন্টটি সফলভাবে অনুমোদিত হয়েছে। এখন আপনি সব ফিচার ব্যবহার করতে পারবেন।",
          targetUid: uid,
          type: 'approval',
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _confirmSubscription(String uid, String requestId, String plan, String userPhone) async {
    setState(() => _isProcessing = true);
    try {
      int months = 0;
      if (plan == '3_months') months = 3;
      else if (plan == '6_months') months = 6;
      else if (plan == '12_months') months = 12;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      DateTime currentExpiry = DateTime.now();
      
      if (userDoc.exists && userDoc.data()!.containsKey('subscriptionExpiryDate')) {
        DateTime dbExpiry = (userDoc.data()!['subscriptionExpiryDate'] as Timestamp).toDate();
        if (dbExpiry.isAfter(currentExpiry)) {
          currentExpiry = dbExpiry;
        }
      }

      DateTime newExpiry = DateTime(currentExpiry.year, currentExpiry.month + months, currentExpiry.day);

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'subscriptionExpiryDate': Timestamp.fromDate(newExpiry),
        'isApproved': true, 
      });

      await FirebaseFirestore.instance.collection('subscription_requests').doc(requestId).update({
        'status': 'approved',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Subscription confirmed successfully!"), backgroundColor: Colors.green),
        );

        String msg = "Great news! Your premium subscription for Amar Dokan is now active. Enjoy all the professional features.\n\n"
            "সুখবর! আমার দোকান অ্যাপে আপনার প্রিমিয়াম সাবস্ক্রিপশনটি এখন সচল হয়েছে। সব প্রফেশনাল ফিচারগুলো উপভোগ করুন।";
        _sendWhatsAppNotification(userPhone, msg);

        String planName = plan == '3_months' ? '৩ মাস' : (plan == '6_months' ? '৬ মাস' : '১২ মাস');
        await NotificationUtils.sendNotification(
          title: "প্রিমিয়াম সাবস্ক্রিপশন চালু হয়েছে",
          message: "অভিনন্দন! আপনার $planName মেয়াদী প্রিমিয়াম সাবস্ক্রিপশনটি সফলভাবে চালু হয়েছে।",
          targetUid: uid,
          type: 'subscription',
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Super Admin Panel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1F1F1F),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.greenAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white30,
          isScrollable: true,
          tabs: [
            Tab(text: AppTranslations.get('pending')),
            Tab(text: AppTranslations.get('approved')),
            Tab(text: AppTranslations.get('subscriptions')),
            const Tab(text: "Premium"), 
            const Tab(text: "Broadcast"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(isApproved: false),
          _buildUserList(isApproved: true),
          _buildSubscriptionRequests(),
          _buildPremiumUsersList(),
          _buildBroadcastUpdateSection(),
        ],
      ),
    );
  }

  Widget _buildUserList({required bool isApproved}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('isApproved', isEqualTo: isApproved)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isApproved ? Icons.people_rounded : Icons.group_off_rounded, size: 64, color: Colors.white12),
                const SizedBox(height: 16),
                Text(
                  isApproved ? 'No approved users.' : AppTranslations.get('no_pending_users'),
                  style: const TextStyle(color: Colors.white30),
                ),
              ],
            ),
          );
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            final uid = users[index].id;
            final name = data['name'] ?? 'Unknown';
            final shopName = data['shopName'] ?? 'No Shop Name';
            final phone = data['phone'] ?? 'No Phone';

            return Card(
              elevation: 4,
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                      ),
                      child: SelectableText(
                        "Shop ID: $uid",
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.store_rounded, size: 14, color: Colors.white60),
                        const SizedBox(width: 6),
                        Text('${AppTranslations.get('shop_name')}: $shopName', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_android_rounded, size: 14, color: Colors.white60),
                        const SizedBox(width: 6),
                        Text('${AppTranslations.get('mobile')}: $phone', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
                trailing: !isApproved 
                  ? ElevatedButton(
                      onPressed: _isProcessing ? null : () => _showApprovePinDialog(uid, userPhone: phone),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(AppTranslations.get('approve_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    )
                  : const Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 30),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubscriptionRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subscription_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, size: 64, color: Colors.white12),
                const SizedBox(height: 16),
                Text('No subscription requests.', style: TextStyle(color: Colors.white30)),
              ],
            ),
          );
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;
            final reqId = requests[index].id;
            final uid = data['uid'];
            final name = data['name'] ?? 'Unknown';
            final shop = data['shopName'] ?? 'No Shop';
            final plan = data['plan'] ?? 'Unknown';
            final txId = data['txId'] ?? 'No TxID';
            final phone = data['phone'] ?? '';

            return Card(
              color: const Color(0xFF1E1E1E),
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                      ),
                      child: SelectableText(
                        "Shop ID: $uid",
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text("$shop ($phone)", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const Divider(height: 24, color: Colors.white12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Plan:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(plan.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("Transaction ID:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(txId, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : () => _showApprovePinDialog(uid, isSubscription: true, requestId: reqId, plan: plan, userPhone: phone),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(AppTranslations.get('confirm_payment')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPremiumUsersList() {
    DateTime now = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('subscriptionExpiryDate', isGreaterThan: Timestamp.fromDate(now))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border_rounded, size: 64, color: Colors.white12),
                const SizedBox(height: 16),
                Text('No premium subscribers.', style: TextStyle(color: Colors.white30)),
              ],
            ),
          );
        }

        final premiumUsers = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: premiumUsers.length,
          itemBuilder: (context, index) {
            final data = premiumUsers[index].data() as Map<String, dynamic>;
            final uid = premiumUsers[index].id;
            final name = data['name'] ?? 'Unknown';
            final shop = data['shopName'] ?? 'No Shop';
            final phone = data['phone'] ?? '';
            final expiry = (data['subscriptionExpiryDate'] as Timestamp).toDate();
            int daysRemaining = expiry.difference(now).inDays;

            return Card(
              color: const Color(0xFF1E1E1E),
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: const CircleAvatar(
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.workspace_premium, color: Colors.white),
                ),
                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                      ),
                      child: SelectableText(
                        "Shop ID: $uid",
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text("$shop ($phone)", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        "Expires in: $daysRemaining days",
                        style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBroadcastUpdateSection() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "সবার জন্য নোটিফিকেশন পাঠান",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: titleController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "টাইটেল",
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: messageController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: "মেসেজ",
              labelStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                String title = titleController.text.trim();
                String message = messageController.text.trim();

                if (title.isEmpty || message.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("টাইটেল এবং মেসেজ উভয়ই দিন।"), backgroundColor: Colors.red),
                  );
                  return;
                }

                setState(() => _isProcessing = true);
                await NotificationUtils.sendAppUpdate(title: title, message: message);
                setState(() => _isProcessing = false);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("নোটিফিকেশন পাঠানো হয়েছে।"), backgroundColor: Colors.green),
                );
                titleController.clear();
                messageController.clear();
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text("সেন্ড করুন"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.shade700,
                foregroundColor: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
