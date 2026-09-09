import React from 'react';
import SitePageLayout from './SitePageLayout';
import { Link } from 'react-router-dom';
import { useSiteSettings } from '../context/SiteSettingsContext';

export default function Disclaimer() {
  const { settings } = useSiteSettings();
  return (
    <SitePageLayout
      eyebrow="Disclaimer"
      title="Campus Mart facilitates listings, not guaranteed outcomes"
      description="The marketplace helps students discover, communicate, and transact, but users remain responsible for truthful listings, respectful conduct, and lawful transactions."
    >
      <div style={{ display: 'grid', gap: 18 }}>
        <div style={cardStyle}>
          <p style={{ ...bodyStyle, margin: 0, whiteSpace: 'pre-wrap' }}>{settings.disclaimerContent}</p>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(220px,1fr))', gap: 14 }}>
          <div style={cardStyle}>
            <h3 style={{ margin: '0 0 10px' }}>Listing responsibility</h3>
            <p style={bodyStyle}>Sellers remain responsible for ownership, truthful descriptions, condition disclosures, and lawful item posting.</p>
          </div>
          <div style={cardStyle}>
            <h3 style={{ margin: '0 0 10px' }}>Buyer responsibility</h3>
            <p style={bodyStyle}>Buyers should verify price, identity, condition, meetup safety, and payment safety before closing any deal.</p>
          </div>
          <div style={cardStyle}>
            <h3 style={{ margin: '0 0 10px' }}>Platform role</h3>
            <p style={bodyStyle}>Campus Mart can moderate, suspend, and review issues, but cannot guarantee that every conversation, listing, or transaction is risk-free.</p>
          </div>
        </div>
        <div style={alertShellStyle}>
          <div>
            <h3 style={{ margin: '0 0 8px' }}>If something feels unsafe, escalate immediately</h3>
            <p style={{ ...bodyStyle, margin: 0 }}>
              Use report flow, block tools, support tickets, and admin moderation rather than continuing an unsafe transaction.
            </p>
          </div>
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <Link to="/report-problem" className="btn btn-primary btn-sm">Report Problem</Link>
            <Link to="/community-guidelines" className="btn btn-ghost btn-sm">Community Guidelines</Link>
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

const alertShellStyle = {
  display: 'flex',
  justifyContent: 'space-between',
  gap: 18,
  flexWrap: 'wrap',
  alignItems: 'center',
  borderRadius: 20,
  background: 'rgba(239,68,68,0.08)',
  border: '1px solid rgba(239,68,68,0.18)',
  padding: 20,
};

const bodyStyle = {
  color: 'var(--text2)',
  lineHeight: 1.8,
};
