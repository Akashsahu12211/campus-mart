import React from 'react';

const shellStyle = {
  minHeight: '100vh',
  background: 'radial-gradient(circle at top, rgba(91,75,255,0.10) 0%, var(--page-bg) 48%, var(--bg) 100%)',
  color: 'var(--text)',
  paddingTop: '104px',
  paddingBottom: '32px',
};

const cardStyle = {
  maxWidth: '980px',
  margin: '0 auto',
  padding: '0 24px',
};

export default function SitePageLayout({ eyebrow, title, description, children }) {
  return (
    <div style={shellStyle}>
      <div style={cardStyle}>
        <div
          style={{
            border: '1px solid rgba(95,86,255,0.24)',
            background: 'var(--surface)',
            borderRadius: '28px',
            padding: '32px',
            boxShadow: 'var(--shadow)',
          }}
        >
          {eyebrow && (
            <div
              style={{
                display: 'inline-flex',
                padding: '6px 12px',
                borderRadius: '999px',
                border: '1px solid rgba(95,86,255,0.24)',
                background: 'rgba(95,86,255,0.12)',
                color: '#bdb4ff',
                fontSize: '0.78rem',
                fontWeight: 700,
                letterSpacing: '0.04em',
                marginBottom: '18px',
              }}
            >
              {eyebrow}
            </div>
          )}
          <h1 style={{ margin: 0, fontSize: 'clamp(2rem,4vw,3.4rem)', fontWeight: 900 }}>
            {title}
          </h1>
          {description && (
            <p style={{ marginTop: '14px', color: 'var(--text2)', fontSize: '1rem', lineHeight: 1.8, maxWidth: '760px' }}>
              {description}
            </p>
          )}
          <div style={{ marginTop: '28px' }}>{children}</div>
        </div>
      </div>
    </div>
  );
}
