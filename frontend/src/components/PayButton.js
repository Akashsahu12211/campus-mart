import React, { useState } from 'react';
import {
  createPaymentOrder, verifyPayment, getPaymentConfig
} from '../api/api';
import PaymentStatusModal from './PaymentStatusModal';

export default function PayButton({
  item,
  amount,
  notes,
  buttonLabel,
  onSuccess,
  onError,
}) {
  const [loading, setLoading] = useState(false);
  const [modalStatus, setModalStatus] = useState(null);
  const [modalMessage, setModalMessage] = useState('');

  const payableAmount = amount ?? item.price;

  const closeModal = () => {
    setModalStatus(null);
    setModalMessage('');
    if (modalStatus === 'success') {
      window.location.href = '/orders';
    }
  };

  const handlePay = async () => {
    setLoading(true);
    try {
      const configRes = await getPaymentConfig();
      const { keyId, configured, message } = configRes.data || {};
      if (!configured || !keyId) {
        throw new Error(message || 'Payments are not configured yet');
      }

      const orderRes = await createPaymentOrder({
        itemId: item.id,
        amount: payableAmount,
        notes: notes ?? `Buying: ${item.title}`,
      });
      const orderData = orderRes.data;

      const options = {
        key: keyId,
        amount: orderData.amount,
        currency: 'INR',
        name: 'Campus Mart',
        description: item.title,
        order_id: orderData.orderId,
        prefill: {
          name: orderData.buyerName,
          email: orderData.buyerEmail,
          contact: orderData.buyerPhone || '',
        },
        theme: { color: '#5B4BFF' },
        modal: {
          ondismiss: () => {
            setLoading(false);
            setModalStatus('cancelled');
            setModalMessage('');
          }
        },
        handler: async (response) => {
          try {
            setModalStatus('loading');
            const verifyRes = await verifyPayment({
              razorpayOrderId: response.razorpay_order_id,
              razorpayPaymentId: response.razorpay_payment_id,
              razorpaySignature: response.razorpay_signature,
            });
            setLoading(false);
            setModalStatus('success');
            onSuccess?.(verifyRes.data);
          } catch (err) {
            setLoading(false);
            setModalStatus('error');
            setModalMessage(
              err.response?.data?.error || 'Verification failed');
            onError?.(err.response?.data?.error || 'Verification failed');
          }
        },
      };

      const rzp = new window.Razorpay(options);
      rzp.on('payment.failed', (resp) => {
        setLoading(false);
        setModalStatus('error');
        setModalMessage(resp.error.description || 'Payment failed');
        onError?.(resp.error.description);
      });
      rzp.open();
    } catch (err) {
      setLoading(false);
      setModalStatus('error');
      setModalMessage(
        err.response?.data?.error || 'Failed to initiate payment');
      onError?.(
        err.response?.data?.error || 'Failed to initiate payment');
    }
  };

  return (
    <>
      <PaymentStatusModal
        status={modalStatus}
        message={modalMessage}
        itemTitle={item.title}
        amount={payableAmount?.toLocaleString('en-IN')}
        onClose={closeModal}
      />

      <button
        onClick={handlePay}
        disabled={loading}
        style={{
          width: '100%', padding: '14px',
          background: loading
            ? '#1e2438'
            : 'linear-gradient(135deg,#5b4bff,#4338ca)',
          border: 'none', borderRadius: '12px',
          color: '#fff', fontSize: '1rem', fontWeight: 700,
          cursor: loading ? 'not-allowed' : 'pointer',
          display: 'flex', alignItems: 'center',
          justifyContent: 'center', gap: '8px',
          fontFamily: "'Plus Jakarta Sans',sans-serif",
          transition: 'all 0.2s',
          boxShadow: loading
            ? 'none' : '0 4px 20px rgba(91,75,255,0.35)',
        }}
      >
        {loading ? (
          <>
            <div style={{
              width: '18px', height: '18px', borderRadius: '50%',
              border: '2px solid #fff', borderTopColor: 'transparent',
              animation: 'spin 0.7s linear infinite',
            }} />
            Processing...
          </>
        ) : (
          <>{buttonLabel || `Pay ₹${payableAmount?.toLocaleString('en-IN')} Securely`}</>
        )}
      </button>
    </>
  );
}
