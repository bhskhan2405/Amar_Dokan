import 'package:flutter/material.dart';
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
  bool _isSubmitting = false;

  final String _paymentPhone = "01828424364";
  final String _whatsappPhone = "8801875787997";

  @override
  void dispose() {
    _txIdController.dispose();
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

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // ইউজার ডাটা আনা
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // পেমেন্ট রিকোয়েস্ট তৈরি
      await FirebaseFirestore.instance.collection('subscription_requests').add({
        'uid': user.uid,
        'name': userData['name'] ?? 'Unknown',
        'shopName': userData['shopName'] ?? 'No Shop',
        'phone': userData['phone'] ?? 'No Phone',
        'plan': _selectedPlan,
        'txId': _txIdController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // এডমিনকে নতুন পেমেন্ট রিকোয়েস্ট জানানো
      String planName = _selectedPlan == '3_months' ? '৩ মাস' : (_selectedPlan == '6_months' ? '৬ মাস' : '১২ মাস');
      await NotificationUtils.notifyAdmin(
        title: "নতুন সাবস্ক্রিপশন রিকোয়েস্ট",
        message: "${userData['name'] ?? 'ইউজার'} ($planName) প্রিমিয়াম প্ল্যানের জন্য পেমেন্ট সাবমিট করেছেন। TxID: ${_txIdController.text.trim()}",
      );

      _showSnackBar(AppTranslations.get('payment_submitted_msg'));

      final reqData = {
        'uid': user.uid,
        'name': userData['name'] ?? 'Unknown',
        'shopName': userData['shopName'] ?? 'No Shop',
        'phone': userData['phone'] ?? 'No Phone',
        'plan': _selectedPlan,
        'txId': _txIdController.text.trim(),
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
      body: SingleChildScrollView(
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    const Text('Payment Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D47A1))),
                    const SizedBox(height: 12),
                    Text(
                      'Send money to $_paymentPhone (bKash/Nagad)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _txIdController,
                      decoration: InputDecoration(
                        labelText: AppTranslations.get('enter_txid'),
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
        color: isSelected ? color.withOpacity(0.05) : Colors.white,
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
}
