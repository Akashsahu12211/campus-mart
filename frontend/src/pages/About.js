import React from 'react';
import SitePageLayout from './SitePageLayout';
import { useSiteSettings } from '../context/SiteSettingsContext';

const cardStyle = {
  background: 'rgba(255,255,255,0.03)',
  border: '1px solid rgba(255,255,255,0.08)',
  borderRadius: '20px',
  padding: '22px',
};

export default function About() {
  const { settings } = useSiteSettings();
  return (
    <SitePageLayout
      eyebrow={`About ${settings.companyName || 'Campus Mart'}`}
      title="Built for student commerce, not generic classifieds."
      description={settings.aboutSummary || 'Campus Mart helps students buy, sell, reserve, review, chat, and complete safer campus deals with admin moderation and support in place.'}
    >
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(240px,1fr))', gap: '16px' }}>
        <div style={cardStyle}>
          <h3 style={{ marginTop: 0 }}>What We Solve</h3>
          <p style={{ margin: 0, color: '#b6bfd8', lineHeight: 1.7 }}>
            Fast resale for books, electronics, hostel essentials, cycles, and more without noisy public marketplace friction.
          </p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ marginTop: 0 }}>How We Build Trust</h3>
          <p style={{ margin: 0, color: '#b6bfd8', lineHeight: 1.7 }}>
            Verified student accounts, reporting, moderation, reviews, order visibility, and clearer support channels.
          </p>
        </div>
        <div style={cardStyle}>
          <h3 style={{ marginTop: 0 }}>Startup Direction</h3>
          <p style={{ margin: 0, color: '#b6bfd8', lineHeight: 1.7 }}>
            We are shaping Campus Mart into a polished campus commerce product across web and Flutter with safer operations and stronger UX.
          </p>
        </div>
      </div>
    </SitePageLayout>
  );
}
