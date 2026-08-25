import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/notification_utils.dart';
import '../utils/translations.dart';

class NotificationsScreen extends StatelessWidget {
  final bool isAdmin;

  const NotificationsScreen({super.key, this.isAdmin = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          AppTranslations.get('notifications') ?? 'নোটিফিকেশন',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'সব পড়া হয়েছে মার্ক করুন',
            onPressed: () => NotificationUtils.markAllAsRead(isAdmin),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: isAdmin 
            ? NotificationUtils.getAdminNotificationsStream() 
            : NotificationUtils.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'নোটিফিকেশন লোড করতে সমস্যা হয়েছে। দয়া করে ফায়ারস্টোর রুলস চেক করুন।',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'কোনো নোটিফিকেশন নেই',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              final bool isRead = data['isRead'] ?? false;
              final Timestamp? timestamp = data['timestamp'];
              final String timeStr = timestamp != null 
                  ? DateFormat('dd MMM, hh:mm a').format(timestamp.toDate()) 
                  : '';

              return Card(
                elevation: isRead ? 0 : 2,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isRead ? Colors.grey.shade200 : Colors.blue.shade100,
                    width: 1,
                  ),
                ),
                color: isRead ? Colors.white.withOpacity(0.8) : Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey.shade100 : Colors.blue.shade50,
                    child: Icon(
                      _getIconForType(data['type']),
                      color: isRead ? Colors.grey : const Color(0xFF0D47A1),
                    ),
                  ),
                  title: Text(
                    data['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        data['message'] ?? '',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeStr,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!isRead) {
                      NotificationUtils.markAsRead(notifications[index].id);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'admin_alert':
        return Icons.admin_panel_settings_rounded;
      case 'app_update':
        return Icons.system_update_rounded;
      case 'subscription':
        return Icons.workspace_premium_rounded;
      case 'approval':
        return Icons.verified_user_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
