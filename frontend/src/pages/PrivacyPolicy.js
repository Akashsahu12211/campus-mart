import React from 'react';
import SitePageLayout from './SitePageLayout';
import { useSiteSettings } from '../context/SiteSettingsContext';

function Section({ title, children }) {
  return (
    <section style={{ marginBottom: '22px' }}>
      <h3 style={{ marginBottom: '8px' }}>{title}</h3>
      <div style={{ color: '#b6bfd8', lineHeight: 1.8 }}>{children}</div>
    </section>
  );
}

export default function PrivacyPolicy() {
  const { settings } = useSiteSettings();
  return (
    <SitePageLayout
      eyebrow="Privacy Policy"
      title="Your marketplace data should stay predictable"
      description="This policy explains what Campus Mart stores, why it is used, and how support, moderation, and account data are handled."
    >
      <section style={{ marginBottom: '22px' }}>
        <div style={{ color: 'var(--text2)', lineHeight: 1.8, whiteSpace: 'pre-wrap' }}>
          {settings.privacyPolicyContent}
        </div>
      </section>
      <Section title="Information We Collect">
        Account details, listing content, chat and transaction metadata, support requests, reports, and device notification tokens where enabled.
      </Section>
      <Section title="Why We Use It">
        To run listings, secure access, enable communication, detect abuse, improve product quality, and support campus transactions.
      </Section>
      <Section title="Sharing & Safety">
        We do not treat user data as public beyond product functionality. Admin and moderation access is limited to support, abuse handling, and operational safety.
      </Section>
      <Section title="Your Controls">
        You can update profile data, change password, manage listings, and contact support for account-related issues. More privacy controls will be added in upcoming phases.
      </Section>
    </SitePageLayout>
  );
}
