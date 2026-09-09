import React, { useEffect } from 'react';
import './PaymentStatusModal.css';

const PaymentStatusModal = ({ status, message, onClose, itemTitle, amount }) => {
  useEffect(() => {
    if (status === 'success') {
      // Auto-close success after 4 seconds
      const timer = setTimeout(onClose, 4000);
      return () => clearTimeout(timer);
    }
  }, [status, onClose]);

  if (!status) return null;

  return (
    <div className="payment-status-overlay">
      <div className="payment-status-modal">
        {status === 'success' && (
          <>
            {/* Confetti Animation */}
            <div className="confetti">
              {[...Array(30)].map((_, i) => (
                <div key={i} className="confetti-piece"></div>
              ))}
            </div>

            {/* Success Content */}
            <div className="success-content">
              <div className="success-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
                  <path
                    d="M9 16.17L4.83 12m0 0l-1.42 1.41M4.83 12L1 8.17"
                    strokeWidth="2"
                  />
                  <path d="M16 12l2.29 2.29 4.88-4.88" strokeWidth="2" />
                </svg>
              </div>

              <h2>Payment Successful! 🎉</h2>
              <div className="payment-details">
                <p className="item-name">{itemTitle}</p>
                <p className="amount">₹{amount}</p>
              </div>

              <div className="escrow-info">
                <div className="info-icon">ℹ️</div>
                <p>
                  Amount held in <strong>48-hour escrow</strong> for buyer protection.
                  <br />
                  Confirm delivery on the Orders page to release funds.
                </p>
              </div>

              <button className="btn-primary" onClick={onClose}>
                Continue to Orders
              </button>
            </div>
          </>
        )}

        {status === 'error' && (
          <div className="error-content">
            <div className="error-icon">❌</div>
            <h2>Payment Failed</h2>
            <p className="error-message">{message || 'Something went wrong'}</p>
            <div className="error-actions">
              <button className="btn-secondary" onClick={onClose}>
                Try Again
              </button>
              <button className="btn-text" onClick={onClose}>
                Cancel
              </button>
            </div>
          </div>
        )}

        {status === 'cancelled' && (
          <div className="cancelled-content">
            <div className="cancelled-icon">⏸️</div>
            <h2>Payment Cancelled</h2>
            <p className="cancelled-message">No amount was charged to your account.</p>
            <button className="btn-primary" onClick={onClose}>
              Go Back
            </button>
          </div>
        )}

        {status === 'loading' && (
          <div className="loading-content">
            <div className="spinner"></div>
            <h2>Processing Payment...</h2>
            <p>Please wait while we verify your payment</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default PaymentStatusModal;
