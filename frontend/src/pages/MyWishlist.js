import React, { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getWishlist, removeFromWishlist } from '../api/api';
import { useAuth } from '../App';
import '../styles/MyWishlist.css';

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

export default function MyWishlist() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [wishlistItems, setWishlistItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState({ type: '', text: '' });

  const loadWishlist = useCallback(async () => {
    if (!user?.id) return;
    try {
      setLoading(true);
      const res = await getWishlist(user.id);
      setWishlistItems(res.data || []);
    } catch (e) {
      setMsg({ type: 'error', text: '❌ Failed to load wishlist' });
      console.error('Wishlist fetch error:', e);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    if (!user) {
      navigate('/login');
      return;
    }
    loadWishlist();
  }, [user, navigate, loadWishlist]);

  const handleRemove = async (itemId) => {
    try {
      await removeFromWishlist(user.id, itemId);
      setMsg({ type: 'success', text: '❌ Removed from wishlist' });
      setWishlistItems(prev => prev.filter(w => w.item?.id !== itemId));
      setTimeout(() => setMsg({ type: '', text: '' }), 2000);
    } catch (e) {
      setMsg({ type: 'error', text: '❌ Failed to remove' });
      console.error('Remove error:', e);
    }
  };

  const handleViewItem = (itemId) => {
    navigate(`/item/${itemId}`);
  };

  if (loading) {
    return (
      <div className="wishlist-container">
        <div className="loading-state">
          <div className="spinner"></div>
          <p>Loading your wishlist...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="wishlist-container">
      <div className="wishlist-header">
        <h1>❤️ My Wishlist</h1>
        <p className="wishlist-count">
          {wishlistItems.length === 0 ? 'No items yet' : `${wishlistItems.length} item${wishlistItems.length !== 1 ? 's' : ''}`}
        </p>
      </div>

      {msg.text && (
        <div className={`alert alert-${msg.type}`}>
          {msg.text}
        </div>
      )}

      {wishlistItems.length === 0 ? (
        <div className="empty-state">
          <div className="empty-icon">💔</div>
          <h2>Your Wishlist is Empty</h2>
          <p>Start adding items you like!</p>
          <button className="btn btn-primary" onClick={() => navigate('/')}>
            Browse Items
          </button>
        </div>
      ) : (
        <div className="wishlist-grid">
          {wishlistItems.map((wishlist) => {
            const item = wishlist.item;
            if (!item) return null;

            const icon = CAT_ICONS[item.category?.name] || '📦';
            const sold = item.status === 'SOLD';
            const reserved = item.status === 'RESERVED';

            return (
              <div key={wishlist.id} className="wishlist-card">
                {/* Image Section */}
                <div className="card-image-container">
                  <img
                    src={item.imageUrls?.[0] || '/placeholder.png'}
                    alt={item.title}
                    className="card-image"
                    onClick={() => handleViewItem(item.id)}
                  />
                  <div className="card-badge">
                    {sold ? (
                      <span className="badge badge-sold">SOLD</span>
                    ) : reserved ? (
                      <span className="badge badge-reserved">RESERVED</span>
                    ) : (
                      <span className="badge badge-available">AVAILABLE</span>
                    )}
                  </div>
                  <button
                    className="wishlist-btn active"
                    onClick={() => handleRemove(item.id)}
                    title="Remove from wishlist"
                  >
                    ❤️
                  </button>
                </div>

                {/* Item Details */}
                <div className="card-details">
                  <div className="card-category">
                    <span>{icon} {item.category?.name || 'Other'}</span>
                  </div>

                  <h3
                    className="card-title"
                    onClick={() => handleViewItem(item.id)}
                  >
                    {item.title}
                  </h3>

                  <div className="card-price">
                    <span className="price">₹{item.price}</span>
                  </div>

                  <div className="card-seller">
                    <span className="seller-name">
                      👤 {item.seller?.name || 'Unknown'}
                    </span>
                  </div>

                  <div className="card-actions">
                    <button
                      className="btn btn-sm btn-outline"
                      onClick={() => handleViewItem(item.id)}
                    >
                      View Details
                    </button>
                    <button
                      className="btn btn-sm btn-danger"
                      onClick={() => handleRemove(item.id)}
                    >
                      Remove ✕
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
