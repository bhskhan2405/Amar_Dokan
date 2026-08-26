import 'package:flutter/material.dart';
import '../utils/translations.dart';
import '../utils/receipt_utils.dart';

class SubscriptionReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> requestData;
  const SubscriptionReceiptScreen({super.key, required this.requestData});

  @override
  Widget build(BuildContext context) {
    final String planName = (requestData['plan'] ?? 'Unknown').toString().replaceAll('_', ' ').toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(AppTranslations.get('subscription_receipt'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              AppTranslations.get('send_receipt_msg'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                children: [
                  _buildReceiptRow(AppTranslations.get('owner_name'), requestData['name']),
                  _buildReceiptRow(AppTranslations.get('shop_name'), requestData['shopName']),
                  _buildReceiptRow(AppTranslations.get('mobile'), requestData['phone']),
                  const Divider(height: 32),
                  _buildReceiptRow(AppTranslations.get('plan_details'), planName, isBold: true),
                  _buildReceiptRow(AppTranslations.get('transaction_id'), requestData['txId'], color: Colors.orange.shade900, isBold: true),
                  _buildReceiptRow('Sender Last 4', requestData['senderDigits'] ?? 'N/A', isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ReceiptUtils.shareSubscriptionCard(
                    name: requestData['name'] ?? '',
                    shopName: requestData['shopName'] ?? '',
                    phone: requestData['phone'] ?? '',
                    plan: planName,
                    txId: requestData['txId'] ?? '',
                    senderDigits: requestData['senderDigits'],
                  );
                },
                icon: const Icon(Icons.share_rounded),
                label: Text(AppTranslations.get('whatsapp_us'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppTranslations.get('cancel'), style: TextStyle(color: Colors.grey.shade600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, dynamic value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Flexible(
            child: Text(
              value.toString(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: 15,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
