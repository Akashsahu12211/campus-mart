import React, { useCallback, useEffect, useState, useContext } from 'react';
import { AuthContext } from '../App';
import { useNavigate } from 'react-router-dom';
import { getReservedItems, unreserveItem } from '../api/api';
import '../styles/MyReservations.css';

export default function MyReservations() {
  const { user } = useContext(AuthContext);
  const navigate = useNavigate();
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState({ type: '', text: '' });

  const loadReservations = useCallback(async () => {
    if (!user?.id) return;
    try {
      setLoading(true);
      const res = await getReservedItems(user.id);
      setItems(res.data || []);
    } catch (e) {
      setMsg({ type: 'error', text: 'Failed to load reservations' });
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    if (!user) {
      navigate('/login');
      return;
    }
    loadReservations();
  }, [user, navigate, loadReservations]);

  const handleUnreserve = async (itemId) => {
    try {
      await unreserveItem(itemId);
      setMsg({ type: 'success', text: '✅ Reservation cancelled!' });
      loadReservations();
    } catch (e) {
      setMsg({ type: 'error', text: 'Failed to cancel reservation' });
    }
  };

  return (
    <div className="my-reservations">
      <div className="container">
        <h1>🔒 My Reservations</h1>
        <p className="subtitle">Items you've reserved - {items.length} total</p>

        {msg.text && (
          <div className={`alert alert-${msg.type}`}>
            {msg.text}
          </div>
        )}

        {loading ? (
          <div className="loading">Loading...</div>
        ) : items.length === 0 ? (
          <div className="empty-state">
            <h3>No Reserved Items Yet</h3>
            <p>Start browsing and reserve items you're interested in!</p>
            <button className="btn-primary" onClick={() => navigate('/')}>
              Browse Items
            </button>
          </div>
        ) : (
          <div className="reservations-grid">
            {items.map((item) => (
              <div key={item.id} className="reservation-card">
                <div className="item-image">
                  <img
                    src={item.imageUrls?.[0] || '/placeholder.png'}
                    alt={item.title}
                    onClick={() => navigate(`/item/${item.id}`)}
                  />
                  <span className="status-badge">🔒 RESERVED</span>
                </div>

                <div className="item-details">
                  <h3>{item.title}</h3>
                  <p className="price">₹{item.price?.toLocaleString('en-IN')}</p>

                  <div className="seller-info">
                    <strong>Seller:</strong> {item.seller?.name}
                    <br />
                    <strong>Phone:</strong> {item.seller?.phone}
                  </div>

                  <div className="item-meta">
                    <span className="condition">{item.condition}</span>
                    <span className="reserved-date">Reserved</span>
                  </div>

                  <div className="actions">
                    <button
                      className="btn-primary"
                      onClick={() => navigate(`/item/${item.id}`)}
                    >
                      View Details
                    </button>
                    <button
                      className="btn-secondary"
                      onClick={() => handleUnreserve(item.id)}
                    >
                      Cancel Reservation
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
