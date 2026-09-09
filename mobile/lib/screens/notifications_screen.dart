import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  bool _loading = true;
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final res = await _api.getNotifications(user.id);
      setState(() {
        _notifications = List<dynamic>.from(res['notifications'] ?? []);
        _unreadCount = res['unreadCount'] ?? 0;
        _error = '';
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
    setState(() => _loading = false);
  }

  Future<void> _markRead(int notificationId) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      await _api.markNotificationRead(user.id, notificationId);
      setState(() {
        _notifications = _notifications.map((item) {
          if (item['id'] == notificationId) {
            item['read'] = true;
            item['isRead'] = true;
          }
          return item;
        }).toList();
        _unreadCount = (_unreadCount - 1).clamp(0, 9999);
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _markAllRead() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      await _api.markAllNotificationsRead(user.id);
      setState(() {
        for (final item in _notifications) {
          item['read'] = true;
          item['isRead'] = true;
        }
        _unreadCount = 0;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Read all', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5B4BFF)))
          : _notifications.isEmpty
              ? const Center(
                  child: Text('No notifications yet', style: TextStyle(color: Color(0xFF94A3B8))),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error, style: const TextStyle(color: Color(0xFFEF4444))),
                      ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1320),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1E2438)),
                      ),
                      child: Text('Unread: $_unreadCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    ..._notifications.map((item) {
                      final isRead = item['read'] == true || item['isRead'] == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isRead ? const Color(0xFF0F1320) : const Color(0xFF171D33),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isRead ? const Color(0xFF1E2438) : const Color(0xFF5B4BFF),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(item['title'] ?? 'Campus Mart', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                ),
                                if (!isRead)
                                  const Icon(Icons.fiber_manual_record, color: Color(0xFF00D4AA), size: 12),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(item['body'] ?? '', style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.5)),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item['createdAt'] ?? '', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                if (!isRead)
                                  TextButton(
                                    onPressed: () => _markRead(item['id'] as int),
                                    child: const Text('Mark read', style: TextStyle(color: Color(0xFF5B4BFF))),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
