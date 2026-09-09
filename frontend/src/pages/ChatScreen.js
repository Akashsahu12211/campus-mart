import React, {
  useEffect, useState, useRef, useCallback
} from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import {
  getConversation, sendMessage as sendHttp, markAsRead
} from '../api/api';
import wsService from '../services/websocket';
import { useAuth } from '../App';

export default function ChatScreen() {
  const { user }   = useAuth();
  const location   = useLocation();
  const navigate   = useNavigate();
  const {
    otherUserId, otherUserName,
    otherUserPic, itemId, itemTitle
  } = location.state || {};

  const [messages,  setMessages]  = useState([]);
  const [input,     setInput]     = useState('');
  const [loading,   setLoading]   = useState(true);
  const [sending,   setSending]   = useState(false);
  const [isTyping,  setIsTyping]  = useState(false);
  const [blockedMsg, setBlockedMsg] = useState('');
  const bottomRef   = useRef(null);
  const inputRef    = useRef(null);
  const typingTimer = useRef(null);

  // ── Load conversation ──────────────────────────────────────
  const loadMessages = useCallback(async () => {
    if (!user || !otherUserId) return;
    try {
      const res = await getConversation(
        user.id, otherUserId, itemId || null);
      setMessages(res.data);
      setBlockedMsg('');
      // Mark as read
      await markAsRead(user.id, otherUserId);
    } catch (e) {
      const message = String(e?.response?.data?.error || e?.message || '').toLowerCase();
      if (message.includes('block') || message.includes('cannot message')) {
        setBlockedMsg('This conversation is unavailable because one of you has blocked the other user.');
      }
    }
    finally { setLoading(false); }
  }, [user, otherUserId, itemId]);

  // ── WebSocket setup ────────────────────────────────────────
  useEffect(() => {
    if (!user || !otherUserId) {
      console.error('ChatScreen: Missing user or otherUserId. User:', user?.id, 'OtherUser:', otherUserId);
      navigate('/login'); 
      return;
    }

    console.log('ChatScreen mounted! Starting chat with:', otherUserId, otherUserName);
    loadMessages();

    // Handle incoming WS messages
    const handleIncoming = (msg) => {
      console.log('📩 Incoming WebSocket message:', msg.type, msg);
      if (msg.type === 'CHAT' &&
         ((msg.senderId === otherUserId &&
           msg.receiverId === user.id) ||
          (msg.senderId === user.id &&
           msg.receiverId === otherUserId))) {
        console.log('💬 Chat message received, updating UI');
        setMessages(prev => {
          // Avoid duplicates
          if (prev.some(m =>
              m.id === msg.messageId)) return prev;
          return [...prev, {
            id:         msg.messageId,
            content:    msg.content,
            createdAt:  msg.timestamp,
            isRead:     false,
            sender: {
              id:   msg.senderId,
              name: msg.senderName,
            },
          }];
        });
        // Mark as read if we are receiver
        if (msg.receiverId === user.id) {
          markAsRead(user.id, otherUserId).catch(() => {});
        }
      }
      if (msg.type === 'TYPING' &&
          msg.senderId === otherUserId) {
        console.log('⌨️ Typing indicator received');
        setIsTyping(true);
        setTimeout(() => setIsTyping(false), 2500);
      }
      if (msg.type === 'READ' &&
          msg.senderId === user.id) {
        console.log('✓ Read receipt received');
        setMessages(prev =>
          prev.map(m => ({ ...m, isRead: true })));
      }
    };

    console.log('🔌 Connecting WebSocket for user:', user.id);
    wsService.connect(user.id, handleIncoming);
    wsService.addHandler(handleIncoming);

    return () => {
      wsService.removeHandler(handleIncoming);
      clearTimeout(typingTimer.current);
    };
  }, [user, otherUserId, itemId, otherUserName, navigate, loadMessages]);

  // ── Auto scroll ────────────────────────────────────────────
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isTyping]);

  // ── Send Message ───────────────────────────────────────────
  const handleSend = async () => {
    if (!input.trim() || sending) return;
    if (blockedMsg) return;
    const content = input.trim();
    console.log('📤 Sending message:', content, 'to user:', otherUserId);
    setInput('');
    setSending(true);

    // Optimistic update
    const optimistic = {
      id:        'opt_' + Date.now(),
      content,
      createdAt: new Date().toISOString(),
      isRead:    false,
      sender:    { id: user.id, name: user.name },
    };
    setMessages(prev => [...prev, optimistic]);

    // Try WebSocket first
    console.log('🔌 Attempting WebSocket send...');
    const wsSent = wsService.sendMessage({
      senderId:   user.id,
      receiverId: otherUserId,
      itemId:     itemId || null,
      content,
    });

    // HTTP fallback if WS not connected
    if (!wsSent) {
      console.log('⚠️ WebSocket send failed, using HTTP fallback');
      try {
        const res = await sendHttp({
          senderId:   user.id,
          receiverId: otherUserId,
          itemId:     itemId || null,
          content,
        });
        console.log('✅ HTTP send successful:', res.data);
        // Replace optimistic with real
        setMessages(prev =>
          prev.map(m =>
            m.id === optimistic.id ? res.data : m));
      } catch (e) {
        console.error('❌ HTTP send failed:', e.message);
        const message = String(e?.response?.data?.error || e?.message || '').toLowerCase();
        if (message.includes('block') || message.includes('cannot message')) {
          setBlockedMsg('You cannot send messages in this chat right now.');
        }
      }
    } else {
      console.log('✅ WebSocket send successful');
    }
    setSending(false);
    inputRef.current?.focus();
  };

  // ── Typing indicator ───────────────────────────────────────
  const handleInputChange = (e) => {
    setInput(e.target.value);
    clearTimeout(typingTimer.current);
    typingTimer.current = setTimeout(() => {
      wsService.sendTyping({
        senderId:   user.id,
        receiverId: otherUserId,
        senderName: user.name,
      });
    }, 500);
  };

  const formatTime = (ts) => {
    if (!ts) return '';
    const d = new Date(ts.includes('T') ? ts : ts.replace(' ','T'));
    return d.toLocaleTimeString('en-IN', {
      hour: '2-digit', minute: '2-digit'
    });
  };

  if (!otherUserId) {
    console.error('ChatScreen: Missing otherUserId in state. State was:', location.state);
    return (
      <div style={{
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        height: '100vh', background: '#080b14',
        color: '#e8eaf6',
      }}>
        <p>❌ Error: Could not open chat. Please try again.</p>
        <button
          onClick={() => navigate('/chat')}
          style={{
            marginTop: '20px',
            padding: '10px 20px',
            background: '#5b4bff',
            border: 'none',
            borderRadius: '8px',
            color: 'white',
            cursor: 'pointer',
          }}
        >
          Go back to Messages
        </button>
      </div>
    );
  }

  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      height: '100vh', background: '#080b14',
    }}>

      {/* ── Header ── */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: '12px',
        padding: '14px 20px', paddingTop: '78px',
        background: 'rgba(8,11,20,0.95)',
        backdropFilter: 'blur(16px)',
        borderBottom: '1px solid #1e2438',
        flexShrink: 0,
      }}>
        <button
          onClick={() => navigate('/chat')}
          style={{
            background: 'none', border: 'none',
            color: '#a0a8c8', cursor: 'pointer',
            fontSize: '1.2rem', padding: '4px',
          }}
        >
          ←
        </button>

        {/* Avatar */}
        <div style={{
          width: '40px', height: '40px', borderRadius: '50%',
          background: otherUserPic
            ? 'transparent'
            : 'linear-gradient(135deg,#5b4bff,#00d4aa)',
          overflow: 'hidden',
          display: 'flex', alignItems: 'center',
          justifyContent: 'center',
          fontSize: '1rem', fontWeight: 800, color: '#fff',
          flexShrink: 0,
        }}>
          {otherUserPic ? (
            <img src={otherUserPic} alt=""
              style={{ width: '100%', height: '100%',
                objectFit: 'cover' }} />
          ) : (
            otherUserName?.charAt(0).toUpperCase()
          )}
        </div>

        <div>
          <p style={{
            fontWeight: 700, color: '#e8eaf6', fontSize: '0.95rem',
          }}>
            {otherUserName}
          </p>
          {itemTitle && (
            <p style={{
              fontSize: '0.72rem', color: '#5b4bff', fontWeight: 600,
            }}>
              re: {itemTitle}
            </p>
          )}
        </div>
      </div>

      {/* ── Messages ── */}
      <div style={{
        flex: 1, overflowY: 'auto', padding: '16px',
        display: 'flex', flexDirection: 'column', gap: '8px',
      }}>
        {loading ? (
          <div className="loading-wrap">
            <div className="spinner" />
          </div>
        ) : blockedMsg ? (
          <div style={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            textAlign: 'center',
            color: '#fca5a5',
            padding: '24px',
          }}>
            {blockedMsg}
          </div>
        ) : messages.length === 0 ? (
          <div style={{
            flex: 1, display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center',
            color: '#5a6285', textAlign: 'center',
          }}>
            <p style={{ fontSize: '2.5rem', marginBottom: '8px' }}>
              👋
            </p>
            <p style={{ fontWeight: 600, marginBottom: '4px' }}>
              Start the conversation
            </p>
            <p style={{ fontSize: '0.82rem' }}>
              Say hi to {otherUserName}!
            </p>
          </div>
        ) : (
          messages.map((msg, i) => {
            const isMine = msg.sender?.id === user?.id;
            const showDate = i === 0 || (
              new Date(messages[i-1].createdAt).toDateString() !==
              new Date(msg.createdAt).toDateString()
            );
            return (
              <React.Fragment key={msg.id}>
                {showDate && (
                  <div style={{
                    textAlign: 'center', margin: '8px 0',
                  }}>
                    <span style={{
                      background: '#141929',
                      border: '1px solid #1e2438',
                      borderRadius: '12px',
                      padding: '3px 12px',
                      fontSize: '0.72rem', color: '#5a6285',
                    }}>
                      {new Date(msg.createdAt)
                        .toLocaleDateString('en-IN', {
                          day:'numeric', month:'short'
                        })}
                    </span>
                  </div>
                )}
                <div style={{
                  display: 'flex',
                  justifyContent: isMine
                    ? 'flex-end' : 'flex-start',
                }}>
                  <div style={{
                    maxWidth: '72%',
                    background: isMine
                      ? 'linear-gradient(135deg,#5b4bff,#4338ca)'
                      : '#0f1320',
                    border: isMine
                      ? 'none' : '1px solid #1e2438',
                    borderRadius: isMine
                      ? '16px 16px 4px 16px'
                      : '16px 16px 16px 4px',
                    padding: '10px 14px',
                    boxShadow: isMine
                      ? '0 4px 16px rgba(91,75,255,0.25)'
                      : 'none',
                  }}>
                    <p style={{
                      color: '#e8eaf6', fontSize: '0.9rem',
                      lineHeight: 1.5, margin: 0,
                      wordBreak: 'break-word',
                    }}>
                      {msg.content}
                    </p>
                    <div style={{
                      display: 'flex', gap: '4px',
                      alignItems: 'center',
                      justifyContent: 'flex-end',
                      marginTop: '4px',
                    }}>
                      <span style={{
                        fontSize: '0.68rem', color:
                          isMine ? 'rgba(255,255,255,0.5)' : '#5a6285',
                      }}>
                        {formatTime(msg.createdAt)}
                      </span>
                      {isMine && (
                        <span style={{
                          fontSize: '0.68rem',
                          color: msg.isRead
                            ? '#00d4aa' : 'rgba(255,255,255,0.4)',
                        }}>
                          {msg.isRead ? '✓✓' : '✓'}
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              </React.Fragment>
            );
          })
        )}

        {/* Typing indicator */}
        {isTyping && (
          <div style={{ display: 'flex', justifyContent: 'flex-start' }}>
            <div style={{
              background: '#0f1320', border: '1px solid #1e2438',
              borderRadius: '16px 16px 16px 4px',
              padding: '10px 16px', display: 'flex', gap: '4px',
              alignItems: 'center',
            }}>
              {[0, 1, 2].map(n => (
                <div key={n} style={{
                  width: '6px', height: '6px', borderRadius: '50%',
                  background: '#5a6285',
                  animation: 'bounce 1.2s infinite',
                  animationDelay: `${n * 0.2}s`,
                }} />
              ))}
            </div>
          </div>
        )}

        <div ref={bottomRef} />
      </div>

      {/* ── Input ── */}
      <div style={{
        padding: '12px 16px',
        paddingBottom: 'max(12px, env(safe-area-inset-bottom))',
        background: 'linear-gradient(180deg, #0a0d18 0%, #0f1220 100%)',
        borderTop: '2px solid #5b4bff',
        display: 'flex', gap: '10px', alignItems: 'flex-end',
        flexShrink: 0,
        boxShadow: '0 -4px 24px rgba(91,75,255,0.2)',
      }}>
        <div style={{
          flex: 1,
          position: 'relative',
          display: 'flex',
          alignItems: 'center',
        }}>
          <textarea
            ref={inputRef}
            value={input}
            disabled={Boolean(blockedMsg)}
            onChange={handleInputChange}
            onKeyDown={e => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                handleSend();
              }
            }}
            placeholder={blockedMsg || `Message ${otherUserName}...`}
            style={{
              flex: 1, background: '#0f1320',
              border: '2px solid #5b4bff',
              borderRadius: '14px', color: '#ffffff',
              padding: '11px 14px', fontSize: '0.92rem',
              fontFamily: 'inherit', resize: 'none',
              minHeight: '44px', maxHeight: '120px',
              outline: 'none', lineHeight: 1.5,
              boxShadow: '0 0 16px rgba(91,75,255,0.2), inset 0 0 8px rgba(91,75,255,0.1)',
            }}
            onFocus={e => {
              e.target.style.borderColor = '#7c5cff';
              e.target.style.boxShadow = '0 0 24px rgba(91,75,255,0.4), inset 0 0 12px rgba(91,75,255,0.2)';
            }}
            onBlur={e => {
              e.target.style.borderColor = '#5b4bff';
              e.target.style.boxShadow = '0 0 16px rgba(91,75,255,0.2), inset 0 0 8px rgba(91,75,255,0.1)';
            }}
            rows={1}
          />
        </div>
        <button
          onClick={handleSend}
          disabled={!input.trim() || sending || Boolean(blockedMsg)}
          style={{
            width: '44px', height: '44px', borderRadius: '14px',
            background: input.trim()
              ? 'linear-gradient(135deg,#5b4bff,#4338ca)'
              : '#1e2438',
            border: 'none', cursor: input.trim()
              ? 'pointer' : 'default',
            display: 'flex', alignItems: 'center',
            justifyContent: 'center', fontSize: '1.1rem',
            flexShrink: 0,
            transition: 'all 0.15s',
            boxShadow: input.trim()
              ? '0 4px 12px rgba(91,75,255,0.3)'
              : 'none',
            color: input.trim() ? 'white' : '#5a6285',
          }}
        >
          {sending ? '⏳' : '➤'}
        </button>
      </div>

      {/* Bounce animation */}
      <style>{`
        @keyframes bounce {
          0%, 60%, 100% { transform: translateY(0); }
          30% { transform: translateY(-6px); }
        }
      `}</style>
    </div>
  );
}
