import React, { useContext, useState } from 'react';
import { AuthContext } from '../App';
import { submitContactMessage } from '../api/api';
import SitePageLayout from './SitePageLayout';
import {
  SUPPORT_BUSINESS_EMAIL,
  SUPPORT_EMAIL,
  SUPPORT_RESPONSE_WINDOW,
  SUPPORT_WHATSAPP_NUMBER,
} from '../config/support';
import { useSiteSettings } from '../context/SiteSettingsContext';

const inputStyle = {
  width: '100%',
  boxSizing: 'border-box',
  padding: '14px 16px',
  borderRadius: '14px',
  border: '1px solid rgba(255,255,255,0.1)',
  background: '#111728',
  color: '#fff',
  outline: 'none',
};

export default function Contact() {
  const { user } = useContext(AuthContext);
  const { settings } = useSiteSettings();
  const [form, setForm] = useState({
    name: user?.name || '',
    email: user?.email || '',
    subject: '',
    message: '',
  });
  const [status, setStatus] = useState({ type: '', text: '' });
  const [saving, setSaving] = useState(false);

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSaving(true);
    setStatus({ type: '', text: '' });
    try {
      await submitContactMessage({
        ...form,
        studentId: user?.id,
        appPlatform: 'web',
        pagePath: '/contact',
      });
      setStatus({ type: 'success', text: 'Support team ko message bhej diya gaya hai.' });
      setForm((current) => ({ ...current, subject: '', message: '' }));
    } catch (error) {
      setStatus({ type: 'error', text: error.response?.data?.error || 'Message bhejne me issue aaya.' });
    }
    setSaving(false);
  };

  return (
    <SitePageLayout
      eyebrow="Contact & Support"
      title="Talk to the team behind Campus Mart"
      description="Product issue, business query, campus rollout, or support escalation - yahan se direct message bhej sakte ho."
    >
      <div style={{ display: 'grid', gridTemplateColumns: '1.1fr 0.9fr', gap: '20px' }}>
        <form onSubmit={handleSubmit} style={{ display: 'grid', gap: '14px' }}>
          <input style={inputStyle} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Your name" />
          <input style={inputStyle} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="Your email" />
          <input style={inputStyle} value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} placeholder="Subject" />
          <textarea style={{ ...inputStyle, minHeight: '160px', resize: 'vertical' }} value={form.message} onChange={(e) => setForm({ ...form, message: e.target.value })} placeholder="How can we help?" />
          {status.text && (
            <div style={{
              padding: '12px 14px',
              borderRadius: '12px',
              background: status.type === 'success' ? 'rgba(0,212,170,0.12)' : 'rgba(239,68,68,0.12)',
              border: `1px solid ${status.type === 'success' ? 'rgba(0,212,170,0.3)' : 'rgba(239,68,68,0.3)'}`,
              color: status.type === 'success' ? '#7ef2d0' : '#ff8f8f',
            }}>
              {status.text}
            </div>
          )}
          <button type="submit" disabled={saving} style={{
            border: 'none',
            borderRadius: '14px',
            padding: '14px 18px',
            background: 'linear-gradient(135deg,#635bff,#4f46e5)',
            color: '#fff',
            fontWeight: 800,
            cursor: 'pointer',
          }}>
            {saving ? 'Sending...' : 'Send Message'}
          </button>
        </form>

        <div style={{ display: 'grid', gap: '14px' }}>
          {[
            ['Email Support', settings.supportEmail || SUPPORT_EMAIL],
            ['WhatsApp', settings.supportWhatsappNumber ? `+${settings.supportWhatsappNumber}` : (SUPPORT_WHATSAPP_NUMBER ? `+${SUPPORT_WHATSAPP_NUMBER}` : 'Configured on deploy')],
            ['Business', settings.businessEmail || SUPPORT_BUSINESS_EMAIL],
            ['Response Window', settings.supportHours || SUPPORT_RESPONSE_WINDOW],
            ['Office Address', settings.officeAddress || 'Add your startup office or campus support address here.'],
          ].map(([label, value]) => (
            <div key={label} style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '18px', padding: '18px' }}>
              <div style={{ color: '#97a4cb', fontSize: '0.85rem', marginBottom: '6px' }}>{label}</div>
              <div style={{ fontWeight: 700 }}>{value}</div>
            </div>
          ))}
        </div>
      </div>
    </SitePageLayout>
  );
}
