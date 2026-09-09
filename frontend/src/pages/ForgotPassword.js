import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { requestForgotPassword, resetForgotPassword } from '../api/api';

const card = {
  background: '#0F1320',
  border: '1px solid rgba(91,75,255,0.2)',
  borderRadius: 20,
  padding: '36px 32px',
  width: '100%',
  maxWidth: 440,
  boxShadow: '0 20px 60px rgba(0,0,0,0.5)',
};

const input = {
  width: '100%',
  padding: '12px 14px',
  borderRadius: 10,
  background: '#080B14',
  border: '1px solid #1E2438',
  color: '#fff',
  fontSize: 14,
  outline: 'none',
  boxSizing: 'border-box',
};

export default function ForgotPassword() {
  const [step, setStep] = useState('request');
  const [form, setForm] = useState({ email: '', otp: '', newPassword: '' });
  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState({ type: '', text: '' });

  const handleRequest = async (event) => {
    event.preventDefault();
    setLoading(true);
    setMsg({ type: '', text: '' });
    try {
      const response = await requestForgotPassword({ email: form.email });
      setMsg({ type: 'success', text: response.data.message });
      setStep('reset');
    } catch (error) {
      setMsg({ type: 'error', text: error.response?.data?.error || 'Unable to send reset OTP' });
    }
    setLoading(false);
  };

  const handleReset = async (event) => {
    event.preventDefault();
    setLoading(true);
    setMsg({ type: '', text: '' });
    try {
      const response = await resetForgotPassword(form);
      setMsg({ type: 'success', text: response.data.message });
    } catch (error) {
      setMsg({ type: 'error', text: error.response?.data?.error || 'Unable to reset password' });
    }
    setLoading(false);
  };

  return (
    <div style={{ minHeight: '100vh', background: '#080B14', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
      <div style={card}>
        <h1 style={{ marginTop: 0, color: '#fff', fontSize: 24 }}>Forgot Password</h1>
        <p style={{ color: '#94A3B8', lineHeight: 1.7 }}>
          Email OTP ke through password reset karo. Pehle OTP request karo, phir new password set karo.
        </p>

        <form onSubmit={step === 'request' ? handleRequest : handleReset} style={{ display: 'grid', gap: 14 }}>
          <input
            type="email"
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
            placeholder="Your registered email"
            style={input}
            required
          />

          {step === 'reset' && (
            <>
              <input
                type="text"
                value={form.otp}
                onChange={(e) => setForm({ ...form, otp: e.target.value })}
                placeholder="Enter email OTP"
                style={input}
                required
              />
              <input
                type="password"
                value={form.newPassword}
                onChange={(e) => setForm({ ...form, newPassword: e.target.value })}
                placeholder="New password"
                style={input}
                required
              />
            </>
          )}

          {msg.text && (
            <div style={{
              padding: '12px 14px',
              borderRadius: 10,
              background: msg.type === 'success' ? 'rgba(0,212,170,0.1)' : 'rgba(239,68,68,0.1)',
              border: `1px solid ${msg.type === 'success' ? '#00D4AA' : '#EF4444'}`,
              color: msg.type === 'success' ? '#7ef2d0' : '#ff8f8f',
              fontSize: 13,
            }}>
              {msg.text}
            </div>
          )}

          <button type="submit" disabled={loading} style={{ border: 'none', borderRadius: 10, padding: 13, background: 'linear-gradient(135deg,#5B4BFF,#4338CA)', color: '#fff', fontWeight: 700, cursor: 'pointer' }}>
            {loading ? 'Please wait...' : step === 'request' ? 'Send Reset OTP' : 'Reset Password'}
          </button>
        </form>

        <p style={{ textAlign: 'center', marginTop: 18, color: '#94A3B8' }}>
          <Link to="/login" style={{ color: '#5B4BFF', fontWeight: 700 }}>Back to Login</Link>
        </p>
      </div>
    </div>
  );
}
