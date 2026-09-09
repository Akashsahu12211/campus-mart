import React, { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../../App';
import BrandMark from '../../components/BrandMark';
import '../../styles/AdminLayout.css';

const NAV_ITEMS = [
  { path: '/admin', icon: 'D', label: 'Dashboard' },
  { path: '/admin/users', icon: 'U', label: 'Users' },
  { path: '/admin/items', icon: 'I', label: 'Items' },
  { path: '/admin/reports', icon: 'R', label: 'Reports' },
  { path: '/admin/support', icon: 'S', label: 'Support' },
  { path: '/admin/site-settings', icon: 'P', label: 'Platform' },
  { path: '/admin/logs', icon: 'L', label: 'Audit Logs' },
];

export default function AdminLayout({ children }) {
  const { user } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(true);

  if (!user || (user.role !== 'ADMIN' && user.role !== 'MODERATOR')) {
    return (
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100vh',
        background: '#080b14',
      }}>
        <div style={{
          textAlign: 'center',
          background: '#0f1320',
          border: '1px solid rgba(239,68,68,0.3)',
          borderRadius: '16px',
          padding: '40px',
        }}>
          <div style={{ fontSize: '3rem' }}>X</div>
          <h2 style={{ color: '#ef4444', fontFamily: "'Syne',sans-serif" }}>
            Access Denied
          </h2>
          <p style={{ color: '#5a6285' }}>
            Admin privileges required
          </p>
          <button
            onClick={() => navigate('/')}
            className="btn btn-primary"
            style={{ marginTop: '16px' }}
          >
            Go Home
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="admin-shell">
      <div className="admin-shell__top-accent" />

      <aside className={`admin-shell__sidebar ${sidebarOpen ? '' : 'is-collapsed'}`}>
        <div className="admin-shell__sidebar-header">
          <div className="admin-shell__mark">
            <BrandMark style={{ width: '18px', height: '18px', display: 'block' }} />
          </div>
          {sidebarOpen && (
            <div className="admin-shell__brand">
              <div className="admin-shell__brand-title">
                Campus<span style={{ color: '#7265ff' }}>Mart</span>
              </div>
              <div className="admin-shell__brand-subtitle">
                ADMIN PANEL
              </div>
            </div>
          )}
          <button
            onClick={() => setSidebarOpen(!sidebarOpen)}
            className="admin-shell__collapse"
          >
            {sidebarOpen ? '<' : '>'}
          </button>
        </div>

        <nav className="admin-shell__nav">
          {NAV_ITEMS.map((item) => {
            const active = location.pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`admin-shell__nav-link ${active ? 'is-active' : ''}`}
              >
                <span className="admin-shell__icon">
                  {item.icon}
                </span>
                {sidebarOpen && (
                  <span className="admin-shell__label">
                    {item.label}
                  </span>
                )}
              </Link>
            );
          })}
        </nav>

        <div className="admin-shell__footer">
          <div className="admin-shell__user">
            <div className="admin-shell__avatar">
              {user.name?.charAt(0).toUpperCase()}
            </div>
            {sidebarOpen && (
              <div className="admin-shell__user-meta">
                <div className="admin-shell__user-name">
                  {user.name}
                </div>
                <div className="admin-shell__user-role">
                  {user.role}
                </div>
              </div>
            )}
          </div>
          {sidebarOpen && (
            <div className="admin-shell__footer-actions">
              <Link to="/" className="btn btn-ghost btn-sm" style={{ flex: 1, fontSize: '0.75rem', padding: '7px 10px' }}>
                Site
              </Link>
            </div>
          )}
        </div>
      </aside>

      <main className={`admin-shell__main ${sidebarOpen ? '' : 'is-collapsed'}`}>
        {children}
      </main>
    </div>
  );
}
