import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { persistAuthSession, registerUser, verifyEmailOtp, verifyPhoneOtp, resendEmailOtp, resendPhoneOtp } from '../api/api';
import BrandMark from '../components/BrandMark';

// Steps: 'form' → 'email_otp' → 'phone_otp' → 'success'
export default function Register() {
  const navigate = useNavigate();

  const [step,    setStep]    = useState('form');
  const [sessionId, setSessionId] = useState(null);
  const [maskedEmail, setMaskedEmail] = useState('');
  const [maskedPhone, setMaskedPhone] = useState('');
  const [devOtp,  setDevOtp]  = useState('');
  const [loading, setLoading] = useState(false);
  const [msg,     setMsg]     = useState({ text: '', type: '' });

  const [form, setForm] = useState({
    name: '', email: '', password: '', confirmPassword: '', phone: ''
  });
  const [showPw,       setShowPw]       = useState(false);
  const [pwStrength,   setPwStrength]   = useState(0);
  const [emailOtp,     setEmailOtp]     = useState('');
  const [phoneOtp,     setPhoneOtp]     = useState('');
  const [resendTimer,  setResendTimer]  = useState(0);

  function calcStrength(pw) {
    let s = 0;
    if (pw.length >= 6)                          s++;
    if (pw.length >= 10)                         s++;
    if (/[A-Z]/.test(pw))                        s++;
    if (/[0-9]/.test(pw))                        s++;
    if (/[^A-Za-z0-9]/.test(pw))                s++;
    return s;
  }

  function startTimer() {
    setResendTimer(30);
    const iv = setInterval(() => {
      setResendTimer(t => { if (t <= 1) { clearInterval(iv); return 0; } return t - 1; });
    }, 1000);
  }

  const showMsg = (text, type = 'error') => setMsg({ text, type });

  // ── STEP 1: Submit Registration Form ──
  async function handleRegister(e) {
    e.preventDefault();
    if (form.password !== form.confirmPassword) { showMsg('Passwords do not match'); return; }
    setLoading(true); setMsg({ text: '', type: '' });
    try {
      const res = await registerUser({
        name: form.name, email: form.email,
        password: form.password, phone: form.phone
      });
      setSessionId(res.data.sessionId);
      setMaskedEmail(res.data.email);
      setStep('email_otp');
      showMsg('OTP sent to ' + res.data.email, 'success');
      startTimer();
    } catch (e) {
      showMsg(e.response?.data?.error || 'Registration failed');
    }
    setLoading(false);
  }

  // ── STEP 2: Verify Email OTP ──
  async function handleEmailOtp(e) {
    e.preventDefault();
    if (emailOtp.length !== 6) { showMsg('Enter 6-digit OTP'); return; }
    setLoading(true); setMsg({ text: '', type: '' });
    try {
      const res = await verifyEmailOtp({ sessionId, otp: emailOtp });
      setMaskedPhone(res.data.phone);
      if (res.data.devPhoneOtp) setDevOtp(res.data.devPhoneOtp);
      setStep('phone_otp');
      showMsg('Email verified! OTP sent to your phone.', 'success');
      startTimer();
    } catch (e) {
      showMsg(e.response?.data?.error || 'Verification failed');
    }
    setLoading(false);
  }

  // ── STEP 3: Verify Phone OTP ──
  async function handlePhoneOtp(e) {
    e.preventDefault();
    if (phoneOtp.length !== 6) { showMsg('Enter 6-digit OTP'); return; }
    setLoading(true); setMsg({ text: '', type: '' });
    try {
      const res = await verifyPhoneOtp({ sessionId, otp: phoneOtp });
      localStorage.setItem('campusmart_user',  JSON.stringify(res.data.student));
      persistAuthSession(res.data);
      setStep('success');
    } catch (e) {
      showMsg(e.response?.data?.error || 'Verification failed');
    }
    setLoading(false);
  }

  const S = styles;

  return (
    <div style={S.page}>
      <div style={S.card}>
        {/* Logo */}
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div style={S.logo}>
            <BrandMark style={{ width: 38, height: 38, display: 'block' }} />
          </div>
          <h1 style={S.title}>Campus Mart</h1>
          <p style={S.sub}>College Student Marketplace</p>
        </div>

        {/* Progress steps */}
        <ProgressBar step={step} />

        {/* ── FORM STEP ── */}
        {step === 'form' && (
          <form onSubmit={handleRegister}>
            <h2 style={S.stepTitle}>Account Details</h2>

            <Field label="Full Name" value={form.name}
              onChange={v => setForm(f => ({ ...f, name: v }))}
              placeholder="Your full name" icon="👤" />

            <Field label="Email Address" value={form.email} type="email"
              onChange={v => setForm(f => ({ ...f, email: v }))}
              placeholder="your@email.com" icon="📧" />

            <div style={{ marginBottom: 16 }}>
              <label style={S.label}>Password</label>
              <div style={{ position: 'relative' }}>
                <span style={S.fieldIcon}>🔒</span>
                <input
                  type={showPw ? 'text' : 'password'}
                  value={form.password}
                  onChange={e => { setForm(f => ({ ...f, password: e.target.value })); setPwStrength(calcStrength(e.target.value)); }}
                  placeholder="Min 6 chars + number"
                  style={S.input} required
                />
                <span onClick={() => setShowPw(p => !p)} style={S.eyeBtn}>{showPw ? '🙈' : '👁️'}</span>
              </div>
              {form.password && (
                <div style={{ marginTop: 6 }}>
                  <div style={{ display: 'flex', gap: 4 }}>
                    {[1,2,3,4,5].map(i => (
                      <div key={i} style={{
                        flex: 1, height: 4, borderRadius: 2,
                        background: i <= pwStrength
                          ? (pwStrength <= 2 ? '#EF4444' : pwStrength <= 3 ? '#5B4BFF' : '#00D4AA')
                          : '#1E2438',
                        transition: 'background 0.3s'
                      }} />
                    ))}
                  </div>
                  <div style={{ fontSize: 11, color: '#718096', marginTop: 3 }}>
                    {['', 'Weak', 'Weak', 'Fair', 'Strong', 'Very Strong'][pwStrength]}
                  </div>
                </div>
              )}
            </div>

            <Field label="Confirm Password" value={form.confirmPassword}
              type="password"
              onChange={v => setForm(f => ({ ...f, confirmPassword: v }))}
              placeholder="Re-enter password" icon="🔐" />

            <Field label="Phone Number" value={form.phone} type="text"
              onChange={v => {
                // Allow anything to be typed, then extract digits
                let input = v;
                let digits = input.replace(/\D/g, '');
                // Remove leading 91 only if user typed +91 or 091
                if (digits.startsWith('91') && input.includes('91') && digits.length > 10) {
                  digits = digits.slice(2);
                }
                setForm(f => ({ ...f, phone: digits }));
              }}
              placeholder="9151256571 or +919151256571" icon="📱" />

            {msg.text && <MsgBox msg={msg} />}

            <button type="submit" disabled={loading} style={S.btn}>
              {loading ? 'Processing...' : 'Next →'}
            </button>

            <p style={{ textAlign: 'center', color: '#718096', fontSize: 13, marginTop: 16 }}>
              Already have an account? <Link to="/login" style={{ color: '#5B4BFF' }}>Login</Link>
            </p>
          </form>
        )}

        {/* ── EMAIL OTP STEP ── */}
        {step === 'email_otp' && (
          <form onSubmit={handleEmailOtp}>
            <div style={{ textAlign: 'center', marginBottom: 20 }}>
              <div style={{ fontSize: 48, marginBottom: 8 }}>📧</div>
              <h2 style={S.stepTitle}>Verify Email</h2>
              <p style={{ color: '#A0AEC0', fontSize: 14 }}>
                OTP sent to <strong style={{ color: '#5B4BFF' }}>{maskedEmail}</strong>
              </p>
              <p style={{ color: '#718096', fontSize: 12 }}>Valid for 10 minutes</p>
            </div>

            <OtpInput value={emailOtp} onChange={setEmailOtp} />

            {msg.text && <MsgBox msg={msg} />}

            <button type="submit" disabled={loading || emailOtp.length !== 6} style={S.btn}>
              {loading ? 'Verifying...' : 'Verify Email →'}
            </button>

            <div style={{ textAlign: 'center', marginTop: 14 }}>
              {resendTimer > 0
                ? <span style={{ color: '#718096', fontSize: 13 }}>Resend in {resendTimer}s</span>
                : <button type="button" onClick={async () => {
                    try { await resendEmailOtp({ sessionId }); startTimer(); showMsg('New OTP sent!', 'success'); }
                    catch (e) { showMsg(e.response?.data?.error || 'Failed to resend'); }
                  }} style={S.linkBtn}>Resend OTP</button>
              }
            </div>
          </form>
        )}

        {/* ── PHONE OTP STEP ── */}
        {step === 'phone_otp' && (
          <form onSubmit={handlePhoneOtp}>
            <div style={{ textAlign: 'center', marginBottom: 20 }}>
              <div style={{ fontSize: 48, marginBottom: 8 }}>📱</div>
              <h2 style={S.stepTitle}>Verify Phone</h2>
              <p style={{ color: '#A0AEC0', fontSize: 14 }}>
                OTP sent to <strong style={{ color: '#5B4BFF' }}>{maskedPhone}</strong>
              </p>
              {devOtp && (
                <div style={{ background: 'rgba(0,212,170,0.1)', border: '1px solid #00D4AA', borderRadius: 8, padding: '8px 16px', marginTop: 10, fontSize: 13 }}>
                  🔧 <strong style={{ color: '#00D4AA' }}>Dev Mode OTP: {devOtp}</strong>
                </div>
              )}
            </div>

            <OtpInput value={phoneOtp} onChange={setPhoneOtp} />

            {msg.text && <MsgBox msg={msg} />}

            <button type="submit" disabled={loading || phoneOtp.length !== 6} style={S.btn}>
              {loading ? 'Verifying...' : 'Verify Phone →'}
            </button>

            <div style={{ textAlign: 'center', marginTop: 14 }}>
              {resendTimer > 0
                ? <span style={{ color: '#718096', fontSize: 13 }}>Resend in {resendTimer}s</span>
                : <button type="button" onClick={async () => {
                    try {
                      const r = await resendPhoneOtp({ sessionId });
                      if (r.data.devPhoneOtp) setDevOtp(r.data.devPhoneOtp);
                      startTimer();
                      showMsg('New OTP sent!', 'success');
                    } catch (e) { showMsg(e.response?.data?.error || 'Failed'); }
                  }} style={S.linkBtn}>Resend OTP</button>
              }
            </div>
          </form>
        )}

        {/* ── SUCCESS STEP ── */}
        {step === 'success' && (
          <div style={{ textAlign: 'center', padding: '20px 0' }}>
            <div style={{ fontSize: 72, marginBottom: 16, animation: 'pulse 0.6s ease-in-out' }}>✨</div>
            <h2 style={{ color: '#00D4AA', fontSize: 24, fontWeight: 800, marginBottom: 8 }}>
              Account Created!
            </h2>
            <p style={{ color: '#A0AEC0', marginBottom: 12 }}>
              Congratulations! Your account is now verified and active.
            </p>
            <p style={{ color: '#718096', fontSize: 14, marginBottom: 28 }}>
              You're all set. Start buying and selling on Campus Mart!
            </p>
            <button onClick={() => navigate('/')} style={S.btn}>
              Done ✓
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

// ── Sub-components ──
function ProgressBar({ step }) {
  const steps = [
    { key: 'form',      label: 'Details',      icon: '📝' },
    { key: 'email_otp', label: 'Email OTP',    icon: '📧' },
    { key: 'phone_otp', label: 'Phone OTP',    icon: '📱' },
    { key: 'success',   label: 'Done',         icon: '✅' },
  ];
  const current = steps.findIndex(s => s.key === step);
  return (
    <div style={{ display: 'flex', alignItems: 'center', marginBottom: 28 }}>
      {steps.map((s, i) => (
        <React.Fragment key={s.key}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: 1 }}>
            <div style={{
              width: 36, height: 36, borderRadius: '50%',
              background: i <= current ? '#5B4BFF' : '#1E2438',
              border: `2px solid ${i <= current ? '#5B4BFF' : '#2A3550'}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 16, transition: 'all 0.3s',
            }}>{i < current ? '✓' : s.icon}</div>
            <span style={{ fontSize: 10, color: i <= current ? '#A0AEC0' : '#4A5568', marginTop: 4 }}>{s.label}</span>
          </div>
          {i < steps.length - 1 && (
            <div style={{ flex: 1, height: 2, background: i < current ? '#5B4BFF' : '#1E2438', marginBottom: 16 }} />
          )}
        </React.Fragment>
      ))}
    </div>
  );
}

function Field({ label, value, onChange, placeholder, icon, type = 'text' }) {
  const S = styles;
  return (
    <div style={{ marginBottom: 16 }}>
      <label style={S.label}>{label}</label>
      <div style={{ position: 'relative' }}>
        <span style={S.fieldIcon}>{icon}</span>
        <input type={type} value={value} onChange={e => onChange(e.target.value)}
          placeholder={placeholder} style={S.input} required />
      </div>
    </div>
  );
}

function OtpInput({ value, onChange }) {
  const digits = [...'000000'].map((_, i) => value[i] || '');
  return (
    <div style={{ display: 'flex', gap: 10, justifyContent: 'center', marginBottom: 20 }}>
      {digits.map((d, i) => (
        <input key={i} type="text" inputMode="numeric" maxLength={1} value={d}
          onChange={e => {
            const v = e.target.value.replace(/\D/, '');
            const arr = value.split('');
            arr[i] = v;
            const newVal = arr.join('').slice(0, 6);
            onChange(newVal);
            if (v && i < 5) {
              document.querySelectorAll('.otp-box')[i + 1]?.focus();
            }
          }}
          onKeyDown={e => {
            if (e.key === 'Backspace' && !d && i > 0) {
              document.querySelectorAll('.otp-box')[i - 1]?.focus();
            }
          }}
          className="otp-box"
          style={{
            width: 48, height: 56, textAlign: 'center', fontSize: 22,
            fontWeight: 800, borderRadius: 10, outline: 'none',
            background: '#0F1320', color: '#fff',
            border: d ? '2px solid #5B4BFF' : '2px solid #1E2438',
            transition: 'border 0.2s',
          }}
        />
      ))}
    </div>
  );
}

function MsgBox({ msg }) {
  return (
    <div style={{
      padding: '10px 14px', borderRadius: 8, marginBottom: 14, fontSize: 13,
      background: msg.type === 'success' ? 'rgba(0,212,170,0.1)' : 'rgba(239,68,68,0.1)',
      border: `1px solid ${msg.type === 'success' ? '#00D4AA' : '#EF4444'}`,
      color: msg.type === 'success' ? '#00D4AA' : '#EF4444',
    }}>{msg.text}</div>
  );
}

const styles = {
  page:  { minHeight: '100vh', background: '#080B14', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px', fontFamily: 'Inter, Arial, sans-serif' },
  card:  { background: '#0F1320', border: '1px solid rgba(91,75,255,0.2)', borderRadius: 20, padding: '36px 32px', width: '100%', maxWidth: 440, boxShadow: '0 20px 60px rgba(0,0,0,0.5)' },
  logo:  { width: 64, height: 64, borderRadius: '50%', background: 'linear-gradient(135deg,#5B4BFF,#00D4AA)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 28, margin: '0 auto 12px' },
  title: { margin: '0 0 4px', fontSize: 24, fontWeight: 900, color: '#fff', textAlign: 'center' },
  sub:   { margin: 0, color: '#718096', fontSize: 13, textAlign: 'center' },
  stepTitle: { fontSize: 20, fontWeight: 800, color: '#fff', marginBottom: 20, textAlign: 'center' },
  label: { display: 'block', fontSize: 12, color: '#A0AEC0', marginBottom: 5, fontWeight: 600 },
  input: { width: '100%', padding: '11px 14px 11px 40px', borderRadius: 10, background: '#080B14', border: '1px solid #1E2438', color: '#fff', fontSize: 14, outline: 'none', boxSizing: 'border-box', fontFamily: 'inherit' },
  fieldIcon: { position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)', fontSize: 16 },
  eyeBtn: { position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', cursor: 'pointer', fontSize: 16 },
  btn:   { width: '100%', padding: '13px', borderRadius: 10, background: 'linear-gradient(135deg,#5B4BFF,#4338CA)', border: 'none', color: '#fff', fontWeight: 700, fontSize: 15, cursor: 'pointer' },
  linkBtn: { background: 'none', border: 'none', color: '#5B4BFF', cursor: 'pointer', fontSize: 13, fontWeight: 600 },
};
