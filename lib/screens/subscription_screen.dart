import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/notification_utils.dart';
import 'subscription_receipt_screen.dart';
import '../utils/translations.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String? _selectedPlan;
  final TextEditingController _txIdController = TextEditingController();
  final TextEditingController _senderPhoneController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasPendingRequest = false;
  Map<String, dynamic>? _pendingRequestData;

  final String _paymentPhone = "01828424364";
  final String _whatsappPhone = "8801875787997";

  @override
  void initState() {
    super.initState();
    _checkPendingRequest();
  }

  Future<void> _checkPendingRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('subscription_requests')
        .where('uid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _hasPendingRequest = true;
          _pendingRequestData = snapshot.docs.first.data();
        });
      }
    }
  }

  @override
  void dispose() {
    _txIdController.dispose();
    _senderPhoneController.dispose();
    super.dispose();
  }

  void _submitPayment() async {
    if (_selectedPlan == null) {
      _showSnackBar(AppTranslations.get('select_plan_msg'));
      return;
    }
    if (_txIdController.text.trim().isEmpty) {
      _showSnackBar(AppTranslations.get('txid_required'));
      return;
    }
    if (_senderPhoneController.text.trim().length < 4) {
      _showSnackBar("পেমেন্ট করা নাম্বারের শেষ ৪ ডিজিট দিন।");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ইউজার ডাটা আনা
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final txId = _txIdController.text.trim();
      final senderDigits = _senderPhoneController.text.trim();

      // পেমেন্ট রিকোয়েস্ট তৈরি
      await FirebaseFirestore.instance.collection('subscription_requests').add({
        'uid': user.uid,
        'name': userData['name'] ?? 'Unknown',
        'shopName': userData['shopName'] ?? 'No Shop',
        'phone': userData['phone'] ?? 'No Phone',
        'plan': _selectedPlan,
        'txId': txId,
        'senderDigits': senderDigits,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // এডমিনকে নতুন পেমেন্ট রিকোয়েস্ট জানানো
      String planName = _selectedPlan == '3_months' ? '৩ মাস' : (_selectedPlan == '6_months' ? '৬ মাস' : '১২ মাস');
      await NotificationUtils.notifyAdmin(
        title: "নতুন সাবস্ক্রিপশন রিকোয়েস্ট",
        message: "${userData['name'] ?? 'ইউজার'} ($planName) পেমেন্ট সাবমিট করেছেন।\nTxID: $txId\nSender Last 4: $senderDigits",
      );

      _showSnackBar(AppTranslations.get('payment_submitted_msg'));

      final reqData = {
        'uid': user.uid,
        'name': userData['name'] ?? 'Unknown',
        'shopName': userData['shopName'] ?? 'No Shop',
        'phone': userData['phone'] ?? 'No Phone',
        'plan': _selectedPlan,
        'txId': txId,
        'senderDigits': senderDigits,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SubscriptionReceiptScreen(requestData: reqData)),
      );

    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppTranslations.get('buy_premium'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _hasPendingRequest ? _buildPendingUI() : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.stars_rounded, size: 60, color: Color(0xFF0D47A1)),
            const SizedBox(height: 16),
            Text(
              AppTranslations.get('premium_feature'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.get('subscription_required'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            
            _buildPlanCard(
              id: '3_months',
              title: AppTranslations.get('plan_3_month'),
              icon: Icons.timer_3,
              color: Colors.blue.shade700,
            ),
            _buildPlanCard(
              id: '6_months',
              title: AppTranslations.get('plan_6_month'),
              icon: Icons.timer_10,
              color: Colors.teal.shade700,
            ),
            _buildPlanCard(
              id: '12_months',
              title: AppTranslations.get('plan_12_month'),
              icon: Icons.verified_rounded,
              color: Colors.indigo.shade800,
            ),

            if (_selectedPlan != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    const Text('Payment Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D47A1))),
                    const SizedBox(height: 12),
                    Text(
                      'নিচের এই নাম্বারে Bkash/Nagad থেকে Send Money করুন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _paymentPhone,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy_all_rounded, color: Colors.blueAccent),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _paymentPhone));
                            _showSnackBar("পেমেন্ট নাম্বার কপি করা হয়েছে।");
                          },
                          tooltip: "পেমেন্ট নাম্বার কপি করুন",
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'পেমেন্ট করার পর রিসিট বা এপ্লিকেশন কার্ডটি নিচের হোয়াটসঅ্যাপ নাম্বারে পাঠিয়ে দিন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "+$_whatsappPhone",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.copy, size: 18, color: Colors.green),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: "+$_whatsappPhone"));
                            _showSnackBar("হোয়াটসঅ্যাপ নাম্বার কপি করা হয়েছে।");
                          },
                        ),
                      ],
                    ),
                    Text(
                      '(সাবধান: এই হোয়াটসঅ্যাপ নাম্বারে কোনো প্রকার লেনদেন করবেন না)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'টাকা পাঠানোর পর নিচের ১ নম্বর বক্সে TxID দিন এবং ২ নম্বর বক্সে যে নাম্বার থেকে টাকা পাঠিয়েছেন তার শেষ ৪ ডিজিট দিন।',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _txIdController,
                      decoration: InputDecoration(
                        labelText: '১. ${AppTranslations.get('enter_txid')}',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _senderPhoneController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: '২. সেন্ডার নাম্বারের শেষ ৪ ডিজিট',
                        counterText: '',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(AppTranslations.get('submit_payment'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () async {
                final url = Uri.parse('https://wa.me/$_whatsappPhone');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              label: Text(AppTranslations.get('whatsapp_us')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({required String id, required String title, required IconData icon, required Color color}) {
    bool isSelected = _selectedPlan == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = id),
      child: Card(
        elevation: isSelected ? 4 : 1,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected ? BorderSide(color: color, width: 2) : BorderSide.none,
        ),
        color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isSelected ? color : Colors.black87)),
          trailing: isSelected ? Icon(Icons.check_circle, color: color) : const Icon(Icons.circle_outlined, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildPendingUI() {
    String plan = _pendingRequestData?['plan'] ?? 'Unknown';
    String planName = plan == '3_months' ? '৩ মাস' : (plan == '6_months' ? '৬ মাস' : '১২ মাস');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pending_actions_rounded, size: 100, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              "আপনার প্রিমিয়াম প্ল্যান রিকোয়েস্টটি পেন্ডিং আছে।",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 12),
            Text(
              "আপনার $planName মেয়াদী প্ল্যানটি ২৪ ঘণ্টার মধ্যে সচল হয়ে যাবে। দয়া করে অপেক্ষা করুন।",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse('https://wa.me/$_whatsappPhone');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
              icon: const Icon(Icons.chat),
              label: const Text("হোয়াটসঅ্যাপে যোগাযোগ করুন"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ফিরে যান"),
            ),
          ],
        ),
      ),
    );
  }
}
