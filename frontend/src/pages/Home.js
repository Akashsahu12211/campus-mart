import React, { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { getAllCategories, getPaginatedItems } from '../api/api';
import { useAuth } from '../App';
import ItemCard from '../components/ItemCard';
import { useLanguage } from '../context/LanguageContext';
import '../styles/Home.css';
import { getRecentItems } from '../utils/recentItems';

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

const CONDITIONS = [
  { value: '', label: 'Any Condition' },
  { value: 'NEW', label: 'New' },
  { value: 'LIKE_NEW', label: 'Like New' },
  { value: 'GOOD', label: 'Good' },
  { value: 'FAIR', label: 'Fair' },
  { value: 'POOR', label: 'Poor' },
];

const sectionSubtitleStyle = {
  margin: '4px 0 0',
  color: '#718096',
  fontSize: '0.85rem',
};

const paginationMetaStyle = {
  display: 'flex',
  alignItems: 'center',
  gap: '8px',
  color: '#A0AEC0',
  fontSize: '14px',
  flexWrap: 'wrap',
  justifyContent: 'center',
};

const paginationButtonStyle = (disabled) => ({
  padding: '10px 16px',
  borderRadius: '8px',
  border: '1px solid #5B4BFF',
  background: disabled ? 'transparent' : 'rgba(91,75,255,0.1)',
  color: disabled ? '#718096' : '#5B4BFF',
  cursor: disabled ? 'not-allowed' : 'pointer',
  fontWeight: 700,
  transition: 'all 0.3s',
});

export default function Home() {
  const { user } = useAuth();
  const { t } = useLanguage();
  const [items, setItems] = useState([]);
  const [categories, setCategories] = useState([]);
  const [activeCat, setActiveCat] = useState(null);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [pageSize] = useState(20);
  const [totalPages, setTotalPages] = useState(0);
  const [sortBy, setSortBy] = useState('newest');
  const [minPrice, setMinPrice] = useState('');
  const [maxPrice, setMaxPrice] = useState('');
  const [condition, setCondition] = useState('');
  const [hostel, setHostel] = useState('');
  const [branch, setBranch] = useState('');
  const [locationFilter, setLocationFilter] = useState(null);
  const [locationSource, setLocationSource] = useState(null);
  const [recentItems, setRecentItems] = useState([]);

  const hasAdvancedFilters = Boolean(
    minPrice ||
      maxPrice ||
      condition ||
      hostel.trim() ||
      branch.trim(),
  );

  const fetchItems = useCallback(async () => {
    setLoading(true);
    try {
      const res = await getPaginatedItems({
        page,
        pageSize,
        sort: sortBy,
        ...(activeCat ? { categoryId: activeCat } : {}),
        ...(query.trim() ? { q: query.trim() } : {}),
        ...(minPrice ? { minPrice: Number(minPrice) } : {}),
        ...(maxPrice ? { maxPrice: Number(maxPrice) } : {}),
        ...(condition ? { condition } : {}),
        ...(hostel.trim() ? { hostel: hostel.trim() } : {}),
        ...(branch.trim() ? { branch: branch.trim() } : {}),
        ...(locationFilter || {}),
      });

      setItems(res.data.content || []);
      setTotal(res.data.totalElements || 0);
      setTotalPages(res.data.totalPages || 1);
    } catch (err) {
      console.error('Fetch error:', err);
      setItems([]);
      setTotal(0);
      setTotalPages(1);
    } finally {
      setLoading(false);
    }
  }, [
    activeCat,
    branch,
    condition,
    hostel,
    locationFilter,
    maxPrice,
    minPrice,
    page,
    pageSize,
    query,
    sortBy,
  ]);

  useEffect(() => {
    fetchItems();
  }, [fetchItems]);

  useEffect(() => {
    getAllCategories()
      .then((response) => setCategories(response.data))
      .catch((err) => console.error('Category fetch error:', err));
  }, []);

  useEffect(() => {
    setRecentItems(getRecentItems());
  }, [items]);

  const handleSearch = (event) => {
    event.preventDefault();
    setActiveCat(null);
    setPage(0);
    fetchItems();
  };

  const handleCategoryClick = (catId) => {
    setActiveCat(catId);
    setPage(0);
  };

  const clearFilters = () => {
    setActiveCat(null);
    setQuery('');
    setMinPrice('');
    setMaxPrice('');
    setCondition('');
    setHostel('');
    setBranch('');
    setLocationFilter(null);
    setLocationSource(null);
    setSortBy('newest');
    setPage(0);
  };

  const applyNearMe = () => {
    if (!navigator.geolocation) {
      if (user?.latitude != null && user?.longitude != null) {
        setLocationFilter({
          userLat: user.latitude,
          userLng: user.longitude,
          radiusKm: 8,
        });
        setLocationSource('saved');
        setSortBy('nearby');
      }
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        setLocationFilter({
          userLat: position.coords.latitude,
          userLng: position.coords.longitude,
          radiusKm: 8,
        });
        setLocationSource('current');
        setSortBy('nearby');
        setPage(0);
      },
      () => {
        if (user?.latitude != null && user?.longitude != null) {
          setLocationFilter({
            userLat: user.latitude,
            userLng: user.longitude,
            radiusKm: 8,
          });
          setLocationSource('saved');
          setSortBy('nearby');
          setPage(0);
        }
      },
    );
  };

  const recentVisibleItems = recentItems
    .filter((saved) => saved?.id !== undefined)
    .slice(0, 6);
  const nearbyBookItems = items
    .filter((item) => item.listingType === 'BOOK')
    .slice(0, 4);

  const chipVars = (active = false) => ({
    '--chip-border': active ? '#5b4bff' : '#252d45',
    '--chip-bg': active ? '#5b4bff' : '#141929',
    '--chip-color': active ? '#fff' : '#a0a8c8',
  });

  return (
    <div className="page home-page">
      <section className="fade-up home-hero">
        <div className="home-hero-badge">
          {'\u{1F393}'} COLLEGE STUDENT MARKETPLACE
        </div>

        <h1 className="home-hero-title">
          Buy & Sell on
          <br />
          <span className="home-hero-title-accent">Your Campus</span>
        </h1>

        <p className="home-hero-subtitle">
          Books, electronics, cycles and more - from students, for students.
        </p>

        <form onSubmit={handleSearch} className="home-search-form">
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t(
              'searchPlaceholder',
              'Search items - books, laptop, cycle...',
            )}
            className="form-input home-search-input"
          />
          <button
            type="submit"
            className="btn btn-primary btn-sm home-search-button"
          >
            {t('search', 'Search')}
          </button>
        </form>

        <div className="home-filter-grid">
          <input
            value={minPrice}
            onChange={(e) => setMinPrice(e.target.value)}
            placeholder="Min Price"
            className="form-input home-filter-control"
          />
          <input
            value={maxPrice}
            onChange={(e) => setMaxPrice(e.target.value)}
            placeholder="Max Price"
            className="form-input home-filter-control"
          />
          <select
            value={condition}
            onChange={(e) => setCondition(e.target.value)}
            className="home-filter-control home-filter-select"
          >
            {CONDITIONS.map((opt) => (
              <option key={opt.value || 'any'} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
          <input
            value={hostel}
            onChange={(e) => setHostel(e.target.value)}
            placeholder="Hostel"
            className="form-input home-filter-control"
          />
          <input
            value={branch}
            onChange={(e) => setBranch(e.target.value)}
            placeholder="Department / Branch"
            className="form-input home-filter-control home-filter-control--wide"
          />
        </div>

        <div className="home-stats-row">
          <button
            type="button"
            className="home-chip"
            onClick={applyNearMe}
            style={chipVars(Boolean(locationFilter))}
          >
            {'\u{1F4CD}'} {t('locationNearMe', 'Near Me')}
          </button>

          {user?.latitude != null && user?.longitude != null && (
            <button
              type="button"
              className="home-chip"
              onClick={() => {
                setLocationFilter({
                  userLat: user.latitude,
                  userLng: user.longitude,
                  radiusKm: 8,
                });
                setLocationSource('saved');
                setSortBy('nearby');
                setPage(0);
              }}
              style={chipVars(Boolean(locationFilter && user.latitude != null))}
            >
              {'\u{1F9ED}'} {t('locationSaved', 'Saved Area')}
            </button>
          )}

          {[
            { icon: '\u{1F4E6}', label: 'Items Listed', val: total },
            {
              icon: '\u{1F5C2}\uFE0F',
              label: 'Categories',
              val: categories.length,
            },
            { icon: '\u{1F50D}', label: 'Search Results', val: items.length },
          ].map(({ icon, label, val }) => (
            <div key={label} className="home-stat-chip">
              {icon} <strong>{val}</strong> {label}
            </div>
          ))}
        </div>

        {locationSource && (
          <p className="home-location-note">
            Discovery mode:{' '}
            {locationSource === 'current'
              ? 'current location'
              : `saved area${
                  user?.locationLabel ? ` (${user.locationLabel})` : ''
                }`}
          </p>
        )}
      </section>

      <section className="home-category-row">
        <button
          type="button"
          className="home-chip home-chip--category"
          onClick={clearFilters}
          style={chipVars(!activeCat)}
        >
          All Items
        </button>

        {categories.map((cat) => (
          <button
            key={cat.id}
            type="button"
            className="home-chip home-chip--category"
            onClick={() => handleCategoryClick(cat.id)}
            style={chipVars(activeCat === cat.id)}
          >
            {CAT_ICONS[cat.name] || '\u{1F4E6}'} {cat.name}
          </button>
        ))}
      </section>

      {loading ? (
        <div className="loading-wrap">
          <div className="spinner" />
        </div>
      ) : items.length === 0 ? (
        <div className="empty-state home-empty-state">
          <span className="emoji">{'\u{1F6D2}'}</span>
          <h3>No items found</h3>
          <p>Try different keywords or browse all categories</p>
          {user && (
            <Link
              to="/add-item"
              className="btn btn-primary btn-sm home-empty-action"
            >
              Be the first to list!
            </Link>
          )}
        </div>
      ) : (
        <>
          <section className="home-toolbar">
            <p className="home-results-meta">
              {loading
                ? 'Loading...'
                : `${total} item${total !== 1 ? 's' : ''} found${
                    hasAdvancedFilters ? ' \u00B7 filtered' : ''
                  }${locationFilter ? ' \u00B7 nearby' : ''}`}
            </p>

            <div className="home-toolbar-actions">
              <button
                type="button"
                onClick={clearFilters}
                className="btn btn-ghost btn-sm home-toolbar-button"
              >
                Reset Filters
              </button>

              <select
                value={sortBy}
                onChange={(e) => {
                  setSortBy(e.target.value);
                  setPage(0);
                }}
                className="home-sort-select"
              >
                <option value="newest">Newest First</option>
                <option value="nearby">Nearby First</option>
                <option value="price_low">Price: Low to High</option>
                <option value="price_high">Price: High to Low</option>
              </select>

              {user && (
                <Link
                  to="/add-item"
                  className="btn btn-primary btn-sm home-sell-cta"
                >
                  + Sell Something
                </Link>
              )}
            </div>
          </section>

          <div className="items-grid home-items-grid">
            {items.map((item, index) => (
              <div
                key={item.id}
                className="fade-up"
                style={{ animationDelay: `${Math.min(index * 0.04, 0.4)}s` }}
              >
                <ItemCard item={item} />
              </div>
            ))}
          </div>

          {recentVisibleItems.length > 0 && (
            <section className="home-secondary-section">
              <div className="home-secondary-header">
                <div>
                  <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 800 }}>
                    Recently Viewed
                  </h3>
                  <p style={sectionSubtitleStyle}>Last items you opened.</p>
                </div>
              </div>

              <div className="items-grid home-items-grid">
                {recentVisibleItems.map((item, index) => (
                  <div
                    key={`recent-${item.id}`}
                    className="fade-up"
                    style={{
                      animationDelay: `${Math.min(index * 0.04, 0.3)}s`,
                    }}
                  >
                    <ItemCard item={item} />
                  </div>
                ))}
              </div>
            </section>
          )}

          {nearbyBookItems.length > 0 && (
            <section className="home-secondary-section">
              <div className="home-secondary-header">
                <div>
                  <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 800 }}>
                    Book Spotlight
                  </h3>
                  <p style={sectionSubtitleStyle}>
                    Active book listings surfaced from current discovery results.
                  </p>
                </div>
              </div>

              <div className="items-grid home-items-grid">
                {nearbyBookItems.map((item, index) => (
                  <div
                    key={`book-${item.id}`}
                    className="fade-up"
                    style={{
                      animationDelay: `${Math.min(index * 0.04, 0.3)}s`,
                    }}
                  >
                    <ItemCard item={item} />
                  </div>
                ))}
              </div>
            </section>
          )}

          {totalPages > 1 && (
            <div className="home-pagination">
              <button
                type="button"
                onClick={() => setPage(Math.max(0, page - 1))}
                disabled={page === 0}
                style={paginationButtonStyle(page === 0)}
              >
                {'\u2190'} Previous
              </button>

              <div style={paginationMetaStyle}>
                <span>
                  Page{' '}
                  <strong style={{ color: '#5B4BFF', fontSize: '16px' }}>
                    {page + 1}
                  </strong>{' '}
                  of{' '}
                  <strong style={{ color: '#5B4BFF', fontSize: '16px' }}>
                    {totalPages}
                  </strong>
                </span>
                <span style={{ color: '#718096' }}>({total} total items)</span>
              </div>

              <button
                type="button"
                onClick={() => setPage(Math.min(totalPages - 1, page + 1))}
                disabled={page >= totalPages - 1}
                style={paginationButtonStyle(page >= totalPages - 1)}
              >
                Next {'\u2192'}
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
