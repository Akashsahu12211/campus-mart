import React, { useEffect, useState, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  getItemById,
  getSimilarItems,
  markAsSold,
  markAsReserved,
  deleteItem,
  checkWishlist,
  addToWishlist,
  removeFromWishlist,
  getSellerReviews,
  getItemReviews,
  checkReview,
  addReview,
  deleteReview,
  reserveByBuyer,
  makeOffer,
  getOffersForItem,
  acceptOffer,
  rejectOffer,
  getBuyerOrders,
  confirmDelivery,
  raiseDispute,
  hasAuthSession,
  blockUser,
  unblockUser,
  checkBlockStatus,
  submitItemReport
} from '../api/api';
import { useAuth } from '../App';
import PayButton from '../components/PayButton';
import ItemCard from '../components/ItemCard';
import { addRecentItem } from '../utils/recentItems';
import { FaWhatsapp } from 'react-icons/fa';

const detailPillStyle = {
  fontSize: '0.78rem',
  color: '#a0a8c8',
  background: '#141929',
  border: '1px solid #1e2438',
  borderRadius: '999px',
  padding: '6px 10px',
  fontWeight: 700,
};

const CAT_ICONS = {
  'Books & Notes': '📚',
  'Electronics': '💻',
  'Cycles & Vehicles': '🚲',
  'Room Items': '🛋️',
  'Clothes': '👕',
  'Sports': '⚽',
  'Stationery': '✏️',
  'Other': '📦',
};

const CONDITION_LABELS = {
  NEW: '🌟 New',
  LIKE_NEW: '✨ Like New',
  GOOD: '👍 Good',
  FAIR: '🔧 Fair',
  POOR: '🔴 Poor',
};

export default function ItemDetail() {
  const { id } = useParams();
  const { user } = useAuth();
  const navigate = useNavigate();

  const [item, setItem] = useState(null);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [activeImg, setActiveImg] = useState(0);
  const [zoomed, setZoomed] = useState(false);
  const [zoomSrc, setZoomSrc] = useState('');
  const [wishlisted, setWishlisted] = useState(false);
  const [similarItems, setSimilarItems] = useState([]);

  const [reviews, setReviews] = useState({
    reviews: [],
    averageRating: 0,
    totalReviews: 0
  });
  const [sellerItemReview, setSellerItemReview] = useState(null);
  const [newRating, setNewRating] = useState(5);
  const [newComment, setNewComment] = useState('');
  const [alreadyReviewed, setAlreadyReviewed] = useState(false);
  const [reviewMsg, setReviewMsg] = useState('');

  // ✅ OFFER SYSTEM STATE
  const [showOfferForm, setShowOfferForm] = useState(false);
  const [offerPrice, setOfferPrice] = useState('');
  const [offerNote, setOfferNote] = useState('');
  const [offers, setOffers] = useState([]);
  const [offerMsg, setOfferMsg] = useState('');

  // 💳 PAYMENT STATE
  const [existingOrder, setExistingOrder] = useState(null);
  const [disputeReason, setDisputeReason] = useState('');
  const [showDispute,   setShowDispute]   = useState(false);
  const [blockState, setBlockState] = useState({ blocked: false, blockedEitherWay: false });
  const [showReportForm, setShowReportForm] = useState(false);
  const [reportReason, setReportReason] = useState('SPAM');
  const [reportDescription, setReportDescription] = useState('');
  const [reportMsg, setReportMsg] = useState('');

  useEffect(() => {
    getItemById(id)
      .then(r => {
        setItem(r.data);
      })
      .catch(() => setMsg({ type: 'error', text: 'Item not found.' }))
      .finally(() => setLoading(false));
  }, [id]);

  useEffect(() => {
    if (user?.id && item?.id && hasAuthSession()) {
      checkWishlist(user.id, item.id)
        .then(r => setWishlisted(r.data.wishlisted))
        .catch(err => {
          // Silently fail - permission errors are expected for public item pages
          if (err.response?.status === 403) {
            console.warn('Wishlist check denied - user may not have permission');
          }
        });
    } else {
      setWishlisted(false);
    }
  }, [user, item]);

  // 💳 Check for existing payment order
  useEffect(() => {
    if (user?.id && item?.id && hasAuthSession()) {
      getBuyerOrders(user.id)
        .then(r => {
          const order = r.data.find(
            o => o.item?.id === item.id &&
                 (o.status === 'ESCROW_HOLD' ||
                  o.status === 'PAID' ||
                  o.status === 'DISPUTED'));
          setExistingOrder(order || null);
        })
        .catch(err => {
          // Silently fail - permission errors are expected for public item pages
          if (err.response?.status === 403) {
            console.warn('Order check denied - user may not have permission');
          }
        });
    } else {
      setExistingOrder(null);
    }
  }, [user, item]);

  useEffect(() => {
    if (!item) return;

    getSellerReviews(item.seller?.id)
      .then(r => setReviews(r.data))
      .catch(err => console.error('Failed to fetch seller reviews:', err));

    // Fetch reviews for this specific item (includes seller's self-review)
    getItemReviews(item.id)
      .then(r => {
        console.log('Item reviews response:', r.data);
        const reviews = r.data?.reviews || [];
        const sellerReview = reviews.find(rv => rv.reviewer?.id === item.seller?.id);
        console.log('Seller review found:', sellerReview);
        if (sellerReview) {
          setSellerItemReview(sellerReview);
        }
      })
      .catch(err => console.error('Failed to fetch item reviews:', err));

    if (user?.id && hasAuthSession()) {
      checkReview(user.id, item.id)
        .then(r => setAlreadyReviewed(r.data.reviewed))
        .catch(() => {});
    } else {
      setAlreadyReviewed(false);
    }
  }, [item, user]);

  useEffect(() => {
    if (!user?.id || !item?.seller?.id || user.id === item.seller.id || !hasAuthSession()) {
      setBlockState({ blocked: false, blockedEitherWay: false });
      return;
    }

    checkBlockStatus(user.id, item.seller.id)
      .then((res) => setBlockState(res.data || { blocked: false, blockedEitherWay: false }))
      .catch(err => {
        // Silently fail - permission errors are expected for public item pages
        if (err.response?.status === 403) {
          console.warn('Block status check denied - user may not have permission');
        }
        setBlockState({ blocked: false, blockedEitherWay: false });
      });
  }, [user?.id, item?.seller?.id]);

  useEffect(() => {
    if (!item?.id) {
      setSimilarItems([]);
      return;
    }

    getSimilarItems(item.id)
      .then(res => setSimilarItems(Array.isArray(res.data) ? res.data : []))
      .catch(() => setSimilarItems([]));
  }, [item?.id]);

  useEffect(() => {
    if (item?.id) {
      addRecentItem(item);
    }
  }, [item]);

  const images = item?.imageUrls?.filter(Boolean) || [];
  const hasImages = images.length > 0;

  const prevImg = useCallback(() => {
    setActiveImg(i => (i - 1 + images.length) % images.length);
  }, [images.length]);

  const nextImg = useCallback(() => {
    setActiveImg(i => (i + 1) % images.length);
  }, [images.length]);

  useEffect(() => {
    const onKey = e => {
      if (zoomed && e.key === 'Escape') {
        setZoomed(false);
        return;
      }
      if (images.length > 1) {
        if (e.key === 'ArrowLeft') prevImg();
        if (e.key === 'ArrowRight') nextImg();
      }
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [zoomed, images.length, prevImg, nextImg]);

  const openZoom = src => {
    setZoomSrc(src);
    setZoomed(true);
  };

  const openWhatsApp = () => {
    if (!item?.seller?.phoneVisibleToViewer || !item?.seller?.phone || blockState.blockedEitherWay) return;

    const firstName = item.seller?.name?.split(' ')[0] || '';
    const msgText = encodeURIComponent(
      `Hi ${firstName}! I'm interested in your item "${item.title}" listed on Campus Mart for ₹${item.price}. Is it still available?`
    );

    window.open(`https://wa.me/91${item.seller.phone}?text=${msgText}`, '_blank');
  };

  const isOwner = user && item && user.id === item.seller?.id;
  const isSold = item?.status === 'SOLD';
  const isResv = item?.status === 'RESERVED';
  const isInteractionBlocked = Boolean(blockState.blockedEitherWay);
  const sellerIdentityVerified = Boolean(
    item?.seller?.identityVerified ??
    (item?.seller?.emailVerified && item?.seller?.phoneVerified && item?.seller?.isActive && !item?.seller?.isBanned)
  );
  const sellerPhoneVisible = Boolean(item?.seller?.phoneVisibleToViewer && item?.seller?.phone);
  const sellerMaskedPhone = item?.seller?.maskedPhone;
  const sellerContactReason = item?.seller?.contactRevealReason;
  const directChatAllowed = item?.seller?.allowDirectChat !== false;
  const acceptedBuyerOffer = user && offers.find(
    offer => offer.buyer?.id === user.id && offer.status === 'ACCEPTED'
  );
  const isReservedForCurrentUser = user && item?.reservedBy === user.id;
  const detailRows = [
    item?.academicSubject ? ['Subject', item.academicSubject] : null,
    item?.bookAuthor ? ['Author', item.bookAuthor] : null,
    item?.bookEdition ? ['Edition', item.bookEdition] : null,
    item?.academicCourse ? ['Course', item.academicCourse] : null,
    item?.academicLevel ? ['Level', item.academicLevel] : null,
    item?.boardOrUniversity ? ['Board / University', item.boardOrUniversity] : null,
    item?.publisher ? ['Publisher', item.publisher] : null,
    item?.isbn ? ['ISBN', item.isbn] : null,
  ].filter(Boolean);
  const icon = CAT_ICONS[item?.category?.name] || '📦';
  const contactNotice = !isOwner && !isInteractionBlocked && (() => {
    if (!directChatAllowed) {
      return 'Seller has paused direct chat for now. You can still use offers and moderation tools.';
    }
    if (sellerPhoneVisible) {
      return '';
    }
    switch (sellerContactReason) {
      case 'SELLER_HIDDEN':
        return `Phone kept private by seller. Use in-app chat instead.`;
      case 'SUBSCRIPTION_REQUIRED':
        return `Seller phone is protected for paid access only. Free users can continue with in-app chat.`;
      case 'LOGIN_REQUIRED':
        return `Login first to use chat and continue safely inside the app.`;
      default:
        return `Seller phone is masked for safety. Continue with in-app chat.`;
    }
  })();

  const handleMarkSold = async () => {
    try {
      const r = await markAsSold(id);
      setItem(r.data);
      setMsg({ type: 'success', text: '✅ Marked as sold!' });
    } catch {
      setMsg({ type: 'error', text: 'Error updating status.' });
    }
  };

  const handleMarkReserved = async () => {
    try {
      const r = await markAsReserved(id);
      setItem(r.data);
      setMsg({ type: 'success', text: '🔒 Marked as reserved!' });
    } catch {
      setMsg({ type: 'error', text: 'Error updating status.' });
    }
  };

  const handleDelete = async () => {
    if (!window.confirm('Delete this listing permanently?')) return;
    try {
      await deleteItem(id);
      navigate('/my-items');
    } catch {
      setMsg({ type: 'error', text: 'Error deleting item.' });
    }
  };

  const handleBlockToggle = async () => {
    if (!user?.id || !item?.seller?.id) return;
    try {
      if (blockState.blocked) {
        await unblockUser(item.seller.id, user.id);
        setBlockState({ blocked: false, blockedEitherWay: false });
        setMsg({ type: 'success', text: 'User unblocked successfully.' });
      } else {
        await blockUser({ blockerId: user.id, blockedId: item.seller.id });
        setBlockState({ blocked: true, blockedEitherWay: true });
        setMsg({ type: 'success', text: 'User blocked. Chat and direct contact are disabled now.' });
      }
    } catch (e) {
      setMsg({ type: 'error', text: e.response?.data?.error || 'Could not update block status.' });
    }
  };

  const handleSubmitReport = async () => {
    if (!user?.id) {
      navigate('/login');
      return;
    }

    try {
      const res = await submitItemReport({
        itemId: item.id,
        reason: reportReason,
        description: reportDescription.trim(),
      });
      const data = res.data || {};
      setReportMsg(data.autoHidden
        ? 'Report submitted. This listing crossed the safety threshold and has been hidden for review.'
        : 'Report submitted. Our moderation team will review it shortly.');
      setShowReportForm(false);
      setReportDescription('');
    } catch (e) {
      setReportMsg(e.response?.data?.error || 'Could not submit report');
    }
  };

  const toggleWishlist = async () => {
    if (!user) {
      navigate('/login');
      return;
    }

    try {
      if (wishlisted) {
        await removeFromWishlist(user.id, item.id);
        setWishlisted(false);
      } else {
        await addToWishlist({ studentId: user.id, itemId: item.id });
        setWishlisted(true);
      }
    } catch (_) {}
  };

  const handleShareItem = async () => {
    const sharePayload = {
      title: item?.title,
      text: `${item?.title} on Campus Mart for INR ${item?.price}`,
      url: window.location.href,
    };

    try {
      if (navigator.share) {
        await navigator.share(sharePayload);
      } else if (navigator.clipboard) {
        await navigator.clipboard.writeText(window.location.href);
        setMsg({ type: 'success', text: 'Item link copied to clipboard.' });
      }
    } catch (_) {}
  };

  const handleSubmitReview = async () => {
    try {
      await addReview({
        sellerId: item.seller.id,
        itemId: item.id,
        rating: newRating,
        comment: newComment
      });

      setAlreadyReviewed(true);
      setReviewMsg('✅ Review submitted!');
      setNewComment('');

      const r = await getSellerReviews(item.seller.id);
      setReviews(r.data);
    } catch {
      setReviewMsg('❌ Could not submit');
    }
  };

  // ✅ OFFER SYSTEM FUNCTIONS
  const submitOffer = async () => {
    if (!user) {
      setMsg({ type: 'error', text: 'Please login to make an offer' });
      return;
    }
    if (!offerPrice) {
      setOfferMsg('❌ Please enter an offer price');
      return;
    }

    try {
      await makeOffer({
        itemId: item.id,
        offeredPrice: parseFloat(offerPrice),
        note: offerNote
      });

      setOfferMsg('✅ Offer sent successfully!');
      setShowOfferForm(false);
      setOfferPrice('');
      setOfferNote('');
      
      // Reload offers
      const res = await getOffersForItem(item.id);
      setOffers(res.data || []);
    } catch (e) {
      setOfferMsg('❌ Failed to send offer: ' + (e.response?.data?.error || e.message));
    }
  };

  const handleAcceptOffer = async (offerId) => {
    try {
      await acceptOffer(offerId);
      setOfferMsg('✅ Offer accepted!');
      const res = await getOffersForItem(item.id);
      setOffers(res.data || []);
      const itemRes = await getItemById(id);
      setItem(itemRes.data);
    } catch (e) {
      setOfferMsg('❌ Failed to accept offer');
    }
  };

  const handleRejectOffer = async (offerId) => {
    try {
      await rejectOffer(offerId);
      setOfferMsg('✅ Offer rejected');
      const res = await getOffersForItem(item.id);
      setOffers(res.data || []);
      const itemRes = await getItemById(id);
      setItem(itemRes.data);
    } catch (e) {
      setOfferMsg('❌ Failed to reject offer');
    }
  };

  // 💳 PAYMENT HANDLERS
  const handlePaySuccess = (data) => {
    setMsg({ type: 'success', text: data.message });
    setExistingOrder({ id: data.orderId, status: 'ESCROW_HOLD',
      amount: acceptedBuyerOffer?.offeredPrice || item.price });
    // Reload item
    getItemById(id).then(r => setItem(r.data)).catch(() => {});
  };

  const handleConfirmDelivery = async () => {
    try {
      const r = await confirmDelivery(existingOrder.id);
      setMsg({ type: 'success', text: r.data.message });
      setExistingOrder({ ...existingOrder, status: 'RELEASED' });
    } catch (e) {
      setMsg({ type: 'error',
        text: e.response?.data?.error || 'Failed' });
    }
  };

  const handleRaiseDispute = async () => {
    if (!disputeReason.trim()) return;
    try {
      const r = await raiseDispute(existingOrder.id, {
        reason: disputeReason
      });
      setMsg({ type: 'success', text: r.data.message });
      setExistingOrder({ ...existingOrder, status: 'DISPUTED' });
      setShowDispute(false);
    } catch (e) {
      setMsg({ type: 'error',
        text: e.response?.data?.error || 'Failed' });
    }
  };

  // Load offers when item loads
  useEffect(() => {
    if (!item?.id) return;
    getOffersForItem(item.id)
      .then(res => setOffers(res.data || []))
      .catch(() => setOffers([]));
  }, [item?.id]);

  if (loading) {
    return (
      <div className="page loading-wrap">
        <div className="spinner" />
      </div>
    );
  }

  if (!item) {
    return (
      <div className="page">
        <div className="alert alert-error">{msg.text}</div>
      </div>
    );
  }

  return (
    <div className="page fade-in">
      {msg.text && (
        <div
          className={`alert alert-${msg.type === 'success' ? 'success' : 'error'}`}
          style={{ marginBottom: '20px' }}
        >
          {msg.text}
        </div>
      )}

      <button
        onClick={() => navigate(-1)}
        className="btn btn-ghost btn-sm"
        style={{ marginBottom: '20px' }}
      >
        ← Back
      </button>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: '28px',
          alignItems: 'start'
        }}
      >
        <div>
          <div
            style={{
              borderRadius: '16px',
              overflow: 'hidden',
              background: '#0f1320',
              border: '1px solid #1e2438',
              position: 'relative',
              height: '380px',
              cursor: hasImages ? 'zoom-in' : 'default'
            }}
            onClick={() => hasImages && openZoom(images[activeImg])}
          >
            {hasImages ? (
              <img
                src={images[activeImg]}
                alt={item.title}
                style={{
                  width: '100%',
                  height: '100%',
                  objectFit: 'contain',
                  padding: '8px'
                }}
                onError={e => {
                  e.target.style.display = 'none';
                }}
              />
            ) : (
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  height: '100%',
                  fontSize: '5rem',
                  opacity: 0.4
                }}
              >
                {icon}
              </div>
            )}

            {images.length > 1 && (
              <>
                <button
                  onClick={e => {
                    e.stopPropagation();
                    prevImg();
                  }}
                  style={{
                    position: 'absolute',
                    left: '10px',
                    top: '50%',
                    transform: 'translateY(-50%)',
                    background: 'rgba(0,0,0,0.6)',
                    border: 'none',
                    borderRadius: '50%',
                    width: '36px',
                    height: '36px',
                    color: '#fff',
                    cursor: 'pointer',
                    fontSize: '1rem',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    backdropFilter: 'blur(4px)'
                  }}
                >
                  ‹
                </button>
                <button
                  onClick={e => {
                    e.stopPropagation();
                    nextImg();
                  }}
                  style={{
                    position: 'absolute',
                    right: '10px',
                    top: '50%',
                    transform: 'translateY(-50%)',
                    background: 'rgba(0,0,0,0.6)',
                    border: 'none',
                    borderRadius: '50%',
                    width: '36px',
                    height: '36px',
                    color: '#fff',
                    cursor: 'pointer',
                    fontSize: '1rem',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    backdropFilter: 'blur(4px)'
                  }}
                >
                  ›
                </button>
              </>
            )}

            {images.length > 1 && (
              <div
                style={{
                  position: 'absolute',
                  bottom: '10px',
                  right: '10px',
                  background: 'rgba(0,0,0,0.6)',
                  color: '#fff',
                  padding: '2px 8px',
                  borderRadius: '10px',
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  backdropFilter: 'blur(4px)'
                }}
              >
                {activeImg + 1} / {images.length}
              </div>
            )}

            {hasImages && (
              <div
                style={{
                  position: 'absolute',
                  top: '10px',
                  right: '10px',
                  background: 'rgba(0,0,0,0.5)',
                  color: '#aaa',
                  padding: '3px 8px',
                  borderRadius: '6px',
                  fontSize: '0.7rem',
                  backdropFilter: 'blur(4px)'
                }}
              >
                🔍 Click to zoom
              </div>
            )}
          </div>

          {images.length > 1 && (
            <div
              style={{
                display: 'flex',
                gap: '8px',
                marginTop: '10px',
                overflowX: 'auto',
                paddingBottom: '4px'
              }}
            >
              {images.map((img, i) => (
                <div
                  key={i}
                  onClick={() => setActiveImg(i)}
                  style={{
                    width: '68px',
                    height: '68px',
                    borderRadius: '10px',
                    overflow: 'hidden',
                    border: `2px solid ${i === activeImg ? '#5b4bff' : '#1e2438'}`,
                    cursor: 'pointer',
                    flexShrink: 0,
                    transition: 'border-color 0.2s',
                    background: '#0f1320'
                  }}
                >
                  <img
                    src={img}
                    alt={`thumb-${i}`}
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    onError={e => {
                      e.target.style.display = 'none';
                    }}
                  />
                </div>
              ))}
            </div>
          )}
        </div>

        <div>
          <div style={{ display: 'flex', gap: '8px', marginBottom: '12px', flexWrap: 'wrap' }}>
            <span style={{ fontSize: '0.8rem', color: '#5a6285', fontWeight: 600 }}>
              {icon} {item.category?.name}
            </span>
            {item.condition && (
              <span style={{ fontSize: '0.8rem', color: '#a0a8c8' }}>
                · {CONDITION_LABELS[item.condition]}
              </span>
            )}
            <span className={`badge badge-${isSold ? 'sold' : isResv ? 'reserved' : 'available'}`}>
              {isSold ? 'Sold' : isResv ? 'Reserved' : 'Available'}
            </span>
            {item.donation && <span style={{ ...detailPillStyle, color: '#f59e0b' }}>Donation</span>}
            {item.listingType === 'BOOK' && <span style={{ ...detailPillStyle, color: '#5b4bff' }}>Book Listing</span>}
            {item.bundle && <span style={{ ...detailPillStyle, color: '#00d4aa' }}>Bundle{item.bundleSize ? ` • ${item.bundleSize}` : ''}</span>}
          </div>

          <h1
            style={{
              fontFamily: "'Syne',sans-serif",
              fontSize: '1.6rem',
              lineHeight: 1.2,
              marginBottom: '14px'
            }}
          >
            {item.title}
          </h1>

          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
              marginBottom: '20px',
              flexWrap: 'wrap'
            }}
          >
            <span
              style={{
                fontSize: '2.2rem',
                fontWeight: 900,
                color: '#5b4bff',
                fontFamily: "'Syne',sans-serif"
              }}
            >
              ₹{item.price?.toLocaleString('en-IN')}
            </span>

            {item.negotiable && (
              <span
                style={{
                  background: 'rgba(0,212,170,0.12)',
                  color: '#00d4aa',
                  border: '1px solid rgba(0,212,170,0.25)',
                  borderRadius: '6px',
                  padding: '3px 10px',
                  fontSize: '0.78rem',
                  fontWeight: 700
                }}
              >
                Negotiable
              </span>
            )}

              <button
                onClick={toggleWishlist}
              style={{
                background: wishlisted ? 'rgba(239,68,68,0.15)' : 'rgba(100,116,139,0.1)',
                border: `1px solid ${wishlisted ? '#ef4444' : '#334155'}`,
                borderRadius: '10px',
                padding: '10px 18px',
                cursor: 'pointer',
                color: wishlisted ? '#ef4444' : '#64748b',
                fontSize: '1.1rem'
              }}
              >
                {wishlisted ? '❤️ Saved' : '🤍 Save'}
              </button>
              <button
                onClick={handleShareItem}
                style={{
                  padding: '10px 14px',
                  borderRadius: '10px',
                  border: '1px solid #334155',
                  background: 'rgba(100,116,139,0.1)',
                  color: '#CBD5E1',
                  fontWeight: 700,
                  cursor: 'pointer'
                }}
              >
                🔗 Share
              </button>
          </div>

          {item.description && (
            <div style={{ marginBottom: '20px' }}>
              <h4
                style={{
                  fontSize: '0.8rem',
                  fontWeight: 700,
                  color: '#5a6285',
                  textTransform: 'uppercase',
                  letterSpacing: '0.06em',
                  marginBottom: '8px'
                }}
              >
                Description
              </h4>
              <p style={{ color: '#a0a8c8', lineHeight: 1.7, fontSize: '0.92rem' }}>
                {item.description}
              </p>
            </div>
          )}

          {(item.donation || detailRows.length > 0) && (
            <div style={{ marginBottom: '20px' }}>
              <h4
                style={{
                  fontSize: '0.8rem',
                  fontWeight: 700,
                  color: '#5a6285',
                  textTransform: 'uppercase',
                  letterSpacing: '0.06em',
                  marginBottom: '8px'
                }}
              >
                {item.listingType === 'BOOK' ? 'Book Details' : 'Listing Details'}
              </h4>
              {item.donation && (
                <div style={{ padding: '12px 14px', borderRadius: '12px', border: '1px solid rgba(245,158,11,0.25)', background: 'rgba(245,158,11,0.08)', color: '#fbbf24', marginBottom: '10px' }}>
                  Seller is offering this item as a donation/free giveaway.
                </div>
              )}
              {detailRows.map(([label, value]) => (
                <div key={label} style={{ display: 'flex', justifyContent: 'space-between', gap: '12px', padding: '10px 0', borderBottom: '1px solid #1e2438' }}>
                  <span style={{ color: '#718096', fontSize: '0.9rem' }}>{label}</span>
                  <span style={{ color: '#e5e7eb', fontWeight: 600, textAlign: 'right' }}>{value}</span>
                </div>
              ))}
            </div>
          )}

          {item.viewCount > 0 && (
            <p style={{ color: '#3d4566', fontSize: '0.78rem', marginBottom: '16px' }}>
              👁 {item.viewCount} views
            </p>
          )}

          <div
            style={{
              background: '#0f1320',
              border: '1px solid #1e2438',
              borderRadius: '12px',
              padding: '16px',
              marginBottom: '20px'
            }}
          >
            <p
              style={{
                fontSize: '0.75rem',
                color: '#5a6285',
                fontWeight: 700,
                marginBottom: '10px',
                textTransform: 'uppercase',
                letterSpacing: '0.06em'
              }}
            >
              Seller Info
            </p>

            <div style={{ display: 'flex', gap: '14px', alignItems: 'center', flexWrap: 'wrap' }}>
              <div
                style={{
                  width: '44px',
                  height: '44px',
                  borderRadius: '50%',
                  flexShrink: 0,
                  background: item.seller?.profilePic
                    ? 'transparent'
                    : 'linear-gradient(135deg,#5b4bff,#00d4aa)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '1.1rem',
                  fontWeight: 800,
                  color: '#fff',
                  overflow: 'hidden'
                }}
              >
                {item.seller?.profilePic ? (
                  <img
                    src={item.seller.profilePic}
                    alt=""
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                  />
                ) : (
                  item.seller?.name?.charAt(0)
                )}
              </div>

              <div>
                <p style={{ fontWeight: 700, fontSize: '0.97rem' }}>{item.seller?.name}</p>
                <p style={{ color: '#5a6285', fontSize: '0.82rem' }}>
                  {item.seller?.branch}
                  {item.seller?.collegeId ? ` · #${item.seller.collegeId}` : ''}
                </p>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 6 }}>
                  <span style={{
                    padding: '4px 8px',
                    borderRadius: 999,
                    fontSize: 11,
                    fontWeight: 700,
                    background: sellerIdentityVerified ? 'rgba(0,212,170,0.12)' : 'rgba(245,158,11,0.12)',
                    border: `1px solid ${sellerIdentityVerified ? 'rgba(0,212,170,0.3)' : 'rgba(245,158,11,0.28)'}`,
                    color: sellerIdentityVerified ? '#00D4AA' : '#F59E0B',
                  }}>
                    {sellerIdentityVerified ? 'Verified identity' : 'Partial verification'}
                  </span>
                  {sellerMaskedPhone && !sellerPhoneVisible && (
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: 999,
                      fontSize: 11,
                      fontWeight: 700,
                      background: 'rgba(91,75,255,0.12)',
                      border: '1px solid rgba(91,75,255,0.28)',
                      color: '#A89DFF',
                    }}>
                      Phone: {sellerMaskedPhone}
                    </span>
                  )}
                </div>
                {item.seller?.hostel && (
                  <p style={{ color: '#5a6285', fontSize: '0.78rem' }}>{item.seller.hostel}</p>
                )}
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {!isOwner && user && (
              <div style={{ display: 'flex', gap: 10 }}>
                <button
                  onClick={handleBlockToggle}
                  style={{
                    flex: 1,
                    padding: '11px 14px',
                    borderRadius: 12,
                    border: `1px solid ${blockState.blocked ? 'rgba(0,212,170,0.28)' : 'rgba(239,68,68,0.32)'}`,
                    background: blockState.blocked ? 'rgba(0,212,170,0.08)' : 'rgba(239,68,68,0.08)',
                    color: blockState.blocked ? '#00D4AA' : '#EF4444',
                    fontWeight: 700,
                    cursor: 'pointer',
                  }}
                >
                  {blockState.blocked ? 'Unblock User' : 'Block User'}
                </button>
                <button
                  onClick={() => setShowReportForm((prev) => !prev)}
                  style={{
                    flex: 1,
                    padding: '11px 14px',
                    borderRadius: 12,
                    border: '1px solid rgba(245,158,11,0.32)',
                    background: 'rgba(245,158,11,0.08)',
                    color: '#F59E0B',
                    fontWeight: 700,
                    cursor: 'pointer',
                  }}
                >
                  {showReportForm ? 'Cancel Report' : 'Report Item'}
                </button>
              </div>
            )}

            {reportMsg && (
              <div style={{
                borderRadius: 12,
                padding: '12px 14px',
                background: reportMsg.startsWith('Report submitted') ? 'rgba(0,212,170,0.08)' : 'rgba(239,68,68,0.08)',
                border: `1px solid ${reportMsg.startsWith('Report submitted') ? 'rgba(0,212,170,0.24)' : 'rgba(239,68,68,0.24)'}`,
                color: reportMsg.startsWith('Report submitted') ? '#00D4AA' : '#EF4444',
                fontSize: 13,
              }}>
                {reportMsg}
              </div>
            )}

            {showReportForm && !isOwner && (
              <div style={{ padding: 16, background: '#111728', borderRadius: 14, border: '1px solid #1E2438' }}>
                <h4 style={{ margin: '0 0 12px', fontSize: 15 }}>Report this listing</h4>
                <select value={reportReason} onChange={(e) => setReportReason(e.target.value)} style={reportFieldStyle}>
                  <option value="FAKE_ITEM">Fake Item</option>
                  <option value="WRONG_PRICE">Wrong Price</option>
                  <option value="SPAM">Spam</option>
                  <option value="INAPPROPRIATE">Inappropriate</option>
                  <option value="ALREADY_SOLD">Already Sold</option>
                  <option value="OTHER">Other</option>
                </select>
                <textarea
                  value={reportDescription}
                  onChange={(e) => setReportDescription(e.target.value)}
                  rows={4}
                  placeholder="Add context for moderators"
                  style={{ ...reportFieldStyle, marginTop: 10, resize: 'vertical' }}
                />
                <button onClick={handleSubmitReport} style={{ ...reportActionStyle, marginTop: 10 }}>
                  Submit Report
                </button>
              </div>
            )}

            {isInteractionBlocked && (
              <div style={{
                width: '100%',
                padding: '14px 16px',
                borderRadius: 12,
                background: 'rgba(239,68,68,0.08)',
                border: '1px solid rgba(239,68,68,0.24)',
                color: '#FCA5A5',
                fontSize: 14,
                lineHeight: 1.5,
              }}>
                Direct contact is disabled because one of you has blocked the other user.
              </div>
            )}

            {!isInteractionBlocked && contactNotice && (
              <div style={{
                width: '100%',
                padding: '14px 16px',
                borderRadius: 12,
                background: 'rgba(91,75,255,0.08)',
                border: '1px solid rgba(91,75,255,0.24)',
                color: '#C9C2FF',
                fontSize: 14,
                lineHeight: 1.5,
              }}>
                {contactNotice}
              </div>
            )}

            {!isSold && (!isResv || isReservedForCurrentUser) && !isOwner && sellerPhoneVisible && !isInteractionBlocked && (
              <button
                onClick={openWhatsApp}
                style={{
                  width: '100%',
                  padding: '14px 18px',
                  borderRadius: 12,
                  border: 'none',
                  cursor: 'pointer',
                  background: 'linear-gradient(135deg,#5B4BFF,#4338CA)',
                  color: '#fff',
                  fontWeight: 700,
                  fontSize: 16,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 8
                }}
              >
                <FaWhatsapp size={18} />
                Chat on WhatsApp
              </button>
            )}

            {!isSold && (!isResv || isReservedForCurrentUser) && !isOwner && user && !isInteractionBlocked && directChatAllowed && (
              <button
                onClick={() => {
                  console.log('Chat button clicked! Navigating to /chat/room with state:', {
                    otherUserId: item.seller?.id,
                    otherUserName: item.seller?.name,
                  });
                  navigate('/chat/room', {
                    state: {
                      otherUserId:   item.seller?.id,
                      otherUserName: item.seller?.name,
                      otherUserPic:  item.seller?.profilePic,
                      itemId:        item.id,
                      itemTitle:     item.title,
                    }
                  });
                }}
                style={{
                  width: '100%',
                  padding: '14px 18px',
                  borderRadius: 12,
                  border: '1.5px solid #5B4BFF',
                  background: 'transparent',
                  cursor: 'pointer',
                  color: '#5B4BFF',
                  fontWeight: 700,
                  fontSize: 16,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 8,
                  transition: 'all 0.2s',
                }}
                onMouseEnter={e => {
                  e.currentTarget.style.background = 'rgba(91,75,255,0.1)';
                  e.currentTarget.style.transform = 'scale(1.02)';
                }}
                onMouseLeave={e => {
                  e.currentTarget.style.background = 'transparent';
                  e.currentTarget.style.transform = 'scale(1)';
                }}
              >
                💬 Chat in App
              </button>
            )}

            {/* 💳 PAYMENT SECTION */}
            {!isSold && !isOwner && user && item && !isInteractionBlocked && (
              <div style={{ marginTop: '12px' }}>

                {/* Already paid — show escrow status */}
                {existingOrder ? (
                  <div style={{
                    background: existingOrder.status === 'RELEASED'
                      ? 'rgba(34,197,94,0.06)'
                      : existingOrder.status === 'DISPUTED'
                        ? 'rgba(239,68,68,0.06)'
                        : 'rgba(91,75,255,0.06)',
                    border: `1px solid ${
                      existingOrder.status === 'RELEASED'
                        ? 'rgba(34,197,94,0.25)'
                        : existingOrder.status === 'DISPUTED'
                          ? 'rgba(239,68,68,0.25)'
                          : 'rgba(91,75,255,0.25)'}`,
                    borderRadius: '14px', padding: '16px',
                  }}>
                    <div style={{
                      display: 'flex', justifyContent: 'space-between',
                      marginBottom: '12px',
                    }}>
                      <h4 style={{
                        fontFamily: "'Syne',sans-serif",
                        fontSize: '0.95rem',
                      }}>
                        {existingOrder.status === 'ESCROW_HOLD'
                          ? '🔒 Payment in Escrow'
                          : existingOrder.status === 'RELEASED'
                            ? '✅ Payment Released'
                            : existingOrder.status === 'DISPUTED'
                              ? '⚠️ Dispute Raised'
                              : '💳 Payment Status'}
                      </h4>
                      <span style={{
                        fontSize: '1.1rem', fontWeight: 900,
                        color: '#5b4bff',
                      }}>
                        ₹{existingOrder.amount?.toLocaleString?.() ??
                           item.price?.toLocaleString('en-IN')}
                      </span>
                    </div>

                    {existingOrder.status === 'ESCROW_HOLD' && (
                      <>
                        <p style={{
                          color: '#a0a8c8', fontSize: '0.83rem',
                          marginBottom: '12px', lineHeight: 1.5,
                        }}>
                          Your payment is safely held in escrow. After you receive
                          the item, confirm delivery to release payment to seller.
                          Auto-releases in 48 hours.
                        </p>
                        <div style={{ display: 'flex', gap: '8px' }}>
                          <button
                            onClick={handleConfirmDelivery}
                            style={{
                              flex: 2, padding: '10px 16px',
                              background: '#22c55e',
                              color: '#fff', border: 'none',
                              borderRadius: '10px', fontSize: '0.85rem',
                              fontWeight: 700, cursor: 'pointer',
                            }}
                          >
                            ✅ Received Item — Release Payment
                          </button>
                          <button
                            onClick={() => setShowDispute(true)}
                            style={{
                              flex: 1, padding: '10px 16px',
                              background: '#ef4444',
                              color: '#fff', border: 'none',
                              borderRadius: '10px', fontSize: '0.75rem',
                              fontWeight: 700, cursor: 'pointer',
                            }}
                          >
                            ⚠️ Dispute
                          </button>
                        </div>
                      </>
                    )}

                    {existingOrder.status === 'RELEASED' && (
                      <p style={{ color: '#22c55e', fontSize: '0.85rem' }}>
                        Payment released to seller. Transaction complete!
                      </p>
                    )}

                    {existingOrder.status === 'DISPUTED' && (
                      <p style={{ color: '#f59e0b', fontSize: '0.85rem' }}>
                        Dispute under review. Admin will respond within 24-48 hours.
                      </p>
                    )}

                    {/* Dispute modal */}
                    {showDispute && (
                      <div style={{
                        position: 'fixed', inset: 0, zIndex: 1000,
                        background: 'rgba(0,0,0,0.7)',
                        display: 'flex', alignItems: 'center',
                        justifyContent: 'center',
                        backdropFilter: 'blur(4px)',
                      }}>
                        <div style={{
                          background: '#0f1320',
                          border: '1px solid #1e2438',
                          borderRadius: '16px', padding: '28px',
                          width: '400px',
                        }}>
                          <h3 style={{
                            fontFamily: "'Syne',sans-serif",
                            color: '#ef4444', marginBottom: '8px',
                          }}>
                            Raise Dispute ⚠️
                          </h3>
                          <p style={{
                            color: '#5a6285', fontSize: '0.85rem',
                            marginBottom: '14px',
                          }}>
                            Payment will remain frozen until admin resolves.
                          </p>
                          <textarea
                            value={disputeReason}
                            onChange={e => setDisputeReason(e.target.value)}
                            placeholder="Item not received, wrong item, etc."
                            style={{
                              width: '100%', minHeight: '80px',
                              background: '#141929',
                              border: '1px solid #1e2438',
                              borderRadius: '8px',
                              color: '#e8eaf6',
                              padding: '12px',
                              marginBottom: '16px',
                              fontFamily: "'Plus Jakarta Sans',sans-serif",
                              fontSize: '0.85rem',
                            }}
                          />
                          <div style={{ display: 'flex', gap: '10px' }}>
                            <button
                              onClick={handleRaiseDispute}
                              disabled={!disputeReason.trim()}
                              style={{
                                flex: 1, padding: '10px',
                                background: !disputeReason.trim() ? '#666' : '#ef4444',
                                color: '#fff', border: 'none',
                                borderRadius: '8px', fontWeight: 700,
                                cursor: !disputeReason.trim() ? 'not-allowed' : 'pointer',
                              }}
                            >
                              Submit Dispute
                            </button>
                            <button
                              onClick={() => setShowDispute(false)}
                              style={{
                                flex: 1, padding: '10px',
                                background: 'transparent',
                                color: '#5b4bff', border: '1.5px solid #5b4bff',
                                borderRadius: '8px', fontWeight: 700,
                                cursor: 'pointer',
                              }}
                            >
                              Cancel
                            </button>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                ) : (!isResv || isReservedForCurrentUser || acceptedBuyerOffer) ? (
                  /* Pay Button */
                  <div>
                    <div style={{
                      background: 'rgba(0,212,170,0.06)',
                      border: '1px solid rgba(0,212,170,0.2)',
                      borderRadius: '10px', padding: '10px 14px',
                      marginBottom: '10px', fontSize: '0.78rem',
                    }}>
                      <p style={{ color: '#00d4aa', fontWeight: 700,
                        marginBottom: '3px' }}>
                        🔒 Escrow Protected Payment
                      </p>
                      <p style={{ color: '#5a6285' }}>
                        Your money is held safely until you confirm delivery.
                        Pay via UPI, Card, Net Banking, or Cash on Delivery.
                      </p>
                    </div>

                    <PayButton
                      item={item}
                      amount={acceptedBuyerOffer?.offeredPrice || item.price}
                      notes={acceptedBuyerOffer
                        ? `Accepted offer payment for ${item.title}`
                        : `Buying: ${item.title}`}
                      buttonLabel={acceptedBuyerOffer
                        ? `Pay Accepted Offer ₹${acceptedBuyerOffer.offeredPrice?.toLocaleString('en-IN')} Securely`
                        : undefined}
                      onSuccess={handlePaySuccess}
                      onError={(err) => setMsg({ type: 'error', text: err })}
                    />
                  </div>
                ) : null}
              </div>
            )}

            {/* ✅ OFFER BUTTON & FORM */}
            {!isSold && !isOwner && !acceptedBuyerOffer && (
              <>
                <button
                  onClick={() => setShowOfferForm(!showOfferForm)}
                  style={{
                    width: '100%',
                    padding: '14px 18px',
                    borderRadius: 12,
                    border: '1px solid #5B4BFF',
                    background: showOfferForm ? 'rgba(91,75,255,0.2)' : 'transparent',
                    color: '#5B4BFF',
                    fontWeight: 700,
                    fontSize: 16,
                    cursor: 'pointer'
                  }}
                >
                  💰 {showOfferForm ? 'Cancel Offer' : 'Make an Offer'}
                </button>

                {showOfferForm && (
                  <div style={{
                    marginTop: '16px',
                    padding: '16px',
                    border: '1px solid #1e2438',
                    borderRadius: '10px',
                    background: '#141929'
                  }}>
                    <h4 style={{ margin: '0 0 12px 0' }}>Your Offer</h4>
                    
                    <input
                      type="number"
                      placeholder="Your offer price (₹)"
                      value={offerPrice}
                      onChange={(e) => setOfferPrice(e.target.value)}
                      style={{
                        width: '100%',
                        padding: '10px',
                        borderRadius: '8px',
                        border: '1px solid #2a2d3a',
                        background: '#0f1320',
                        color: '#fff',
                        marginBottom: '10px',
                        boxSizing: 'border-box',
                        fontSize: '14px'
                      }}
                    />

                    <textarea
                      placeholder="Add a note (optional)"
                      value={offerNote}
                      onChange={(e) => setOfferNote(e.target.value)}
                      style={{
                        width: '100%',
                        padding: '10px',
                        borderRadius: '8px',
                        border: '1px solid #2a2d3a',
                        background: '#0f1320',
                        color: '#fff',
                        marginBottom: '10px',
                        boxSizing: 'border-box',
                        fontSize: '13px',
                        fontFamily: 'inherit',
                        resize: 'vertical'
                      }}
                      rows={3}
                    />

                    {offerMsg && (
                      <div style={{
                        color: offerMsg.startsWith('✅') ? '#00d4aa' : '#ef4444',
                        fontSize: '13px',
                        marginBottom: '8px'
                      }}>
                        {offerMsg}
                      </div>
                    )}

                    <button
                      onClick={submitOffer}
                      style={{
                        width: '100%',
                        padding: '10px',
                        borderRadius: '8px',
                        background: 'linear-gradient(135deg,#5B4BFF,#4338CA)',
                        border: 'none',
                        color: '#fff',
                        fontWeight: 700,
                        cursor: 'pointer'
                      }}
                    >
                      Send Offer
                    </button>
                  </div>
                )}
              </>
            )}
            
            {/* ✅ OFFERS RECEIVED (for sellers) */}
            {isOwner && offers.length > 0 && (
              <div style={{ marginTop: '24px', padding: '16px', border: '1px solid #1e2438', borderRadius: '10px', background: '#0f1320' }}>
                <h4 style={{ margin: '0 0 12px 0' }}>💰 Offers Received ({offers.length})</h4>
                {offers.map(offer => (
                  <div key={offer.id} style={{
                    padding: '12px',
                    background: '#141929',
                    borderRadius: '8px',
                    marginBottom: '10px',
                    borderLeft: `3px solid ${offer.status === 'PENDING' ? '#5B4BFF' : offer.status === 'ACCEPTED' ? '#00d4aa' : '#ef4444'}`
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                      <span style={{ fontWeight: 700 }}>₹{offer.offeredPrice?.toLocaleString('en-IN')}</span>
                      <span style={{
                        fontSize: '12px',
                        padding: '2px 8px',
                        borderRadius: '4px',
                        background: offer.status === 'PENDING' ? 'rgba(91,75,255,0.2)' : offer.status === 'ACCEPTED' ? 'rgba(0,212,170,0.2)' : 'rgba(239,68,68,0.2)',
                        color: offer.status === 'PENDING' ? '#5B4BFF' : offer.status === 'ACCEPTED' ? '#00d4aa' : '#ef4444'
                      }}>
                        {offer.status}
                      </span>
                    </div>
                    {offer.note && <p style={{ margin: '4px 0', fontSize: '13px', color: '#a0a8c8' }}>"{offer.note}"</p>}
                    <p style={{ margin: '4px 0', fontSize: '12px', color: '#5a6285' }}>
                      from {offer.buyer?.name}
                    </p>
                    
                    {offer.status === 'PENDING' && (
                      <div style={{ display: 'flex', gap: '8px', marginTop: '8px' }}>
                        <button
                          onClick={() => handleAcceptOffer(offer.id)}
                          style={{
                            flex: 1,
                            padding: '8px',
                            borderRadius: '6px',
                            background: '#00d4aa',
                            border: 'none',
                            color: '#000',
                            fontWeight: 700,
                            cursor: 'pointer',
                            fontSize: '12px'
                          }}
                        >
                          ✅ Accept
                        </button>
                        <button
                          onClick={() => handleRejectOffer(offer.id)}
                          style={{
                            flex: 1,
                            padding: '8px',
                            borderRadius: '6px',
                            background: '#ef4444',
                            border: 'none',
                            color: '#fff',
                            fontWeight: 700,
                            cursor: 'pointer',
                            fontSize: '12px'
                          }}
                        >
                          ❌ Reject
                        </button>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}

            <div style={{ marginTop: 32 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 20 }}>
                <h3 style={{ margin: 0, fontSize: 18, fontWeight: 700 }}>Seller Reviews</h3>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontSize: 28, fontWeight: 900, color: '#5B4BFF' }}>
                    {reviews.averageRating || '—'}
                  </span>
                  <div>
                    <div style={{ color: '#5B4BFF', fontSize: 16 }}>
                      {'⭐'.repeat(Math.round(reviews.averageRating || 0))}
                    </div>
                    <div style={{ color: '#718096', fontSize: 12 }}>
                      {reviews.totalReviews} reviews
                    </div>
                  </div>
                </div>
              </div>

              {/* Seller's Own Review */}
              {sellerItemReview && (
                <div style={{
                  background: 'rgba(91,75,255,0.1)',
                  border: '2px solid rgba(91,75,255,0.3)',
                  borderRadius: 14, padding: 18, marginBottom: 24,
                }}>
                  <div style={{ marginBottom: 12 }}>
                    <div style={{ fontWeight: 700, color: '#fff', fontSize: 14, marginBottom: 6 }}>
                      {item?.seller?.name}'s Review ({sellerItemReview.rating}⭐)
                      </div>
                      <p style={{ margin: 0, color: '#A0AEC0', fontSize: 13, lineHeight: 1.6 }}>
                        {sellerItemReview.comment}
                      </p>
                    </div>
                  </div>
                )}

              {user && item?.seller?.id !== user.id && item?.status === 'SOLD' && !alreadyReviewed && (
                <div
                  style={{
                    background: '#0F1320',
                    border: '1px solid rgba(91,75,255,0.2)',
                    borderRadius: 14,
                    padding: 20,
                    marginBottom: 20
                  }}
                >
                  <h4 style={{ margin: '0 0 14px', fontSize: 14, fontWeight: 700 }}>
                    Write a Review
                  </h4>

                  <div style={{ display: 'flex', gap: 6, marginBottom: 12 }}>
                    {[1, 2, 3, 4, 5].map(s => (
                      <span
                        key={s}
                        onClick={() => setNewRating(s)}
                        style={{
                          fontSize: 28,
                          cursor: 'pointer',
                          opacity: s <= newRating ? 1 : 0.3
                        }}
                      >
                        ⭐
                      </span>
                    ))}
                  </div>

                  <textarea
                    value={newComment}
                    onChange={e => setNewComment(e.target.value)}
                    placeholder="Share your experience with this seller..."
                    rows={3}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      borderRadius: 10,
                      background: '#080B14',
                      border: '1px solid rgba(255,255,255,0.1)',
                      color: '#fff',
                      fontSize: 13,
                      resize: 'vertical',
                      boxSizing: 'border-box',
                      fontFamily: 'inherit'
                    }}
                  />

                  {reviewMsg && (
                    <div
                      style={{
                        color: reviewMsg.startsWith('✅') ? '#00D4AA' : '#EF4444',
                        fontSize: 12,
                        marginTop: 6
                      }}
                    >
                      {reviewMsg}
                    </div>
                  )}

                  <button
                    onClick={handleSubmitReview}
                    style={{
                      marginTop: 12,
                      padding: '10px 24px',
                      borderRadius: 10,
                      background: 'linear-gradient(135deg,#5B4BFF,#4338CA)',
                      border: 'none',
                      color: '#fff',
                      fontWeight: 700,
                      cursor: 'pointer'
                    }}
                  >
                    Submit Review
                  </button>
                </div>
              )}

              {reviews.reviews.length === 0 ? (
                <div
                  style={{
                    textAlign: 'center',
                    padding: '24px',
                    color: '#718096',
                    fontSize: 13
                  }}
                >
                  No reviews yet for this seller
                </div>
              ) : (
                reviews.reviews.map(rv => (
                  <div key={rv.id} style={{
                    background: '#0F1320',
                    border: `1px solid ${user?.id === rv.reviewer?.id ? 'rgba(91,75,255,0.3)' : 'rgba(255,255,255,0.07)'}`,
                    borderRadius: 12, padding: 16, marginBottom: 12,
                  }}>
                    {/* Header */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
                      <div style={{
                        width: 36, height: 36, borderRadius: '50%',
                        background: 'linear-gradient(135deg,#5B4BFF,#00D4AA)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontWeight: 800, fontSize: 14, color: '#fff', flexShrink: 0,
                      }}>
                        {rv.reviewer?.name?.charAt(0)?.toUpperCase()}
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontWeight: 700, fontSize: 13 }}>{rv.reviewer?.name}</div>
                        <div style={{ color: '#F6AD55', fontSize: 13 }}>
                          {'⭐'.repeat(rv.rating)}
                        </div>
                      </div>
                      <div style={{ color: '#718096', fontSize: 11 }}>
                        {new Date(rv.createdAt).toLocaleDateString('en-IN', {
                          day: 'numeric', month: 'short', year: 'numeric'
                        })}
                      </div>
                      {/* Edit/Delete buttons — sirf apne review pe */}
                      {user?.id === rv.reviewer?.id && (
                        <div style={{ display: 'flex', gap: 6 }}>
                          <button
                            onClick={async () => {
                              if (!window.confirm('Delete this review?')) return;
                              try {
                                await deleteReview(rv.id);
                                const r = await getSellerReviews(item.seller.id);
                                setReviews(r.data);
                              } catch {}
                            }}
                            style={{
                              background: 'rgba(239,68,68,0.1)',
                              border: '1px solid rgba(239,68,68,0.3)',
                              borderRadius: 6, padding: '3px 10px',
                              color: '#EF4444', fontSize: 11,
                              fontWeight: 700, cursor: 'pointer',
                            }}>🗑️</button>
                        </div>
                      )}
                    </div>

                    {/* Comment */}
                    {rv.comment && (
                      <div style={{ color: '#A0AEC0', fontSize: 13, lineHeight: 1.5 }}>
                        {rv.comment}
                      </div>
                    )}
                  </div>
                ))
              )}
            </div>

            {isOwner && (
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                {!isSold && !isResv && (
                  <button onClick={handleMarkReserved} className="btn btn-secondary" style={{ flex: 1 }}>
                    🔒 Mark Reserved
                  </button>
                )}
                {!isSold && (
                  <button onClick={handleMarkSold} className="btn btn-success" style={{ flex: 1 }}>
                    ✅ Mark Sold
                  </button>
                )}
                <button onClick={() => navigate(`/edit-item/${item.id}`)} className="btn btn-ghost" style={{ flex: 1 }}>
                  ✏️ Edit
                </button>
                <button onClick={handleDelete} className="btn btn-danger" style={{ flex: 1 }}>
                  🗑️ Delete
                </button>
              </div>
            )}

            {/* Buyer Reserve Button */}
            {item?.status === 'AVAILABLE' && user && !isInteractionBlocked &&
             item?.seller?.id !== user.id && (
              <button
                onClick={async () => {
                  try {
                    await reserveByBuyer(item.id);
                    const res = await getItemById(id);
                    setItem(res.data);
                    setMsg({ 
                      type: 'success', 
                      text: '✅ Item reserved! Contact seller to confirm purchase.' 
                    });
                  } catch (e) {
                    setMsg({ 
                      type: 'error', 
                      text: e.response?.data?.error || 'Failed to reserve' 
                    });
                  }
                }}
                style={{
                  width: '100%',
                  padding: '12px',
                  borderRadius: '10px',
                  background: 'rgba(91,75,255,0.1)',
                  border: '1px solid rgba(91,75,255,0.3)',
                  color: '#5B4BFF',
                  fontWeight: 700,
                  fontSize: '0.95rem',
                  cursor: 'pointer',
                  marginTop: '8px',
                }}
              >
                🔒 Reserve This Item
              </button>
            )}

            {/* Already reserved by someone */}
            {item?.status === 'RESERVED' && user?.id !== item?.seller?.id && (
              <div style={{
                padding: '12px',
                borderRadius: '10px',
                background: isReservedForCurrentUser ? 'rgba(0,212,170,0.08)' : 'rgba(91,75,255,0.08)',
                border: isReservedForCurrentUser ? '1px solid rgba(0,212,170,0.2)' : '1px solid rgba(91,75,255,0.2)',
                color: isReservedForCurrentUser ? '#00d4aa' : '#5B4BFF',
                fontSize: '0.85rem',
                textAlign: 'center',
                marginTop: '8px',
              }}>
                {isReservedForCurrentUser
                  ? '✅ This item is reserved for you. Complete payment to confirm the purchase.'
                  : '🔒 This item is currently reserved'}
              </div>
            )}
          </div>
        </div>
      </div>

      {similarItems.length > 0 && (
        <section style={{ marginTop: 40 }}>
          <div style={{ marginBottom: 16 }}>
            <h3 style={{ margin: 0, fontSize: 18, fontWeight: 700 }}>Similar Items</h3>
            <p style={{ margin: '6px 0 0', color: '#718096', fontSize: 13 }}>
              Same category ke aur active listings.
            </p>
          </div>

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
              gap: '16px',
            }}
          >
            {similarItems.map(similarItem => (
              <ItemCard key={similarItem.id} item={similarItem} />
            ))}
          </div>
        </section>
      )}

      {zoomed && (
        <div
          onClick={() => setZoomed(false)}
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 1000,
            background: 'rgba(0,0,0,0.92)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'zoom-out',
            padding: '20px',
            backdropFilter: 'blur(8px)'
          }}
        >
          <img
            src={zoomSrc}
            alt="Zoomed"
            style={{
              maxWidth: '90vw',
              maxHeight: '90vh',
              objectFit: 'contain',
              borderRadius: '12px',
              boxShadow: '0 0 60px rgba(0,0,0,0.8)'
            }}
            onClick={e => e.stopPropagation()}
          />
          <button
            onClick={() => setZoomed(false)}
            style={{
              position: 'absolute',
              top: '20px',
              right: '20px',
              background: 'rgba(255,255,255,0.1)',
              border: '1px solid rgba(255,255,255,0.15)',
              borderRadius: '50%',
              width: '40px',
              height: '40px',
              color: '#fff',
              cursor: 'pointer',
              fontSize: '1.1rem',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            ✕
          </button>
        </div>
      )}
    </div>
  );
}

const reportFieldStyle = {
  width: '100%',
  padding: '10px 12px',
  borderRadius: 10,
  border: '1px solid #2A324A',
  background: '#0F1320',
  color: '#fff',
  fontFamily: 'inherit',
  boxSizing: 'border-box',
};

const reportActionStyle = {
  width: '100%',
  padding: '11px 14px',
  borderRadius: 10,
  border: 'none',
  background: 'linear-gradient(135deg,#F59E0B,#D97706)',
  color: '#fff',
  fontWeight: 700,
  cursor: 'pointer',
};
