import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/translations.dart';

class NotificationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> notificationData;

  const NotificationDetailScreen({super.key, required this.notificationData});

  @override
  Widget build(BuildContext context) {
    final String title = notificationData['title'] ?? AppTranslations.get('notifications');
    final String message = notificationData['message'] ?? '';
    final dynamic timestamp = notificationData['timestamp'];
    
    String timeStr = '';
    if (timestamp != null) {
      if (timestamp is DateTime) {
        timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
      } else {
        // Firestore Timestamp handle
        try {
          timeStr = DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
        } catch (_) {}
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.get('details') ?? 'Details', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF0D47A1),
                  child: Icon(Icons.notifications_active, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              message,
              style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(AppTranslations.get('go_back') ?? 'Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
