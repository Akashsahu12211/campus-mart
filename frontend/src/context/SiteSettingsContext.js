import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import api from '../api/api';
import {
  SUPPORT_BUSINESS_EMAIL,
  SUPPORT_EMAIL,
  SUPPORT_RESPONSE_WINDOW,
  SUPPORT_WHATSAPP_LINK,
  SUPPORT_WHATSAPP_NUMBER,
} from '../config/support';
import { SOCIAL_LINKS as ENV_SOCIAL_LINKS } from '../config/socials';

const DEFAULT_SETTINGS = {
  companyName: 'Campus Mart',
  companyTagline: 'Student-first campus marketplace',
  cartLogoUrl: '',
  aboutSummary:
    'Campus Mart helps students buy, sell, discover, and support each other inside safer campus communities.',
  supportEmail: SUPPORT_EMAIL,
  businessEmail: SUPPORT_BUSINESS_EMAIL,
  supportWhatsappNumber: SUPPORT_WHATSAPP_NUMBER,
  supportWhatsappLink: SUPPORT_WHATSAPP_LINK,
  supportHours: SUPPORT_RESPONSE_WINDOW,
  officeAddress: 'Add your startup office or campus support address here.',
  instagramUrl: ENV_SOCIAL_LINKS.find((entry) => entry.key === 'instagram')?.href || '',
  linkedinUrl: ENV_SOCIAL_LINKS.find((entry) => entry.key === 'linkedin')?.href || '',
  youtubeUrl: ENV_SOCIAL_LINKS.find((entry) => entry.key === 'youtube')?.href || '',
  xUrl: ENV_SOCIAL_LINKS.find((entry) => entry.key === 'x')?.href || '',
  githubUrl: ENV_SOCIAL_LINKS.find((entry) => entry.key === 'github')?.href || '',
  privacyPolicyContent:
    'Replace this placeholder with your full privacy policy. Include what data you collect, why, how long you keep it, and how users can contact you.',
  termsContent:
    'Replace this placeholder with your terms and conditions. Explain permitted use, prohibited activity, moderation rights, and account responsibilities.',
  refundPolicyContent:
    'Replace this placeholder with your refund and dispute workflow. Explain when refunds may apply, who reviews them, and what proof is required.',
  cookiePolicyContent:
    'Replace this placeholder with your cookie and local storage policy. Explain session, preference, and security storage usage.',
  disclaimerContent:
    'Replace this placeholder with your legal disclaimer. Explain that users remain responsible for truthful listings and safe transactions.',
};

const SiteSettingsContext = createContext({
  settings: DEFAULT_SETTINGS,
  loading: true,
  refreshSettings: async () => {},
});

function normalizeSettings(raw = {}) {
  const supportWhatsappNumber = String(raw.supportWhatsappNumber || DEFAULT_SETTINGS.supportWhatsappNumber || '')
    .replace(/\D/g, '');

  return {
    ...DEFAULT_SETTINGS,
    ...raw,
    supportWhatsappNumber,
    supportWhatsappLink: supportWhatsappNumber ? `https://wa.me/${supportWhatsappNumber}` : DEFAULT_SETTINGS.supportWhatsappLink,
  };
}

export function SiteSettingsProvider({ children }) {
  const [settings, setSettings] = useState(DEFAULT_SETTINGS);
  const [loading, setLoading] = useState(true);

  const refreshSettings = async () => {
    try {
      const res = await api.get('/public/site-settings');
      setSettings(normalizeSettings(res.data || {}));
    } catch {
      setSettings(normalizeSettings());
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void refreshSettings();
  }, []);

  const value = useMemo(() => ({
    settings,
    loading,
    refreshSettings,
  }), [settings, loading]);

  return <SiteSettingsContext.Provider value={value}>{children}</SiteSettingsContext.Provider>;
}

export const useSiteSettings = () => useContext(SiteSettingsContext);
