import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
  addReview,
  deleteReview,
  getAllCategories,
  getItemById,
  getSellerReviews,
  updateItem,
  updateReview,
  uploadItemImage,
} from '../api/api';
import { useAuth } from '../App';
import { buildListingMetadata } from '../utils/listingMetadata';

const CONDITIONS = [
  { val: 'NEW', label: 'New' },
  { val: 'LIKE_NEW', label: 'Like New' },
  { val: 'GOOD', label: 'Good' },
  { val: 'FAIR', label: 'Fair' },
  { val: 'POOR', label: 'Poor' },
];

export default function EditItem() {
  const { id } = useParams();
  const { user } = useAuth();
  const navigate = useNavigate();
  const [categories, setCategories] = useState([]);
  const [form, setForm] = useState({
    title: '',
    description: '',
    price: '',
    categoryId: '',
    condition: 'GOOD',
    negotiable: false,
    donation: false,
    bundle: false,
    bundleSize: '',
    bookAuthor: '',
    bookEdition: '',
    academicSubject: '',
    academicCourse: '',
    academicLevel: '',
    boardOrUniversity: '',
    publisher: '',
    isbn: '',
  });
  const [imageUrls, setImageUrls] = useState(['']);
  const [uploadingImages, setUploadingImages] = useState({});
  const [msg, setMsg] = useState({ type: '', text: '' });
  const [loading, setLoading] = useState(false);
  const [fetching, setFetching] = useState(true);
  const [sellerReview, setSellerReview] = useState(null);
  const [reviewRating, setReviewRating] = useState(5);
  const [reviewComment, setReviewComment] = useState('');

  useEffect(() => {
    Promise.all([getItemById(id), getAllCategories()])
      .then(([itemRes, catRes]) => {
        const item = itemRes.data;
        if (item.seller?.id !== user?.id) {
          navigate('/my-items');
          return null;
        }

        setForm({
          title: item.title || '',
          description: item.description || '',
          price: item.price || '',
          categoryId: item.category?.id || '',
          condition: item.condition || 'GOOD',
          negotiable: item.negotiable || false,
          donation: item.donation || false,
          bundle: item.bundle || false,
          bundleSize: item.bundleSize || '',
          bookAuthor: item.bookAuthor || '',
          bookEdition: item.bookEdition || '',
          academicSubject: item.academicSubject || '',
          academicCourse: item.academicCourse || '',
          academicLevel: item.academicLevel || '',
          boardOrUniversity: item.boardOrUniversity || '',
          publisher: item.publisher || '',
          isbn: item.isbn || '',
        });
        setImageUrls(item.imageUrls?.length > 0 ? item.imageUrls : ['']);
        setCategories(catRes.data);
        return getSellerReviews(item.seller?.id);
      })
      .then((reviewRes) => {
        if (!reviewRes) return;
        const reviews = reviewRes.data?.reviews || [];
        const myReview = reviews.find((review) => review.itemId === parseInt(id, 10) && review.reviewer?.id === user?.id);
        if (myReview) {
          setSellerReview(myReview);
          setReviewRating(myReview.rating);
          setReviewComment(myReview.comment || '');
        }
      })
      .catch(() => setMsg({ type: 'error', text: 'Item not found.' }))
      .finally(() => setFetching(false));
  }, [id, navigate, user?.id]);

  const selectedCategory = useMemo(
    () => categories.find((category) => category.id === parseInt(form.categoryId, 10)),
    [categories, form.categoryId],
  );

  const isBookCategory = Boolean(selectedCategory?.name?.toLowerCase().includes('book'));
  const hasUploadingImages = Object.values(uploadingImages).some(Boolean);

  const handleChange = (event) => {
    const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
    setForm((current) => ({ ...current, [event.target.name]: value }));
  };

  const handleImageUpload = async (file, index) => {
    if (!file) return;
    if (file.size > 6 * 1024 * 1024) {
      setMsg({ type: 'error', text: 'Each image must be 6MB or smaller.' });
      return;
    }

    setUploadingImages((current) => ({ ...current, [index]: true }));
    try {
      const response = await uploadItemImage(file);
      setImageUrls((current) => {
        const next = [...current];
        next[index] = response.data.url;
        return next;
      });
    } catch (error) {
      setMsg({ type: 'error', text: error.response?.data?.error || 'Image upload failed.' });
    } finally {
      setUploadingImages((current) => {
        const next = { ...current };
        delete next[index];
        return next;
      });
    }
  };

  const handleSubmit = async (event) => {
    event.preventDefault();
    if (!form.title.trim() || !form.price || !form.categoryId) {
      setMsg({ type: 'error', text: 'Title, price and category are required.' });
      return;
    }
    if (form.bundle && (!form.bundleSize || Number(form.bundleSize) < 2)) {
      setMsg({ type: 'error', text: 'Bundle size should be at least 2.' });
      return;
    }
    if (hasUploadingImages) {
      setMsg({ type: 'error', text: 'Please wait for image uploads to finish.' });
      return;
    }

    setLoading(true);
    try {
      const validImages = imageUrls.filter((url) => url.trim() !== '');
      await updateItem(id, {
        title: form.title.trim(),
        description: form.description,
        price: form.donation ? 0 : parseFloat(form.price),
        imageUrls: validImages,
        condition: form.condition,
        negotiable: form.donation ? false : form.negotiable,
        categoryId: parseInt(form.categoryId, 10),
        ...buildListingMetadata({
          categoryName: selectedCategory?.name,
          title: form.title,
          description: form.description,
          donation: form.donation,
          bundle: form.bundle,
          bundleSize: form.bundle ? Number(form.bundleSize || 0) : null,
          bookAuthor: form.bookAuthor,
          bookEdition: form.bookEdition,
          academicSubject: form.academicSubject,
          academicCourse: form.academicCourse,
          academicLevel: form.academicLevel,
          boardOrUniversity: form.boardOrUniversity,
          publisher: form.publisher,
          isbn: form.isbn,
        }),
      });

      if (reviewRating > 0 || reviewComment.trim()) {
        try {
          if (sellerReview) {
            await updateReview(sellerReview.id, {
              rating: reviewRating,
              comment: reviewComment.trim(),
            });
          } else {
            await addReview({
              rating: reviewRating,
              comment: reviewComment.trim(),
              itemId: parseInt(id, 10),
              sellerId: user.id,
            });
          }
        } catch (_) {}
      }

      setMsg({ type: 'success', text: 'Item updated.' });
      setTimeout(() => navigate('/my-items'), 1200);
    } catch (error) {
      setMsg({ type: 'error', text: error.response?.data?.error || 'Update failed.' });
    } finally {
      setLoading(false);
    }
  };

  if (fetching) {
    return <div className="page loading-wrap"><div className="spinner" /></div>;
  }

  return (
    <div className="page" style={{ display: 'flex', justifyContent: 'center' }}>
      <div style={{ width: '100%', maxWidth: '580px' }}>
        <h1 style={{ fontFamily: "'Syne',sans-serif", fontSize: '1.8rem', marginBottom: '24px' }}>Edit Listing</h1>

        {msg.text && <div className={`alert alert-${msg.type === 'success' ? 'success' : 'error'}`}>{msg.text}</div>}

        <form onSubmit={handleSubmit}>
          <div className="card" style={{ padding: '24px', marginBottom: '14px' }}>
            <div className="form-group">
              <label className="form-label">Title *</label>
              <input name="title" value={form.title} onChange={handleChange} className="form-input" />
            </div>
            <div className="form-group">
              <label className="form-label">Description</label>
              <textarea name="description" value={form.description} onChange={handleChange} className="form-textarea" />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Price (INR) *</label>
                <input name="price" type="number" min="0" value={form.price} onChange={handleChange} className="form-input" />
              </div>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Category *</label>
                <select name="categoryId" value={form.categoryId} onChange={handleChange} className="form-select">
                  <option value="">Select...</option>
                  {categories.map((category) => <option key={category.id} value={category.id}>{category.name}</option>)}
                </select>
              </div>
            </div>
            <div style={{ display: 'flex', gap: '8px', marginTop: '14px', flexWrap: 'wrap' }}>
              {CONDITIONS.map((condition) => (
                <button
                  key={condition.val}
                  type="button"
                  onClick={() => setForm((current) => ({ ...current, condition: condition.val }))}
                  style={{
                    padding: '6px 14px',
                    borderRadius: '8px',
                    cursor: 'pointer',
                    fontFamily: "'Plus Jakarta Sans',sans-serif",
                    fontWeight: 600,
                    fontSize: '0.82rem',
                    border: `1.5px solid ${form.condition === condition.val ? '#5b4bff' : '#1e2438'}`,
                    background: form.condition === condition.val ? 'rgba(91,75,255,0.1)' : 'transparent',
                    color: form.condition === condition.val ? '#a89dff' : '#5a6285',
                  }}
                >
                  {condition.label}
                </button>
              ))}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '14px' }}>
              <input type="checkbox" id="donation" name="donation" checked={form.donation} onChange={handleChange} style={{ width: '16px', height: '16px', accentColor: '#f59e0b' }} />
              <label htmlFor="donation" style={{ cursor: 'pointer', fontWeight: 600, fontSize: '0.88rem' }}>Donation / free giveaway</label>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '14px' }}>
              <input type="checkbox" id="negotiable" name="negotiable" checked={form.negotiable} onChange={handleChange} style={{ width: '16px', height: '16px', accentColor: '#5b4bff' }} />
              <label htmlFor="negotiable" style={{ cursor: 'pointer', fontWeight: 600, fontSize: '0.88rem' }}>Price is negotiable</label>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '14px' }}>
              <input type="checkbox" id="bundle" name="bundle" checked={form.bundle} onChange={handleChange} style={{ width: '16px', height: '16px', accentColor: '#00d4aa' }} />
              <label htmlFor="bundle" style={{ cursor: 'pointer', fontWeight: 600, fontSize: '0.88rem' }}>Selling as bundle</label>
            </div>
            {form.bundle && (
              <div className="form-group" style={{ marginTop: '14px', marginBottom: 0 }}>
                <label className="form-label">Bundle Size *</label>
                <input name="bundleSize" type="number" min="2" value={form.bundleSize} onChange={handleChange} className="form-input" />
              </div>
            )}
          </div>

          {isBookCategory && (
            <div className="card" style={{ padding: '24px', marginBottom: '16px' }}>
              <h3 style={{ fontFamily: "'Syne',sans-serif", marginBottom: '14px', fontSize: '0.95rem', color: '#a0a8c8' }}>Book Details</h3>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
                <div className="form-group" style={{ marginBottom: 0 }}><label className="form-label">Subject</label><input name="academicSubject" value={form.academicSubject} onChange={handleChange} className="form-input" /></div>
                <div className="form-group" style={{ marginBottom: 0 }}><label className="form-label">Author</label><input name="bookAuthor" value={form.bookAuthor} onChange={handleChange} className="form-input" /></div>
                <div className="form-group" style={{ marginBottom: 0 }}><label className="form-label">Edition</label><input name="bookEdition" value={form.bookEdition} onChange={handleChange} className="form-input" /></div>
                <div className="form-group" style={{ marginBottom: 0 }}><label className="form-label">Course / Stream</label><input name="academicCourse" value={form.academicCourse} onChange={handleChange} className="form-input" /></div>
                <div className="form-group" style={{ marginBottom: 0 }}><label className="form-label">Class / Semester</label><input name="academicLevel" value={form.academicLevel} onChange={handleChange} className="form-input" /></div>
                <div className="form-group" style={{ marginBottom: 0 }}><label className="form-label">Board / University</label><input name="boardOrUniversity" value={form.boardOrUniversity} onChange={handleChange} className="form-input" /></div>
                <div className="form-group" style={{ marginBottom: 0 }}><label className="form-label">Publisher</label><input name="publisher" value={form.publisher} onChange={handleChange} className="form-input" /></div>
                <div className="form-group" style={{ marginBottom: 0 }}><label className="form-label">ISBN</label><input name="isbn" value={form.isbn} onChange={handleChange} className="form-input" /></div>
              </div>
            </div>
          )}

          <div className="card" style={{ padding: '24px', marginBottom: '16px', border: '2px solid rgba(91,75,255,0.2)', background: 'rgba(91,75,255,0.04)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
              <h3 style={{ fontFamily: "'Syne',sans-serif", margin: 0, fontSize: '0.95rem', color: '#a0a8c8' }}>
                Your Item Review {sellerReview ? '(Edit)' : '(Add one)'}
              </h3>
              {sellerReview && (
                <button
                  type="button"
                  onClick={async () => {
                    if (window.confirm('Delete this review?')) {
                      try {
                        await deleteReview(sellerReview.id);
                        setSellerReview(null);
                        setReviewRating(5);
                        setReviewComment('');
                        setMsg({ type: 'success', text: 'Review deleted.' });
                      } catch (_) {
                        setMsg({ type: 'error', text: 'Failed to delete review.' });
                      }
                    }
                  }}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#EF4444', fontSize: '1rem', padding: '4px 8px' }}
                >
                  Delete
                </button>
              )}
            </div>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 600, color: '#a0a8c8', fontSize: '0.9rem' }}>Rating:</label>
              <div style={{ display: 'flex', gap: '6px' }}>
                {[1, 2, 3, 4, 5].map((star) => (
                  <button
                    key={star}
                    type="button"
                    onClick={() => setReviewRating(star)}
                    style={{
                      fontSize: '26px',
                      background: 'none',
                      border: 'none',
                      cursor: 'pointer',
                      transform: reviewRating >= star ? 'scale(1.1)' : 'scale(1)',
                      transition: 'transform 0.1s',
                      color: reviewRating >= star ? '#F5C451' : '#5a6285',
                    }}
                  >
                    {reviewRating >= star ? '★' : '☆'}
                  </button>
                ))}
              </div>
            </div>

            <div className="form-group" style={{ marginBottom: 0 }}>
              <label className="form-label">Comment:</label>
              <textarea
                value={reviewComment}
                onChange={(event) => setReviewComment(event.target.value)}
                style={{
                  width: '100%',
                  minHeight: '80px',
                  padding: '12px',
                  borderRadius: '10px',
                  border: '1px solid #1e2438',
                  background: '#080b14',
                  color: '#fff',
                  fontFamily: "'Plus Jakarta Sans',sans-serif",
                  fontSize: '0.9rem',
                  resize: 'vertical',
                }}
              />
            </div>
          </div>

          <div className="card" style={{ padding: '24px', marginBottom: '16px' }}>
            <h3 style={{ fontFamily: "'Syne',sans-serif", marginBottom: '12px', fontSize: '0.95rem', color: '#a0a8c8' }}>Photos</h3>
            {imageUrls.map((url, index) => (
              <div key={index} style={{ display: 'flex', gap: '8px', marginBottom: '8px', alignItems: 'center' }}>
                <input
                  value={url}
                  readOnly
                  placeholder={`Image ${index + 1} URL`}
                  className="form-input"
                  style={{ flex: 1 }}
                />
                <label className="btn btn-ghost btn-sm" style={{ cursor: 'pointer', flexShrink: 0 }}>
                  {uploadingImages[index] ? 'Uploading...' : 'Upload'}
                  <input
                    type="file"
                    accept="image/*"
                    style={{ display: 'none' }}
                    onChange={async (event) => {
                      const file = event.target.files?.[0];
                      await handleImageUpload(file, index);
                      event.target.value = '';
                    }}
                  />
                </label>
                {url && (
                  <div style={{ width: '40px', height: '40px', borderRadius: '6px', overflow: 'hidden', flexShrink: 0 }}>
                    <img src={url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} onError={(event) => { event.target.style.display = 'none'; }} />
                  </div>
                )}
                <button
                  type="button"
                  onClick={() => {
                    if (imageUrls.length === 1) {
                      setImageUrls(['']);
                      return;
                    }
                    setImageUrls((current) => current.filter((_, imageIndex) => imageIndex !== index));
                  }}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#ef4444', fontSize: '1rem', flexShrink: 0 }}
                >
                  x
                </button>
              </div>
            ))}
            {imageUrls.length < 20 && (
              <button type="button" onClick={() => setImageUrls((current) => [...current, ''])} className="btn btn-ghost btn-sm">+ Add Photo</button>
            )}
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <button type="button" onClick={() => navigate('/my-items')} className="btn btn-secondary" style={{ flex: 1 }}>Cancel</button>
            <button type="submit" className="btn btn-primary" style={{ flex: 2 }} disabled={loading || hasUploadingImages}>
              {loading ? 'Saving...' : hasUploadingImages ? 'Uploading images...' : 'Save Changes'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
