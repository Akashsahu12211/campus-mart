import React, { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { addItem, addReview, getAllCategories, uploadItemImage } from '../api/api';
import { useAuth } from '../App';
import { buildListingMetadata } from '../utils/listingMetadata';

const CONDITIONS = [
  { val: 'NEW', label: 'Brand New', desc: 'Never used' },
  { val: 'LIKE_NEW', label: 'Like New', desc: 'Barely used' },
  { val: 'GOOD', label: 'Good', desc: 'Minor wear' },
  { val: 'FAIR', label: 'Fair', desc: 'Visible wear' },
  { val: 'POOR', label: 'Poor', desc: 'Heavy wear' },
];

const MAX_IMAGES = 20;

export default function AddItem() {
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
  const [imageUrls, setImageUrls] = useState(['', '', '', '', '']);
  const [uploadingImages, setUploadingImages] = useState({});
  const [errors, setErrors] = useState({});
  const [serverMsg, setServerMsg] = useState({ type: '', text: '' });
  const [loading, setLoading] = useState(false);
  const [reviewRating, setReviewRating] = useState(5);
  const [reviewComment, setReviewComment] = useState('');

  useEffect(() => {
    getAllCategories().then((response) => setCategories(response.data)).catch(() => {});
  }, []);

  const selectedCategory = useMemo(
    () => categories.find((category) => category.id === parseInt(form.categoryId, 10)),
    [categories, form.categoryId],
  );

  const isBookCategory = Boolean(selectedCategory?.name?.toLowerCase().includes('book'));
  const hasUploadingImages = Object.values(uploadingImages).some(Boolean);

  const handleChange = (event) => {
    const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
    setForm((current) => ({ ...current, [event.target.name]: value }));
    if (errors[event.target.name]) {
      setErrors((current) => ({ ...current, [event.target.name]: '' }));
    }
  };

  const validate = () => {
    const nextErrors = {};
    if (!form.title.trim()) nextErrors.title = 'Title is required.';
    if ((!form.donation && (!form.price || Number.isNaN(Number(form.price)) || Number(form.price) <= 0))
      || (form.donation && (form.price === '' || Number.isNaN(Number(form.price)) || Number(form.price) < 0))) {
      nextErrors.price = form.donation
        ? 'Donation item price should be zero or positive.'
        : 'Enter a valid price.';
    }
    if (!form.categoryId) nextErrors.categoryId = 'Select a category.';
    if (form.bundle && (!form.bundleSize || Number(form.bundleSize) < 2)) {
      nextErrors.bundleSize = 'Bundle size should be at least 2.';
    }
    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const handleImageUpload = async (file, index) => {
    if (!file) return;
    if (file.size > 6 * 1024 * 1024) {
      setServerMsg({ type: 'error', text: 'Each image must be 6MB or smaller.' });
      return;
    }

    setUploadingImages((current) => ({ ...current, [index]: true }));
    setServerMsg({ type: '', text: '' });
    try {
      const response = await uploadItemImage(file);
      setImageUrls((current) => {
        const next = [...current];
        next[index] = response.data.url;
        return next;
      });
    } catch (error) {
      setServerMsg({
        type: 'error',
        text: error.response?.data?.error || 'Image upload failed.',
      });
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
    if (!validate()) return;
    if (hasUploadingImages) {
      setServerMsg({ type: 'error', text: 'Please wait for image uploads to finish.' });
      return;
    }

    setLoading(true);
    setServerMsg({ type: '', text: '' });
    try {
      const validImages = imageUrls.filter((url) => url.trim() !== '');
      const payload = {
        title: form.title.trim(),
        description: form.description.trim(),
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
          academicSubject: form.academicSubject || (isBookCategory ? form.title : ''),
          academicCourse: form.academicCourse,
          academicLevel: form.academicLevel,
          boardOrUniversity: form.boardOrUniversity,
          publisher: form.publisher,
          isbn: form.isbn,
        }),
      };

      const result = await addItem(payload);

      if (reviewRating > 0 || reviewComment.trim()) {
        void addReview({
          rating: reviewRating,
          comment: reviewComment.trim(),
          itemId: result.data.id,
          sellerId: user.id,
        }).catch(() => {});
      }

      setServerMsg({ type: 'success', text: 'Item listed successfully.' });
      setTimeout(() => navigate('/my-items'), 700);
    } catch (error) {
      setServerMsg({
        type: 'error',
        text: error.response?.data?.error || 'Failed to list item.',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="page" style={{ display: 'flex', justifyContent: 'center' }}>
      <div style={{ width: '100%', maxWidth: '600px' }}>
        <div style={{ marginBottom: '28px' }}>
          <h1 style={{ fontFamily: "'Syne',sans-serif", fontSize: '2rem', marginBottom: '4px' }}>List an Item</h1>
          <p style={{ color: '#a0a8c8', fontSize: '0.9rem' }}>Sell your stuff to fellow students</p>
        </div>

        {serverMsg.text && (
          <div className={`alert alert-${serverMsg.type === 'success' ? 'success' : 'error'}`}>
            {serverMsg.text}
          </div>
        )}

        <form onSubmit={handleSubmit}>
          <div className="card" style={{ padding: '24px', marginBottom: '16px' }}>
            <h3 style={{ fontFamily: "'Syne',sans-serif", marginBottom: '18px', fontSize: '1rem', color: '#a0a8c8' }}>
              Basic Information
            </h3>

            <div className="form-group">
              <label className="form-label">Item Title *</label>
              <input
                name="title"
                value={form.title}
                onChange={handleChange}
                placeholder="e.g. DBMS Textbook by Navathe - 7th Edition"
                className={`form-input ${errors.title ? 'error' : ''}`}
              />
              {errors.title && <span className="form-error">{errors.title}</span>}
            </div>

            <div className="form-group">
              <label className="form-label">Description</label>
              <textarea
                name="description"
                value={form.description}
                onChange={handleChange}
                placeholder="Describe condition, edition, defects, reason for selling..."
                className="form-textarea"
                style={{ minHeight: '110px' }}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Price (INR) *</label>
                <input
                  name="price"
                  type="number"
                  min="0"
                  value={form.price}
                  onChange={handleChange}
                  placeholder="e.g. 350"
                  className={`form-input ${errors.price ? 'error' : ''}`}
                />
                {errors.price && <span className="form-error">{errors.price}</span>}
              </div>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Category *</label>
                <select
                  name="categoryId"
                  value={form.categoryId}
                  onChange={handleChange}
                  className={`form-select ${errors.categoryId ? 'error' : ''}`}
                >
                  <option value="">Select category...</option>
                  {categories.map((category) => (
                    <option key={category.id} value={category.id}>{category.name}</option>
                  ))}
                </select>
                {errors.categoryId && <span className="form-error">{errors.categoryId}</span>}
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '16px' }}>
              <input
                type="checkbox"
                id="donation"
                name="donation"
                checked={form.donation}
                onChange={handleChange}
                style={{ width: '18px', height: '18px', accentColor: '#f59e0b', cursor: 'pointer' }}
              />
              <label htmlFor="donation" style={{ cursor: 'pointer', fontWeight: 600, fontSize: '0.9rem' }}>
                Mark as donation / free giveaway
              </label>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '12px' }}>
              <input
                type="checkbox"
                id="negotiable"
                name="negotiable"
                checked={form.negotiable}
                onChange={handleChange}
                disabled={form.donation}
                style={{ width: '18px', height: '18px', accentColor: '#5b4bff', cursor: 'pointer' }}
              />
              <label htmlFor="negotiable" style={{ cursor: 'pointer', fontWeight: 600, fontSize: '0.9rem' }}>
                Price is negotiable
              </label>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '12px' }}>
              <input
                type="checkbox"
                id="bundle"
                name="bundle"
                checked={form.bundle}
                onChange={handleChange}
                style={{ width: '18px', height: '18px', accentColor: '#00d4aa', cursor: 'pointer' }}
              />
              <label htmlFor="bundle" style={{ cursor: 'pointer', fontWeight: 600, fontSize: '0.9rem' }}>
                Selling as bundle / set
              </label>
            </div>

            {form.bundle && (
              <div className="form-group" style={{ marginTop: '16px', marginBottom: 0 }}>
                <label className="form-label">Bundle Size *</label>
                <input
                  name="bundleSize"
                  type="number"
                  min="2"
                  value={form.bundleSize}
                  onChange={handleChange}
                  placeholder="e.g. 4 books"
                  className={`form-input ${errors.bundleSize ? 'error' : ''}`}
                />
                {errors.bundleSize && <span className="form-error">{errors.bundleSize}</span>}
              </div>
            )}
          </div>

          {isBookCategory && (
            <div className="card" style={{ padding: '24px', marginBottom: '16px' }}>
              <h3 style={{ fontFamily: "'Syne',sans-serif", marginBottom: '14px', fontSize: '1rem', color: '#a0a8c8' }}>
                Book Details
              </h3>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Subject</label>
                  <input name="academicSubject" value={form.academicSubject} onChange={handleChange} className="form-input" placeholder="DBMS / Physics / Maths" />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Author</label>
                  <input name="bookAuthor" value={form.bookAuthor} onChange={handleChange} className="form-input" placeholder="Author name" />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Edition</label>
                  <input name="bookEdition" value={form.bookEdition} onChange={handleChange} className="form-input" placeholder="7th Edition" />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Course / Stream</label>
                  <input name="academicCourse" value={form.academicCourse} onChange={handleChange} className="form-input" placeholder="B.Tech CSE / Class 10" />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Class / Semester</label>
                  <input name="academicLevel" value={form.academicLevel} onChange={handleChange} className="form-input" placeholder="Semester 4 / Class 12" />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Board / University</label>
                  <input name="boardOrUniversity" value={form.boardOrUniversity} onChange={handleChange} className="form-input" placeholder="CBSE / DU / AKTU" />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">Publisher</label>
                  <input name="publisher" value={form.publisher} onChange={handleChange} className="form-input" placeholder="Pearson / NCERT" />
                </div>
                <div className="form-group" style={{ marginBottom: 0 }}>
                  <label className="form-label">ISBN</label>
                  <input name="isbn" value={form.isbn} onChange={handleChange} className="form-input" placeholder="Optional ISBN" />
                </div>
              </div>
            </div>
          )}

          <div className="card" style={{ padding: '24px', marginBottom: '16px' }}>
            <h3 style={{ fontFamily: "'Syne',sans-serif", marginBottom: '14px', fontSize: '1rem', color: '#a0a8c8' }}>
              Item Condition
            </h3>
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              {CONDITIONS.map((condition) => (
                <button
                  key={condition.val}
                  type="button"
                  onClick={() => setForm((current) => ({ ...current, condition: condition.val }))}
                  style={{
                    padding: '8px 14px',
                    borderRadius: '10px',
                    cursor: 'pointer',
                    border: `2px solid ${form.condition === condition.val ? '#5b4bff' : '#1e2438'}`,
                    background: form.condition === condition.val ? 'rgba(91,75,255,0.12)' : 'transparent',
                    color: form.condition === condition.val ? '#a89dff' : '#5a6285',
                    fontFamily: "'Plus Jakarta Sans',sans-serif",
                    fontWeight: 600,
                    fontSize: '0.83rem',
                    transition: 'all 0.15s',
                  }}
                >
                  <div>{condition.label}</div>
                  <div style={{ fontSize: '0.7rem', opacity: 0.7 }}>{condition.desc}</div>
                </button>
              ))}
            </div>
          </div>

          <div className="card" style={{ padding: '24px', marginBottom: '20px' }}>
            <h3 style={{ fontFamily: "'Syne',sans-serif", marginBottom: '6px', fontSize: '1rem', color: '#a0a8c8' }}>
              Photos
            </h3>
            <p style={{ color: '#5a6285', fontSize: '0.8rem', marginBottom: '16px' }}>
              Add photos of your item - up to {MAX_IMAGES} images
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: '10px' }}>
              {imageUrls.map((url, index) => (
                <div
                  key={index}
                  style={{
                    height: '90px',
                    borderRadius: '10px',
                    border: `2px dashed ${url ? '#5b4bff' : '#1e2438'}`,
                    background: '#0f1320',
                    overflow: 'hidden',
                    position: 'relative',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer',
                  }}
                >
                  {uploadingImages[index] ? (
                    <div style={{ textAlign: 'center', color: '#a0a8c8', fontSize: '0.72rem', padding: '8px' }}>
                      Uploading...
                    </div>
                  ) : url ? (
                    <>
                      <img src={url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      <button
                        type="button"
                        onClick={() => {
                          const next = [...imageUrls];
                          next.splice(index, 1);
                          setImageUrls(next);
                        }}
                        style={{
                          position: 'absolute',
                          top: '3px',
                          right: '3px',
                          background: 'rgba(239,68,68,0.85)',
                          border: 'none',
                          borderRadius: '50%',
                          width: '20px',
                          height: '20px',
                          color: '#fff',
                          cursor: 'pointer',
                          fontSize: '0.7rem',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                        }}
                      >
                        x
                      </button>
                    </>
                  ) : (
                    <label style={{ cursor: 'pointer', textAlign: 'center', color: '#5a6285' }}>
                      <div style={{ fontSize: '1.4rem' }}>+</div>
                      <div style={{ fontSize: '0.65rem', marginTop: '2px' }}>Photo {index + 1}</div>
                      <input
                        type="file"
                        accept="image/*"
                        capture="environment"
                        style={{ display: 'none' }}
                        onChange={async (event) => {
                          const file = event.target.files?.[0];
                          await handleImageUpload(file, index);
                          event.target.value = '';
                        }}
                      />
                    </label>
                  )}
                </div>
              ))}

              {imageUrls.length < MAX_IMAGES && (
                <div
                  onClick={() => setImageUrls((current) => [...current, ''])}
                  style={{
                    height: '90px',
                    borderRadius: '10px',
                    border: '2px dashed rgba(91,75,255,0.3)',
                    background: 'rgba(91,75,255,0.04)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer',
                    flexDirection: 'column',
                    gap: '4px',
                    transition: 'all 0.2s',
                  }}
                >
                  <span style={{ fontSize: '1.4rem', color: '#5b4bff' }}>+</span>
                  <span style={{ fontSize: '0.65rem', color: '#5a6285' }}>Add More</span>
                </div>
              )}
            </div>
            <p style={{ fontSize: '0.75rem', color: '#5a6285', marginTop: '8px' }}>
              {imageUrls.filter((url) => url).length} photo{imageUrls.filter((url) => url).length !== 1 ? 's' : ''} added (max {MAX_IMAGES})
            </p>
          </div>

          <div className="card" style={{ padding: '24px', marginBottom: '20px', border: '2px solid rgba(91,75,255,0.2)', background: 'rgba(91,75,255,0.04)' }}>
            <h3 style={{ fontFamily: "'Syne',sans-serif", marginBottom: '14px', fontSize: '1rem', color: '#a0a8c8' }}>
              Your Item Review (Optional)
            </h3>
            <p style={{ color: '#5a6285', fontSize: '0.85rem', marginBottom: '16px' }}>
              Add a short self-review to build buyer trust.
            </p>

            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 600, color: '#a0a8c8' }}>Item Rating:</label>
              <div style={{ display: 'flex', gap: '8px' }}>
                {[1, 2, 3, 4, 5].map((star) => (
                  <button
                    key={star}
                    type="button"
                    onClick={() => setReviewRating(star)}
                    style={{
                      fontSize: '28px',
                      background: 'none',
                      border: 'none',
                      cursor: 'pointer',
                      transition: 'transform 0.1s',
                      transform: reviewRating >= star ? 'scale(1.1)' : 'scale(1)',
                      color: reviewRating >= star ? '#F5C451' : '#5a6285',
                    }}
                  >
                    {reviewRating >= star ? '★' : '☆'}
                  </button>
                ))}
              </div>
              <span style={{ fontSize: '0.8rem', color: '#5a6285', marginTop: '4px', display: 'block' }}>
                {reviewRating}/5 stars
              </span>
            </div>

            <div className="form-group">
              <label className="form-label">Review Comment:</label>
              <textarea
                value={reviewComment}
                onChange={(event) => setReviewComment(event.target.value)}
                placeholder="e.g. well-maintained, barely used, no hidden defects..."
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
              <span style={{ fontSize: '0.75rem', color: '#5a6285', marginTop: '4px', display: 'block' }}>
                {reviewComment.length}/200 characters
              </span>
            </div>
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <button type="button" onClick={() => navigate(-1)} className="btn btn-secondary" style={{ flex: 1 }}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary" style={{ flex: 2 }} disabled={loading || hasUploadingImages}>
              {loading ? 'Listing...' : hasUploadingImages ? 'Uploading images...' : 'List Item'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
