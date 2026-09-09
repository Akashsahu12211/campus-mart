import React from 'react';
import SitePageLayout from './SitePageLayout';
import { Link } from 'react-router-dom';
import { useSiteSettings } from '../context/SiteSettingsContext';

export default function RefundPolicy() {
  const { settings } = useSiteSettings();
  const sections = [
    {
      title: 'When refunds may apply',
      body: 'Duplicate payments, failed delivery, fraud indicators, materially different items, or moderation-approved disputes can enter refund review.',
    },
    {
      title: 'When refunds may not apply',
      body: 'Completed in-person handovers, undisputed released payouts, or cases where the delivered item clearly matched the listing may not qualify.',
    },
    {
      title: 'Resolution path',
      body: 'Use report/problem flow, dispute flow, or support tickets so admins can verify payment events, messages, timestamps, and evidence.',
    },
  ];

  return (
    <SitePageLayout
      eyebrow="Refund Policy"
      title="Payment disputes and refunds stay policy-backed"
      description="Campus Mart supports escrow-style safety flows where available. Refunds are reviewed against payment status, dispute evidence, and delivery confirmation."
    >
      <div style={{ display: 'grid', gap: 18 }}>
        <div style={noteStyle}>
          {settings.refundPolicyContent}
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 14 }}>
          {sections.map((section) => (
            <div key={section.title} style={cardStyle}>
              <h3 style={{ margin: '0 0 10px', fontSize: '1.05rem' }}>{section.title}</h3>
              <p style={bodyStyle}>{section.body}</p>
            </div>
          ))}
        </div>

        <div style={highlightStyle}>
          <div>
            <div style={{ fontSize: 12, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#CFC8FF', fontWeight: 800 }}>
              Recommended Flow
            </div>
            <h3 style={{ margin: '8px 0 6px', fontSize: '1.3rem' }}>Raise the issue early with evidence</h3>
            <p style={{ ...bodyStyle, margin: 0 }}>
              Chat history, screenshots, order timeline, and listing details help the admin team resolve disputes faster and more fairly.
            </p>
          </div>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <Link to="/report-problem" className="btn btn-primary btn-sm">Report a Problem</Link>
            <Link to="/support-tickets" className="btn btn-ghost btn-sm">Track Tickets</Link>
          </div>
        </div>
      </div>
    </SitePageLayout>
  );
}

const cardStyle = {
  background: 'var(--surface2)',
  border: '1px solid var(--border)',
  borderRadius: 18,
  padding: 18,
};

const highlightStyle = {
  display: 'flex',
  justifyContent: 'space-between',
  gap: 20,
  flexWrap: 'wrap',
  alignItems: 'center',
  background: 'linear-gradient(135deg, rgba(91,75,255,0.16), rgba(0,212,170,0.12))',
  border: '1px solid rgba(91,75,255,0.24)',
  borderRadius: 22,
  padding: 22,
};

const bodyStyle = {
  color: 'var(--text2)',
  lineHeight: 1.8,
};

const noteStyle = {
  background: 'var(--surface2)',
  border: '1px solid var(--border)',
  borderRadius: 18,
  padding: 18,
  color: 'var(--text2)',
  lineHeight: 1.8,
  whiteSpace: 'pre-wrap',
};
