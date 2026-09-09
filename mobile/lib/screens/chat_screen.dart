import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../utils/app_logger.dart';

class ChatScreen extends StatefulWidget {
  final int     otherUserId;
  final String  otherUserName;
  final String? otherUserPic;
  final int?    itemId;
  final String? itemTitle;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPic,
    this.itemId,
    this.itemTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api        = ApiService();
  final _chatSvc    = ChatService();
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  List<dynamic> _messages = [];
  bool          _loading  = true;
  bool          _sending  = false;
  bool          _isTyping = false;
  Timer?        _typingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupWebSocket();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _chatSvc.removeHandler(_handleIncoming);
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      AppLogger.warn('[Chat Screen] User not loaded, skipping message load.');
      return;
    }

    AppLogger.debug('[Chat Screen] Loading messages with user ${widget.otherUserId}, item ${widget.itemId}');
    try {
      final msgs = await _api.getConversation(
        user1Id: user.id,
        user2Id: widget.otherUserId,
        itemId:  widget.itemId,
      );
      
      if (mounted) {
        setState(() { 
          _messages = msgs;
          _loading = false;
        });
        AppLogger.debug('[Chat Screen] Loaded ${msgs.length} messages');
      }
      
      // Mark as read
      await _api.markAsRead(
        receiverId: user.id,
        senderId:   widget.otherUserId,
      );
      AppLogger.debug('[Chat Screen] Messages marked as read');
    } catch (e) {
      AppLogger.error('[Chat Screen] Error loading messages.', e);
      if (mounted) {
        setState(() => _loading = false);
      }
    }
    _scrollToBottom();
  }

  void _setupWebSocket() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    _chatSvc.connect(user.id, onMessage: _handleIncoming);
    _chatSvc.addHandler(_handleIncoming);
  }

  void _handleIncoming(Map<String, dynamic> msg) {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final type = msg['type'] as String?;
    AppLogger.debug('[Chat Screen] Received event type=$type');

    if (type == 'CHAT') {
      final senderId   = msg['senderId'] as int?;
      final receiverId = msg['receiverId'] as int?;

      bool isRelevant =
        (senderId   == widget.otherUserId &&
         receiverId == user.id) ||
        (senderId   == user.id &&
         receiverId == widget.otherUserId);

      if (isRelevant) {
        AppLogger.debug('[Chat Screen] Message is relevant, adding to UI.');
        setState(() {
          // Remove optimistic duplicates
          _messages.removeWhere((m) =>
            m['id'].toString().startsWith('opt_'));
          _messages.add({
            'id':        msg['messageId'],
            'content':   msg['content'],
            'createdAt': msg['timestamp'],
            'isRead':    false,
            'sender':    {
              'id':   msg['senderId'],
              'name': msg['senderName'],
            },
          });
        });
        // Mark read if we received
        if (receiverId == user.id) {
          AppLogger.debug('[Chat Screen] Marking message as read.');
          _api.markAsRead(
            receiverId: user.id,
            senderId:   widget.otherUserId,
          );
        }
        _scrollToBottom();
      } else {
        AppLogger.debug('[Chat Screen] Message not relevant to this conversation.');
      }
    }

    if (type == 'TYPING' &&
        msg['senderId'] == widget.otherUserId) {
      AppLogger.debug('[Chat Screen] Other user is typing...');
      setState(() => _isTyping = true);
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }

    if (type == 'READ') {
      AppLogger.debug('[Chat Screen] Read receipt received.');
      setState(() {
        for (int i = 0; i < _messages.length; i++) {
          _messages[i] = {
            ..._messages[i],
            'isRead': true,
          };
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    
    final content = _inputCtrl.text.trim();
    if (content.isEmpty || _sending) return;

    _inputCtrl.clear();
    setState(() => _sending = true);

    // Optimistic message
    final optimisticId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
    AppLogger.debug('[Chat Screen] Sending message (optimistic ID: $optimisticId)');
    
    setState(() {
      _messages.add({
        'id':        optimisticId,
        'content':   content,
        'createdAt': DateTime.now().toIso8601String(),
        'isRead':    false,
        'sender':    {'id': user.id, 'name': user.name},
      });
    });
    _scrollToBottom();

    // Try WS first
    final wsSent = _chatSvc.sendMessage(
      senderId:   user.id,
      receiverId: widget.otherUserId,
      itemId:     widget.itemId,
      content:    content,
    );

    // HTTP fallback
    if (!wsSent) {
      AppLogger.warn('[Chat Screen] WebSocket failed, using HTTP fallback.');
      try {
        final saved = await _api.sendMessageHttp(
          senderId:   user.id,
          receiverId: widget.otherUserId,
          itemId:     widget.itemId,
          content:    content,
        );
        AppLogger.debug('[Chat Screen] Message saved via HTTP.');
        setState(() {
          final idx = _messages.indexWhere(
            (m) => m['id'] == optimisticId);
          if (idx >= 0) _messages[idx] = saved;
        });
      } catch (e) {
        AppLogger.error('[Chat Screen] Send failed.', e);
        // Remove optimistic on failure
        setState(() =>
          _messages.removeWhere(
            (m) => m['id'] == optimisticId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'),
            backgroundColor: AppTheme.danger));
      }
    } else {
      AppLogger.debug('[Chat Screen] Message sent via WebSocket.');
    }

    setState(() => _sending = false);
    _focusNode.requestFocus();
  }

  void _onInputChanged(String val) {
    _typingTimer?.cancel();
    if (val.isNotEmpty) {
      _typingTimer = Timer(const Duration(milliseconds: 500), () {
        final user = context.read<AuthProvider>().user;
        if (user == null) return;
        AppLogger.debug('[Chat Screen] Sending typing indicator.');
        _chatSvc.sendTyping(
          senderId:   user.id,
          receiverId: widget.otherUserId,
          senderName: user.name,
        );
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? ts) {
    if (ts == null) return '';
    final d = DateTime.tryParse(
      ts.contains('T') ? ts : ts.replaceAll(' ', 'T'));
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2,'0')}:'
           '${d.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          // Avatar
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withAlpha(51)),
            child: Center(child: Text(
              widget.otherUserName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.otherUserName,
                style: const TextStyle(fontSize: 15)),
              if (widget.itemTitle != null)
                Text(widget.itemTitle!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),

      body: Column(children: [

        // ── Messages ──────────────────────────────────────────
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(
                color: AppTheme.accent))
            : _messages.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👋',
                      style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 10),
                    Text('Say hi to ${widget.otherUserName}!',
                      style: const TextStyle(
                        color: AppTheme.muted, fontSize: 14)),
                  ],
                ))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length +
                             (_isTyping ? 1 : 0),
                  itemBuilder: (ctx, i) {

                    // Typing indicator
                    if (i == _messages.length && _isTyping) {
                      return _buildTypingBubble();
                    }

                    final msg   = _messages[i];
                    final isMine =
                      (msg['sender']?['id'] as int?) == user?.id;
                    final showDate = i == 0 || _isDiffDay(
                      _messages[i-1]['createdAt'],
                      msg['createdAt']);

                    return Column(children: [
                      if (showDate) _buildDateSeparator(
                        msg['createdAt']),
                      _buildBubble(msg, isMine),
                    ]);
                  },
                ),
        ),

        // ── Input ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: AppTheme.bg,
            border: Border(
              top: BorderSide(color: AppTheme.border))),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface2,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.border2)),
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode:  _focusNode,
                    maxLines:   5,
                    minLines:   1,
                    onChanged:  _onInputChanged,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(
                      color: AppTheme.textPrim, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: AppTheme.muted),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                  ),
                )),
                const SizedBox(width: 8),
                // Send button
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _inputCtrl,
                  builder: (_, val, __) => GestureDetector(
                    onTap: val.text.trim().isEmpty
                      ? null : _sendMessage,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: val.text.trim().isNotEmpty
                          ? const LinearGradient(
                              colors: [AppTheme.accent,
                                       Color(0xFF4338CA)])
                          : null,
                        color: val.text.trim().isEmpty
                          ? AppTheme.border : null),
                      child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                        : Icon(Icons.send_rounded,
                            color: val.text.trim().isNotEmpty
                              ? Colors.white : AppTheme.muted,
                            size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, bool isMine) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 4,
        left:  isMine ? 48 : 0,
        right: isMine ? 0  : 48,
      ),
      child: Align(
        alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMine
              ? const LinearGradient(
                  colors: [AppTheme.accent, Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight)
              : null,
            color: isMine ? null : AppTheme.surface,
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(16),
              topRight:    const Radius.circular(16),
              bottomLeft:  Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            border: isMine
              ? null
              : Border.all(color: AppTheme.border),
            boxShadow: isMine ? [
              BoxShadow(
                color: AppTheme.accent.withAlpha(51),
                blurRadius: 8, offset: const Offset(0, 2)),
            ] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(msg['content'] ?? '',
                style: const TextStyle(
                  color: Colors.white, fontSize: 14,
                  height: 1.4)),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatTime(msg['createdAt']),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMine
                        ? Colors.white.withAlpha(140)
                        : AppTheme.muted)),
                  if (isMine) ...[
                    const SizedBox(width: 3),
                    Text(
                      msg['isRead'] == true ? '✓✓' : '✓',
                      style: TextStyle(
                        fontSize: 10,
                        color: msg['isRead'] == true
                          ? AppTheme.accent2
                          : Colors.white.withAlpha(102))),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(16),
              topRight:    Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft:  Radius.circular(4)),
            border: Border.all(color: AppTheme.border)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (n) => Padding(
              padding: EdgeInsets.only(right: n < 2 ? 3 : 0),
              child: _TypingDot(delay: n * 200),
            )),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSeparator(String? ts) {
    if (ts == null) return const SizedBox.shrink();
    final d = DateTime.tryParse(
      ts.contains('T') ? ts : ts.replaceAll(' ', 'T'));
    if (d == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(10)),
        child: Text(
          '${d.day}/${d.month}/${d.year}',
          style: const TextStyle(
            color: AppTheme.muted, fontSize: 11)),
      )),
    );
  }

  bool _isDiffDay(String? ts1, String? ts2) {
    if (ts1 == null || ts2 == null) return false;
    final d1 = DateTime.tryParse(
      ts1.contains('T') ? ts1 : ts1.replaceAll(' ', 'T'));
    final d2 = DateTime.tryParse(
      ts2.contains('T') ? ts2 : ts2.replaceAll(' ', 'T'));
    if (d1 == null || d2 == null) return false;
    return d1.day != d2.day || d1.month != d2.month;
  }
}

// Typing dot animation
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
    AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7, height: 7,
          decoration: const BoxDecoration(
            color: AppTheme.muted, shape: BoxShape.circle)),
      ),
    );
}
