import React from 'react';
import SitePageLayout from './SitePageLayout';
import { useSiteSettings } from '../context/SiteSettingsContext';

export default function TermsAndConditions() {
  const { settings } = useSiteSettings();
  return (
    <SitePageLayout
      eyebrow="Terms & Conditions"
      title="Use Campus Mart responsibly"
      description="These terms set the baseline rules for listing quality, acceptable behavior, moderation, and platform usage."
    >
      <div style={{ display: 'grid', gap: '14px' }}>
        <div style={{ background: 'var(--surface2)', border: '1px solid var(--border)', borderRadius: '18px', padding: '18px 20px', color: 'var(--text2)', lineHeight: 1.8, whiteSpace: 'pre-wrap' }}>
          {settings.termsContent}
        </div>
        {[
          ['Accurate Listings', 'Users must not post fake, misleading, stolen, or already unavailable items as active listings.'],
          ['Campus Conduct', 'Harassment, spam, abuse, impersonation, and fraudulent payment behavior are not allowed.'],
          ['Moderation Rights', 'Campus Mart may hide, review, or remove listings and suspend accounts to protect the community.'],
          ['User Responsibility', 'Buyers and sellers remain responsible for verifying item condition, price, and exchange terms before completing a deal.'],
          ['Service Evolution', 'Features, policies, and moderation workflows may evolve as the platform matures.'],
        ].map(([title, text]) => (
          <div key={title} style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '18px', padding: '18px 20px' }}>
            <div style={{ fontWeight: 800, marginBottom: '8px' }}>{title}</div>
            <div style={{ color: '#b6bfd8', lineHeight: 1.7 }}>{text}</div>
          </div>
        ))}
      </div>
    </SitePageLayout>
  );
}
