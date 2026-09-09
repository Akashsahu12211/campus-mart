import React, { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../../App';
import {
  getAdminReports,
  getDisputedOrders,
  resolveDispute,
  reviewReport,
} from '../../api/admin_api';

const STATUS_COLORS = {
  PENDING: { bg: 'rgba(245,158,11,0.12)', color: '#f59e0b' },
  REVIEWED: { bg: 'rgba(34,197,94,0.12)', color: '#22c55e' },
  DISMISSED: { bg: 'rgba(100,116,139,0.1)', color: '#64748b' },
  RESOLVED: { bg: 'rgba(34,197,94,0.12)', color: '#22c55e' },
  REFUNDED: { bg: 'rgba(34,197,94,0.12)', color: '#22c55e' },
  RELEASED: { bg: 'rgba(59,130,246,0.12)', color: '#3b82f6' },
};

export default function AdminReports() {
  const { user } = useAuth();
  const [reports, setReports] = useState([]);
  const [disputes, setDisputes] = useState([]);
  const [activeTab, setActiveTab] = useState('reports');
  const [pending, setPending] = useState(false);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [selectedDispute, setSelectedDispute] = useState(null);

  const showMsg = useCallback((type, text) => {
    setMsg({ type, text });
    window.clearTimeout(showMsg.timerId);
    showMsg.timerId = window.setTimeout(() => {
      setMsg({ type: '', text: '' });
    }, 3000);
  }, []);

  const loadReports = useCallback(async (pendingOnly = false) => {
    if (!user?.id) return;
    setLoading(true);
    try {
      const response = await getAdminReports(pendingOnly);
      setReports(response.data || []);
      setMsg({ type: '', text: '' });
    } catch (error) {
      setReports([]);
      setMsg({
        type: 'error',
        text: error.response?.data?.error || 'Failed to load reports',
      });
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  const loadDisputes = useCallback(async () => {
    if (!user?.id) return;
    setLoading(true);
    try {
      const response = await getDisputedOrders();
      setDisputes(response.data || []);
      setMsg({ type: '', text: '' });
    } catch (error) {
      setDisputes([]);
      setMsg({
        type: 'error',
        text: error.response?.data?.error || 'Failed to load disputes',
      });
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  useEffect(() => {
    if (!user?.id) return;
    if (activeTab === 'reports') {
      loadReports(pending);
      return;
    }
    loadDisputes();
  }, [activeTab, loadDisputes, loadReports, pending, user?.id]);

  useEffect(() => () => window.clearTimeout(showMsg.timerId), [showMsg]);

  const handleReview = async (reportId, action) => {
    try {
      await reviewReport(reportId, { action });
      showMsg(
        'success',
        action === 'approve'
          ? 'Report approved and item hidden.'
          : 'Report dismissed.'
      );
      loadReports(pending);
    } catch (error) {
      showMsg('error', error.response?.data?.error || 'Failed to review report');
    }
  };

  const handleResolveDispute = async (orderId, action) => {
    try {
      await resolveDispute(orderId, { action });
      showMsg(
        'success',
        action === 'approve'
          ? 'Dispute approved and refund initiated.'
          : 'Dispute rejected and payment released.'
      );
      setSelectedDispute(null);
      loadDisputes();
    } catch (error) {
      showMsg(
        'error',
        error.response?.data?.error || 'Failed to resolve dispute'
      );
    }
  };

  return (
    <div>
      <div
        style={{
          background:
            'linear-gradient(135deg, rgba(239,68,68,0.1) 0%, rgba(245,158,11,0.1) 100%)',
          border: '1px solid rgba(239,68,68,0.3)',
          borderRadius: '14px',
          padding: '16px 20px',
          marginBottom: '24px',
          display: 'flex',
          alignItems: 'center',
          gap: '12px',
        }}
      >
        <span style={{ fontSize: '1.4rem' }}>🔐</span>
        <div style={{ flex: 1 }}>
          <div
            style={{
              fontFamily: "'Syne',sans-serif",
              fontSize: '1rem',
              fontWeight: 700,
              color: '#fca5a5',
            }}
          >
            ADMIN MODE ACTIVE
          </div>
          <div
            style={{
              fontSize: '0.82rem',
              color: '#a0a8c8',
              marginTop: '2px',
            }}
          >
            {activeTab === 'reports'
              ? `Reviewing ${reports.length} user-submitted reports`
              : `Managing ${disputes.length} order disputes`}
          </div>
        </div>
      </div>

      <div style={{ marginBottom: '24px' }}>
        <h1
          style={{
            fontFamily: "'Syne',sans-serif",
            fontSize: '1.8rem',
            color: '#e8eaf6',
          }}
        >
          {activeTab === 'reports' ? 'Reports 🚨' : 'Disputes ⚖️'}
        </h1>
        <p style={{ color: '#5a6285', fontSize: '0.88rem' }}>
          {activeTab === 'reports'
            ? `${reports.filter((report) => report.status === 'PENDING').length} pending reports`
            : `${disputes.filter((dispute) => dispute.status === 'PENDING').length} pending disputes`}
        </p>
      </div>

      <div
        style={{
          display: 'flex',
          gap: '8px',
          marginBottom: '20px',
          borderBottom: '1px solid #1e2438',
          paddingBottom: '12px',
        }}
      >
        <button
          onClick={() => setActiveTab('reports')}
          style={{
            background:
              activeTab === 'reports' ? 'rgba(91,75,255,0.15)' : 'transparent',
            color: activeTab === 'reports' ? '#5b4bff' : '#5a6285',
            border: `1px solid ${activeTab === 'reports' ? '#5b4bff' : '#1e2438'}`,
            borderRadius: '8px',
            padding: '8px 14px',
            fontSize: '0.88rem',
            fontWeight: 600,
            cursor: 'pointer',
            transition: 'all 0.3s',
          }}
        >
          📋 User Reports
        </button>
        <button
          onClick={() => setActiveTab('disputes')}
          style={{
            background:
              activeTab === 'disputes' ? 'rgba(91,75,255,0.15)' : 'transparent',
            color: activeTab === 'disputes' ? '#5b4bff' : '#5a6285',
            border: `1px solid ${activeTab === 'disputes' ? '#5b4bff' : '#1e2438'}`,
            borderRadius: '8px',
            padding: '8px 14px',
            fontSize: '0.88rem',
            fontWeight: 600,
            cursor: 'pointer',
            transition: 'all 0.3s',
          }}
        >
          ⚖️ Order Disputes
        </button>
      </div>

      {msg.text && (
        <div
          className={`alert alert-${msg.type === 'success' ? 'success' : 'error'}`}
          style={{ marginBottom: '16px' }}
        >
          {msg.text}
        </div>
      )}

      {activeTab === 'reports' && (
        <>
          <div style={{ display: 'flex', gap: '8px', marginBottom: '20px' }}>
            <button
              onClick={() => {
                setPending(false);
                loadReports(false);
              }}
              className={`pill ${!pending ? 'active' : ''}`}
            >
              All Reports
            </button>
            <button
              onClick={() => {
                setPending(true);
                loadReports(true);
              }}
              className={`pill ${pending ? 'active' : ''}`}
            >
              ⏳ Pending Only
            </button>
          </div>

          {loading ? (
            <div className="loading-wrap">
              <div className="spinner" />
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {reports.map((report) => {
                const statusStyle =
                  STATUS_COLORS[report.status] || STATUS_COLORS.PENDING;
                return (
                  <div
                    key={report.id}
                    style={{
                      background: '#0f1320',
                      border: '1px solid #1e2438',
                      borderRadius: '12px',
                      padding: '16px',
                    }}
                  >
                    <div
                      style={{
                        display: 'flex',
                        gap: '14px',
                        justifyContent: 'space-between',
                        flexWrap: 'wrap',
                      }}
                    >
                      <div>
                        <div
                          style={{
                            display: 'flex',
                            gap: '10px',
                            alignItems: 'center',
                            marginBottom: '6px',
                          }}
                        >
                          <span
                            style={{
                              background: 'rgba(239,68,68,0.1)',
                              color: '#ef4444',
                              padding: '2px 8px',
                              borderRadius: '6px',
                              fontSize: '0.72rem',
                              fontWeight: 700,
                            }}
                          >
                            {report.reason}
                          </span>
                          <span
                            style={{
                              background: statusStyle.bg,
                              color: statusStyle.color,
                              padding: '2px 8px',
                              borderRadius: '6px',
                              fontSize: '0.72rem',
                              fontWeight: 700,
                            }}
                          >
                            {report.status}
                          </span>
                        </div>
                        <p
                          style={{
                            color: '#e8eaf6',
                            fontWeight: 700,
                            marginBottom: '4px',
                            fontSize: '0.92rem',
                          }}
                        >
                          📦 {report.item?.title || 'Deleted item'}
                        </p>
                        <p style={{ color: '#5a6285', fontSize: '0.8rem' }}>
                          Reported by:{' '}
                          <strong style={{ color: '#a0a8c8' }}>
                            {report.reporter?.name}
                          </strong>
                        </p>
                        <p style={{ color: '#5a6285', fontSize: '0.78rem', marginTop: '4px' }}>
                          Item reports: <strong style={{ color: '#e8eaf6' }}>{report.itemReportCount ?? 0}</strong>
                          {' · '}
                          Pending: <strong style={{ color: '#f59e0b' }}>{report.pendingReportCount ?? 0}</strong>
                        </p>
                        {report.description && (
                          <p
                            style={{
                              color: '#5a6285',
                              fontSize: '0.8rem',
                              fontStyle: 'italic',
                              marginTop: '4px',
                            }}
                          >
                            "{report.description}"
                          </p>
                        )}
                        {report.reviewedBy && (
                          <p style={{ color: '#5a6285', fontSize: '0.78rem', marginTop: '8px' }}>
                            Reviewed by <strong style={{ color: '#a0a8c8' }}>{report.reviewedBy?.name}</strong>
                            {report.reviewedAt ? ` on ${new Date(report.reviewedAt).toLocaleDateString('en-IN')}` : ''}
                          </p>
                        )}
                      </div>

                      {report.status === 'PENDING' && (
                        <div
                          style={{
                            display: 'flex',
                            gap: '8px',
                            alignItems: 'flex-start',
                          }}
                        >
                          <button
                            onClick={() => handleReview(report.id, 'approve')}
                            className="btn btn-danger btn-sm"
                          >
                            ✅ Approve & Hide Item
                          </button>
                          <button
                            onClick={() => handleReview(report.id, 'dismiss')}
                            className="btn btn-ghost btn-sm"
                          >
                            ❌ Dismiss
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}

              {reports.length === 0 && (
                <div className="empty-state">
                  <span className="emoji">🚨</span>
                  <h3>No reports</h3>
                  <p>All clear! No reports at this time.</p>
                </div>
              )}
            </div>
          )}
        </>
      )}

      {activeTab === 'disputes' && (
        <>
          {loading ? (
            <div className="loading-wrap">
              <div className="spinner" />
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {disputes.map((dispute) => {
                const statusStyle =
                  STATUS_COLORS[dispute.status] || STATUS_COLORS.PENDING;
                const raisedByBuyer = dispute.raisedBy === dispute.buyerId;
                return (
                  <div
                    key={dispute.id}
                    style={{
                      background: '#0f1320',
                      border: '1px solid #1e2438',
                      borderRadius: '12px',
                      padding: '16px',
                      cursor: 'pointer',
                    }}
                    onClick={() => setSelectedDispute(dispute)}
                  >
                    <div
                      style={{
                        display: 'flex',
                        gap: '14px',
                        justifyContent: 'space-between',
                        flexWrap: 'wrap',
                      }}
                    >
                      <div>
                        <div
                          style={{
                            display: 'flex',
                            gap: '10px',
                            alignItems: 'center',
                            marginBottom: '6px',
                          }}
                        >
                          <span
                            style={{
                              background: 'rgba(59, 130, 246, 0.1)',
                              color: '#3b82f6',
                              padding: '2px 8px',
                              borderRadius: '6px',
                              fontSize: '0.72rem',
                              fontWeight: 700,
                            }}
                          >
                            Order #{dispute.id}
                          </span>
                          <span
                            style={{
                              background: statusStyle.bg,
                              color: statusStyle.color,
                              padding: '2px 8px',
                              borderRadius: '6px',
                              fontSize: '0.72rem',
                              fontWeight: 700,
                            }}
                          >
                            {dispute.status}
                          </span>
                        </div>
                        <p
                          style={{
                            color: '#e8eaf6',
                            fontWeight: 700,
                            marginBottom: '4px',
                            fontSize: '0.92rem',
                          }}
                        >
                          💰 ₹{dispute.amount}
                        </p>
                        <p style={{ color: '#5a6285', fontSize: '0.8rem' }}>
                          Reason:{' '}
                          <strong style={{ color: '#a0a8c8' }}>
                            {dispute.disputeReason || dispute.reason || 'Not provided'}
                          </strong>
                        </p>
                        <p style={{ color: '#5a6285', fontSize: '0.8rem' }}>
                          Raised by: {raisedByBuyer ? '👤 Buyer' : '👥 Seller'}
                        </p>
                      </div>

                      {dispute.status === 'DISPUTED' && (
                        <div
                          style={{
                            display: 'flex',
                            gap: '8px',
                            alignItems: 'flex-start',
                          }}
                        >
                          <button
                            onClick={(event) => {
                              event.stopPropagation();
                              handleResolveDispute(dispute.id, 'approve');
                            }}
                            className="btn btn-success btn-sm"
                          >
                            ✅ Approve (Refund)
                          </button>
                          <button
                            onClick={(event) => {
                              event.stopPropagation();
                              handleResolveDispute(dispute.id, 'reject');
                            }}
                            className="btn btn-ghost btn-sm"
                          >
                            ❌ Reject (Release)
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}

              {disputes.length === 0 && (
                <div className="empty-state">
                  <span className="emoji">⚖️</span>
                  <h3>No disputes</h3>
                  <p>All transactions are proceeding smoothly!</p>
                </div>
              )}
            </div>
          )}

          {selectedDispute && (
            <div
              style={{
                position: 'fixed',
                inset: 0,
                background: 'rgba(0,0,0,0.7)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                zIndex: 1000,
              }}
              onClick={() => setSelectedDispute(null)}
            >
              <div
                style={{
                  background: '#0f1320',
                  border: '1px solid #1e2438',
                  borderRadius: '14px',
                  padding: '24px',
                  maxWidth: '500px',
                  width: '90%',
                }}
                onClick={(event) => event.stopPropagation()}
              >
                <h2 style={{ color: '#e8eaf6', marginBottom: '16px' }}>
                  Dispute Details - Order #{selectedDispute.id}
                </h2>

                <div
                  style={{
                    background: '#1a1f2e',
                    borderRadius: '8px',
                    padding: '14px',
                    marginBottom: '16px',
                    fontSize: '0.88rem',
                    color: '#a0a8c8',
                    lineHeight: '1.6',
                  }}
                >
                  <p>
                    <strong>Amount:</strong> ₹{selectedDispute.amount}
                  </p>
                  <p>
                    <strong>Status:</strong> {selectedDispute.status}
                  </p>
                  <p>
                    <strong>Reason:</strong>{' '}
                    {selectedDispute.disputeReason || selectedDispute.reason || 'Not provided'}
                  </p>
                  <p>
                    <strong>Description:</strong>{' '}
                    {selectedDispute.disputeDescription ||
                      selectedDispute.description ||
                      'No extra description'}
                  </p>
                  <p>
                    <strong>Raised by:</strong>{' '}
                    {selectedDispute.raisedBy === selectedDispute.buyerId
                      ? 'Buyer'
                      : 'Seller'}
                  </p>
                </div>

                {selectedDispute.status === 'DISPUTED' ? (
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button
                      onClick={() => handleResolveDispute(selectedDispute.id, 'approve')}
                      className="btn btn-success"
                      style={{ flex: 1 }}
                    >
                      ✅ Approve - Issue Refund
                    </button>
                    <button
                      onClick={() => handleResolveDispute(selectedDispute.id, 'reject')}
                      className="btn btn-ghost"
                      style={{ flex: 1 }}
                    >
                      ❌ Reject - Release Payment
                    </button>
                  </div>
                ) : (
                  <button
                    onClick={() => setSelectedDispute(null)}
                    className="btn btn-ghost"
                    style={{ width: '100%' }}
                  >
                    Close
                  </button>
                )}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
