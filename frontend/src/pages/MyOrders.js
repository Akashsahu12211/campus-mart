import React, { useCallback, useEffect, useState } from 'react';
import { getBuyerOrders, getSellerOrders, getOrderTimeline, confirmDelivery, cancelOrder } from '../api/api';
import { useAuth } from '../App';
import '../styles/MyOrders.css';

const STATUS_CONFIG_BUYER = {
  CREATED:     { label: 'Pending Payment', color: '#64748b', icon: '⏳', bg: 'rgba(100,116,139,0.1)' },
  PAID:        { label: 'Pending Delivery', color: '#f59e0b', icon: '📦', bg: 'rgba(245,158,11,0.1)' },
  ESCROW_HOLD: { label: 'Held in Escrow', color: '#a89dff', icon: '🔒', bg: 'rgba(91,75,255,0.1)' },
  RELEASED:    { label: 'Completed', color: '#22c55e', icon: '✅', bg: 'rgba(34,197,94,0.1)' },
  DISPUTED:    { label: 'Disputed', color: '#f59e0b', icon: '⚠️', bg: 'rgba(245,158,11,0.1)' },
  FAILED:      { label: 'Payment Failed', color: '#ef4444', icon: '❌', bg: 'rgba(239,68,68,0.1)' },
  CANCELLED:   { label: 'Cancelled', color: '#ef4444', icon: '✕', bg: 'rgba(239,68,68,0.1)' },
  REFUNDED:    { label: 'Refunded', color: '#3b82f6', icon: '↩️', bg: 'rgba(59,130,246,0.1)' },
};

const STATUS_CONFIG_SELLER = {
  CREATED:     { label: 'Awaiting Payment', color: '#64748b', icon: '⏳', bg: 'rgba(100,116,139,0.1)' },
  PAID:        { label: 'Ready to Ship', color: '#f59e0b', icon: '📦', bg: 'rgba(245,158,11,0.1)' },
  ESCROW_HOLD: { label: 'Held in Escrow', color: '#a89dff', icon: '🔒', bg: 'rgba(91,75,255,0.1)' },
  RELEASED:    { label: 'Funds Released', color: '#22c55e', icon: '✅', bg: 'rgba(34,197,94,0.1)' },
  DISPUTED:    { label: 'Under Dispute', color: '#f59e0b', icon: '⚠️', bg: 'rgba(245,158,11,0.1)' },
  FAILED:      { label: 'Payment Failed', color: '#ef4444', icon: '❌', bg: 'rgba(239,68,68,0.1)' },
  CANCELLED:   { label: 'Cancelled', color: '#ef4444', icon: '✕', bg: 'rgba(239,68,68,0.1)' },
  REFUNDED:    { label: 'Refunded', color: '#3b82f6', icon: '↩️', bg: 'rgba(59,130,246,0.1)' },
};

export default function MyOrders() {
  const { user } = useAuth();
  const [view, setView] = useState('buyer'); // 'buyer' or 'seller'
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [expandedOrderId, setExpandedOrderId] = useState(null);
  const [timeline, setTimeline] = useState({});
  const [message, setMessage] = useState('');

  const loadOrders = useCallback(async () => {
    if (!user?.id) return;
    setLoading(true);
    try {
      let res;
      if (view === 'buyer') {
        res = await getBuyerOrders(user.id);
      } else {
        res = await getSellerOrders(user.id);
      }
      setOrders(res.data);
      setFilter('all');
      setExpandedOrderId(null);
    } catch (err) {
      console.error('Failed to load orders', err);
    } finally {
      setLoading(false);
    }
  }, [user, view]);

  useEffect(() => {
    if (!user?.id) return;
    loadOrders();
  }, [user?.id, loadOrders]);

  const loadTimeline = async (orderId) => {
    if (timeline[orderId]) return;
    try {
      const res = await getOrderTimeline(orderId);
      setTimeline(prev => ({ ...prev, [orderId]: res.data }));
    } catch (err) {
      console.error('Failed to load timeline', err);
    }
  };

  const handleConfirmDelivery = async (orderId) => {
    try {
      const res = await confirmDelivery(orderId);
      setMessage(res.data.message);
      setOrders(prev => prev.map(o =>
        o.id === orderId ? { ...o, status: 'RELEASED' } : o));
      setTimeout(() => setMessage(''), 3000);
    } catch (err) {
      setMessage(err.response?.data?.error || 'Failed to confirm delivery');
    }
  };

  const handleCancelOrder = async (orderId) => {
    try {
      const res = await cancelOrder(orderId);
      setMessage(res.data.message);
      setOrders(prev => prev.map(o =>
        o.id === orderId ? { ...o, status: 'CANCELLED' } : o));
      setTimeout(() => setMessage(''), 3000);
    } catch (err) {
      setMessage(err.response?.data?.error || 'Failed to cancel order');
    }
  };

  const formatDate = (timestamp) => {
    return new Date(timestamp).toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getGrossAmount = (order) => Number(order?.amount || 0);
  const getPlatformFee = (order) => Number(order?.platformFeeAmount || 0);
  const getSellerNet = (order) => Number((order?.sellerNetAmount ?? order?.amount) || 0);

  // Filter orders
  const filteredOrders = orders.filter(order => {
    if (filter === 'all') return true;
    if (filter === 'success') return order.status === 'RELEASED';
    if (filter === 'pending') return ['PAID', 'ESCROW_HOLD'].includes(order.status);
    if (filter === 'failed') return ['FAILED', 'DISPUTED'].includes(order.status);
    if (filter === 'cancelled') return order.status === 'CANCELLED';
    return true;
  });

  // Calculate stats
  const stats = {
    total: orders.filter(o => o.status === 'RELEASED').length,
    success: orders.filter(o => o.status === 'RELEASED').length,
    pending: orders.filter(o => ['PAID', 'ESCROW_HOLD'].includes(o.status)).length,
    failed: orders.filter(o => ['FAILED', 'DISPUTED'].includes(o.status)).length,
    cancelled: orders.filter(o => o.status === 'CANCELLED').length,
    totalAmount: orders.filter(o => o.status === 'RELEASED').reduce((sum, o) => sum + (view === 'seller' ? getSellerNet(o) : getGrossAmount(o)), 0),
  };

  const STATUS_CONFIG = view === 'buyer' ? STATUS_CONFIG_BUYER : STATUS_CONFIG_SELLER;

  if (loading) {
    return (
      <div className="orders-page">
        <div className="loading-container">
          <div className="spinner"></div>
          <p>Loading your orders...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="orders-page">
      {/* View Toggle Tabs */}
      <div className="view-tabs">
        <button
          className={`view-tab ${view === 'buyer' ? 'active' : ''}`}
          onClick={() => setView('buyer')}
        >
          <span className="tab-icon">🛍️</span>
          My Purchases
        </button>
        <button
          className={`view-tab ${view === 'seller' ? 'active' : ''}`}
          onClick={() => setView('seller')}
        >
          <span className="tab-icon">📤</span>
          My Sales
        </button>
      </div>

      {/* Header */}
      <div className="orders-header">
        <div>
          <h1>{view === 'buyer' ? 'My Purchases 🛍️' : 'My Sales 📤'}</h1>
          <p className="subtitle">
            {view === 'buyer' 
              ? 'Track and manage all your purchases'
              : 'Track and manage all your sales'}
          </p>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon" style={{ background: 'rgba(91,75,255,0.1)', color: '#5b4bff' }}>
            📊
          </div>
          <div className="stat-content">
            <p className="stat-label">Total {view === 'buyer' ? 'Orders' : 'Sales'}</p>
            <p className="stat-value">{stats.total}</p>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon" style={{ background: 'rgba(34,197,94,0.1)', color: '#22c55e' }}>
            ✅
          </div>
          <div className="stat-content">
            <p className="stat-label">{view === 'buyer' ? 'Received' : 'Completed'}</p>
            <p className="stat-value">{stats.success}</p>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon" style={{ background: 'rgba(100,116,139,0.1)', color: '#64748b' }}>
            📦
          </div>
          <div className="stat-content">
            <p className="stat-label">Pending</p>
            <p className="stat-value">{stats.pending}</p>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon" style={{ background: 'rgba(245,158,11,0.1)', color: '#f59e0b' }}>
            💰
          </div>
          <div className="stat-content">
            <p className="stat-label">{view === 'buyer' ? 'Total Spent' : 'Total Earnings'}</p>
            <p className="stat-value">₹{stats.totalAmount.toLocaleString('en-IN')}</p>
          </div>
        </div>
      </div>

      {/* Success Message */}
      {message && (
        <div className="success-message">
          <span>✅</span>
          <p>{message}</p>
        </div>
      )}

      {/* Filter Tabs */}
      <div className="filter-tabs">
        {[
          { id: 'all', label: '🔵 All Orders', count: stats.total },
          { id: 'success', label: '✅ Completed', count: stats.success },
          { id: 'pending', label: '� Pending', count: stats.pending },
          { id: 'failed', label: '❌ Failed', count: stats.failed },
          { id: 'cancelled', label: '✕ Cancelled', count: stats.cancelled },
        ].map(tab => (
          <button
            key={tab.id}
            className={`filter-tab ${filter === tab.id ? 'active' : ''}`}
            onClick={() => setFilter(tab.id)}
          >
            {tab.label}
            {tab.count > 0 && <span className="count-badge">{tab.count}</span>}
          </button>
        ))}
      </div>

      {/* Orders List */}
      <div className="orders-list">
        {filteredOrders.length === 0 ? (
          <div className="empty-state">
            <span className="empty-icon">
              {view === 'buyer' ? '🛒' : '📭'}
            </span>
            <h3>
              {view === 'buyer' 
                ? (filter === 'cancelled' ? 'No cancelled orders' :
                   filter === 'success' ? 'No completed orders' :
                   filter === 'pending' ? 'No pending orders' :
                   filter === 'failed' ? 'No failed orders' :
                   'No orders')
                : (filter === 'cancelled' ? 'No cancelled sales' :
                   filter === 'success' ? 'No completed sales' :
                   filter === 'pending' ? 'No pending sales' :
                   filter === 'failed' ? 'No failed sales' :
                   'No sales')}
            </h3>
            <p>
              {view === 'buyer'
                ? (filter === 'cancelled' ? 'You have not cancelled any orders' :
                   filter === 'success' ? 'Complete a purchase to see it here' :
                   filter === 'pending' ? 'Start shopping to see pending orders' :
                   filter === 'failed' ? 'No failed transactions' :
                   'Your orders will appear here once you make a purchase')
                : (filter === 'cancelled' ? 'You have not cancelled any sales' :
                   filter === 'success' ? 'Sales will appear here when completed' :
                   filter === 'pending' ? 'Start listing items to see pending sales' :
                   filter === 'failed' ? 'No failed sales' :
                   'Your sales will appear here once someone buys your items')}
            </p>
          </div>
        ) : (
          filteredOrders.map(order => {
            const status = STATUS_CONFIG[order.status] || STATUS_CONFIG.CREATED;
            const isExpanded = expandedOrderId === order.id;

            return (
              <div key={order.id} className="order-card">
                {/* Order Card Header */}
                <div
                  className={`order-header ${isExpanded ? 'expanded' : ''}`}
                  onClick={() => {
                    const nextExpanded = isExpanded ? null : order.id;
                    setExpandedOrderId(nextExpanded);
                    if (nextExpanded) loadTimeline(order.id);
                  }}
                >
                  {/* Product Image */}
                  <div className="order-image">
                    {order.item?.images && order.item.images.length > 0 && order.item.images[0] ? (
                      <img 
                        src={order.item.images[0]} 
                        alt={order.item.title}
                        onError={(e) => {
                          e.target.style.display = 'none';
                          e.target.nextSibling.style.display = 'flex';
                        }}
                      />
                    ) : null}
                    <div 
                      className="image-placeholder"
                      style={{
                        display: (!order.item?.images || order.item.images.length === 0 || !order.item.images[0]) ? 'flex' : 'none'
                      }}
                    >
                      {order.item?.category === 'Electronics' ? '📱' : 
                       order.item?.category === 'Jewelry' ? '💍' :
                       order.item?.category === 'Books' ? '📚' :
                       order.item?.category === 'Clothing' ? '👕' : '📦'}
                    </div>
                  </div>

                  {/* Order Info */}
                  <div className="order-info">
                    <div className="order-title">
                      <h3>{order.item?.title || 'Unknown Item'}</h3>
                      <span className="order-id">#{order.id}</span>
                    </div>
                    <p className="order-meta">
                      {view === 'buyer' ? 'Seller' : 'Buyer'}: 
                      <strong>
                        {view === 'buyer' 
                          ? order.seller?.name 
                          : order.buyer?.name}
                      </strong>
                    </p>
                    <p className="order-date">
                      {formatDate(order.createdAt)}
                    </p>
                  </div>

                  {/* Amount and Status */}
                  <div className="order-right">
                    <p className="order-amount">₹{(view === 'seller' ? getSellerNet(order) : getGrossAmount(order)).toLocaleString('en-IN')}</p>
                    <span
                      className="status-badge"
                      style={{ background: status.bg, color: status.color }}
                    >
                      {status.icon} {status.label}
                    </span>
                  </div>

                  {/* Expand Icon */}
                  <div className={`expand-icon ${isExpanded ? 'rotated' : ''}`}>
                    ▼
                  </div>
                </div>

                {/* Expanded Details */}
                {isExpanded && (
                  <div className="order-details">
                    {/* Description */}
                    {order.item?.description && (
                      <div className="detail-section">
                        <h4>📝 Item Description</h4>
                        <p className="description">{order.item.description}</p>
                      </div>
                    )}

                    {/* Escrow/Status Info */}
                    {order.status === 'ESCROW_HOLD' && (
                      <div className="detail-section escrow-section">
                        <h4>🔒 Escrow Protection Active</h4>
                        <p>Your payment is securely held in escrow. Confirm delivery when you receive the item.</p>
                        <button
                          className="btn-confirm"
                          onClick={() => handleConfirmDelivery(order.id)}
                        >
                          ✅ Confirm Delivery
                        </button>
                      </div>
                    )}

                    {order.status === 'PAID' && (
                      <div className="detail-section escrow-section">
                        <h4>📦 Payment Received - Awaiting Delivery</h4>
                        <p>Your payment has been confirmed. Please wait for the seller to deliver the item.</p>
                      </div>
                    )}

                    {order.status === 'CREATED' && (
                      <div className="detail-section escrow-section" style={{background: 'rgba(245,158,11,0.08)', borderColor: 'rgba(245,158,11,0.2)'}}>
                        <h4>⏳ Pending Payment</h4>
                        <p>Complete the payment to reserve this item. You can return to checkout anytime.</p>
                        <button
                          className="btn-cancel"
                          onClick={() => handleCancelOrder(order.id)}
                          style={{ marginTop: '10px', backgroundColor: '#ef4444', color: 'white' }}
                        >
                          ✕ Cancel Order
                        </button>
                      </div>
                    )}

                    {/* Timeline */}
                    {expandedOrderId === order.id && (
                      <div className="detail-section">
                        <h4>⏱️ Order Timeline</h4>
                        {timeline[order.id] ? (
                          <div className="timeline">
                            {timeline[order.id].map((event, idx) => (
                              <div key={idx} className="timeline-event">
                                <div className="timeline-marker">{event.eventType === 'CREATED' ? '📦' : '✅'}</div>
                                <div className="timeline-content">
                                  <p className="event-type">{event.eventType}</p>
                                  <p className="event-time">{formatDate(event.createdAt)}</p>
                                  {event.description && <p className="event-desc">{event.description}</p>}
                                </div>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <p style={{ color: '#64748b' }}>Loading timeline...</p>
                        )}
                      </div>
                    )}

                    {/* Additional Info */}
                    {(order.platformFeeAmount || order.sellerNetAmount) && (
                      <div className="detail-section" style={{ background: 'rgba(91,75,255,0.08)', border: '1px solid rgba(91,75,255,0.18)', borderRadius: 12, padding: 14 }}>
                        <h4>{view === 'seller' ? '💸 Monetization Breakdown' : '🛡️ Marketplace Protection'}</h4>
                        <div className="detail-row">
                          <span>Order gross</span>
                          <span>₹{getGrossAmount(order).toLocaleString('en-IN')}</span>
                        </div>
                        <div className="detail-row">
                          <span>Platform fee{order.platformFeePercent ? ` (${Number(order.platformFeePercent).toFixed(2)}%)` : ''}</span>
                          <span>₹{getPlatformFee(order).toLocaleString('en-IN')}</span>
                        </div>
                        <div className="detail-row">
                          <span>{view === 'seller' ? 'Seller net payout' : 'Seller net after fee'}</span>
                          <span>₹{getSellerNet(order).toLocaleString('en-IN')}</span>
                        </div>
                        {order.sellerSubscriptionCode && (
                          <div className="detail-row">
                            <span>Seller plan</span>
                            <span>{order.sellerSubscriptionCode}</span>
                          </div>
                        )}
                      </div>
                    )}
                    <div className="detail-footer">
                      <div className="detail-row">
                        <span>Order ID:</span>
                        <span className="mono">{order.razorpayOrderId}</span>
                      </div>
                      <div className="detail-row">
                        <span>Payment Status:</span>
                        <span>{order.status}</span>
                      </div>
                      {order.releaseDeadline && (
                        <div className="detail-row">
                          <span>Funds Release:</span>
                          <span>{formatDate(order.releaseDeadline)}</span>
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
