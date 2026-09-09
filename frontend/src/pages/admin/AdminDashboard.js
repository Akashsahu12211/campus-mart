import React, { useEffect, useState } from 'react';
import { useAuth } from '../../App';
import {
  getAdminStats, getUserGrowthChart,
  getListingsChart, getCategoryDist
} from '../../api/admin_api';

const StatCard = ({ icon, label, value, sub, color = '#5b4bff' }) => (
  <div style={{
    background: '#0f1320', border: '1px solid #1e2438',
    borderRadius: '14px', padding: '18px',
    borderTop: `3px solid ${color}`,
  }}>
    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
      <div>
        <p style={{ color: '#5a6285', fontSize: '0.78rem', fontWeight: 700,
          textTransform: 'uppercase', letterSpacing: '0.06em' }}>
          {label}
        </p>
        <p style={{ fontSize: '2rem', fontWeight: 900,
          fontFamily: "'Syne',sans-serif", color: '#e8eaf6',
          marginTop: '4px' }}>
          {value?.toLocaleString?.() ?? value}
        </p>
        {sub && (
          <p style={{ fontSize: '0.75rem', color: '#5a6285',
            marginTop: '3px' }}>
            {sub}
          </p>
        )}
      </div>
      <div style={{
        width: '44px', height: '44px', borderRadius: '12px',
        background: color + '18',
        display: 'flex', alignItems: 'center',
        justifyContent: 'center', fontSize: '1.4rem',
      }}>
        {icon}
      </div>
    </div>
  </div>
);

const MiniChart = ({ data, valueKey, color = '#5b4bff', label }) => {
  if (!data?.length) return null;
  const max = Math.max(...data.map(d => d[valueKey]), 1);
  return (
    <div>
      <p style={{ color: '#5a6285', fontSize: '0.78rem', fontWeight: 700,
        textTransform: 'uppercase', marginBottom: '12px',
        letterSpacing: '0.06em' }}>
        {label} — Last 7 Days
      </p>
      <div style={{ display: 'flex', gap: '6px', alignItems: 'flex-end',
        height: '80px' }}>
        {data.map((d, i) => (
          <div key={i} style={{ flex: 1, display: 'flex',
            flexDirection: 'column', alignItems: 'center', gap: '4px' }}>
            <div style={{
              width: '100%', height: `${(d[valueKey]/max)*70 + 10}px`,
              background: `linear-gradient(180deg, ${color}, ${color}66)`,
              borderRadius: '4px 4px 0 0',
              minHeight: '8px',
              transition: 'height 0.3s',
            }} />
            <span style={{ fontSize: '0.62rem', color: '#5a6285',
              fontWeight: 600 }}>
              {d.day}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default function AdminDashboard() {
  const { user } = useAuth();
  const [stats,      setStats]      = useState(null);
  const [usersChart, setUsersChart] = useState([]);
  const [itemsChart, setItemsChart] = useState([]);
  const [catChart,   setCatChart]   = useState([]);
  const [loading,    setLoading]    = useState(true);
  const [error,      setError]      = useState('');

  useEffect(() => {
    if (!user?.id) return;
    Promise.all([
      getAdminStats(),
      getUserGrowthChart(),
      getListingsChart(),
      getCategoryDist(),
    ]).then(([s, u, it, c]) => {
      setStats(s.data);
      setUsersChart(u.data);
      setItemsChart(it.data);
      setCatChart(c.data);
      setError('');
    }).catch((e) => {
      console.error(e);
      setStats(null);
      setUsersChart([]);
      setItemsChart([]);
      setCatChart([]);
      setError(e.response?.data?.error || 'Failed to load admin dashboard');
    })
      .finally(() => setLoading(false));
  }, [user?.id]);

  if (loading) return (
    <div className="loading-wrap"><div className="spinner" /></div>
  );

  const u = stats?.users || {};
  const i = stats?.items || {};
  const r = stats?.reports || {};
  const p = stats?.platform || {};
  const s = stats?.support || {};
  const a = stats?.analytics || {};
  const m = stats?.monetization || {};

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
            You have full access to platform management tools
          </div>
        </div>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '8px 12px',
          background: 'rgba(239,68,68,0.15)',
          borderRadius: '8px',
          border: '1px solid rgba(239,68,68,0.2)',
        }}>
          <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#ef4444' }} />
          <span style={{ fontSize: '0.75rem', color: '#fca5a5', fontWeight: 600 }}>LIVE</span>
        </div>
      </div>

      {error && (
        <div className="alert alert-error" style={{ marginBottom: '16px' }}>
          {error}
        </div>
      )}

      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontFamily: "'Syne',sans-serif",
          fontSize: '1.8rem', color: '#e8eaf6' }}>
          Dashboard 📊
        </h1>
        <p style={{ color: '#5a6285', fontSize: '0.88rem' }}>
          Campus Mart platform overview
        </p>
      </div>

      {/* Stats Grid */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
        gap: '16px', marginBottom: '24px',
      }}>
        <StatCard icon="👥" label="Total Users"
          value={u.total} sub={`+${u.today || 0} today`}
          color="#5b4bff" />
        <StatCard icon="🚫" label="Banned Users"
          value={u.banned} sub={`${u.admins} admins, ${u.mods} mods`}
          color="#ef4444" />
        <StatCard icon="📦" label="Total Listings"
          value={i.total} sub={`+${i.today || 0} today`}
          color="#00d4aa" />
        <StatCard icon="✅" label="Items Sold"
          value={i.sold} sub={`${i.available} available`}
          color="#22c55e" />
        <StatCard icon="🚨" label="Pending Reports"
          value={r.pending} sub={`${r.total} total`}
          color="#f59e0b" />
        <StatCard icon="💬" label="Total Messages"
          value={p.totalMessages} sub={`${p.totalOffers} offers`}
          color="#8b5cf6" />
        <StatCard icon="S" label="Open Support"
          value={s.open} sub={`${s.total || 0} total`}
          color="#06b6d4" />
        <StatCard icon="₹" label="GMV"
          value={a.gmv} sub={`${a.orders || 0} orders`}
          color="#14b8a6" />
        <StatCard icon="💳" label="Paid Subscribers"
          value={m.paidSubscribers || 0} sub={`${m.plusSubscribers || 0} plus · ${m.premiumSubscribers || 0} premium`}
          color="#8b5cf6" />
        <StatCard icon="🔥" label="Active Boosts"
          value={m.activeBoostedListings || 0} sub={`Pending fees ₹${m.pendingPlatformFees || 0}`}
          color="#ef4444" />
        <StatCard icon="📈" label="Conversion"
          value={`${a.conversionRate || 0}%`} sub={`${a.completedOrders || 0} released`}
          color="#22c55e" />
      </div>

      {/* Charts Row */}
      <div style={{
        display: 'grid', gridTemplateColumns: '1fr 1fr',
        gap: '16px', marginBottom: '24px',
      }}>
        <div style={{
          background: '#0f1320', border: '1px solid #1e2438',
          borderRadius: '14px', padding: '20px',
        }}>
          <MiniChart data={usersChart} valueKey="users"
            color="#5b4bff" label="New Registrations" />
        </div>
        <div style={{
          background: '#0f1320', border: '1px solid #1e2438',
          borderRadius: '14px', padding: '20px',
        }}>
          <MiniChart data={itemsChart} valueKey="items"
            color="#00d4aa" label="New Listings" />
        </div>
      </div>

      {/* Category Distribution */}
      {catChart.length > 0 && (
        <div style={{
          background: '#0f1320', border: '1px solid #1e2438',
          borderRadius: '14px', padding: '20px', marginBottom: '24px',
        }}>
          <p style={{ color: '#5a6285', fontSize: '0.78rem', fontWeight: 700,
            textTransform: 'uppercase', letterSpacing: '0.06em',
            marginBottom: '16px' }}>
            Category Distribution
          </p>
          {catChart.slice(0, 6).map((cat, i) => {
            const maxVal = catChart[0]?.count || 1;
            const pct = Math.round((cat.count / maxVal) * 100);
            const colors = ['#5b4bff','#00d4aa','#f59e0b',
                           '#ef4444','#8b5cf6','#22c55e'];
            return (
              <div key={i} style={{ marginBottom: '12px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between',
                  marginBottom: '4px' }}>
                  <span style={{ color: '#a0a8c8', fontSize: '0.85rem',
                    fontWeight: 600 }}>
                    {cat.category}
                  </span>
                  <span style={{ color: '#5a6285', fontSize: '0.82rem' }}>
                    {cat.count}
                  </span>
                </div>
                <div style={{ height: '6px', background: '#1e2438',
                  borderRadius: '4px', overflow: 'hidden' }}>
                  <div style={{
                    height: '100%', width: `${pct}%`,
                    background: colors[i % colors.length],
                    borderRadius: '4px',
                    transition: 'width 0.5s ease',
                  }} />
                </div>
              </div>
            );
          })}
        </div>
      )}

      <div style={{
        background: '#0f1320', border: '1px solid #1e2438',
        borderRadius: '14px', padding: '20px', marginBottom: '24px',
      }}>
        <p style={{ color: '#5a6285', fontSize: '0.78rem', fontWeight: 700,
          textTransform: 'uppercase', letterSpacing: '0.06em',
          marginBottom: '16px' }}>
          Advanced Analytics
        </p>
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit,minmax(180px,1fr))',
          gap: '12px',
        }}>
          <MetricTile label="Support Resolution" value={`${a.supportResolutionRate || 0}%`} />
          <MetricTile label="Google Users" value={a.googleUsers || 0} />
          <MetricTile label="Facebook Users" value={a.facebookUsers || 0} />
          <MetricTile label="Local Users" value={a.localUsers || 0} />
          <MetricTile label="Disputed Orders" value={a.disputedOrders || 0} />
          <MetricTile label="Released Fees" value={`₹${m.releasedPlatformFees || 0}`} />
        </div>
      </div>

      {/* Quick Actions */}
      <div style={{
        background: '#0f1320', border: '1px solid #1e2438',
        borderRadius: '14px', padding: '20px',
      }}>
        <p style={{ color: '#5a6285', fontSize: '0.78rem', fontWeight: 700,
          textTransform: 'uppercase', letterSpacing: '0.06em',
          marginBottom: '16px' }}>
          Quick Actions
        </p>
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
          {[
            { label: '👥 Manage Users', path: '/admin/users' },
            { label: '📦 Moderate Items', path: '/admin/items' },
            { label: '🚨 Review Reports', path: '/admin/reports' },
            { label: '📋 Audit Logs', path: '/admin/logs' },
          ].map(a => (
            <a key={a.path} href={a.path}
              className="btn btn-secondary btn-sm">
              {a.label}
            </a>
          ))}
        </div>
      </div>
    </div>
  );
}

const MetricTile = ({ label, value }) => (
  <div style={{
    padding: '14px',
    borderRadius: '12px',
    border: '1px solid #1e2438',
    background: '#12172A',
  }}>
    <div style={{ color: '#5a6285', fontSize: '0.74rem', fontWeight: 700, textTransform: 'uppercase' }}>{label}</div>
    <div style={{ color: '#E8EAF6', fontWeight: 900, fontSize: '1.4rem', marginTop: 6 }}>{value}</div>
  </div>
);
