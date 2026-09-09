import React, { useContext, useState } from 'react';
import { AuthContext } from '../App';
import { submitProblemReport } from '../api/api';
import SitePageLayout from './SitePageLayout';

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

export default function ReportProblem() {
  const { user } = useContext(AuthContext);
  const [form, setForm] = useState({
    name: user?.name || '',
    email: user?.email || '',
    subject: '',
    category: 'Bug',
    message: '',
  });
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState({ type: '', text: '' });

  const handleSubmit = async (event) => {
    event.preventDefault();
    setSaving(true);
    setStatus({ type: '', text: '' });
    try {
      await submitProblemReport({
        ...form,
        studentId: user?.id,
        appPlatform: 'web',
        pagePath: window.location.pathname,
      });
      setStatus({ type: 'success', text: 'Problem report receive ho gaya. Isse admin/support panel me track kiya jayega.' });
      setForm((current) => ({ ...current, subject: '', message: '' }));
    } catch (error) {
      setStatus({ type: 'error', text: error.response?.data?.error || 'Problem report submit nahi ho paaya.' });
    }
    setSaving(false);
  };

  return (
    <SitePageLayout
      eyebrow="Report a Problem"
      title="Something broken, confusing, or risky?"
      description="Bug, payment issue, login problem, admin issue, listing glitch, ya trust concern - is form se directly escalate karo."
    >
      <form onSubmit={handleSubmit} style={{ display: 'grid', gap: '14px', maxWidth: '760px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
          <input style={inputStyle} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Your name" />
          <input style={inputStyle} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} placeholder="Your email" />
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 220px', gap: '14px' }}>
          <input style={inputStyle} value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })} placeholder="Issue title" />
          <select style={inputStyle} value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
            <option>Bug</option>
            <option>Login</option>
            <option>Payment</option>
            <option>Listing</option>
            <option>Chat</option>
            <option>Admin</option>
          </select>
        </div>
        <textarea style={{ ...inputStyle, minHeight: '180px', resize: 'vertical' }} value={form.message} onChange={(e) => setForm({ ...form, message: e.target.value })} placeholder="What happened, where it happened, and how we can reproduce it?" />
        {status.text && <div style={{ color: status.type === 'success' ? '#7ef2d0' : '#ff8f8f' }}>{status.text}</div>}
        <button type="submit" disabled={saving} style={{ border: 'none', borderRadius: '14px', padding: '14px 18px', background: 'linear-gradient(135deg,#635bff,#4f46e5)', color: '#fff', fontWeight: 800, cursor: 'pointer', maxWidth: '240px' }}>
          {saving ? 'Submitting...' : 'Submit Problem Report'}
        </button>
      </form>
    </SitePageLayout>
  );
}
