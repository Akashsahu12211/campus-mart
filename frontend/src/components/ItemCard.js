import React, { useContext, useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { AuthContext } from '../App';
import {
  addToWishlist,
  checkWishlist,
  hasAuthSession,
  removeFromWishlist,
} from '../api/api';
import '../styles/ItemCard.css';

const CAT_ICONS = {
  'Books & Notes': '\u{1F4DA}',
  Electronics: '\u{1F4BB}',
  'Cycles & Vehicles': '\u{1F6B2}',
  'Room Items': '\u{1FA91}',
  Clothes: '\u{1F455}',
  Sports: '\u26BD',
  Stationery: '\u270F\uFE0F',
  Other: '\u{1F4E6}',
};

const CONDITION_COLORS = {
  NEW: { bg: 'rgba(0,212,170,0.12)', color: '#00d4aa' },
  LIKE_NEW: { bg: 'rgba(91,75,255,0.12)', color: '#a89dff' },
  GOOD: { bg: 'rgba(34,197,94,0.12)', color: '#22c55e' },
  FAIR: { bg: 'rgba(245,158,11,0.12)', color: '#f59e0b' },
  POOR: { bg: 'rgba(239,68,68,0.12)', color: '#ef4444' },
};

const CONDITION_LABELS = {
  NEW: 'New',
  LIKE_NEW: 'Like New',
  GOOD: 'Good',
  FAIR: 'Fair',
  POOR: 'Poor',
};

export default function ItemCard({ item }) {
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const [wishlisted, setWishlisted] = useState(false);

  const icon = CAT_ICONS[item.category?.name] || '\u{1F4E6}';
  const isSold = item.status === 'SOLD';
  const isResv = item.status === 'RESERVED';
  const firstImg = item.imageUrls?.[0];
  const imgCount = item.imageUrls?.length || 0;
  const condStyle = CONDITION_COLORS[item.condition] || CONDITION_COLORS.GOOD;
  const listingBadges = [
    item.boostActive
      ? { label: 'Boosted', bg: 'rgba(239,68,68,0.88)' }
      : null,
    item.negotiable && !isSold
      ? { label: 'NEGO', bg: 'rgba(0,212,170,0.85)' }
      : null,
    item.donation
      ? { label: 'Donate', bg: 'rgba(245,158,11,0.88)' }
      : null,
    item.listingType === 'BOOK'
      ? { label: 'Book', bg: 'rgba(91,75,255,0.88)' }
      : null,
    item.bundle
      ? {
          label: item.bundleSize ? `Bundle ${item.bundleSize}` : 'Bundle',
          bg: 'rgba(15,118,110,0.88)',
        }
      : null,
  ].filter(Boolean);

  useEffect(() => {
    if (user?.id && item?.id && hasAuthSession()) {
      checkWishlist(user.id, item.id)
        .then((r) => setWishlisted(r.data.wishlisted))
        .catch(() => {});
    } else {
      setWishlisted(false);
    }
  }, [user, item?.id]);

  async function toggleWishlist(event) {
    event.preventDefault();
    event.stopPropagation();

    if (!user) {
      navigate('/login');
      return;
    }

    try {
      if (wishlisted) {
        await removeFromWishlist(user.id, item.id);
      } else {
        await addToWishlist({ studentId: user.id, itemId: item.id });
      }
      setWishlisted((current) => !current);
    } catch {}
  }

  return (
    <Link to={`/item/${item.id}`} className="item-card-link">
      <div className="card item-card">
        <div
          className="item-card__media"
          style={{
            background: firstImg
              ? 'transparent'
              : 'linear-gradient(135deg,#0f1320,#141929)',
          }}
        >
          {firstImg ? (
            <img
              src={firstImg}
              alt={item.title}
              className="item-card__image"
              onError={(event) => {
                event.target.style.display = 'none';
              }}
            />
          ) : (
            <span className="item-card__placeholder">{icon}</span>
          )}

          <button
            type="button"
            onClick={toggleWishlist}
            className="item-card__wishlist"
          >
            <span style={{ color: wishlisted ? '#EF4444' : '#ffffff' }}>
              {wishlisted ? '\u2665' : '\u2661'}
            </span>
          </button>

          <div className="item-card__badges">
            {listingBadges.map((badge) => (
              <div
                key={badge.label}
                className="item-card__badge"
                style={{ background: badge.bg }}
              >
                {badge.label}
              </div>
            ))}
          </div>

          {imgCount > 1 && (
            <div className="item-card__photo-count">
              {'\u{1F4F7}'} {imgCount}
            </div>
          )}

          {(isSold || isResv) && (
            <div className="item-card__overlay">
              <span
                className="item-card__status"
                style={{ background: isSold ? '#ef4444' : '#f59e0b' }}
              >
                {isSold ? 'SOLD' : 'RESERVED'}
              </span>
            </div>
          )}
        </div>

        <div className="item-card__body">
          <div className="item-card__meta">
            <span className="item-card__category">
              {icon} {item.category?.name || 'Other'}
            </span>
            {item.condition && (
              <span
                className="item-card__condition"
                style={{
                  background: condStyle.bg,
                  color: condStyle.color,
                }}
              >
                {CONDITION_LABELS[item.condition]}
              </span>
            )}
          </div>

          <h3 className="item-card__title">{item.title}</h3>

          <div className="item-card__footer">
            <span
              className="item-card__price"
              style={{
                color: isSold ? '#5a6285' : '#5b4bff',
                textDecoration: isSold ? 'line-through' : 'none',
              }}
            >
              {item.donation ? 'Free' : `INR ${item.price?.toLocaleString('en-IN')}`}
            </span>

            <div className="item-card__seller">
              <div className="item-card__seller-name">
                {item.seller?.name?.split(' ')[0]}
              </div>
              {item.seller?.collegeId && (
                <div className="item-card__seller-id">#{item.seller.collegeId}</div>
              )}
              {item.seller?.averageRating !== undefined &&
                item.seller?.averageRating !== null && (
                  <div className="item-card__rating">
                    {'\u2B50'} {item.seller.averageRating}
                    {item.seller?.totalReviews > 0 && (
                      <span className="item-card__rating-count">
                        ({item.seller.totalReviews})
                      </span>
                    )}
                  </div>
                )}
            </div>
          </div>

          {item.viewCount > 0 && (
            <div className="item-card__views">
              {'\u{1F441}'} {item.viewCount} views
            </div>
          )}
        </div>
      </div>
    </Link>
  );
}
