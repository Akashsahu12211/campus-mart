import SockJS from 'sockjs-client';
import { Client } from '@stomp/stompjs';
import { WS_BASE_URL } from '../config/runtimeConfig';
import { getAuthToken } from '../api/api';
import { logger } from '../utils/logger';

class WebSocketService {
  constructor() {
    this.client = null;
    this.connected = false;
    this.userId = null;
    this.handlers = [];
    this.reconnectTimer = null;
  }

  connect(userId, onMessage) {
    if (this.connected && this.userId === userId) return;

    this.userId = userId;
    if (onMessage) this.handlers.push(onMessage);

    this.client = new Client({
      webSocketFactory: () => new SockJS(WS_BASE_URL),
      connectHeaders: (() => {
        const token = getAuthToken();
        return token ? { Authorization: `Bearer ${token}` } : {};
      })(),
      reconnectDelay: 3000,
      onConnect: () => {
        this.connected = true;
        logger.debug('[WS] Connected');

        this.client.subscribe(`/user/${userId}/queue/messages`, (frame) => {
          try {
            const msg = JSON.parse(frame.body);
            this.handlers.forEach((handler) => handler(msg));
          } catch (error) {
            logger.error('[WS] Parse error:', error);
          }
        });
      },
      onDisconnect: () => {
        this.connected = false;
        logger.debug('[WS] Disconnected');
      },
      onStompError: (frame) => {
        logger.error('[WS] STOMP error:', frame.headers.message);
      },
    });

    this.client.activate();
  }

  sendMessage({ senderId, receiverId, itemId, content }) {
    if (!this.connected || !this.client) {
      logger.warn('[WS] Not connected, using HTTP fallback');
      return false;
    }

    this.client.publish({
      destination: '/app/chat.send',
      body: JSON.stringify({ senderId, receiverId, itemId, content }),
    });
    return true;
  }

  sendTyping({ senderId, receiverId, senderName }) {
    if (!this.connected || !this.client) return;

    this.client.publish({
      destination: '/app/chat.typing',
      body: JSON.stringify({ senderId, receiverId, senderName }),
    });
  }

  addHandler(handler) {
    if (!this.handlers.includes(handler)) {
      this.handlers.push(handler);
    }
  }

  removeHandler(handler) {
    this.handlers = this.handlers.filter((existingHandler) => existingHandler !== handler);
  }

  disconnect() {
    if (this.client) {
      this.client.deactivate();
      this.connected = false;
      this.handlers = [];
      this.userId = null;
    }
  }
}

const wsService = new WebSocketService();

export default wsService;
