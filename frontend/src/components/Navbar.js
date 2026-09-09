import React, { useContext, useEffect, useMemo, useRef, useState } from 'react';
import { Link, NavLink, useLocation, useNavigate } from 'react-router-dom';
import { AuthContext } from '../App';
import { getNotifications } from '../api/api';
import BrandMark from './BrandMark';
import { useLanguage } from '../context/LanguageContext';
import { useTheme } from '../context/ThemeContext';
import '../styles/Navbar.css';

export default function Navbar() {
  const { user, logout } = useContext(AuthContext);
  const navigate = useNavigate();
  const location = useLocation();
  const { t } = useLanguage();
  const { resolvedTheme } = useTheme();
  const [scrolled, setScrolled] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [moreOpen, setMoreOpen] = useState(false);
  const moreRef = useRef(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    window.addEventListener('scroll', onScroll);
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  useEffect(() => {
    if (!user?.id) {
      setUnreadCount(0);
      return undefined;
    }

    const loadUnread = () => {
      getNotifications(user.id)
        .then((res) => setUnreadCount(res.data?.unreadCount || 0))
        .catch(() => setUnreadCount(0));
    };

    loadUnread();
    window.addEventListener('campusmart:notifications-updated', loadUnread);
    return () => window.removeEventListener('campusmart:notifications-updated', loadUnread);
  }, [user?.id]);

  useEffect(() => {
    setMobileOpen(false);
    setMoreOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    const onResize = () => {
      if (window.innerWidth > 1024) {
        setMobileOpen(false);
      }
      if (window.innerWidth <= 1024) {
        setMoreOpen(false);
      }
    };
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  useEffect(() => {
    const onPointerDown = (event) => {
      if (moreRef.current && !moreRef.current.contains(event.target)) {
        setMoreOpen(false);
      }
    };
    document.addEventListener('mousedown', onPointerDown);
    return () => document.removeEventListener('mousedown', onPointerDown);
  }, []);

  const handleLogout = () => {
    logout();
    setMobileOpen(false);
    setMoreOpen(false);
    navigate('/');
  };

  const primaryNavItems = useMemo(() => {
    if (!user) {
      return [];
    }

    return [
      { to: '/', label: t('browse', 'Browse') },
      { to: '/add-item', label: '+ List Item', className: 'cm-navbar__cta btn btn-primary btn-sm' },
      { to: '/my-items', label: 'My Listings' },
      { to: '/orders', label: 'Orders' },
    ];
  }, [t, user]);

  const moreNavItems = useMemo(() => {
    if (!user) {
      return [];
    }

    const items = [
      { to: '/notifications', label: 'Notifications', badge: unreadCount > 0 ? (unreadCount > 99 ? '99+' : unreadCount) : '' },
      { to: '/activity', label: t('activity', 'Activity') },
      { to: '/settings', label: t('settings', 'Settings') },
    ];

    if (user.role === 'ADMIN' || user.role === 'MODERATOR') {
      items.push({ to: '/admin', label: 'Admin' });
    }

    return items;
  }, [t, user, unreadCount]);

  const renderNavItem = (item) => {
    const baseClass = item.className?.includes('btn')
      ? `cm-navbar__nav-link ${item.className}`
      : `cm-navbar__nav-link ${item.className || ''}`.trim();

    return (
      <NavLink
        key={item.to}
        to={item.to}
        className={({ isActive }) => `${baseClass}${isActive ? ' is-active' : ''}`}
      >
        <span>{item.label}</span>
        {item.badge ? <span className="cm-navbar__badge">{item.badge}</span> : null}
      </NavLink>
    );
  };

  const moreIsActive = moreNavItems.some((item) => location.pathname === item.to);

  return (
    <nav className={`cm-navbar ${scrolled ? 'is-scrolled' : ''} ${resolvedTheme === 'light' ? 'light' : ''}`}>
      <div className="cm-navbar__inner">
        <Link to="/" className="cm-navbar__brand">
          <span className="cm-navbar__brand-mark">
            <BrandMark className="cm-navbar__brand-logo" style={{ display: 'block' }} />
          </span>
          <span className="cm-navbar__brand-text">
            Campus<span className="cm-navbar__brand-accent">Mart</span>
          </span>
        </Link>

        <button
          type="button"
          className={`cm-navbar__toggle ${mobileOpen ? 'is-open' : ''}`}
          aria-label={mobileOpen ? 'Close navigation menu' : 'Open navigation menu'}
          aria-expanded={mobileOpen}
          onClick={() => setMobileOpen((prev) => !prev)}
        >
          <span className="cm-navbar__toggle-bars" />
        </button>

        <div className={`cm-navbar__menu ${mobileOpen ? 'is-open' : ''}`}>
          <div className="cm-navbar__center">
            <div className="cm-navbar__nav cm-navbar__nav--primary">
              {primaryNavItems.map(renderNavItem)}
            </div>
          </div>
          {user ? (
            <div className="cm-navbar__actions">
              <div className="cm-navbar__desktop-secondary">
                <div className="cm-navbar__more" ref={moreRef}>
                  <button
                    type="button"
                    className={`cm-navbar__more-trigger ${moreIsActive ? 'is-active' : ''}`}
                    aria-expanded={moreOpen}
                    onClick={() => setMoreOpen((current) => !current)}
                  >
                    More
                    <span className={`cm-navbar__chevron ${moreOpen ? 'is-open' : ''}`}>+</span>
                  </button>
                  <div className={`cm-navbar__more-menu ${moreOpen ? 'is-open' : ''}`}>
                    {moreNavItems.map((item) => (
                      <NavLink
                        key={item.to}
                        to={item.to}
                        className={({ isActive }) => `cm-navbar__more-link ${isActive ? 'is-active' : ''}`}
                      >
                        <span>{item.label}</span>
                        {item.badge ? <span className="cm-navbar__badge">{item.badge}</span> : null}
                      </NavLink>
                    ))}
                  </div>
                </div>

                <NavLink to="/help" className={({ isActive }) => `cm-navbar__nav-link ${isActive ? 'is-active' : ''}`}>
                  {t('help', 'Help')}
                </NavLink>
              </div>

              <div className="cm-navbar__mobile-secondary">
                {moreNavItems.map(renderNavItem)}
                <NavLink to="/help" className={({ isActive }) => `cm-navbar__nav-link ${isActive ? 'is-active' : ''}`}>
                  {t('help', 'Help')}
                </NavLink>
              </div>

              <NavLink to="/profile" className={({ isActive }) => `cm-navbar__avatar-link ${isActive ? 'is-active' : ''}`}>
                <div className="cm-navbar__avatar">
                  {user.profilePic ? (
                    <img
                      src={user.profilePic}
                      alt=""
                      style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                      onError={(e) => { e.target.style.display = 'none'; }}
                    />
                  ) : (
                    <span style={{ color: '#fff', fontWeight: 800, fontSize: '0.9rem' }}>
                      {user.name?.charAt(0)?.toUpperCase() || '?'}
                    </span>
                  )}
                </div>
              </NavLink>

              <button onClick={handleLogout} className="btn btn-ghost btn-sm">Logout</button>
            </div>
          ) : (
            <div className="cm-navbar__actions">
              <NavLink to="/" className={({ isActive }) => `cm-navbar__nav-link ${isActive ? 'is-active' : ''}`}>
                {t('browse', 'Browse')}
              </NavLink>
              <NavLink to="/help" className={({ isActive }) => `cm-navbar__nav-link ${isActive ? 'is-active' : ''}`}>
                {t('help', 'Help')}
              </NavLink>
              <NavLink to="/login" className={({ isActive }) => `cm-navbar__nav-link ${isActive ? 'is-active' : ''}`}>Login</NavLink>
              <NavLink to="/register" className={({ isActive }) => `cm-navbar__nav-link cm-navbar__cta btn btn-primary btn-sm${isActive ? ' is-active' : ''}`}>Register</NavLink>
            </div>
          )}
        </div>
      </div>
    </nav>
  );
}
