import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/notification_utils.dart';
import '../utils/translations.dart';
import '../widgets/custom_banner_ad.dart';

class NotificationsScreen extends StatefulWidget {
  final bool isAdmin;

  const NotificationsScreen({super.key, this.isAdmin = false});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('মুছে ফেলুন?'),
        content: Text('আপনি কি নির্বাচিত ${_selectedIds.length}টি নোটিফিকেশন মুছে ফেলতে চান?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('না')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('হ্যাঁ, মুছুন', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationUtils.deleteMultipleNotifications(_selectedIds.toList());
      _clearSelection();
    }
  }

  Future<void> _deleteAll() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('সব মুছে ফেলুন?'),
        content: const Text('আপনি কি সব নোটিফিকেশন মুছে ফেলতে চান? এটি আর ফিরিয়ে আনা যাবে না।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('বাতিল')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('হ্যাঁ, সব মুছুন', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NotificationUtils.deleteAllNotifications(widget.isAdmin);
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(
          _isSelectionMode 
            ? '${_selectedIds.length} নির্বাচিত' 
            : (AppTranslations.get('notifications') ?? 'নোটিফিকেশন'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: _isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection)
          : null,
        backgroundColor: _isSelectionMode ? Colors.red.shade800 : const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'নির্বাচিত গুলো মুছুন',
              onPressed: _deleteSelected,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'সব পড়া হয়েছে মার্ক করুন',
              onPressed: () => NotificationUtils.markAllAsRead(widget.isAdmin),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete_all') _deleteAll();
              },
              icon: const Icon(Icons.more_vert, color: Colors.white),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('সব মুছে ফেলুন'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          const CustomBannerAd(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.isAdmin 
                  ? NotificationUtils.getAdminNotificationsStream() 
                  : NotificationUtils.getNotificationsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'নোটিফিকেশন লোড করতে সমস্যা হয়েছে।',
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
                    final doc = notifications[index];
                    final id = doc.id;
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isRead = data['isRead'] ?? false;
                    final bool isSelected = _selectedIds.contains(id);
                    final Timestamp? timestamp = data['timestamp'];
                    final String timeStr = timestamp != null 
                        ? DateFormat('dd MMM, hh:mm a').format(timestamp.toDate()) 
                        : '';

                    return Dismissible(
                      key: Key(id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        NotificationUtils.deleteNotification(id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('নোটিফিকেশন মুছে ফেলা হয়েছে'), duration: Duration(seconds: 2)),
                        );
                      },
                      child: Card(
                        elevation: isRead ? 0 : 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected 
                              ? Colors.red.shade300 
                              : (isRead ? Colors.grey.shade200 : Colors.blue.shade100),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        color: isSelected 
                          ? Colors.red.shade50 
                          : (isRead ? Colors.white.withOpacity(0.8) : Colors.white),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected, 
                                onChanged: (_) => _toggleSelection(id),
                                activeColor: Colors.red.shade800,
                              )
                            : CircleAvatar(
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
                          onLongPress: () => _toggleSelection(id),
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(id);
                            } else {
                              if (!isRead) {
                                NotificationUtils.markAsRead(id);
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
