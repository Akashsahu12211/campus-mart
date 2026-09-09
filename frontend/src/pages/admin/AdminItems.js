import React, { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../../App';
import {
  getAdminItems, hideItemAdmin,
  restoreItemAdmin, deleteItemAdmin
} from '../../api/admin_api';

export default function AdminItems() {
  const { user } = useAuth();
  const [items,    setItems]    = useState([]);
  const [filter,   setFilter]   = useState('');
  const [loading,  setLoading]  = useState(true);
  const [msg,      setMsg]      = useState({ type: '', text: '' });

  const load = useCallback(async (status = '') => {
    if (!user?.id) return;
    setLoading(true);
    try {
      const r = await getAdminItems(status);
      setItems(r.data);
      setMsg({ type: '', text: '' });
    } catch (e) {
      setItems([]);
      setMsg({
        type: 'error',
        text: e.response?.data?.error || 'Failed to load items',
      });
    } finally { setLoading(false); }
  }, [user]);

  useEffect(() => { if (user?.id) load(); }, [user?.id, load]);

  const showMsg = (type, text) => {
    setMsg({ type, text });
    setTimeout(() => setMsg({ type: '', text: '' }), 3000);
  };

  const handleHide = async (itemId, title) => {
    const reason = window.prompt(
      `Reason for hiding "${title}"?`, 'Policy violation');
    if (!reason) return;
    try {
      await hideItemAdmin(itemId, { reason });
      showMsg('success', 'Item hidden');
      load(filter);
    } catch (e) {
      showMsg('error', e.response?.data?.error || 'Failed');
    }
  };

  const handleRestore = async (itemId) => {
    try {
      await restoreItemAdmin(itemId);
      showMsg('success', 'Item restored');
      load(filter);
    } catch (e) {
      showMsg('error', e.response?.data?.error || 'Failed');
    }
  };

  const handleDelete = async (itemId, title) => {
    if (!window.confirm(`DELETE "${title}"? Cannot be undone.`)) return;
    try {
      await deleteItemAdmin(itemId);
      showMsg('success', 'Item deleted');
      load(filter);
    } catch (e) {
      showMsg('error', e.response?.data?.error || 'Failed');
    }
  };

  const STATUS_COLORS = {
    AVAILABLE: { bg: 'rgba(34,197,94,0.1)',  color: '#22c55e' },
    SOLD:      { bg: 'rgba(239,68,68,0.1)',  color: '#ef4444' },
    RESERVED:  { bg: 'rgba(245,158,11,0.1)', color: '#f59e0b' },
    HIDDEN:    { bg: 'rgba(100,116,139,0.1)', color: '#64748b' },
    EXPIRED:   { bg: 'rgba(59,130,246,0.1)', color: '#3b82f6' },
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
            Moderating {items.length} items in the platform
          </div>
        </div>
      </div>

      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontFamily: "'Syne',sans-serif",
          fontSize: '1.8rem', color: '#e8eaf6' }}>
          Item Moderation 📦
        </h1>
        <p style={{ color: '#5a6285', fontSize: '0.88rem' }}>
          {items.length} items total
        </p>
      </div>

      {msg.text && (
        <div className={`alert alert-${msg.type === 'success' ? 'success' : 'error'}`}
          style={{ marginBottom: '16px' }}>
          {msg.text}
        </div>
      )}

      {/* Status Filter */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '20px',
        flexWrap: 'wrap' }}>
        {['', 'AVAILABLE', 'SOLD', 'HIDDEN', 'RESERVED', 'EXPIRED']
          .map(s => (
          <button key={s}
            onClick={() => { setFilter(s); load(s); }}
            className={`pill ${filter === s ? 'active' : ''}`}>
            {s || 'All Items'}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="loading-wrap"><div className="spinner" /></div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {items.map(item => {
            const st = STATUS_COLORS[item.status] || STATUS_COLORS.AVAILABLE;
            return (
              <div key={item.id} style={{
                background: '#0f1320', border: '1px solid #1e2438',
                borderRadius: '12px', padding: '14px 16px',
                display: 'flex', gap: '14px', alignItems: 'center',
                flexWrap: 'wrap',
              }}>
                {/* Thumbnail */}
                <div style={{
                  width: '56px', height: '56px', borderRadius: '8px',
                  background: '#141929', flexShrink: 0, overflow: 'hidden',
                  display: 'flex', alignItems: 'center',
                  justifyContent: 'center', fontSize: '1.6rem',
                }}>
                  {item.imageUrls?.[0]
                    ? <img src={item.imageUrls[0]} alt=""
                        style={{ width: '100%', height: '100%',
                          objectFit: 'cover' }} />
                    : '📦'
                  }
                </div>

                {/* Info */}
                <div style={{ flex: 1, minWidth: '200px' }}>
                  <p style={{ fontWeight: 700, color: '#e8eaf6',
                    fontSize: '0.92rem', marginBottom: '2px' }}>
                    {item.title}
                  </p>
                  <p style={{ color: '#5a6285', fontSize: '0.78rem' }}>
                    by {item.seller?.name}
                    {item.seller?.collegeId &&
                      ` (#${item.seller.collegeId})`}
                    {' · '} {item.category?.name}
                    {' · '} 👁 {item.viewCount || 0}
                  </p>
                </div>

                {/* Price */}
                <div style={{ color: '#5b4bff', fontWeight: 800,
                  fontSize: '1rem' }}>
                  ₹{item.price?.toLocaleString('en-IN')}
                </div>

                {/* Status */}
                <span style={{
                  background: st.bg, color: st.color,
                  padding: '3px 10px', borderRadius: '6px',
                  fontSize: '0.72rem', fontWeight: 700,
                }}>
                  {item.status}
                </span>

                {/* Actions */}
                <div style={{ display: 'flex', gap: '6px' }}>
                  {item.status === 'HIDDEN' ? (
                    <button onClick={() => handleRestore(item.id)}
                      className="btn btn-success btn-sm">
                      ✅ Restore
                    </button>
                  ) : (
                    <button onClick={() => handleHide(item.id, item.title)}
                      className="btn btn-secondary btn-sm">
                      🙈 Hide
                    </button>
                  )}
                  <button onClick={() => handleDelete(item.id, item.title)}
                    className="btn btn-danger btn-sm">
                    🗑
                  </button>
                </div>
              </div>
            );
          })}

          {items.length === 0 && (
            <div className="empty-state">
              <span className="emoji">📦</span>
              <h3>No items found</h3>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
