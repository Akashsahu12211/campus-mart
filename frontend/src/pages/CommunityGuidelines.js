import React from 'react';
import SitePageLayout from './SitePageLayout';

export default function CommunityGuidelines() {
  const items = [
    ['Be truthful', 'Fake listings, wrong prices, deceptive images, and hidden conditions are not allowed.'],
    ['Respect users', 'Harassment, spam, intimidation, and abusive language are not acceptable.'],
    ['Trade safely', 'Use clear communication, verify item status, and avoid suspicious or rushed payment behavior.'],
    ['Report problems', 'If a listing or user feels unsafe, use report tools or support forms instead of ignoring it.'],
    ['Follow campus norms', 'Use the platform in a way that supports a healthy student community.'],
  ];

  return (
    <SitePageLayout
      eyebrow="Community Guidelines"
      title="The rules that keep Campus Mart usable and trustworthy"
      description="A professional marketplace only works when community behavior stays predictable, respectful, and honest."
    >
      <div style={{ display: 'grid', gap: '14px' }}>
        {items.map(([title, text]) => (
          <div key={title} style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '18px', padding: '18px 20px' }}>
            <div style={{ fontWeight: 800, marginBottom: '8px' }}>{title}</div>
            <div style={{ color: '#b6bfd8', lineHeight: 1.7 }}>{text}</div>
          </div>
        ))}
      </div>
    </SitePageLayout>
  );
}
