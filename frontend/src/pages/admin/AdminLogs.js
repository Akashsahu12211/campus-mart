import React, { useEffect, useState } from 'react';
import { useAuth } from '../../App';
import { getAdminLogs } from '../../api/admin_api';

const ACTION_COLORS = {
  BAN_USER:          '#ef4444',
  UNBAN_USER:        '#22c55e',
  DELETE_USER:       '#ef4444',
  CHANGE_ROLE:       '#f59e0b',
  HIDE_ITEM:         '#f59e0b',
  RESTORE_ITEM:      '#22c55e',
  FORCE_DELETE_ITEM: '#ef4444',
  REVIEW_REPORT:     '#5b4bff',
};

export default function AdminLogs() {
  const { user }  = useAuth();
  const [logs,    setLogs]    = useState([]);
  const [loading, setLoading] = useState(true);
  const [error,   setError]   = useState('');

  useEffect(() => {
    if (!user?.id) return;
    getAdminLogs()
      .then(r => {
        setLogs(r.data);
        setError('');
      })
      .catch((e) => {
        console.error(e);
        setLogs([]);
        setError(e.response?.data?.error || 'Failed to load audit logs');
      })
      .finally(() => setLoading(false));
  }, [user?.id]);

  const formatDate = (ts) => {
    if (!ts) return '';
    return new Date(ts).toLocaleString('en-IN', {
      day: 'numeric', month: 'short',
      hour: '2-digit', minute: '2-digit',
    });
  };

  return (
    <div>
      {/* 🔴 ADMIN MODE BANNER */}
      <div style={{
        background: 'linear-gradient(135deg, rgba(239,68,68,0.1) 0%, rgba(245,158,11,0.1) 100%)',
        border: '1px solid rgba(239,68,68,0.3)',
        borderRadius: '14px',
        padding: '16px 20px',
        marginBottom: '24px',
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
      }}>
        <span style={{ fontSize: '1.4rem' }}>🔐</span>
        <div style={{ flex: 1 }}>
          <div style={{
            fontFamily: "'Syne',sans-serif",
            fontSize: '1rem',
            fontWeight: 700,
            color: '#fca5a5',
          }}>
            ADMIN MODE ACTIVE
          </div>
          <div style={{
            fontSize: '0.82rem',
            color: '#a0a8c8',
            marginTop: '2px',
          }}>
            Viewing audit trail of {logs.length} admin actions
          </div>
        </div>
      </div>

      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontFamily: "'Syne',sans-serif",
          fontSize: '1.8rem', color: '#e8eaf6' }}>
          Audit Logs 📋
        </h1>
        <p style={{ color: '#5a6285', fontSize: '0.88rem' }}>
          Last 50 admin actions
        </p>
      </div>

      {error && (
        <div className="alert alert-error" style={{ marginBottom: '16px' }}>
          {error}
        </div>
      )}

      {loading ? (
        <div className="loading-wrap"><div className="spinner" /></div>
      ) : (
        <div style={{
          background: '#0f1320', border: '1px solid #1e2438',
          borderRadius: '14px', overflow: 'hidden',
        }}>
          {logs.map((log, i) => (
            <div key={log.id} style={{
              display: 'flex', gap: '14px', padding: '14px 16px',
              alignItems: 'flex-start',
              borderBottom: i < logs.length - 1
                ? '1px solid #141929' : 'none',
            }}>
              {/* Action badge */}
              <div style={{
                background: (ACTION_COLORS[log.action] || '#5b4bff') + '15',
                color: ACTION_COLORS[log.action] || '#5b4bff',
                padding: '3px 8px', borderRadius: '6px',
                fontSize: '0.68rem', fontWeight: 700,
                whiteSpace: 'nowrap', flexShrink: 0,
                alignSelf: 'flex-start', marginTop: '2px',
              }}>
                {log.action}
              </div>

              <div style={{ flex: 1 }}>
                <p style={{ color: '#a0a8c8', fontSize: '0.85rem',
                  marginBottom: '2px' }}>
                  {log.description}
                </p>
                <div style={{ display: 'flex', gap: '12px' }}>
                  <span style={{ color: '#5a6285', fontSize: '0.75rem' }}>
                    by {log.admin?.name}
                  </span>
                  <span style={{ color: '#3d4566', fontSize: '0.75rem' }}>
                    {formatDate(log.createdAt)}
                  </span>
                  <span style={{ color: '#3d4566', fontSize: '0.75rem' }}>
                    {log.targetType}
                    {log.targetId && ` #${log.targetId}`}
                  </span>
                </div>
              </div>
            </div>
          ))}

          {logs.length === 0 && (
            <div className="empty-state" style={{ padding: '40px' }}>
              <span className="emoji">📋</span>
              <h3>No logs yet</h3>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
