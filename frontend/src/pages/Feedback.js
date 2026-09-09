import React, { useContext, useState } from 'react';
import { AuthContext } from '../App';
import { submitFeedback } from '../api/api';
import SitePageLayout from './SitePageLayout';

const fieldStyle = {
  width: '100%',
  boxSizing: 'border-box',
  padding: '14px 16px',
  borderRadius: '14px',
  border: '1px solid rgba(255,255,255,0.1)',
  background: '#111728',
  color: '#fff',
  outline: 'none',
};

export default function Feedback() {
  const { user } = useContext(AuthContext);
  const [form, setForm] = useState({
    name: user?.name || '',
    email: user?.email || '',
    subject: '',
    category: 'UX',
    message: '',
  });
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState({ type: '', text: '' });

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSaving(true);
    setStatus({ type: '', text: '' });
    try {
      await submitFeedback({
        ...form,
        studentId: user?.id,
        appPlatform: 'web',
        pagePath: '/feedback',
      });
      setStatus({ type: 'success', text: 'Feedback save ho gaya. Team product improvements me consider karegi.' });
      setForm((current) => ({ ...current, subject: '', message: '' }));
    } catch (error) {
      setStatus({ type: 'error', text: error.response?.data?.error || 'Feedback submit nahi ho paaya.' });
    }
    setSaving(false);
  };

  return (
    <SitePageLayout
      eyebrow="Feedback"
      title="Tell us what should become better next"
      description="Aap product quality, speed, trust, UI, admin flow, and feature ideas par direct feedback bhej sakte ho."
    >
      <form onSubmit={handleSubmit} style={{ display: 'grid', gap: '14px', maxWidth: '760px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
          <input style={fieldStyle} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Your name" />
          <input style={fieldStyle} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="Your email" />
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 220px', gap: '14px' }}>
          <input style={fieldStyle} value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} placeholder="Short subject" />
          <select style={fieldStyle} value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
            <option>UX</option>
            <option>Performance</option>
            <option>Feature Request</option>
            <option>Trust & Safety</option>
            <option>Admin Experience</option>
          </select>
        </div>
        <textarea style={{ ...fieldStyle, minHeight: '180px', resize: 'vertical' }} value={form.message} onChange={(e) => setForm({ ...form, message: e.target.value })} placeholder="What did you like, what felt weak, and what would make this feel startup-grade?" />
        {status.text && <div style={{ color: status.type === 'success' ? '#7ef2d0' : '#ff8f8f' }}>{status.text}</div>}
        <button type="submit" disabled={saving} style={{ border: 'none', borderRadius: '14px', padding: '14px 18px', background: 'linear-gradient(135deg,#635bff,#4f46e5)', color: '#fff', fontWeight: 800, cursor: 'pointer', maxWidth: '240px' }}>
          {saving ? 'Submitting...' : 'Submit Feedback'}
        </button>
      </form>
    </SitePageLayout>
  );
}
