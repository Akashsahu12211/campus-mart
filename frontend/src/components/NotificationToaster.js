import React, { useEffect, useState } from 'react';

export default function NotificationToaster() {
  const [toast, setToast] = useState(null);

  useEffect(() => {
    let timeoutId;

    const handlePushMessage = (event) => {
      const detail = event.detail || {};
      window.dispatchEvent(new CustomEvent('campusmart:notifications-updated'));
      setToast({
        title: detail.title || 'Campus Mart',
        body: detail.body || 'You have a new update.',
        clickAction: detail.clickAction || '/',
      });

      window.clearTimeout(timeoutId);
      timeoutId = window.setTimeout(() => setToast(null), 5000);
    };

    window.addEventListener('campusmart:push-message', handlePushMessage);
    return () => {
      window.removeEventListener('campusmart:push-message', handlePushMessage);
      window.clearTimeout(timeoutId);
    };
  }, []);

  if (!toast) {
    return null;
  }

  return (
    <button
      type="button"
      onClick={() => {
        window.location.assign(toast.clickAction);
        setToast(null);
      }}
      style={{
        position: 'fixed',
        right: 20,
        bottom: 20,
        zIndex: 1200,
        width: 'min(360px, calc(100vw - 32px))',
        border: '1px solid rgba(91,75,255,0.35)',
        borderRadius: 18,
        padding: 0,
        background: 'linear-gradient(135deg, rgba(15,19,32,0.96), rgba(12,16,28,0.96))',
        boxShadow: '0 24px 80px rgba(0,0,0,0.38)',
        color: '#fff',
        cursor: 'pointer',
        overflow: 'hidden',
        textAlign: 'left',
      }}
    >
      <div
        style={{
          padding: '14px 16px 10px',
          background: 'linear-gradient(135deg, rgba(67,56,202,0.95), rgba(91,75,255,0.95))',
          fontWeight: 800,
          fontSize: 14,
          letterSpacing: '0.02em',
        }}
      >
        Campus Mart Notification
      </div>
      <div style={{ padding: '14px 16px 16px' }}>
        <div style={{ fontSize: 15, fontWeight: 800, marginBottom: 6 }}>
          {toast.title}
        </div>
        <div style={{ fontSize: 13, lineHeight: 1.5, color: '#C7D2FE' }}>
          {toast.body}
        </div>
      </div>
    </button>
  );
}
