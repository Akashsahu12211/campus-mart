import React, { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  acceptOffer,
  boostMonetizedListing,
  deleteItem,
  getInbox,
  getItemsBySeller,
  getMonetizationSummary,
  getOffersForSeller,
  getReservedItemsBySeller,
  markAsSold,
  rejectOffer,
  renewItem,
  unreserveItem,
} from '../api/api';
import { useAuth } from '../App';
import WebSocketService from '../services/websocket';

const CONDITION_LABELS = { 'NEW':'New','LIKE_NEW':'Like New','GOOD':'Good','FAIR':'Fair','POOR':'Poor' };
const STATUS_COLORS = {
  'AVAILABLE': { bg: 'rgba(34,197,94,0.1)', color: '#22c55e' },
  'SOLD':      { bg: 'rgba(239,68,68,0.1)',  color: '#ef4444' },
  'RESERVED':  { bg: 'rgba(245,158,11,0.1)', color: '#f59e0b' },
  'EXPIRED':   { bg: 'rgba(59,130,246,0.1)', color: '#3b82f6' },
};

export default function MyItems() {
  const { user }    = useAuth();
  const navigate    = useNavigate();
  const [items,     setItems]   = useState([]);
  const [reservedItems, setReservedItems] = useState([]);
  const [inbox,     setInbox]   = useState([]);
  const [offers,    setOffers]  = useState([]);
  const [loading,   setLoading] = useState(true);
  const [msg,       setMsg]     = useState({ type: '', text: '' });
  const [filter,    setFilter]  = useState('ALL');
  const [tab,       setTab]     = useState('listings'); // 'listings' | 'reserved' | 'chats' | 'offers'
  const [monetization, setMonetization] = useState(null);
  const [boostingItemId, setBoostingItemId] = useState(null);

  const fetchMyItems = () => {
    getItemsBySeller(user.id)
      .then(r => setItems(r.data))
      .catch(() => setItems([]));
  };

  const fetchReservedItems = () => {
    getReservedItemsBySeller(user.id)
      .then(r => setReservedItems(r.data))
      .catch(() => setReservedItems([]));
  };

  const fetchInbox = () => {
    if (!user?.id) {
      console.warn('⚠️ User not loaded yet');
      return;
    }
    getInbox(user.id)
      .then(r => setInbox(r.data || []))
      .catch(e => {
        console.error('❌ Failed to fetch inbox:', e.response?.status, e.message);
        setInbox([]);
      });
  };

  const fetchOffers = () => {
    getOffersForSeller(user.id)
      .then(r => setOffers(r.data || []))
      .catch(() => setOffers([]));
  };

  const fetchMonetization = () => {
    getMonetizationSummary(user.id)
      .then(r => setMonetization(r.data))
      .catch(() => setMonetization(null));
  };

  useEffect(() => { 
    if (!user?.id) return; // Don't load until user is authenticated
    
    setLoading(true);
    fetchMyItems();
    fetchReservedItems();
    fetchInbox();
    fetchOffers();
    fetchMonetization();
    setLoading(false);
  }, [user?.id]); // eslint-disable-line

  // Real-time WebSocket updates for Chats tab
  useEffect(() => {
    if (!user?.id) return;
    
    const handleMessage = (msg) => {
      console.log('💬 MyItems - New message received:', msg);
      if (msg.type === 'CHAT') {
        // Refetch inbox to show new conversation or update last message
        fetchInbox();
      }
    };

    WebSocketService.addHandler(handleMessage);

    return () => {
      WebSocketService.removeHandler(handleMessage);
    };
  }, [user?.id]); // eslint-disable-line

  // Periodic refresh for Chats tab
  useEffect(() => {
    if (tab !== 'chats' || !user?.id) return;
    
    console.log('💬 Chats tab active - fetching inbox');
    fetchInbox(); // Fetch immediately when tab becomes active
    
    // Then fetch every 3 seconds while tab is active
    const interval = setInterval(fetchInbox, 3000);
    return () => clearInterval(interval);
  }, [tab, user?.id]); // eslint-disable-line

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this listing permanently?')) return;
    try { await deleteItem(id); setMsg({ type: 'success', text: '🗑️ Item deleted.' }); fetchMyItems(); }
    catch { setMsg({ type: 'error', text: 'Error deleting item.' }); }
  };

  const handleMarkSold = async (id) => {
    try { await markAsSold(id); setMsg({ type: 'success', text: '✅ Marked as sold!' }); fetchMyItems(); }
    catch { setMsg({ type: 'error', text: 'Error updating item.' }); }
  };

  const handleRenew = async (id) => {
    try {
      await renewItem(id);
      setMsg({ type: 'success', text: 'Listing renewed successfully.' });
      fetchMyItems();
    } catch {
      setMsg({ type: 'error', text: 'Error renewing item.' });
    }
  };

  const handleBoost = async (id) => {
    setBoostingItemId(id);
    try {
      const res = await boostMonetizedListing(id);
      setMsg({ type: 'success', text: res.data?.message || 'Listing boosted successfully.' });
      fetchMyItems();
      fetchMonetization();
    } catch (err) {
      setMsg({ type: 'error', text: err.response?.data?.error || 'Could not boost listing.' });
    } finally {
      setBoostingItemId(null);
    }
  };

  const handleCancelReservation = async (id) => {
    if (!window.confirm('Cancel this reservation?')) return;
    try { 
      await unreserveItem(id); 
      setMsg({ type: 'success', text: '✅ Reservation cancelled.' }); 
      fetchReservedItems(); 
    }
    catch { setMsg({ type: 'error', text: 'Error cancelling reservation.' }); }
  };

  const handleAcceptOffer = async (offerId) => {
    try {
      await acceptOffer(offerId);
      setMsg({ type: 'success', text: '✅ Offer accepted!' });
      fetchOffers();
    } catch { setMsg({ type: 'error', text: 'Error accepting offer.' }); }
  };

  const handleRejectOffer = async (offerId) => {
    if (!window.confirm('Reject this offer?')) return;
    try {
      await rejectOffer(offerId);
      setMsg({ type: 'success', text: '❌ Offer rejected.' });
      fetchOffers();
    } catch { setMsg({ type: 'error', text: 'Error rejecting offer.' }); }
  };

  const filtered = filter === 'ALL' ? items : items.filter(i => i.status === filter);
  const formatCurrency = (value) => `INR ${Number(value || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;

  const stats = {
    total:     items.length,
    available: items.filter(i => i.status === 'AVAILABLE').length,
    sold:      items.filter(i => i.status === 'SOLD').length,
    reserved:  items.filter(i => i.status === 'RESERVED').length,
    expired:   items.filter(i => i.status === 'EXPIRED').length,
  };

  return (
    <div className="page">
      {/* Header */}


<div
  style={{
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '24px',
    gap: '16px',
    flexWrap: 'nowrap'
  }}
>
  <div style={{ flex: '0 1 auto' }}>
    <h1 style={{ fontFamily: "'Syne',sans-serif", fontSize: '1.9rem', margin: 0 }}>
      My Listings
    </h1>
    <p style={{ color: '#5a6285', fontSize: '0.85rem', marginTop: '4px' }}>
      Manage your items, chats, and offers
    </p>
  </div>

  <Link
    to="/add-item"
    className="btn btn-primary btn-sm"
    style={{
      width: 'fit-content',
      minWidth: 'unset',
      flex: '0 0 auto',
      alignSelf: 'center',
      padding: '10px 18px',
      whiteSpace: 'nowrap'
    }}
  >
    + List New Item
  </Link>
</div>




      {/* Tabs */}
      <div style={{ display: 'flex', gap: '8px', marginBottom: '20px', borderBottom: '1px solid #1e2438', paddingBottom: '12px', flexWrap: 'wrap' }}>
        {[
          { key: 'listings', emoji: '📦', label: 'My Listings', count: stats.total },
          { key: 'reserved', emoji: '🔒', label: 'Reserved By Others', count: reservedItems.length },
          { key: 'chats', emoji: '💬', label: 'Chats', count: inbox.length },
          { key: 'offers', emoji: '💰', label: 'Offers Received', count: offers.length },
        ].map(t => (
          <button key={t.key}
            onClick={() => { setTab(t.key); setFilter('ALL'); }}
            style={{
              padding: '8px 16px', borderRadius: '8px 8px 0 0', cursor: 'pointer',
              border: 'none',
              background: tab === t.key ? '#5b4bff' : 'transparent',
              color: tab === t.key ? '#fff' : '#5a6285',
              fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700,
              fontSize: '0.9rem', transition: 'all 0.15s', whiteSpace: 'nowrap',
            }}>
            {t.emoji} {t.label} {t.count > 0 && <span style={{ marginLeft: '4px', opacity: 0.8 }}>({t.count})</span>}
          </button>
        ))}
      </div>

      {msg.text && (
        <div className={`alert alert-${msg.type === 'success' ? 'success' : 'error'}`} style={{ marginBottom: '16px' }}>
          {msg.text}
        </div>
      )}

      {/* ═══ LISTINGS TAB ═══ */}
      {tab === 'listings' && (
      <>
      <div className="card" style={{ marginBottom: '16px', padding: '16px 18px', background: 'linear-gradient(135deg, rgba(91,75,255,0.12), rgba(0,212,170,0.08))', border: '1px solid rgba(91,75,255,0.22)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: '16px', flexWrap: 'wrap', alignItems: 'center' }}>
          <div>
            <h3 style={{ margin: 0, fontFamily: "'Syne',sans-serif", fontSize: '1rem', color: '#E8EAF6' }}>
              Seller Plan: {monetization?.activeSubscriptionCode || user?.activeSubscriptionCode || 'FREE'}
            </h3>
            <p style={{ color: '#A0A8C8', fontSize: '0.82rem', margin: '6px 0 0' }}>
              Fee {Number(monetization?.commissionPercent ?? user?.currentCommissionPercent ?? 7).toFixed(2)}% · Boost credits {monetization?.availableBoostCredits ?? user?.availableBoostCredits ?? 0} · Active boosts {monetization?.activeBoostedListings ?? 0}
            </p>
          </div>
          <div style={{ textAlign: 'right', minWidth: '190px' }}>
            <div style={{ color: '#C8F5EA', fontSize: '0.78rem', fontWeight: 700 }}>
              Released seller net: {formatCurrency(monetization?.releasedSellerNet)}
            </div>
            <div style={{ color: '#D9D5FF', fontSize: '0.76rem', marginTop: '4px' }}>
              Pending platform fees: {formatCurrency(monetization?.pendingPlatformFees)}
            </div>
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', gap: '12px', marginBottom: '20px', flexWrap: 'wrap' }}>
        {[
          { label: 'Total', val: stats.total, key: 'ALL' },
          { label: 'Active', val: stats.available, key: 'AVAILABLE' },
          { label: 'Sold', val: stats.sold, key: 'SOLD' },
          { label: 'Reserved', val: stats.reserved, key: 'RESERVED' },
          { label: 'Expired', val: stats.expired, key: 'EXPIRED' },
        ].map(s => (
          <button key={s.key} onClick={() => setFilter(s.key)}
            style={{
              padding: '10px 18px', borderRadius: '10px', cursor: 'pointer',
              border: `1.5px solid ${filter === s.key ? '#5b4bff' : '#1e2438'}`,
              background: filter === s.key ? 'rgba(91,75,255,0.1)' : '#0f1320',
              color: filter === s.key ? '#a89dff' : '#5a6285',
              fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700,
              fontSize: '0.85rem', transition: 'all 0.15s',
            }}>
            {s.label} <span style={{ marginLeft: '4px', opacity: 0.8 }}>{s.val}</span>
          </button>
        ))}
      </div>

      {msg.text && (
        <div className={`alert alert-${msg.type === 'success' ? 'success' : 'error'}`} style={{ marginBottom: '16px' }}>
          {msg.text}
        </div>
      )}

      {loading ? (
          <div className="loading-wrap"><div className="spinner" /></div>
        ) : filtered.length === 0 ? (
          <div className="empty-state">
            <span className="emoji">📦</span>
            <h3>{filter === 'ALL' ? "You haven't listed anything yet" : `No ${filter.toLowerCase()} items`}</h3>
            {filter === 'ALL' && (
              <Link
  to="/add-item"
  className="btn btn-primary btn-sm"
  style={{ width: 'auto', alignSelf: 'center', flexShrink: 0 }}
>
  + List New Item
</Link>
            )}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {filtered.map(item => {
              const statusStyle = STATUS_COLORS[item.status] || STATUS_COLORS['AVAILABLE'];
              const firstImg = item.imageUrls?.[0];
              return (
                <div key={item.id} className="card" style={{ display: 'flex', alignItems: 'center', padding: '14px 18px', gap: '14px', flexWrap: 'wrap', overflow: 'visible' }}>
                  {/* Thumbnail */}
                  <div style={{
                    width: '60px', height: '60px', borderRadius: '10px', flexShrink: 0,
                    background: firstImg ? 'transparent' : '#141929',
                    border: '1px solid #1e2438', overflow: 'hidden',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.6rem',
                  }}>
                    {firstImg
                      ? <img src={firstImg} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} onError={e => { e.target.style.display = 'none'; }} />
                      : '📦'
                    }
                  </div>

                  {/* Info */}
                  <div style={{ flex: 1, minWidth: '180px' }}>
                    <Link to={`/item/${item.id}`} style={{ textDecoration: 'none' }}>
                      <h3 style={{ fontFamily: "'Syne',sans-serif", fontSize: '0.95rem', color: '#e8eaf6', marginBottom: '2px' }}>
                        {item.title}
                      </h3>
                    </Link>
                    <p style={{ color: '#5a6285', fontSize: '0.78rem' }}>
                      {item.category?.name}
                      {item.condition ? ` · ${CONDITION_LABELS[item.condition]}` : ''}
                      {item.imageUrls?.length > 0 ? ` · 📷 ${item.imageUrls.length}` : ''}
                      {` · 👁 ${item.viewCount || 0}`}
                    </p>
                  </div>

                  {/* Price */}
                  <div style={{ fontWeight: 800, fontSize: '1.05rem', color: '#5b4bff', flexShrink: 0 }}>
                    ₹{item.price?.toLocaleString('en-IN')}
                    {item.negotiable && <span style={{ fontSize: '0.68rem', color: '#00d4aa', marginLeft: '4px' }}>nego</span>}
                  </div>

                  {/* Status */}
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', alignItems: 'flex-end', flexShrink: 0 }}>
                    <span style={{
                      padding: '3px 10px', borderRadius: '6px', fontSize: '0.72rem', fontWeight: 700,
                      background: statusStyle.bg, color: statusStyle.color, flexShrink: 0,
                    }}>
                      {item.status}
                    </span>
                    {item.boostActive && (
                      <span style={{
                        padding: '3px 10px',
                        borderRadius: '6px',
                        fontSize: '0.68rem',
                        fontWeight: 800,
                        background: 'rgba(239,68,68,0.12)',
                        color: '#EF4444',
                      }}>
                        BOOSTED
                      </span>
                    )}
                  </div>

                {/* Actions */}
                <div style={{ display: 'flex', gap: '6px', flexShrink: 0 }}>
                  <button onClick={() => navigate(`/edit-item/${item.id}`)} className="btn btn-ghost btn-sm">✏️</button>
                  <button onClick={() => navigate(`/item/${item.id}`)} className="btn btn-ghost btn-sm">👁️</button>
                  {item.status === 'EXPIRED' && (
                    <button onClick={() => handleRenew(item.id)} className="btn btn-secondary btn-sm">🔄 Renew</button>
                  )}
                  {item.status === 'AVAILABLE' && (
                    <button
                      onClick={() => handleBoost(item.id)}
                      className="btn btn-secondary btn-sm"
                      disabled={Boolean(boostingItemId) || item.boostActive || (monetization?.availableBoostCredits ?? 0) <= 0}
                      style={{ opacity: (Boolean(boostingItemId) || item.boostActive || (monetization?.availableBoostCredits ?? 0) <= 0) ? 0.65 : 1 }}
                    >
                      {item.boostActive ? 'ðŸ”¥ Boosted' : boostingItemId === item.id ? 'Boosting...' : 'ðŸ”¥ Boost'}
                    </button>
                  )}
                  {item.status === 'AVAILABLE' && (
                    <button onClick={() => handleMarkSold(item.id)} className="btn btn-success btn-sm">✅ Sold</button>
                  )}
                  <button onClick={() => handleDelete(item.id)} className="btn btn-danger btn-sm">🗑️</button>
                </div>
              </div>
            );
          })}
          </div>
        )}
      </>
      )}

      {/* RESERVED ITEMS TAB */}
      {tab === 'reserved' && (
      <>
        {reservedItems.length === 0 ? (
          <div className="empty-state">
            <span className="emoji">🔓</span>
            <h3>No items reserved by others yet</h3>
            <p style={{ marginTop: '8px', color: '#5a6285', fontSize: '0.9rem' }}>
              When someone reserves your listings, they'll appear here for management
            </p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {reservedItems.map(item => {
              const firstImg = item.imageUrls?.[0];
              const reserver = item.reservedByStudent;
              return (
                <div key={item.id} className="card" style={{ display: 'flex', alignItems: 'flex-start', padding: '16px 18px', gap: '16px', flexWrap: 'wrap', overflow: 'visible' }}>
                  {/* Thumbnail */}
                  <div style={{
                    width: '60px', height: '60px', borderRadius: '10px', flexShrink: 0,
                    background: firstImg ? 'transparent' : '#141929',
                    border: '1px solid #1e2438', overflow: 'hidden',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.6rem',
                  }}>
                    {firstImg
                      ? <img src={firstImg} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} onError={e => { e.target.style.display = 'none'; }} />
                      : '📦'
                    }
                  </div>

                  {/* Main Info */}
                  <div style={{ flex: 1, minWidth: '250px' }}>
                    <Link to={`/item/${item.id}`} style={{ textDecoration: 'none' }}>
                      <h3 style={{ fontFamily: "'Syne',sans-serif", fontSize: '0.95rem', color: '#e8eaf6', marginBottom: '4px' }}>
                        {item.title}
                      </h3>
                    </Link>
                    <p style={{ color: '#5a6285', fontSize: '0.78rem', marginBottom: '10px' }}>
                      {item.category?.name}
                      {item.condition ? ` · ${CONDITION_LABELS[item.condition]}` : ''}
                    </p>

                    {/* Reserver Card */}
                    {reserver && (
                      <div style={{
                        padding: '10px 12px', borderRadius: '8px',
                        background: 'rgba(91,75,255,0.1)', border: '1px solid rgba(91,75,255,0.3)',
                        display: 'flex', gap: '10px', alignItems: 'flex-start', marginBottom: '8px',
                      }}>
                        {/* Reserver Avatar */}
                        <div style={{
                          width: '40px', height: '40px', borderRadius: '50%', flexShrink: 0,
                          background: reserver.profilePic ? 'transparent' : '#1e2438',
                          border: '2px solid #5b4bff', overflow: 'hidden',
                          display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.2rem',
                        }}>
                          {reserver.profilePic
                            ? <img src={reserver.profilePic} alt={reserver.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} onError={e => { e.target.style.display = 'none'; }} />
                            : reserver.name?.[0]?.toUpperCase() || '👤'
                          }
                        </div>

                        {/* Reserver Details */}
                        <div style={{ flex: 1, minWidth: '150px' }}>
                          <p style={{ fontWeight: 700, color: '#e8eaf6', fontSize: '0.85rem', marginBottom: '2px' }}>
                            🔒 Reserved by <span style={{ color: '#a89dff' }}>{reserver.name}</span>
                          </p>
                          <p style={{ color: '#5a6285', fontSize: '0.75rem', marginBottom: '2px' }}>
                            📧 {reserver.email}
                          </p>
                          {reserver.phone && (
                            <p style={{ color: '#5a6285', fontSize: '0.75rem' }}>
                              📱 {reserver.phone}
                            </p>
                          )}
                        </div>

                        {/* Contact Button */}
                        <button
                          onClick={() => window.location.href = `mailto:${reserver.email}?subject=About your reservation for ${item.title}`}
                          style={{
                            padding: '6px 12px', borderRadius: '6px',
                            background: '#5b4bff', border: 'none', color: '#fff',
                            fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700,
                            fontSize: '0.75rem', cursor: 'pointer',
                            transition: 'all 0.15s', flexShrink: 0,
                          }}
                          onMouseEnter={e => e.target.style.background = '#7068ff'}
                          onMouseLeave={e => e.target.style.background = '#5b4bff'}
                        >
                          ✉️ Contact
                        </button>
                      </div>
                    )}
                  </div>

                  {/* Price */}
                  <div style={{ fontWeight: 800, fontSize: '1.05rem', color: '#5b4bff', flexShrink: 0 }}>
                    ₹{item.price?.toLocaleString('en-IN')}
                    {item.negotiable && <span style={{ fontSize: '0.68rem', color: '#00d4aa', marginLeft: '4px' }}>nego</span>}
                  </div>

                  {/* Status Badge */}
                  <span style={{
                    padding: '3px 10px', borderRadius: '6px', fontSize: '0.72rem', fontWeight: 700,
                    background: 'rgba(91,75,255,0.2)', color: '#a89dff', flexShrink: 0,
                  }}>
                    RESERVED
                  </span>

                  {/* Actions */}
                  <div style={{ display: 'flex', gap: '6px', flexShrink: 0 }}>
                    <button onClick={() => navigate(`/item/${item.id}`)} className="btn btn-ghost btn-sm">👁️ View</button>
                    <button onClick={() => handleCancelReservation(item.id)} className="btn btn-danger btn-sm">❌ Cancel</button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </>
      )}

      {/* ═══ CHATS TAB ═══ */}
      {tab === 'chats' && (
      <>
        {inbox.length === 0 ? (
          <div className="empty-state">
            <span className="emoji">💬</span>
            <h3>No active chats yet</h3>
            <p style={{ marginTop: '8px', color: '#5a6285', fontSize: '0.9rem' }}>
              Start conversations with buyers when they message you about your items
            </p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {inbox.map(conv => {
              const buyer = conv.otherUser;
              const lastMsg = conv.lastMessage;
              const item = conv.item;
              const unread = conv.unreadCount;
              return (
                <div key={buyer.id} className="card" style={{ display: 'flex', alignItems: 'center', padding: '14px 18px', gap: '14px', flexWrap: 'wrap', overflow: 'visible', cursor: 'pointer', transition: 'all 0.15s', border: unread > 0 ? '1.5px solid #5b4bff' : '1px solid #1e2438' }}
                  onMouseEnter={e => e.currentTarget.style.background = 'rgba(91,75,255,0.05)'}
                  onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                  onClick={() => navigate('/chat/room', { state: { otherUserId: buyer.id, otherUserName: buyer.name, otherUserPic: buyer.profilePic, itemId: item?.id, itemTitle: item?.title } })}>
                  
                  {/* Avatar */}
                  <div style={{
                    width: '48px', height: '48px', borderRadius: '50%', flexShrink: 0,
                    background: buyer.profilePic ? 'transparent' : '#1e2438',
                    border: '2px solid #5b4bff', overflow: 'hidden',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.1rem',
                  }}>
                    {buyer.profilePic
                      ? <img src={buyer.profilePic} alt={buyer.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} onError={e => { e.target.style.display = 'none'; }} />
                      : buyer.name?.[0]?.toUpperCase() || '👤'
                    }
                  </div>

                  {/* Info */}
                  <div style={{ flex: 1, minWidth: '200px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                      <h3 style={{ fontFamily: "'Syne',sans-serif", fontSize: '0.95rem', color: '#e8eaf6', margin: 0 }}>
                        {buyer.name}
                      </h3>
                      {unread > 0 && (
                        <span style={{
                          padding: '2px 6px', borderRadius: '4px', background: '#ef4444',
                          color: '#fff', fontSize: '0.7rem', fontWeight: 700,
                        }}>
                          {unread > 9 ? '9+' : unread}
                        </span>
                      )}
                    </div>
                    <p style={{ color: '#5a6285', fontSize: '0.8rem', margin: 0, maxWidth: '300px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {lastMsg.isMine ? '📤 You: ' : '📥 '}{lastMsg.content}
                    </p>
                  </div>

                  {/* Item */}
                  {item && (
                    <div style={{ fontSize: '0.85rem', color: '#5b4bff', fontWeight: 600, whiteSpace: 'nowrap', flexShrink: 0 }}>
                      📦 {item.title}
                    </div>
                  )}

                  {/* Timestamp */}
                  <div style={{ color: '#5a6285', fontSize: '0.75rem', flexShrink: 0 }}>
                    {new Date(lastMsg.timestamp).toLocaleDateString('en-IN', { month: 'short', day: 'numeric' })}
                  </div>

                  {/* Open Button */}
                  <button style={{
                    padding: '8px 16px', borderRadius: '8px',
                    background: '#5b4bff', border: 'none', color: '#fff',
                    fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700,
                    fontSize: '0.8rem', cursor: 'pointer', flexShrink: 0,
                    transition: 'all 0.15s',
                  }}
                  onMouseEnter={e => e.target.style.background = '#7068ff'}
                  onMouseLeave={e => e.target.style.background = '#5b4bff'}>
                    💬 Open Chat
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </>
      )}

      {/* ═══ OFFERS TAB ═══ */}
      {tab === 'offers' && (
      <>
        {offers.length === 0 ? (
          <div className="empty-state">
            <span className="emoji">💰</span>
            <h3>No offers received yet</h3>
            <p style={{ marginTop: '8px', color: '#5a6285', fontSize: '0.9rem' }}>
              When buyers make offers on your items, they'll appear here
            </p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {offers.map(offer => {
              const buyer = offer.buyer;
              const item = offer.item;
              const status = offer.status; // 'PENDING', 'ACCEPTED', 'REJECTED'
              const statusStyle = {
                'PENDING': { bg: 'rgba(245,158,11,0.1)', color: '#f59e0b', label: '⏳' },
                'ACCEPTED': { bg: 'rgba(34,197,94,0.1)', color: '#22c55e', label: '✅' },
                'REJECTED': { bg: 'rgba(239,68,68,0.1)', color: '#ef4444', label: '❌' },
              }[status] || { bg: '#141929', color: '#5a6285', label: '📋' };

              return (
                <div key={offer.id} className="card" style={{ display: 'flex', alignItems: 'flex-start', padding: '16px 18px', gap: '16px', flexWrap: 'wrap', overflow: 'visible' }}>
                  {/* Thumbnail */}
                  <div style={{
                    width: '60px', height: '60px', borderRadius: '10px', flexShrink: 0,
                    background: item.imageUrls?.[0] ? 'transparent' : '#141929',
                    border: '1px solid #1e2438', overflow: 'hidden',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.6rem',
                  }}>
                    {item.imageUrls?.[0]
                      ? <img src={item.imageUrls[0]} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} onError={e => { e.target.style.display = 'none'; }} />
                      : '📦'
                    }
                  </div>

                  {/* Info */}
                  <div style={{ flex: 1, minWidth: '250px' }}>
                    <h3 style={{ fontFamily: "'Syne',sans-serif", fontSize: '0.95rem', color: '#e8eaf6', marginBottom: '4px' }}>
                      {item.title}
                    </h3>
                    <p style={{ color: '#5a6285', fontSize: '0.8rem', marginBottom: '8px' }}>
                      Offer from <span style={{ color: '#a89dff', fontWeight: 600 }}>{buyer.name}</span> ({buyer.email})
                    </p>
                    <div style={{
                      padding: '8px 12px', borderRadius: '6px',
                      background: 'rgba(91,75,255,0.1)', border: '1px solid rgba(91,75,255,0.3)',
                    }}>
                      <p style={{ color: '#5a6285', fontSize: '0.75rem', margin: '0 0 4px 0' }}>Offered Price:</p>
                      <p style={{ color: '#5b4bff', fontSize: '1.1rem', fontWeight: 800, margin: 0 }}>
                        ₹{offer.offeredPrice?.toLocaleString('en-IN')}
                      </p>
                      <p style={{ color: '#5a6285', fontSize: '0.7rem', margin: '4px 0 0 0' }}>
                        Your asking: ₹{item.price?.toLocaleString('en-IN')}
                      </p>
                    </div>
                    {offer.message && (
                      <p style={{ color: '#5a6285', fontSize: '0.8rem', marginTop: '8px', fontStyle: 'italic' }}>
                        💬 "{offer.message}"
                      </p>
                    )}
                  </div>

                  {/* Status */}
                  <span style={{
                    padding: '6px 12px', borderRadius: '6px', fontSize: '0.8rem', fontWeight: 700,
                    background: statusStyle.bg, color: statusStyle.color, flexShrink: 0,
                  }}>
                    {statusStyle.label} {status}
                  </span>

                  {/* Actions */}
                  <div style={{ display: 'flex', gap: '8px', flexShrink: 0, flexWrap: 'wrap' }}>
                    {status === 'PENDING' && (
                      <>
                        <button onClick={() => handleAcceptOffer(offer.id)} className="btn btn-success btn-sm">
                          ✅ Accept
                        </button>
                        <button onClick={() => handleRejectOffer(offer.id)} className="btn btn-danger btn-sm">
                          ❌ Reject
                        </button>
                      </>
                    )}
                    <button onClick={() => navigate('/chat/room', { state: { otherUserId: buyer.id, otherUserName: buyer.name, otherUserPic: buyer.profilePic, itemId: item.id, itemTitle: item.title } })} className="btn btn-ghost btn-sm">
                      💬 Chat
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </>
      )}
    </div>
  );
}
