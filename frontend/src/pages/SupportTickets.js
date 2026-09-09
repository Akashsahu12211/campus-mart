import React, { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { getSupportTickets } from '../api/api';
import { useAuth } from '../App';

const statusColors = {
  OPEN: '#F59E0B',
  IN_PROGRESS: '#5B4BFF',
  RESOLVED: '#00D4AA',
};

export default function SupportTickets() {
  const { user } = useAuth();
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('ALL');
  const [error, setError] = useState('');

  useEffect(() => {
    if (!user?.id) return;
    setLoading(true);
    getSupportTickets(user.id)
      .then((res) => {
        setTickets(res.data || []);
        setError('');
      })
      .catch((err) => {
        setTickets([]);
        setError(err.response?.data?.error || 'Could not load your support tickets');
      })
      .finally(() => setLoading(false));
  }, [user?.id]);

  const visibleTickets = useMemo(() => (
    filter === 'ALL' ? tickets : tickets.filter((ticket) => ticket.status === filter)
  ), [filter, tickets]);

  const statCards = [
    { label: 'Open', value: tickets.filter((ticket) => ticket.status === 'OPEN').length, color: statusColors.OPEN },
    { label: 'In Progress', value: tickets.filter((ticket) => ticket.status === 'IN_PROGRESS').length, color: statusColors.IN_PROGRESS },
    { label: 'Resolved', value: tickets.filter((ticket) => ticket.status === 'RESOLVED').length, color: statusColors.RESOLVED },
  ];

  return (
    <div style={{ minHeight: '100vh', background: 'var(--page-bg)', color: 'var(--text)', padding: '96px 20px 40px' }}>
      <div style={{ maxWidth: 1080, margin: '0 auto' }}>
        <div style={{ marginBottom: 24 }}>
          <div style={eyebrowStyle}>Support Tickets</div>
          <h1 style={{ margin: '10px 0 0', fontFamily: "'Syne',sans-serif", fontSize: 'clamp(2rem,4vw,2.8rem)' }}>
            Track every feedback, problem report, and contact request
          </h1>
          <p style={{ margin: '10px 0 0', color: 'var(--text2)', maxWidth: 760, lineHeight: 1.7 }}>
            Har support request ko ticket ki tarah track karo, uska status dekho, aur zarurat ho to direct help flows me wapas jao.
          </p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 14, marginBottom: 18 }}>
          {statCards.map((card) => (
            <div key={card.label} style={{ ...cardShellStyle, borderTop: `3px solid ${card.color}` }}>
              <div style={{ color: 'var(--text2)', textTransform: 'uppercase', fontSize: 12, fontWeight: 800 }}>{card.label}</div>
              <div style={{ marginTop: 8, fontSize: 32, fontWeight: 900 }}>{card.value}</div>
            </div>
          ))}
          <div style={cardShellStyle}>
            <div style={{ color: 'var(--text2)', textTransform: 'uppercase', fontSize: 12, fontWeight: 800 }}>Quick Actions</div>
            <div style={{ marginTop: 10, display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              <Link to="/feedback" className="btn btn-primary btn-sm">Feedback</Link>
              <Link to="/report-problem" className="btn btn-ghost btn-sm">Report Problem</Link>
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
          {['ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED'].map((status) => (
            <button
              key={status}
              type="button"
              onClick={() => setFilter(status)}
              style={{
                padding: '8px 14px',
                borderRadius: 999,
                border: `1px solid ${filter === status ? 'rgba(91,75,255,0.45)' : 'var(--border)'}`,
                background: filter === status ? 'rgba(91,75,255,0.14)' : 'var(--surface)',
                color: filter === status ? 'var(--text)' : 'var(--text2)',
                cursor: 'pointer',
                fontWeight: 700,
              }}
            >
              {status.replace('_', ' ')}
            </button>
          ))}
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        {loading ? (
          <div className="loading-wrap"><div className="spinner" /></div>
        ) : visibleTickets.length === 0 ? (
          <div style={emptyShellStyle}>
            <div style={{ fontSize: 46 }}>🎫</div>
            <h3 style={{ margin: '16px 0 8px', fontSize: 28 }}>No tickets yet</h3>
            <p style={{ color: 'var(--text2)', maxWidth: 520, margin: '0 auto 18px' }}>
              Jab aap feedback, problem report, ya contact request bhejte ho, uski status history yahin dikhegi.
            </p>
            <Link to="/help" className="btn btn-primary">Open Help Center</Link>
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 14 }}>
            {visibleTickets.map((ticket) => {
              const badgeColor = statusColors[ticket.status] || '#8FA0C4';
              return (
                <article key={ticket.id} style={ticketStyle}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                    <div>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                        <span style={{ color: 'var(--text2)', fontSize: 12, fontWeight: 800 }}>
                          TICKET #{ticket.id}
                        </span>
                        <span style={pillStyle('#8FA0C4')}>{ticket.type?.replace('_', ' ')}</span>
                        <span style={pillStyle(badgeColor)}>{ticket.status?.replace('_', ' ')}</span>
                      </div>
                      <h3 style={{ margin: '10px 0 6px', fontSize: 22 }}>{ticket.subject}</h3>
                      <div style={{ color: 'var(--text2)', fontSize: 14 }}>
                        {ticket.category || 'General'} · {ticket.appPlatform || 'web'} · {formatDate(ticket.createdAt)}
                      </div>
                    </div>
                    <div style={{ minWidth: 180, textAlign: 'right', color: 'var(--muted)', fontSize: 13 }}>
                      <div>Source</div>
                      <div style={{ marginTop: 4, color: 'var(--text2)' }}>{ticket.pagePath || 'General support'}</div>
                    </div>
                  </div>
                  <div style={{
                    marginTop: 16,
                    paddingTop: 16,
                    borderTop: '1px solid rgba(255,255,255,0.08)',
                    color: 'var(--text)',
                    lineHeight: 1.7,
                    whiteSpace: 'pre-wrap',
                  }}>
                    {ticket.message}
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

function formatDate(value) {
  if (!value) return 'Recently';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Recently';
  return date.toLocaleString();
}

function pillStyle(color) {
  return {
    display: 'inline-flex',
    alignItems: 'center',
    padding: '4px 10px',
    borderRadius: 999,
    fontSize: 12,
    fontWeight: 800,
    color,
    background: `${color}14`,
    border: `1px solid ${color}33`,
  };
}

const eyebrowStyle = {
  display: 'inline-flex',
  padding: '6px 12px',
  borderRadius: 999,
  border: '1px solid rgba(91,75,255,0.24)',
  background: 'rgba(91,75,255,0.12)',
  color: '#BDB4FF',
  fontSize: 12,
  fontWeight: 800,
  letterSpacing: '0.08em',
  textTransform: 'uppercase',
};

const cardShellStyle = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 18,
  padding: 18,
};

const emptyShellStyle = {
  textAlign: 'center',
  padding: '54px 24px',
  borderRadius: 22,
  background: 'var(--surface)',
  border: '1px solid var(--border)',
};

const ticketStyle = {
  background: 'var(--surface)',
  border: '1px solid var(--border)',
  borderRadius: 18,
  padding: 20,
  boxShadow: '0 18px 50px rgba(0,0,0,0.18)',
};
