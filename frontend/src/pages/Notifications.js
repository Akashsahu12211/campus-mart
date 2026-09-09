import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  getNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from '../api/api';
import { useAuth } from '../App';

function formatDate(value) {
  try {
    return new Date(value).toLocaleString('en-IN', {
      day: 'numeric',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return 'Just now';
  }
}

export default function Notifications() {
  const { user } = useAuth();
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!user?.id) return;
    getNotifications(user.id)
      .then((res) => {
        setNotifications(res.data?.notifications || []);
        setUnreadCount(res.data?.unreadCount || 0);
        setError('');
      })
      .catch((err) => setError(err.response?.data?.error || 'Failed to load notifications'))
      .finally(() => setLoading(false));
  }, [user?.id]);

  const handleRead = async (notificationId) => {
    if (!user?.id) return;
    try {
      await markNotificationRead(user.id, notificationId);
      setNotifications((prev) => prev.map((item) => (
        item.id === notificationId ? { ...item, read: true, isRead: true } : item
      )));
      setUnreadCount((prev) => Math.max(0, prev - 1));
      window.dispatchEvent(new CustomEvent('campusmart:notifications-updated'));
    } catch (err) {
      setError(err.response?.data?.error || 'Could not update notification');
    }
  };

  const handleReadAll = async () => {
    if (!user?.id) return;
    try {
      await markAllNotificationsRead(user.id);
      setNotifications((prev) => prev.map((item) => ({ ...item, read: true, isRead: true })));
      setUnreadCount(0);
      window.dispatchEvent(new CustomEvent('campusmart:notifications-updated'));
    } catch (err) {
      setError(err.response?.data?.error || 'Could not mark all read');
    }
  };

  return (
    <div style={{ minHeight: '100vh', background: '#080B14', color: '#fff', padding: '96px 20px 40px' }}>
      <div style={{ maxWidth: 960, margin: '0 auto' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16, alignItems: 'center', flexWrap: 'wrap', marginBottom: 24 }}>
          <div>
            <h1 style={{ margin: 0, fontFamily: "'Syne',sans-serif", fontSize: '2rem' }}>Notification Center</h1>
            <p style={{ margin: '8px 0 0', color: '#8FA0C4' }}>
              All product, offer, message, and activity updates in one place.
            </p>
          </div>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <span style={{
              padding: '8px 14px',
              borderRadius: 999,
              border: '1px solid rgba(91,75,255,0.35)',
              background: 'rgba(91,75,255,0.15)',
              color: '#C7C0FF',
              fontWeight: 700,
            }}>
              {unreadCount} unread
            </span>
            <button onClick={handleReadAll} style={buttonStyle}>
              Mark all read
            </button>
          </div>
        </div>

        {error && <div className="alert alert-error" style={{ marginBottom: 16 }}>{error}</div>}

        {loading ? (
          <div className="loading-wrap"><div className="spinner" /></div>
        ) : notifications.length === 0 ? (
          <div style={emptyStyle}>
            <div style={{ fontSize: '2.2rem', marginBottom: 8 }}>🔔</div>
            <div style={{ fontWeight: 800, fontSize: '1.1rem' }}>No notifications yet</div>
            <div style={{ color: '#8FA0C4', marginTop: 6 }}>New offers, chats and listing updates yahan dikhengi.</div>
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 14 }}>
            {notifications.map((notification) => {
              const isRead = notification.read ?? notification.isRead;
              return (
                <div key={notification.id} style={{
                  background: isRead ? '#0F1320' : 'linear-gradient(135deg, rgba(91,75,255,0.18), rgba(15,19,32,0.95))',
                  border: `1px solid ${isRead ? '#1E2438' : 'rgba(91,75,255,0.32)'}`,
                  borderRadius: 18,
                  padding: 18,
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16, alignItems: 'start', flexWrap: 'wrap' }}>
                    <div style={{ flex: 1, minWidth: 220 }}>
                      <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
                        <span style={{ fontWeight: 800, fontSize: '1rem' }}>{notification.title}</span>
                        {!isRead && (
                          <span style={{
                            padding: '4px 10px',
                            borderRadius: 999,
                            background: 'rgba(0,212,170,0.12)',
                            border: '1px solid rgba(0,212,170,0.24)',
                            color: '#00D4AA',
                            fontWeight: 700,
                            fontSize: 12,
                          }}>
                            New
                          </span>
                        )}
                      </div>
                      <div style={{ color: '#D1DBF1', marginTop: 10, lineHeight: 1.6 }}>{notification.body}</div>
                      <div style={{ color: '#7E8DB2', marginTop: 10, fontSize: 13 }}>
                        {formatDate(notification.createdAt)}
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                      {notification.clickAction && (
                        <Link to={notification.clickAction} style={{ ...buttonStyle, textDecoration: 'none', display: 'inline-flex', alignItems: 'center' }}>
                          Open
                        </Link>
                      )}
                      {!isRead && (
                        <button onClick={() => handleRead(notification.id)} style={buttonStyle}>
                          Mark read
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

const buttonStyle = {
  padding: '10px 14px',
  borderRadius: 12,
  border: '1px solid rgba(255,255,255,0.1)',
  background: '#12172A',
  color: '#fff',
  fontWeight: 700,
  cursor: 'pointer',
};

const emptyStyle = {
  background: '#0F1320',
  border: '1px solid #1E2438',
  borderRadius: 18,
  padding: '48px 24px',
  textAlign: 'center',
};
