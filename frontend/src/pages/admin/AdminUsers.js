import React, { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../../App';
import {
  getAdminUsers, changeUserRole, banUser,
  unbanUser, deleteUserAdmin
} from '../../api/admin_api';

const ROLE_COLORS = {
  ADMIN:     { bg: 'rgba(91,75,255,0.12)',  color: '#a89dff' },
  MODERATOR: { bg: 'rgba(245,158,11,0.12)', color: '#f59e0b' },
  STUDENT:   { bg: 'rgba(100,116,139,0.1)', color: '#64748b' },
};

export default function AdminUsers() {
  const { user } = useAuth();
  const [users,   setUsers]   = useState([]);
  const [search,  setSearch]  = useState('');
  const [loading, setLoading] = useState(true);
  const [msg,     setMsg]     = useState({ type: '', text: '' });
  const [banModal, setBanModal] = useState(null);
  const [banReason, setBanReason] = useState('');

  const load = useCallback(async (q = '') => {
    if (!user?.id) return;
    setLoading(true);
    try {
      const r = await getAdminUsers(q);
      setUsers(r.data);
      setMsg({ type: '', text: '' });
    } catch (e) {
      setUsers([]);
      setMsg({
        type: 'error',
        text: e.response?.data?.error || 'Failed to load users',
      });
    } finally { setLoading(false); }
  }, [user]);

  useEffect(() => { if (user?.id) load(); }, [user?.id, load]);

  const showMsg = (type, text) => {
    setMsg({ type, text });
    setTimeout(() => setMsg({ type: '', text: '' }), 3000);
  };

  const handleRoleChange = async (targetId, newRole) => {
    try {
      await changeUserRole(targetId, { role: newRole });
      showMsg('success', 'Role updated successfully');
      load(search);
    } catch (e) {
      showMsg('error', e.response?.data?.error || 'Failed');
    }
  };

  const handleBan = async () => {
    if (!banModal || !banReason.trim()) return;
    try {
      await banUser(banModal.id, { reason: banReason });
      showMsg('success', `${banModal.name} has been banned`);
      setBanModal(null); setBanReason('');
      load(search);
    } catch (e) {
      showMsg('error', e.response?.data?.error || 'Failed');
    }
  };

  const handleUnban = async (targetId, name) => {
    try {
      await unbanUser(targetId);
      showMsg('success', `${name} has been unbanned`);
      load(search);
    } catch (e) {
      showMsg('error', e.response?.data?.error || 'Failed');
    }
  };

  const handleDelete = async (targetId, name) => {
    if (!window.confirm(
      `DELETE ${name} permanently? This cannot be undone.`)) return;
    try {
      await deleteUserAdmin(targetId);
      showMsg('success', `${name} deleted`);
      load(search);
    } catch (e) {
      showMsg('error', e.response?.data?.error || 'Failed');
    }
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
            Managing {users.length} registered users
          </div>
        </div>
      </div>

      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontFamily: "'Syne',sans-serif",
          fontSize: '1.8rem', color: '#e8eaf6' }}>
          User Management 👥
        </h1>
        <p style={{ color: '#5a6285', fontSize: '0.88rem' }}>
          {users.length} registered users
        </p>
      </div>

      {msg.text && (
        <div className={`alert alert-${msg.type === 'success' ? 'success' : 'error'}`}
          style={{ marginBottom: '16px' }}>
          {msg.text}
        </div>
      )}

      {/* Search */}
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
        <input value={search} onChange={e => setSearch(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && load(search)}
          placeholder="🔍 Search by name or email..."
          className="form-input" style={{ maxWidth: '380px' }} />
        <button onClick={() => load(search)}
          className="btn btn-primary btn-sm">
          Search
        </button>
        <button onClick={() => { setSearch(''); load(''); }}
          className="btn btn-ghost btn-sm">
          Clear
        </button>
      </div>

      {/* Table */}
      {loading ? (
        <div className="loading-wrap"><div className="spinner" /></div>
      ) : (
        <div style={{
          background: '#0f1320', border: '1px solid #1e2438',
          borderRadius: '14px', overflow: 'hidden',
        }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid #1e2438' }}>
                {['User', 'Email', 'Branch', 'Role', 'Status', 'Actions']
                  .map(h => (
                  <th key={h} style={{
                    padding: '12px 16px', textAlign: 'left',
                    fontSize: '0.72rem', color: '#5a6285',
                    fontWeight: 700, textTransform: 'uppercase',
                    letterSpacing: '0.05em',
                  }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {users.map((u, i) => {
                const roleStyle = ROLE_COLORS[u.role] || ROLE_COLORS.STUDENT;
                return (
                  <tr key={u.id} style={{
                    borderBottom: i < users.length - 1
                      ? '1px solid #141929' : 'none',
                    background: u.banned ? 'rgba(239,68,68,0.03)' : 'transparent',
                  }}>
                    {/* User */}
                    <td style={{ padding: '12px 16px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div style={{
                          width: '36px', height: '36px', borderRadius: '50%',
                          background: 'linear-gradient(135deg,#5b4bff,#00d4aa)',
                          display: 'flex', alignItems: 'center',
                          justifyContent: 'center', fontSize: '0.9rem',
                          fontWeight: 800, color: '#fff', flexShrink: 0,
                          overflow: 'hidden',
                        }}>
                          {u.profilePic
                            ? <img src={u.profilePic} alt=""
                                style={{ width: '100%', height: '100%',
                                  objectFit: 'cover' }} />
                            : u.name?.charAt(0).toUpperCase()
                          }
                        </div>
                        <div>
                          <p style={{ color: '#e8eaf6', fontWeight: 700,
                            fontSize: '0.88rem' }}>
                            {u.name}
                          </p>
                          {u.collegeId && (
                            <p style={{ color: '#5a6285', fontSize: '0.72rem' }}>
                              #{u.collegeId}
                            </p>
                          )}
                        </div>
                      </div>
                    </td>
                    {/* Email */}
                    <td style={{ padding: '12px 16px' }}>
                      <span style={{ color: '#a0a8c8', fontSize: '0.83rem' }}>
                        {u.email}
                      </span>
                    </td>
                    {/* Branch */}
                    <td style={{ padding: '12px 16px' }}>
                      <span style={{ color: '#5a6285', fontSize: '0.82rem' }}>
                        {u.branch || '—'}
                      </span>
                    </td>
                    {/* Role */}
                    <td style={{ padding: '12px 16px' }}>
                      {user.role === 'ADMIN' ? (
                        <select value={u.role || 'STUDENT'}
                          onChange={e => handleRoleChange(u.id, e.target.value)}
                          disabled={u.id === user.id}
                          style={{
                            background: roleStyle.bg,
                            color: roleStyle.color,
                            border: `1px solid ${roleStyle.color}40`,
                            borderRadius: '6px', padding: '3px 8px',
                            fontSize: '0.75rem', fontWeight: 700,
                            cursor: u.id === user.id ? 'default' : 'pointer',
                          }}>
                          <option value="STUDENT">STUDENT</option>
                          <option value="MODERATOR">MODERATOR</option>
                          <option value="ADMIN">ADMIN</option>
                        </select>
                      ) : (
                        <span style={{
                          background: roleStyle.bg, color: roleStyle.color,
                          padding: '3px 10px', borderRadius: '6px',
                          fontSize: '0.75rem', fontWeight: 700,
                        }}>
                          {u.role || 'STUDENT'}
                        </span>
                      )}
                    </td>
                    {/* Status */}
                    <td style={{ padding: '12px 16px' }}>
                      <span style={{
                        background: u.banned
                          ? 'rgba(239,68,68,0.12)' : 'rgba(34,197,94,0.1)',
                        color: u.banned ? '#ef4444' : '#22c55e',
                        padding: '3px 10px', borderRadius: '6px',
                        fontSize: '0.72rem', fontWeight: 700,
                      }}>
                        {u.banned ? '🚫 Banned' : '✓ Active'}
                      </span>
                    </td>
                    {/* Actions */}
                    <td style={{ padding: '12px 16px' }}>
                      <div style={{ display: 'flex', gap: '6px' }}>
                        {u.id !== user.id && (
                          <>
                            {u.banned ? (
                              <button onClick={() => handleUnban(u.id, u.name)}
                                className="btn btn-success btn-sm">
                                Unban
                              </button>
                            ) : (
                              <button onClick={() => setBanModal(u)}
                                className="btn btn-danger btn-sm">
                                Ban
                              </button>
                            )}
                            {user.role === 'ADMIN' && (
                              <button
                                onClick={() => handleDelete(u.id, u.name)}
                                className="btn btn-ghost btn-sm"
                                style={{ color: '#ef4444', borderColor: '#ef444440' }}>
                                🗑
                              </button>
                            )}
                          </>
                        )}
                        {u.id === user.id && (
                          <span style={{ color: '#3d4566', fontSize: '0.75rem' }}>
                            (You)
                          </span>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>

          {users.length === 0 && (
            <div className="empty-state" style={{ padding: '40px' }}>
              <span className="emoji">👥</span>
              <h3>No users found</h3>
            </div>
          )}
        </div>
      )}

      {/* Ban Modal */}
      {banModal && (
        <div style={{
          position: 'fixed', inset: 0, zIndex: 1000,
          background: 'rgba(0,0,0,0.7)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          backdropFilter: 'blur(4px)',
        }}>
          <div style={{
            background: '#0f1320', border: '1px solid #1e2438',
            borderRadius: '16px', padding: '28px', width: '400px',
          }}>
            <h3 style={{ fontFamily: "'Syne',sans-serif",
              marginBottom: '8px', color: '#ef4444' }}>
              Ban User 🚫
            </h3>
            <p style={{ color: '#5a6285', marginBottom: '16px',
              fontSize: '0.88rem' }}>
              You are banning: <strong style={{ color: '#e8eaf6' }}>
                {banModal.name}
              </strong>
            </p>
            <div className="form-group">
              <label className="form-label">Ban Reason *</label>
              <textarea value={banReason}
                onChange={e => setBanReason(e.target.value)}
                placeholder="Describe why this user is being banned..."
                className="form-textarea" style={{ minHeight: '80px' }} />
            </div>
            <div style={{ display: 'flex', gap: '10px' }}>
              <button onClick={handleBan}
                className="btn btn-danger" style={{ flex: 1 }}
                disabled={!banReason.trim()}>
                🚫 Confirm Ban
              </button>
              <button onClick={() => { setBanModal(null); setBanReason(''); }}
                className="btn btn-ghost" style={{ flex: 1 }}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
