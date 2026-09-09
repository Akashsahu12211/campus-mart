import React, { useContext, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { AuthContext } from '../App';
import { loginStudent, persistAuthSession, socialLogin } from '../api/api';
import BrandMark from '../components/BrandMark';
import { signInWithFacebookPopup, signInWithGooglePopup } from '../services/socialAuthService';
import { getFirebaseWebConfigIssues, hasFirebaseWebConfig } from '../firebase/firebaseWebConfig';
import '../styles/Login.css';

export default function Login() {
  const { login } = useContext(AuthContext);
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [loading, setLoading] = useState(false);
  const [socialLoading, setSocialLoading] = useState('');
  const [msg, setMsg] = useState({ text: '', type: '' });

  const socialConfigIssues = getFirebaseWebConfigIssues();
  const socialReady = hasFirebaseWebConfig();

  async function handleLogin(e) {
    e.preventDefault();
    setLoading(true);
    setMsg({ text: '', type: '' });

    try {
      const res = await loginStudent({ email, password });
      const raw = res.data;
      const student = raw?.token ? raw.student : raw;

      if (!student?.id) {
        throw new Error('Login response missing user id');
      }

      persistAuthSession(raw);

      await login(student);
      navigate('/');
    } catch (err) {
      const data = err.response?.data;
      setMsg({ text: data?.error || err.message || 'Login failed', type: 'error' });
    }

    setLoading(false);
  }

  async function handleSocial(kind) {
    setSocialLoading(kind);
    setMsg({ text: '', type: '' });
    try {
      const payload = kind === 'GOOGLE'
        ? await signInWithGooglePopup()
        : await signInWithFacebookPopup();
      const res = await socialLogin(payload);
      persistAuthSession(res.data);
      await login(res.data.student);
      navigate('/');
    } catch (err) {
      setMsg({
        text: err.response?.data?.error || err.message || `${kind} login failed`,
        type: 'error',
      });
    }
    setSocialLoading('');
  }

  return (
    <div className="login-page">
      <div className="login-shell">
        <section className="login-card-panel">
          <div className="login-card">
            <div className="login-brandmark">
              <BrandMark style={{ width: '38px', height: '38px', display: 'block' }} />
            </div>
            <div className="login-copy">
              <h1>Welcome Back</h1>
              <p>
                Sign in to manage your listings, wishlist, chats, orders, and
                safer student-to-student deals from one secure place.
              </p>
            </div>

            <form className="login-form" onSubmit={handleLogin}>
              <label className="login-field">
                <span>Email Address</span>
                <div className="login-input-wrap">
                  <span className="login-input-icon">@</span>
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    required
                  />
                </div>
              </label>

              <label className="login-field">
                <span>Password</span>
                <div className="login-input-wrap">
                  <span className="login-input-icon">*</span>
                  <input
                    type={showPw ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Enter your password"
                    required
                  />
                  <button
                    type="button"
                    className="login-password-toggle"
                    onClick={() => setShowPw((current) => !current)}
                  >
                    {showPw ? 'Hide' : 'Show'}
                  </button>
                </div>
              </label>

              {msg.text && (
                <div className={`login-message ${msg.type === 'error' ? 'login-message-error' : 'login-message-info'}`}>
                  {msg.text}
                </div>
              )}

              <button type="submit" disabled={loading} className="login-primary-btn">
                {loading ? 'Signing in...' : 'Sign In'}
              </button>
            </form>

            <div className="login-divider">
              <span />
              <p>Or continue with</p>
              <span />
            </div>

            <div className="login-social-stack">
              <button
                type="button"
                className="login-social-btn login-social-btn-google"
                onClick={() => handleSocial('GOOGLE')}
                disabled={Boolean(socialLoading) || !socialReady}
              >
                <div className="login-social-main">
                  <span className="login-social-icon login-social-icon-google">G</span>
                  <div>
                    <strong>
                      {socialLoading === 'GOOGLE' ? 'Connecting Google...' : 'Continue with Google'}
                    </strong>
                    <small>Only for already registered students</small>
                  </div>
                </div>
                <span className="login-social-arrow">+</span>
              </button>

              <button
                type="button"
                className="login-social-btn login-social-btn-facebook"
                onClick={() => handleSocial('FACEBOOK')}
                disabled={Boolean(socialLoading) || !socialReady}
              >
                <div className="login-social-main">
                  <span className="login-social-icon login-social-icon-facebook">f</span>
                  <div>
                    <strong>
                      {socialLoading === 'FACEBOOK' ? 'Connecting Facebook...' : 'Continue with Facebook'}
                    </strong>
                    <small>Only for already registered students</small>
                  </div>
                </div>
                <span className="login-social-arrow">+</span>
              </button>
            </div>

            {!socialReady && (
              <div className="login-message login-message-warning">
                Social sign-in will work after Firebase provider setup is completed.
                {socialConfigIssues.length > 0 && (
                  <div className="login-config-note">
                    Missing config: {socialConfigIssues.join(', ')}
                  </div>
                )}
              </div>
            )}

            {socialReady && (
              <div className="login-message login-message-info">
                Google and Facebook sign-in are only for students who already registered with the same email.
              </div>
            )}

            <div className="login-links">
              <Link to="/forgot-password">Forgot Password?</Link>
            </div>

            <p className="login-register-copy">
              New to Campus Mart? <Link to="/register">Create Account</Link>
            </p>
          </div>
        </section>

        <section className="login-hero-panel">
          <div className="login-hero-badge">OTP protected login</div>
          <h2>Buy, sell, and connect safely inside your campus</h2>
          <p>
            Sign in to manage your listings, wishlist, chats, orders, and safer
            student-to-student deals from one secure place.
          </p>

          <div className="login-hero-stage">
            <div className="login-hero-orb login-hero-orb-one" />
            <div className="login-hero-orb login-hero-orb-two" />

            <div className="login-student-card">
              <div className="login-student-figure">
                <div className="login-student-head" />
                <div className="login-student-body">
                  <div className="login-student-laptop" />
                  <div className="login-student-bag" />
                </div>
              </div>

              <div className="login-preview-card">
                <div className="login-preview-card-top">
                  <span className="login-preview-chip">Preview</span>
                  <span className="login-preview-status">Available nearby</span>
                </div>
                <div className="login-preview-product">
                  <div className="login-preview-thumb" />
                  <div>
                    <strong>Scientific Calculator</strong>
                    <p>{'\u20B9'}450</p>
                  </div>
                </div>
              </div>
            </div>

            <div className="login-floating-card login-float-top-left">
              Verified student deals
            </div>
            <div className="login-floating-card login-float-top-right">
              Chat before you buy
            </div>
            <div className="login-floating-card login-float-bottom-left">
              Wishlist saved
            </div>
            <div className="login-floating-card login-float-bottom-right">
              Campus-only marketplace
            </div>
          </div>

          <div className="login-hero-points">
            <div className="login-hero-point">Manage listings, wishlist, chats, and orders</div>
            <div className="login-hero-point">OTP-protected login and trusted verification</div>
            <div className="login-hero-point">Built for safer campus-to-campus deals</div>
          </div>
        </section>
      </div>
    </div>
  );
}
