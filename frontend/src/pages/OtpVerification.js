import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { verifyOtp, resendOtp } from '../api/api';
import '../styles/OtpVerification.css';

const OtpVerification = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const [otp, setOtp] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);
  const [timer, setTimer] = useState(300); // 5 minutes
  const [otpType, setOtpType] = useState('EMAIL');
  const [contact, setContact] = useState('');

  // Get OTP type and contact from location state
  useEffect(() => {
    if (location.state) {
      setOtpType(location.state.otpType || 'EMAIL');
      setContact(location.state.contact || '');
    }
  }, [location]);

  // Timer countdown
  useEffect(() => {
    if (timer > 0) {
      const interval = setInterval(() => {
        setTimer(timer - 1);
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [timer]);

  const handleVerify = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess('');

    if (!otp || otp.length !== 6) {
      setError('Please enter a valid 6-digit OTP');
      setLoading(false);
      return;
    }

    try {
      const response = await verifyOtp({
        otp: otp,
        type: otpType
      });
      
      setSuccess(response.data.message);
      setOtp('');
      
      // Store verification status
      localStorage.setItem(`${otpType.toLowerCase()}_verified`, 'true');
      
      // Redirect to appropriate page
      setTimeout(() => {
        if (location.state?.redirectTo) {
          navigate(location.state.redirectTo);
        } else {
          navigate('/register');
        }
      }, 2000);
    } catch (err) {
      setError(err.response?.data?.error || 'OTP verification failed');
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    try {
      setLoading(true);
      const response = await resendOtp({ type: otpType });
      setSuccess(response.data.message);
      setTimer(300);
      setOtp('');
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to resend OTP');
    } finally {
      setLoading(false);
    }
  };

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <div style={styles.header}>
          <h2 style={styles.title}>🔐 Verify {otpType === 'EMAIL' ? 'Email' : 'Phone'}</h2>
          <p style={styles.subtitle}>
            We've sent a 6-digit code to {contact}
          </p>
        </div>

        <form onSubmit={handleVerify} style={styles.form}>
          <div style={styles.inputGroup}>
            <label style={styles.label}>Enter OTP Code</label>
            <input
              type="text"
              maxLength="6"
              placeholder="000000"
              value={otp}
              onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
              style={styles.otpInput}
              disabled={loading}
            />
          </div>

          {error && (
            <div style={styles.errorMessage}>
              ❌ {error}
            </div>
          )}

          {success && (
            <div style={styles.successMessage}>
              ✅ {success}
            </div>
          )}

          <div style={styles.timerSection}>
            <p style={styles.timerText}>
              ⏱️ Expires in {formatTime(timer)}
            </p>
            {timer === 0 && (
              <p style={styles.expiredText}>OTP has expired. Click Resend below.</p>
            )}
          </div>

          <button
            type="submit"
            disabled={loading || otp.length !== 6 || timer === 0}
            style={{
              ...styles.submitBtn,
              opacity: (loading || otp.length !== 6 || timer === 0) ? 0.6 : 1,
              cursor: (loading || otp.length !== 6 || timer === 0) ? 'not-allowed' : 'pointer'
            }}
          >
            {loading ? '⏳ Verifying...' : '✓ Verify OTP'}
          </button>

          <button
            type="button"
            onClick={handleResend}
            disabled={loading || timer > 240} // Allow resend after 1 minute
            style={{
              ...styles.resendBtn,
              opacity: (loading || timer > 240) ? 0.6 : 1,
              cursor: (loading || timer > 240) ? 'not-allowed' : 'pointer'
            }}
          >
            🔄 Resend OTP
          </button>
        </form>

        <div style={styles.footer}>
          <p style={styles.footerText}>
            Didn't get the code? Check your spam folder or try resending.
          </p>
        </div>
      </div>
    </div>
  );
};

const styles = {
  container: {
    minHeight: '100vh',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    background: 'linear-gradient(135deg, #1E3A5F 0%, #0F1419 100%)',
    padding: '20px',
    fontFamily: 'Arial, sans-serif'
  },
  card: {
    background: '#1A1F2E',
    borderRadius: '12px',
    padding: '40px',
    maxWidth: '400px',
    width: '100%',
    boxShadow: '0 10px 40px rgba(0,0,0,0.3)',
    border: '1px solid #2D3748'
  },
  header: {
    textAlign: 'center',
    marginBottom: '30px'
  },
  title: {
    fontSize: '24px',
    fontWeight: '700',
    color: '#FFFFFF',
    margin: '0 0 10px'
  },
  subtitle: {
    fontSize: '14px',
    color: '#A0AEC0',
    margin: 0
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '20px'
  },
  inputGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '10px'
  },
  label: {
    fontSize: '14px',
    fontWeight: '600',
    color: '#CBD5E0'
  },
  otpInput: {
    padding: '12px',
    fontSize: '24px',
    letterSpacing: '8px',
    textAlign: 'center',
    border: '2px solid #2D3748',
    borderRadius: '8px',
    background: '#0F1419',
    color: '#5B4BFF',
    outline: 'none',
    fontWeight: 'bold'
  },
  errorMessage: {
    padding: '12px',
    background: '#742A2A',
    color: '#FCA5A5',
    borderRadius: '8px',
    fontSize: '14px',
    textAlign: 'center'
  },
  successMessage: {
    padding: '12px',
    background: '#1F4620',
    color: '#86EFAC',
    borderRadius: '8px',
    fontSize: '14px',
    textAlign: 'center'
  },
  timerSection: {
    textAlign: 'center'
  },
  timerText: {
    fontSize: '14px',
    color: '#A0AEC0',
    margin: 0
  },
  expiredText: {
    fontSize: '12px',
    color: '#FCA5A5',
    margin: '5px 0 0'
  },
  submitBtn: {
    padding: '12px',
    background: 'linear-gradient(135deg, #5B4BFF, #7C3AED)',
    color: '#FFFFFF',
    border: 'none',
    borderRadius: '8px',
    fontSize: '16px',
    fontWeight: '600',
    cursor: 'pointer',
    transition: 'all 0.3s ease'
  },
  resendBtn: {
    padding: '12px',
    background: 'transparent',
    color: '#5B4BFF',
    border: '2px solid #5B4BFF',
    borderRadius: '8px',
    fontSize: '16px',
    fontWeight: '600',
    cursor: 'pointer',
    transition: 'all 0.3s ease'
  },
  footer: {
    marginTop: '20px',
    textAlign: 'center'
  },
  footerText: {
    fontSize: '12px',
    color: '#718096',
    margin: 0
  }
};

export default OtpVerification;
