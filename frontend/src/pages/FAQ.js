import React from 'react';
import SitePageLayout from './SitePageLayout';

const faqs = [
  ['How do I sell an item?', 'Login karo, "List Item" par jao, photos and details add karo, then publish.'],
  ['Is Campus Mart only for students?', 'Primary focus student community hai, aur verification layers safer campus commerce ke liye hain.'],
  ['How do reports work?', 'Users listings ko report kar sakte hain, aur admin/moderator review karke action lete hain.'],
  ['Can I contact the seller directly?', 'Haan, item detail se chat aur available contact actions use kar sakte ho.'],
  ['What if payment or delivery goes wrong?', 'Order/dispute flow aur support team escalation dono available hain.'],
];

export default function FAQ() {
  return (
    <SitePageLayout
      eyebrow="FAQ"
      title="Common questions, clearly answered"
      description="Ye FAQ abhi Phase 1 foundation ka hissa hai aur aage product expand hone ke saath aur mature hoga."
    >
      <div style={{ display: 'grid', gap: '14px' }}>
        {faqs.map(([question, answer]) => (
          <div key={question} style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '18px', padding: '18px 20px' }}>
            <div style={{ fontWeight: 800, marginBottom: '8px' }}>{question}</div>
            <div style={{ color: '#b6bfd8', lineHeight: 1.7 }}>{answer}</div>
          </div>
        ))}
      </div>
    </SitePageLayout>
  );
}
