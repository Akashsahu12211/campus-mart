import React, { useEffect, useState } from 'react';
import { getActivityHistory } from '../api/api';
import { useAuth } from '../App';

const typeColors = {
  NOTIFICATION: '#5B4BFF',
  LISTING: '#00D4AA',
  BUYER_ORDER: '#F59E0B',
  SELLER_ORDER: '#10B981',
  SUPPORT: '#06B6D4',
  PURCHASE: '#8B5CF6',
  SALE: '#EC4899',
};

export default function ActivityHistory() {
  const { user } = useAuth();
  const [activities, setActivities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!user?.id) {
      return;
    }

    getActivityHistory(user.id)
      .then((res) => {
        setActivities(res.data?.activities || []);
        setError('');
      })
      .catch((err) => setError(err.response?.data?.error || 'Could not load activity history'))
      .finally(() => setLoading(false));
  }, [user?.id]);

  return (
    <div style={{ minHeight: '100vh', background: '#080B14', color: '#fff', padding: '96px 20px 40px' }}>
      <div style={{ maxWidth: 980, margin: '0 auto' }}>
        <h1 style={{ margin: 0, fontFamily: "'Syne',sans-serif", fontSize: '2rem' }}>Activity History</h1>
        <p style={{ color: '#8FA0C4', marginTop: 8 }}>
          Recent notifications, listings, order events, support actions, and account activity in one place.
        </p>

        {error && <div className="alert alert-error" style={{ marginTop: 16 }}>{error}</div>}

        {loading ? (
          <div className="loading-wrap" style={{ minHeight: 280 }}><div className="spinner" /></div>
        ) : activities.length === 0 ? (
          <div className="empty-state" style={{ marginTop: 20 }}>
            <span className="emoji">🕒</span>
            <h3>No activity yet</h3>
            <p>Once you browse, list, order, or contact support, your timeline will appear here.</p>
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 14, marginTop: 24 }}>
            {activities.map((activity) => (
              <div key={`${activity.type}-${activity.id}-${activity.createdAt}`} style={{
                display: 'grid',
                gridTemplateColumns: '14px 1fr',
                gap: 14,
                background: '#0F1320',
                border: '1px solid #1E2438',
                borderRadius: 18,
                padding: 18,
              }}>
                <div style={{
                  width: 14,
                  height: 14,
                  borderRadius: '50%',
                  background: typeColors[activity.type] || '#64748B',
                  marginTop: 5,
                }} />
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap' }}>
                    <div>
                      <div style={{ fontWeight: 800, fontSize: 15 }}>{activity.title}</div>
                      <div style={{ color: '#A0AEC0', marginTop: 4 }}>{activity.description}</div>
                    </div>
                    <div style={{ color: '#718096', fontSize: 12 }}>
                      {activity.createdAt ? new Date(activity.createdAt).toLocaleString('en-IN') : 'Recently'}
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: 8, marginTop: 12, flexWrap: 'wrap' }}>
                    <span style={chipStyle(typeColors[activity.type] || '#64748B')}>{activity.type.replace('_', ' ')}</span>
                    {activity.status && <span style={chipStyle('#334155')}>{activity.status}</span>}
                    {activity.meta?.amount != null && <span style={chipStyle('#0F766E')}>INR {Number(activity.meta.amount).toLocaleString('en-IN')}</span>}
                    {activity.meta?.itemTitle && <span style={chipStyle('#4C1D95')}>{activity.meta.itemTitle}</span>}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function chipStyle(color) {
  return {
    display: 'inline-flex',
    padding: '6px 10px',
    borderRadius: 999,
    fontSize: 12,
    fontWeight: 700,
    background: `${color}22`,
    border: `1px solid ${color}55`,
    color,
  };
}
