import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../utils/app_logger.dart';
import 'chat_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});
  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final _api      = ApiService();
  final _chatSvc  = ChatService();
  List<dynamic> _inbox   = [];
  bool          _loading = true;
  int           _unread  = 0;
  Timer? _fallbackRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadInbox();
    _setupWebSocket();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _fallbackRefreshTimer?.cancel();
    _chatSvc.removeHandler(_handleIncomingMessage);
    super.dispose();
  }

  void _setupWebSocket() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    
    AppLogger.debug('[Chat Inbox] Setting up WebSocket listener...');
    _chatSvc.connect(user.id, onMessage: _handleIncomingMessage);
    _chatSvc.addHandler(_handleIncomingMessage);
  }

  void _handleIncomingMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    
    if (type == 'CHAT') {
      AppLogger.debug('[Chat Inbox] New message received, refreshing inbox...');
      _loadInbox(); // Refetch inbox like web version
    }
  }

  void _startAutoRefresh() {
    _fallbackRefreshTimer?.cancel();
    _fallbackRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      _loadInbox();
    });
  }

  Future<void> _loadInbox() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      AppLogger.warn('[Chat Inbox] User not loaded, skipping inbox fetch.');
      return;
    }
    
    AppLogger.debug('[Chat Inbox] Fetching inbox for user ${user.id}...');
    try {
      final results = await Future.wait([
        _api.getInbox(user.id),
        _api.getUnreadCount(user.id),
      ]);
      
      if (mounted) {
        setState(() {
          _inbox   = results[0] as List;
          _unread  = results[1] as int;
          _loading = false;
        });
        AppLogger.debug('[Chat Inbox] Inbox ready with ${_inbox.length} conversations');
      }
    } catch (e) {
      AppLogger.error('[Chat Inbox] Error loading inbox.', e);
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatTime(String? ts) {
    if (ts == null) return '';
    final date = DateTime.tryParse(
      ts.contains('T') ? ts : ts.replaceAll(' ', 'T'));
    if (date == null) return '';
    final now  = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inHours   < 1)  return '${diff.inMinutes}m';
    if (diff.inDays    < 1)  return '${diff.inHours}h';
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('Messages'),
          if (_unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(10)),
              child: Text('$_unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInbox,
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(
            color: AppTheme.accent))
        : _inbox.isEmpty
          ? Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💬',
                  style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('No messages yet',
                  style: TextStyle(
                    color: AppTheme.textSec,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Start chatting from any item',
                  style: TextStyle(
                    color: AppTheme.muted, fontSize: 13)),
              ],
            ))
          : RefreshIndicator(
              color: AppTheme.accent,
              onRefresh: _loadInbox,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _inbox.length,
                itemBuilder: (ctx, i) {
                  final conv    = _inbox[i];
                  final other   = conv['otherUser'];
                  final lastMsg = conv['lastMessage'];
                  final item    = conv['item'];
                  final unread  =
                    (conv['unreadCount'] as num?)?.toInt() ?? 0;

                  return GestureDetector(
                    onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>
                        ChatScreen(
                          otherUserId:   other['id'],
                          otherUserName: other['name'] ?? '',
                          otherUserPic:  other['profilePic'],
                          itemId:        item?['id'],
                          itemTitle:     item?['title'],
                        ))),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: unread > 0
                            ? AppTheme.accent.withAlpha(102)
                            : AppTheme.border)),
                      child: Row(children: [
                        // Avatar
                        _buildAvatar(
                          other['profilePic'], other['name'] ?? '?'),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(child: Column(
                          crossAxisAlignment:
                            CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                              children: [
                                Text(other['name'] ?? '',
                                  style: const TextStyle(
                                    color: AppTheme.textPrim,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                                Text(
                                  _formatTime(lastMsg?['timestamp']),
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 11)),
                              ],
                            ),
                            if (item != null) ...[
                              const SizedBox(height: 2),
                              Text('📦 ${item['title']}',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                            ],
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(
                                  '${lastMsg?['isMine']==true ? "You: " : ""}${lastMsg?['content'] ?? ""}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unread > 0
                                      ? AppTheme.textSec
                                      : AppTheme.muted,
                                    fontSize: 12,
                                    fontWeight: unread > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400))),
                                if (unread > 0)
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(
                                      minWidth: 20, minHeight: 20),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accent,
                                      shape: BoxShape.circle),
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800)),
                                  ),
                              ],
                            ),
                          ],
                        )),
                      ]),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildAvatar(String? pic, String name) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: pic != null && pic.isNotEmpty
          ? Colors.transparent
          : AppTheme.accent.withAlpha(77),
        image: pic != null && pic.isNotEmpty &&
               !pic.startsWith('data:')
          ? DecorationImage(
              image: NetworkImage(pic),
              fit: BoxFit.cover)
          : null,
      ),
      child: pic == null || pic.isEmpty
        ? Center(child: Text(
            name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w800, fontSize: 18)))
        : null,
    );
  }
}
