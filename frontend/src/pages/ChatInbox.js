import React, { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { getInbox, getUnreadCount } from '../api/api';
import { useAuth } from '../App';

export default function ChatInbox() {
  const { user }   = useAuth();
  const navigate   = useNavigate();
  const [inbox,    setInbox]    = useState([]);
  const [loading,  setLoading]  = useState(true);
  const [unreadTotal, setUnread] = useState(0);

  const loadInbox = useCallback(async () => {
    if (!user?.id) return;
    setLoading(true);
    try {
      const [inboxRes, unreadRes] = await Promise.all([
        getInbox(user.id),
        getUnreadCount(user.id),
      ]);
      setInbox(inboxRes.data);
      setUnread(unreadRes.data.count);
    } catch {}
    finally { setLoading(false); }
  }, [user]);

  useEffect(() => {
    if (!user) { navigate('/login'); return; }
    loadInbox();
  }, [user, navigate, loadInbox]);

  const formatTime = (ts) => {
    if (!ts) return '';
    const date = new Date(ts.replace(' ', 'T'));
    const now  = new Date();
    const diff = now - date;
    if (diff < 60000)       return 'Just now';
    if (diff < 3600000)     return `${Math.floor(diff/60000)}m`;
    if (diff < 86400000)    return `${Math.floor(diff/3600000)}h`;
    return date.toLocaleDateString('en-IN', { day:'numeric', month:'short' });
  };

  if (!user) return null;

  return (
    <div className="page" style={{ maxWidth: '680px' }}>

      {/* Header */}
      <div style={{
        display: 'flex', justifyContent: 'space-between',
        alignItems: 'center', marginBottom: '24px',
      }}>
        <h1 style={{ fontFamily: "'Syne',sans-serif", fontSize: '1.8rem' }}>
          Messages 💬
          {unreadTotal > 0 && (
            <span style={{
              marginLeft: '10px',
              background: '#ef4444', color: '#fff',
              borderRadius: '12px', padding: '2px 10px',
              fontSize: '0.85rem', fontWeight: 700,
              verticalAlign: 'middle',
            }}>
              {unreadTotal}
            </span>
          )}
        </h1>
        <button onClick={loadInbox} className="btn btn-ghost btn-sm">
          🔄 Refresh
        </button>
      </div>

      {loading ? (
        <div className="loading-wrap"><div className="spinner" /></div>
      ) : inbox.length === 0 ? (
        <div className="empty-state">
          <span className="emoji">💬</span>
          <h3>No messages yet</h3>
          <p>Start a conversation by clicking "Chat" on any item</p>
          <Link to="/" className="btn btn-primary btn-sm"
            style={{ marginTop: '16px' }}>
            Browse Items
          </Link>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {inbox.map((conv, i) => (
            <div key={i}
              onClick={() => navigate('/chat', {
                state: {
                  otherUserId: conv.otherUser.id,
                  otherUserName: conv.otherUser.name,
                  otherUserPic: conv.otherUser.profilePic,
                  itemId: conv.item?.id,
                  itemTitle: conv.item?.title,
                }
              })}
              style={{
                background: '#0f1320',
                border: `1px solid ${conv.unreadCount > 0
                  ? 'rgba(91,75,255,0.4)' : '#1e2438'}`,
                borderRadius: '14px', padding: '14px 16px',
                cursor: 'pointer', display: 'flex',
                gap: '12px', alignItems: 'center',
                transition: 'all 0.15s',
              }}
              onMouseEnter={e =>
                e.currentTarget.style.background = '#141929'}
              onMouseLeave={e =>
                e.currentTarget.style.background = '#0f1320'}
            >
              {/* Avatar */}
              <div style={{
                width: '48px', height: '48px', borderRadius: '50%',
                flexShrink: 0, overflow: 'hidden',
                background: conv.otherUser.profilePic
                  ? 'transparent'
                  : 'linear-gradient(135deg,#5b4bff,#00d4aa)',
                display: 'flex', alignItems: 'center',
                justifyContent: 'center',
                fontSize: '1.2rem', fontWeight: 800, color: '#fff',
              }}>
                {conv.otherUser.profilePic ? (
                  <img src={conv.otherUser.profilePic} alt=""
                    style={{ width: '100%', height: '100%',
                      objectFit: 'cover' }} />
                ) : (
                  conv.otherUser.name?.charAt(0).toUpperCase()
                )}
              </div>

              {/* Info */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  display: 'flex', justifyContent: 'space-between',
                  marginBottom: '3px',
                }}>
                  <span style={{
                    fontWeight: 700, color: '#e8eaf6',
                    fontSize: '0.95rem',
                  }}>
                    {conv.otherUser.name}
                  </span>
                  <span style={{
                    fontSize: '0.75rem', color: '#5a6285',
                  }}>
                    {formatTime(conv.lastMessage.timestamp)}
                  </span>
                </div>

                {conv.item && (
                  <p style={{
                    fontSize: '0.72rem', color: '#5b4bff',
                    fontWeight: 600, marginBottom: '3px',
                  }}>
                    📦 {conv.item.title}
                  </p>
                )}

                <div style={{
                  display: 'flex', justifyContent: 'space-between',
                  alignItems: 'center',
                }}>
                  <p style={{
                    fontSize: '0.83rem',
                    overflow: 'hidden', textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap', maxWidth: '280px',
                    fontWeight: conv.unreadCount > 0 ? 700 : 400,
                    color: conv.unreadCount > 0 ? '#a0a8c8' : '#5a6285',
                  }}>
                    {conv.lastMessage.isMine ? 'You: ' : ''}
                    {conv.lastMessage.content}
                  </p>
                  {conv.unreadCount > 0 && (
                    <span style={{
                      background: '#5b4bff', color: '#fff',
                      borderRadius: '50%', width: '20px', height: '20px',
                      fontSize: '0.68rem', fontWeight: 800,
                      display: 'flex', alignItems: 'center',
                      justifyContent: 'center', flexShrink: 0,
                    }}>
                      {conv.unreadCount > 9 ? '9+' : conv.unreadCount}
                    </span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
