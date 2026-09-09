import React from 'react';
import SitePageLayout from './SitePageLayout';
import { useSiteSettings } from '../context/SiteSettingsContext';

export default function CookiePolicy() {
  const { settings } = useSiteSettings();
  const rows = [
    ['Session security', 'Authentication tokens and safe sign-in continuity'],
    ['Product preferences', 'Language, theme, filters, and support choices'],
    ['Marketplace continuity', 'Notification state, activity, and local UX stability'],
  ];

  return (
    <SitePageLayout
      eyebrow="Cookie Policy"
      title="Session and product preferences use lightweight storage"
      description="Campus Mart uses browser storage and similar mechanisms for login sessions, language choice, notification state, and safer product operation."
    >
      <div style={{ display: 'grid', gap: 18 }}>
        <div style={{
          background: 'var(--surface2)',
          border: '1px solid var(--border)',
          borderRadius: 18,
          padding: 18,
          color: 'var(--text2)',
          lineHeight: 1.8,
          whiteSpace: 'pre-wrap',
        }}>
          {settings.cookiePolicyContent}
        </div>
        <div style={{ ...tableShellStyle, overflow: 'hidden' }}>
          {rows.map(([title, text], index) => (
            <div key={title} style={{
              display: 'grid',
              gridTemplateColumns: '220px 1fr',
              gap: 16,
              padding: '16px 18px',
              borderTop: index === 0 ? 'none' : '1px solid var(--border)',
            }}>
              <div style={{ fontWeight: 800 }}>{title}</div>
              <div style={{ color: 'var(--text2)', lineHeight: 1.7 }}>{text}</div>
            </div>
          ))}
        </div>
        <div style={tableShellStyle}>
          <h3 style={{ margin: '0 0 10px' }}>Your control</h3>
          <p style={{ color: 'var(--text2)', lineHeight: 1.8, margin: 0 }}>
            You can log out, clear browser or app storage, revoke notification permission, or update supported settings at any time. We keep storage lightweight and operational rather than ad-heavy.
          </p>
        </div>
      </div>
    </SitePageLayout>
  );
}

const tableShellStyle = {
  background: 'var(--surface2)',
  border: '1px solid var(--border)',
  borderRadius: 18,
};
