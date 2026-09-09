import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../utils/app_logger.dart';
import 'api_service.dart';
import 'secure_session_storage.dart';

typedef MessageHandler = void Function(Map<String, dynamic>);

class ChatService {
  static final ChatService _instance = ChatService._internal();

  factory ChatService() => _instance;

  ChatService._internal();

  StompClient? _client;
  bool _connected = false;
  int? _userId;
  final List<MessageHandler> _handlers = [];

  Future<void> connect(int userId, {MessageHandler? onMessage}) async {
    if (_connected && _userId == userId) {
      AppLogger.debug('[WS] Already connected as user $userId, skipping reconnect.');
      return;
    }

    _userId = userId;
    if (onMessage != null && !_handlers.contains(onMessage)) {
      _handlers.add(onMessage);
    }

    final wsUrl = ApiService().activeWebSocketUrl;
    final token = await SecureSessionStorage.readAccessToken();

    AppLogger.debug('[WS] Connecting as user $userId...');
    AppLogger.debug('[WS] WebSocket URL: $wsUrl');

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        stompConnectHeaders: token != null && token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : const {},
        onConnect: _onConnected,
        onDisconnect: _onDisconnected,
        onStompError: (frame) {
          AppLogger.error('[WS] STOMP error.', frame.body);
        },
        onWebSocketError: (error) {
          AppLogger.error('[WS] WebSocket error.', error);
        },
        reconnectDelay: const Duration(seconds: 3),
        useSockJS: true,
      ),
    );
    _client!.activate();
  }

  void _onConnected(StompFrame frame) {
    _connected = true;
    AppLogger.info('[WS] Connected successfully. User: $_userId');

    _client!.subscribe(
      destination: '/user/$_userId/queue/messages',
      callback: (frame) {
        if (frame.body == null) {
          return;
        }

        try {
          final message = jsonDecode(frame.body!) as Map<String, dynamic>;
          AppLogger.debug('[WS] Received message type: ${message['type']}');
          for (final handler in _handlers) {
            handler(message);
          }
        } catch (error) {
          AppLogger.error('[WS] Parse error.', error);
        }
      },
    );
    AppLogger.debug('[WS] Subscribed to /user/$_userId/queue/messages');
  }

  void _onDisconnected(StompFrame frame) {
    _connected = false;
    AppLogger.warn('[WS] Disconnected');
  }

  bool sendMessage({
    required int senderId,
    required int receiverId,
    int? itemId,
    required String content,
  }) {
    if (!_connected || _client == null) {
      AppLogger.warn('[WS] Not connected, WebSocket message send failed.');
      return false;
    }

    AppLogger.debug(
      '[WS] Sending message: sender=$senderId, receiver=$receiverId, item=$itemId',
    );
    _client!.send(
      destination: '/app/chat.send',
      body: jsonEncode({
        'senderId': senderId,
        'receiverId': receiverId,
        if (itemId != null) 'itemId': itemId,
        'content': content,
      }),
    );
    AppLogger.debug('[WS] Message sent via WebSocket');
    return true;
  }

  void sendTyping({
    required int senderId,
    required int receiverId,
    required String senderName,
  }) {
    if (!_connected || _client == null) {
      AppLogger.warn('[WS] Not connected, typing indicator not sent.');
      return;
    }

    AppLogger.debug('[WS] Sending typing indicator for $senderName');
    _client!.send(
      destination: '/app/chat.typing',
      body: jsonEncode({
        'senderId': senderId,
        'receiverId': receiverId,
        'senderName': senderName,
      }),
    );
  }

  void addHandler(MessageHandler handler) {
    if (!_handlers.contains(handler)) {
      _handlers.add(handler);
      AppLogger.debug('[WS] Handler added (total: ${_handlers.length})');
    }
  }

  void removeHandler(MessageHandler handler) {
    _handlers.remove(handler);
    AppLogger.debug('[WS] Handler removed (total: ${_handlers.length})');
  }

  void disconnect() {
    AppLogger.debug('[WS] Disconnecting WebSocket...');
    _client?.deactivate();
    _connected = false;
    _handlers.clear();
    _userId = null;
    AppLogger.debug('[WS] Disconnected and cleaned up');
  }

  bool get isConnected => _connected;
}
