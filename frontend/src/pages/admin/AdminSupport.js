import React, { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../../App';
import { getAdminSupport, updateAdminSupportStatus } from '../../api/admin_api';

const statuses = ['ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED'];

export default function AdminSupport() {
  const { user } = useAuth();
  const [filter, setFilter] = useState('ALL');
  const [typeFilter, setTypeFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadRequests = useCallback(async (selected = filter) => {
    if (!user?.id) return;
    setLoading(true);
    try {
      const response = await getAdminSupport(selected === 'ALL' ? '' : selected);
      setRequests(response.data || []);
      setError('');
    } catch (err) {
      setRequests([]);
      setError(err.response?.data?.error || 'Failed to load support requests');
    }
    setLoading(false);
  }, [filter, user?.id]);

  useEffect(() => {
    void loadRequests(filter);
  }, [filter, loadRequests]);

  const handleStatusUpdate = async (requestId, status) => {
    try {
      await updateAdminSupportStatus(requestId, { status });
      await loadRequests(filter);
    } catch (err) {
      setError(err.response?.data?.error || 'Status update failed');
    }
  };

  const visibleRequests = requests.filter((request) => {
    const matchesType = typeFilter === 'ALL' || request.type === typeFilter;
    const needle = search.trim().toLowerCase();
    const haystack = [
      request.subject,
      request.message,
      request.name,
      request.email,
      request.category,
      request.pagePath,
      request.appPlatform,
      request.id,
    ].join(' ').toLowerCase();
    return matchesType && (!needle || haystack.includes(needle));
  });

  return (
    <div>
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontFamily: "'Syne',sans-serif", fontSize: '1.8rem', color: '#e8eaf6' }}>
          Support Inbox
        </h1>
        <p style={{ color: '#5a6285', fontSize: '0.88rem' }}>
          Feedback, contact messages, and problem reports from users
        </p>
      </div>

      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '18px' }}>
        {statuses.map((status) => (
          <button
            key={status}
            onClick={() => setFilter(status)}
            style={{
              padding: '8px 14px',
              borderRadius: '999px',
              border: `1px solid ${filter === status ? 'rgba(91,75,255,0.45)' : '#1e2438'}`,
              background: filter === status ? 'rgba(91,75,255,0.16)' : '#0f1320',
              color: filter === status ? '#c6beff' : '#98a3c6',
              cursor: 'pointer',
              fontWeight: 700,
            }}
          >
            {status.replace('_', ' ')}
          </button>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '12px', marginBottom: '18px' }}>
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search ticket id, user, subject, message or source"
          style={{
            padding: '12px 14px',
            borderRadius: '12px',
            border: '1px solid #1e2438',
            background: '#0f1320',
            color: '#e8eaf6',
          }}
        />
        <select
          value={typeFilter}
          onChange={(e) => setTypeFilter(e.target.value)}
          style={{
            padding: '12px 14px',
            borderRadius: '12px',
            border: '1px solid #1e2438',
            background: '#0f1320',
            color: '#e8eaf6',
          }}
        >
          <option value="ALL">All Types</option>
          <option value="FEEDBACK">Feedback</option>
          <option value="PROBLEM_REPORT">Problem Report</option>
          <option value="CONTACT">Contact</option>
        </select>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '18px' }}>
        {[
          { label: 'Open', value: requests.filter((item) => item.status === 'OPEN').length, color: '#f59e0b' },
          { label: 'In Progress', value: requests.filter((item) => item.status === 'IN_PROGRESS').length, color: '#5b4bff' },
          { label: 'Resolved', value: requests.filter((item) => item.status === 'RESOLVED').length, color: '#00d4aa' },
        ].map((card) => (
          <div key={card.label} style={{
            background: '#0f1320',
            border: '1px solid #1e2438',
            borderTop: `3px solid ${card.color}`,
            borderRadius: '14px',
            padding: '16px',
          }}>
            <div style={{ color: '#8fa0c4', fontSize: '0.78rem', textTransform: 'uppercase', fontWeight: 700 }}>{card.label}</div>
            <div style={{ color: '#fff', fontWeight: 900, fontSize: '1.7rem', marginTop: 6 }}>{card.value}</div>
          </div>
        ))}
      </div>

      {error && <div className="alert alert-error" style={{ marginBottom: '16px' }}>{error}</div>}

      {loading ? (
        <div className="loading-wrap"><div className="spinner" /></div>
      ) : visibleRequests.length === 0 ? (
        <div style={{
          background: '#0f1320',
          border: '1px solid #1e2438',
          borderRadius: '16px',
          padding: '32px',
          textAlign: 'center',
          color: '#8591b5',
        }}>
          No support requests found
        </div>
      ) : (
        <div style={{ display: 'grid', gap: '14px' }}>
          {visibleRequests.map((request) => (
            <div
              key={request.id}
              style={{
                background: '#0f1320',
                border: '1px solid #1e2438',
                borderRadius: '16px',
                padding: '18px',
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: '12px', flexWrap: 'wrap' }}>
                <div>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
                    <span style={{ color: '#8fa0c4', fontSize: '0.74rem', fontWeight: 800 }}>
                      TICKET #{request.id}
                    </span>
                    <span style={{ color: '#fff', fontWeight: 800 }}>{request.subject || request.type}</span>
                    <span style={{
                      fontSize: '0.72rem',
                      color: '#bdb4ff',
                      padding: '4px 8px',
                      borderRadius: '999px',
                      background: 'rgba(91,75,255,0.16)',
                      border: '1px solid rgba(91,75,255,0.3)',
                    }}>
                      {request.type}
                    </span>
                    <span style={{
                      fontSize: '0.72rem',
                      color: '#f0c572',
                      padding: '4px 8px',
                      borderRadius: '999px',
                      background: 'rgba(245,158,11,0.14)',
                      border: '1px solid rgba(245,158,11,0.25)',
                    }}>
                      {request.status}
                    </span>
                  </div>
                  <div style={{ color: '#98a3c6', fontSize: '0.84rem', marginTop: '8px' }}>
                    {request.name} · {request.email}
                    {request.student?.id ? ` · User #${request.student.id}` : ''}
                    {request.category ? ` · ${request.category}` : ''}
                  </div>
                  {request.pagePath && (
                    <div style={{ color: '#6f7ba1', fontSize: '0.78rem', marginTop: '4px' }}>
                      Source: {request.appPlatform || 'web'} {request.pagePath}
                    </div>
                  )}
                </div>

                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  <a
                    href={`mailto:${request.email}?subject=${encodeURIComponent(request.subject || 'Campus Mart support')}`}
                    style={replyActionStyle}
                  >
                    Email
                  </a>
                  <a
                    href={`https://wa.me/?text=${encodeURIComponent(`Campus Mart support request: ${request.subject || request.type}`)}`}
                    target="_blank"
                    rel="noreferrer"
                    style={replyActionStyle}
                  >
                    WhatsApp
                  </a>
                  {['OPEN', 'IN_PROGRESS', 'RESOLVED'].map((status) => (
                    <button
                      key={status}
                      onClick={() => handleStatusUpdate(request.id, status)}
                      style={{
                        padding: '8px 10px',
                        borderRadius: '10px',
                        border: '1px solid rgba(255,255,255,0.1)',
                        background: request.status === status ? 'rgba(91,75,255,0.16)' : 'transparent',
                        color: request.status === status ? '#fff' : '#a7b1d1',
                        cursor: 'pointer',
                        fontSize: '0.78rem',
                        fontWeight: 700,
                      }}
                    >
                      {status.replace('_', ' ')}
                    </button>
                  ))}
                </div>
              </div>

              <div
                style={{
                  marginTop: '14px',
                  color: '#d5dcf0',
                  lineHeight: 1.7,
                  whiteSpace: 'pre-wrap',
                  borderTop: '1px solid rgba(255,255,255,0.06)',
                  paddingTop: '14px',
                }}
              >
                {request.message}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

const replyActionStyle = {
  padding: '8px 10px',
  borderRadius: '10px',
  border: '1px solid rgba(255,255,255,0.1)',
  background: 'transparent',
  color: '#a7b1d1',
  cursor: 'pointer',
  fontSize: '0.78rem',
  fontWeight: 700,
  textDecoration: 'none',
};
