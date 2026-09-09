import React from 'react';
import { Link } from 'react-router-dom';
import SitePageLayout from './SitePageLayout';

const helpCardStyle = {
  background: 'rgba(255,255,255,0.03)',
  border: '1px solid rgba(255,255,255,0.08)',
  borderRadius: '20px',
  padding: '20px',
};

export default function HelpCenter() {
  return (
    <SitePageLayout
      eyebrow="Help Center"
      title="Quick answers for buying, selling, safety, and support"
      description="Campus Mart ko smooth use karne ke liye common help topics yahan clustered hain. Agar answer na mile, direct support form use kar sakte ho."
    >
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(230px,1fr))', gap: '16px' }}>
        {[
          ['Account & Login', 'Login, registration, OTP verification, account access, and profile basics.'],
          ['Listings & Selling', 'Item add karna, edit karna, sold mark karna, images and listing quality.'],
          ['Orders & Payments', 'Reservations, payments, disputes, delivery confirmation, and order visibility.'],
          ['Trust & Safety', 'Reports, moderation, suspicious listings, and safer campus deals.'],
        ].map(([title, text]) => (
          <div key={title} style={helpCardStyle}>
            <h3 style={{ marginTop: 0 }}>{title}</h3>
            <p style={{ marginBottom: '12px', lineHeight: 1.7, color: '#b6bfd8' }}>{text}</p>
          </div>
        ))}
      </div>
      <div style={{ marginTop: '22px', display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
        <Link to="/faq" style={{ color: '#fff', textDecoration: 'none', padding: '12px 18px', borderRadius: '14px', background: '#4f46e5', fontWeight: 700 }}>View FAQ</Link>
        <Link to="/report-problem" style={{ color: '#fff', textDecoration: 'none', padding: '12px 18px', borderRadius: '14px', border: '1px solid rgba(255,255,255,0.12)' }}>Report a Problem</Link>
        <Link to="/contact" style={{ color: '#fff', textDecoration: 'none', padding: '12px 18px', borderRadius: '14px', border: '1px solid rgba(255,255,255,0.12)' }}>Contact Support</Link>
      </div>
    </SitePageLayout>
  );
}
