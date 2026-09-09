/* eslint-disable react-hooks/exhaustive-deps */
import React, { useState, useEffect, useContext, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { AuthContext } from '../App';
import {
  updateStudent,
  getStudentById,
  getStudentStats,
  getItemsBySeller,
  getWishlist,
  removeFromWishlist,
  getBuyerOrders,
  getSellerOrders,
  changePassword,
  getReservedItems,
  unreserveItem,
  deleteAccount
} from '../api/api';

const TABS = ['Overview', 'My Listings', 'Wishlist', 'Reservations', 'History', 'Settings'];

export default function Profile() {
const { user, logout, refreshUser } = useContext(AuthContext);
  const navigate = useNavigate();

  const [activeTab, setActiveTab] = useState('Overview');
  const [stats, setStats] = useState({
    totalListings: 0,
    soldItems: 0,
    wishlistCount: 0,
    totalViews: 0,
    avgRating: 0,
    totalReviews: 0,
    boughtCount: 0
  });
  const [listings, setListings] = useState([]);
  const [wishlist, setWishlist] = useState([]);
  const [reservations, setReservations] = useState([]);
  const [listFilter, setListFilter] = useState('ALL');
  const [form, setForm] = useState({
    name: '',
    email: '',
    phone: '',
    branch: '',
    hostel: '',
    collegeId: '',
    bio: '',
    profilePic: ''
  });
  const [pwForm, setPwForm] = useState({ current: '', newPw: '', confirm: '' });
  const [deletePassword, setDeletePassword] = useState('');
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');
  const [pwMsg, setPwMsg] = useState('');
  const [deleteMsg, setDeleteMsg] = useState('');

// ← Initialize form from user data on mount
useEffect(() => {
  if (!user) return;
  console.log('🔧 Profile Mount - User from context:', { 
    id: user.id, 
    name: user.name, 
    profilePic: user.profilePic ? `${user.profilePic.substring(0, 50)}... (${Math.round(user.profilePic.length/1024)}KB)` : 'NULL'
  });
  setForm({
    name:      user.name      || '',
    email:     user.email     || '',
    phone:     user.phone     || '',
    branch:    user.branch    || '',
    hostel:    user.hostel    || '',
    collegeId: user.collegeId || '',
    bio:       user.bio       || '',
    profilePic: user.profilePic || ''  // ← Load from context/localStorage
  });
}, [user]);

const loadData = useCallback(async () => {
  if (!user?.id) return;
  try {
    const [s, l, w, r] = await Promise.all([
      getStudentStats(user.id),
      getItemsBySeller(user.id),
      getWishlist(user.id),
      getReservedItems(user.id)
    ]);
    setStats(s.data || {});
    setListings(l.data || []);
    setWishlist(w.data || []);
    setReservations(r.data || []);
  } catch (e) {}
}, [user]);

// eslint-disable-next-line react-hooks/exhaustive-deps
useEffect(() => {
  if (!user) { navigate('/login'); return; }
  
  console.log('🔄 Fetching fresh data for user:', user.id);
  
  // Fresh data backend se fetch karo har baar
  getStudentById(user.id).then(res => {
    const fresh = res.data;
    console.log('📡 Backend Response profilePic:', fresh.profilePic ? 'EXISTS' : 'NULL');
    
    // CRITICAL FIX: Agar backend NULL return kare, localStorage se use karo!
    const backendImage = fresh.profilePic;
    const localImage = user.profilePic;  // localStorage mein jo hai
    
    const finalProfilePic = backendImage || localImage;  // Prefer backend, fallback to local
    
    console.log('🛡️ Final profilePic source:', backendImage ? 'BACKEND' : 'LOCALSTORAGE');
    
    const updated = { 
      ...user, 
      ...fresh,
      profilePic: finalProfilePic  // Use merged logic
    };
    
    refreshUser(updated);
    
    // Form mein bhi set karo
    setForm({
      name:      fresh.name      || '',
      email:     fresh.email     || '',
      phone:     fresh.phone     || '',
      branch:    fresh.branch    || '',
      hostel:    fresh.hostel    || '',
      collegeId: fresh.collegeId || '',
      bio:       fresh.bio       || '',
      profilePic: finalProfilePic || ''  // Use merged profilePic
    });
  }).catch(err => {
    console.error('❌ Error fetching fresh data:', err);
    // Fallback to localStorage
    setForm({
      name:      user.name      || '',
      email:     user.email     || '',
      phone:     user.phone     || '',
      branch:    user.branch    || '',
      hostel:    user.hostel    || '',
      collegeId: user.collegeId || '',
      bio:       user.bio       || '',
      profilePic: user.profilePic || ''
    });
  });
  
  loadData();
}, [user?.id]);

  const filteredListings = listings.filter(i =>
    listFilter === 'ALL' ? true : i.status === listFilter
  );

  const fields = ['name', 'email', 'phone', 'branch', 'hostel', 'collegeId', 'bio', 'profilePic'];
  const filled = fields.filter(f => form[f] && form[f].trim() !== '').length;
  const completion = Math.round((filled / fields.length) * 100);

async function handleProfileSave() {
  if (!user?.id) {
    setMsg('User not loaded. Please login again.');
    return;
  }

  setSaving(true);
  setMsg('');

  try {
    // Backend ko bhejna - form data mein current profilePic bhi include hoga
    await updateStudent(user.id, {
      ...user,
      ...form
    });

    // Fresh data backend se fetch karo
    const fullStudentRes = await getStudentById(user.id);
    const freshData = fullStudentRes.data;
    
    // Merge: backend data + current form ka profilePic (preserve local image)
    const mergedData = { 
      ...freshData,
      profilePic: form.profilePic || freshData.profilePic  // Prefer form image
    };

    console.log('📸 Saved profilePic:', form.profilePic?.substring(0, 50) + '...');
    console.log('✅ Backend returned:', freshData);
    console.log('🔗 Merged final data:', { ...mergedData, profilePic: '...[base64]' });

    // Update context aur localStorage dono
    await refreshUser(mergedData);

    // Form ko bhi update karo final merged data se
    setForm({
      name:      mergedData.name      || '',
      email:     mergedData.email     || '',
      phone:     mergedData.phone     || '',
      branch:    mergedData.branch    || '',
      hostel:    mergedData.hostel    || '',
      collegeId: mergedData.collegeId || '',
      bio:       mergedData.bio       || '',
      profilePic: mergedData.profilePic || ''
    });

    setMsg('✅ Profile updated successfully!');
  } catch (err) {
    console.log('PROFILE UPDATE ERROR FULL:', err);
    console.log('PROFILE UPDATE ERROR RESPONSE:', err.response);
    console.log('PROFILE UPDATE ERROR DATA:', err.response?.data);

    setMsg('❌ Update failed. Try again.');
  }

  setSaving(false);
}

  async function handlePasswordChange() {
    if (!user?.id) return;
    if (!pwForm.newPw || pwForm.newPw.length < 6) {
      setPwMsg('❌ New password must be at least 6 characters');
      return;
    }

    if (pwForm.newPw !== pwForm.confirm) {
      setPwMsg('❌ Passwords do not match');
      return;
    }

    setSaving(true);
    setPwMsg('');

    try {
      await changePassword(user.id, {
        currentPassword: pwForm.current,
        newPassword: pwForm.newPw
      });
      setPwMsg('✅ Password changed successfully!');
      setPwForm({ current: '', newPw: '', confirm: '' });
    } catch (e) {
      setPwMsg(e.response?.data?.error || '❌ Incorrect current password');
    }

    setSaving(false);
  }

  async function handleRemoveWishlist(studentId, itemId) {
    try {
      await removeFromWishlist(studentId, itemId);
      setWishlist(w => w.filter(x => x.item.id !== itemId));
    } catch {}
  }

  function handlePhotoChange(e) {
    const file = e.target.files[0];
    if (!file) return;
    if (file.size > 3 * 1024 * 1024) {
      alert('Max 3MB');
      return;
    }
    const reader = new FileReader();
    reader.onloadend = async () => {
      const base64 = reader.result;
      // Form mein set karo
      setForm(f => ({ ...f, profilePic: base64 }));
      
      // Auto-save to backend immediately! 🚀
      setSaving(true);
      try {
        await updateStudent(user.id, {
          ...user,
          profilePic: base64
        });
        
        const fullStudentRes = await getStudentById(user.id);
        const mergedData = { 
          ...fullStudentRes.data,
          profilePic: base64 || fullStudentRes.data.profilePic
        };
        
        refreshUser(mergedData);
        setForm(f => ({ ...f, profilePic: base64 }));
        
        console.log('✅ Image auto-saved!');
      } catch (err) {
        console.error('❌ Auto-save failed:', err);
        setMsg('⚠️ Image update failed. Try again.');
      } finally {
        setSaving(false);
      }
    };
    reader.readAsDataURL(file);
  }

  async function handleUnreserve(itemId) {
    try {
      await unreserveItem(itemId);
      setMsg('✅ Reservation cancelled!');
      loadData();
    } catch (e) {
      setMsg('❌ Failed to cancel reservation');
    }
  }

async function handleLogout() {
  await logout();
  navigate('/');
}

async function handleDeleteAccount() {
  if (!deletePassword) {
    setDeleteMsg('❌ Please enter your password to delete the account');
    return;
  }

  setSaving(true);
  setDeleteMsg('');
  try {
    await deleteAccount(user.id, { password: deletePassword });
    await logout();
    navigate('/');
  } catch (e) {
    setDeleteMsg(e.response?.data?.error || '❌ Failed to delete account');
  }

  setSaving(false);
}

  if (!user) return null;

  const avatarLetter = form.name?.charAt(0)?.toUpperCase() || '?';
  const identityVerified = Boolean(
    user.identityVerified ??
    (user.emailVerified && user.phoneVerified && user.isActive && !user.isBanned)
  );

  return (
    <div style={{ minHeight: '100vh', background: '#080B14', color: '#fff', fontFamily: 'Inter, Arial, sans-serif' }}>
      <div
        style={{
          background: 'linear-gradient(135deg, #1E3A5F 0%, #0F1320 60%, #080B14 100%)',
          borderBottom: '1px solid rgba(91,75,255,0.2)',
          padding: '40px 20px 0'
        }}
      >
        <div style={{ maxWidth: 900, margin: '0 auto' }}>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 24, flexWrap: 'wrap' }}>
            <div style={{ position: 'relative', flexShrink: 0 }}>
              <div
                style={{
                  width: 100,
                  height: 100,
                  borderRadius: '50%',
                  border: '3px solid #5B4BFF',
                  background: form.profilePic ? 'transparent' : 'linear-gradient(135deg,#5B4BFF,#00D4AA)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: 36,
                  fontWeight: 900,
                  color: '#fff',
                  overflow: 'hidden',
                  boxShadow: '0 0 24px rgba(91,75,255,0.4)'
                }}
              >
                {form.profilePic ? (
                  <img src={form.profilePic} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                ) : (
                  avatarLetter
                )}
              </div>
              <label
                style={{
                  position: 'absolute',
                  bottom: 2,
                  right: 2,
                  width: 28,
                  height: 28,
                  borderRadius: '50%',
                  background: '#5B4BFF',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  fontSize: 13,
                  border: '2px solid #080B14'
                }}
              >
                📷
                <input type="file" accept="image/*" style={{ display: 'none' }} onChange={handlePhotoChange} />
              </label>
            </div>

            <div style={{ flex: 1, minWidth: 200, paddingBottom: 16 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                <h2 style={{ margin: 0, fontSize: 24, fontWeight: 800 }}>{form.name || 'Student'}</h2>
                <span
                  style={{
                    background: identityVerified ? 'rgba(0,212,170,0.15)' : 'rgba(245,158,11,0.14)',
                    color: identityVerified ? '#00D4AA' : '#F59E0B',
                    border: `1px solid ${identityVerified ? 'rgba(0,212,170,0.3)' : 'rgba(245,158,11,0.3)'}`,
                    borderRadius: 20,
                    padding: '2px 10px',
                    fontSize: 11,
                    fontWeight: 700
                  }}
                >
                  {identityVerified ? '✅ Verified Student' : '⚠ Verification Pending'}
                </span>
              </div>

              <div style={{ color: '#A0AEC0', fontSize: 13, marginTop: 4 }}>
                {form.branch && <span>{form.branch}</span>}
                {form.branch && form.hostel && <span style={{ margin: '0 8px' }}>·</span>}
                {form.hostel && <span>{form.hostel}</span>}
                {form.collegeId && <span style={{ marginLeft: 8, color: '#5B4BFF' }}>#{form.collegeId}</span>}
              </div>

              {form.bio && (
                <div style={{ color: '#718096', fontSize: 13, marginTop: 6, fontStyle: 'italic' }}>
                  "{form.bio}"
                </div>
              )}

              <div style={{ display: 'flex', gap: 10, marginTop: 12, flexWrap: 'wrap' }}>
                {[
                  { label: 'Listings', val: stats.totalListings, color: '#5B4BFF' },
                  { label: 'Sold', val: stats.soldItems, color: '#00D4AA' },
                  { label: 'Saved', val: stats.wishlistCount, color: '#EF4444' },
                  { label: 'Bought', val: stats.boughtCount, color: '#F6AD55' },
                  { label: 'Views', val: stats.totalViews, color: '#A89DFF' },
                  { label: 'Rating', val: stats.avgRating ? `${stats.avgRating}⭐` : 'New', color: '#FBD38D' }
                ].map(({ label, val, color }) => (
                  <div
                    key={label}
                    style={{
                      background: 'rgba(255,255,255,0.05)',
                      border: `1px solid ${color}33`,
                      borderRadius: 20,
                      padding: '4px 14px',
                      fontSize: 12
                    }}
                  >
                    <span style={{ color, fontWeight: 800 }}>{val}</span>
                    <span style={{ color: '#718096', marginLeft: 5 }}>{label}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', gap: 4, marginTop: 20, borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
            {TABS.map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  padding: '10px 18px',
                  fontSize: 13,
                  fontWeight: 600,
                  color: activeTab === tab ? '#5B4BFF' : '#718096',
                  borderBottom: activeTab === tab ? '2px solid #5B4BFF' : '2px solid transparent',
                  transition: 'all 0.2s'
                }}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div style={{ maxWidth: 900, margin: '0 auto', padding: '24px 20px' }}>
        {activeTab === 'Overview' && (
          <div>
            <div
              style={{
                background: '#0F1320',
                border: '1px solid rgba(91,75,255,0.2)',
                borderRadius: 14,
                padding: 20,
                marginBottom: 20
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                <span style={{ fontWeight: 700 }}>Profile Completion</span>
                <span style={{ color: '#5B4BFF', fontWeight: 800 }}>{completion}%</span>
              </div>
              <div style={{ height: 8, background: '#1E2438', borderRadius: 4, overflow: 'hidden' }}>
                <div
                  style={{
                    width: `${completion}%`,
                    height: '100%',
                    background: 'linear-gradient(90deg,#5B4BFF,#00D4AA)',
                    borderRadius: 4,
                    transition: 'width 0.5s'
                  }}
                />
              </div>
              {completion < 100 && (
                <div style={{ color: '#718096', fontSize: 12, marginTop: 8 }}>
                  Complete your profile:{' '}
                  {fields.filter(f => !form[f] || form[f].trim() === '').join(', ')}
                </div>
              )}
            </div>

            <h3 style={{ color: '#A0AEC0', fontSize: 13, fontWeight: 700, marginBottom: 12, letterSpacing: 1 }}>
              RECENT LISTINGS
            </h3>
            {listings.slice(0, 3).length === 0 ? (
              <EmptyState icon="📦" text="No listings yet" sub="Start selling something!" />
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(200px,1fr))', gap: 14 }}>
                {listings.slice(0, 3).map(item => (
                  <MiniItemCard key={item.id} item={item} navigate={navigate} />
                ))}
              </div>
            )}

            <h3
              style={{
                color: '#A0AEC0',
                fontSize: 13,
                fontWeight: 700,
                margin: '24px 0 12px',
                letterSpacing: 1
              }}
            >
              RECENTLY SAVED
            </h3>
            {wishlist.slice(0, 3).length === 0 ? (
              <EmptyState icon="💝" text="Nothing saved yet" sub="Heart items you like!" />
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(200px,1fr))', gap: 14 }}>
                {wishlist.slice(0, 3).map(w => (
                  <MiniItemCard key={w.id} item={w.item} navigate={navigate} />
                ))}
              </div>
            )}
          </div>
        )}

        {activeTab === 'My Listings' && (
          <div>
            <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
              {['ALL', 'AVAILABLE', 'SOLD'].map(f => (
                <button
                  key={f}
                  onClick={() => setListFilter(f)}
                  style={{
                    padding: '6px 18px',
                    borderRadius: 20,
                    fontSize: 12,
                    fontWeight: 700,
                    cursor: 'pointer',
                    background: listFilter === f ? '#5B4BFF' : 'rgba(255,255,255,0.05)',
                    color: listFilter === f ? '#fff' : '#718096',
                    border: `1px solid ${listFilter === f ? '#5B4BFF' : 'rgba(255,255,255,0.1)'}`
                  }}
                >
                  {f}
                </button>
              ))}
              <span style={{ marginLeft: 'auto', color: '#718096', fontSize: 13, alignSelf: 'center' }}>
                {filteredListings.length} items
              </span>
            </div>

            {filteredListings.length === 0 ? (
              <EmptyState icon="📦" text="No items here" sub="Add your first listing!" />
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {filteredListings.map(item => (
                  <ListingRow key={item.id} item={item} navigate={navigate} onRefresh={loadData} />
                ))}
              </div>
            )}
          </div>
        )}

        {activeTab === 'Wishlist' && (
          <div>
            <div style={{ color: '#718096', fontSize: 13, marginBottom: 16 }}>{wishlist.length} saved items</div>
            {wishlist.length === 0 ? (
              <EmptyState icon="💝" text="Your wishlist is empty" sub="Save items you're interested in" />
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(240px,1fr))', gap: 16 }}>
                {wishlist.map(w => (
                  <WishlistCard
                    key={w.id}
                    w={w}
                    navigate={navigate}
                    onRemove={() => handleRemoveWishlist(user.id, w.item.id)}
                  />
                ))}
              </div>
            )}
          </div>
        )}

        {activeTab === 'Reservations' && (
          <div>
            <div style={{ color: '#718096', fontSize: 13, marginBottom: 16 }}>{reservations.length} reserved items</div>
            {reservations.length === 0 ? (
              <EmptyState icon="🔒" text="No reserved items yet" sub="Start browsing and reserve items you're interested in!" />
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill,minmax(240px,1fr))', gap: 16 }}>
                {reservations.map(item => (
                  <ReservationCard
                    key={item.id}
                    item={item}
                    navigate={navigate}
                    onUnreserve={() => handleUnreserve(item.id)}
                  />
                ))}
              </div>
            )}
          </div>
        )}

        {activeTab === 'History' && <HistoryTab userId={user.id} />}

        {activeTab === 'Settings' && (
          <div style={{ maxWidth: 560 }}>
            {msg && (
              <div
                style={{
                  padding: '12px 16px',
                  borderRadius: 10,
                  marginBottom: 16,
                  background: msg.startsWith('✅') ? 'rgba(0,212,170,0.1)' : 'rgba(239,68,68,0.1)',
                  border: `1px solid ${msg.startsWith('✅') ? '#00D4AA' : '#EF4444'}`,
                  color: msg.startsWith('✅') ? '#00D4AA' : '#EF4444',
                  fontSize: 13
                }}
              >
                {msg}
              </div>
            )}

            <SectionCard title="Personal Information">
              {[
                { key: 'name', label: 'Full Name', type: 'text', placeholder: 'Your full name' },
                { key: 'phone', label: 'Phone', type: 'tel', placeholder: '+91 XXXXXXXXXX' },
                { key: 'branch', label: 'Branch', type: 'text', placeholder: 'B.Tech CSE' },
                { key: 'hostel', label: 'Hostel', type: 'text', placeholder: 'Hostel A / Block 3' },
                { key: 'collegeId', label: 'College ID', type: 'text', placeholder: 'Roll / Enrollment No.' },
                { key: 'bio', label: 'Bio', type: 'textarea', placeholder: 'Tell something about yourself...' }
              ].map(({ key, label, type, placeholder }) => (
                <div key={key} style={{ marginBottom: 14 }}>
                  <label
                    style={{
                      display: 'block',
                      fontSize: 12,
                      color: '#A0AEC0',
                      marginBottom: 5,
                      fontWeight: 600
                    }}
                  >
                    {label}
                  </label>
                  {type === 'textarea' ? (
                    <textarea
                      value={form[key]}
                      onChange={e => setForm(f => ({ ...f, [key]: e.target.value }))}
                      placeholder={placeholder}
                      rows={3}
                      style={inputStyle}
                    />
                  ) : (
                    <input
                      type={type}
                      value={form[key]}
                      onChange={e => setForm(f => ({ ...f, [key]: e.target.value }))}
                      placeholder={placeholder}
                      style={inputStyle}
                    />
                  )}
                </div>
              ))}
              <button onClick={handleProfileSave} disabled={saving} style={primaryBtn}>
                {saving ? 'Saving...' : '💾 Save Changes'}
              </button>
              <button
                onClick={handleDeleteAccount}
                disabled={saving}
                style={{
                  width: '100%',
                  padding: '12px',
                  borderRadius: 10,
                  cursor: 'pointer',
                  background: '#2a1014',
                  border: '1px solid rgba(239,68,68,0.45)',
                  color: '#ff8f8f',
                  fontWeight: 700,
                  fontSize: 14,
                  marginTop: 10
                }}
              >
                Delete Account Permanently
              </button>
            </SectionCard>

            <SectionCard title="Change Password" style={{ marginTop: 16 }}>
              {[ 
                { key: 'current', label: 'Current Password', placeholder: 'Enter current password' },
                { key: 'newPw', label: 'New Password', placeholder: 'Minimum 6 characters' },
                { key: 'confirm', label: 'Confirm New Password', placeholder: 'Re-enter new password' }
              ].map(({ key, label, placeholder }) => (
                <div key={key} style={{ marginBottom: 14 }}>
                  <label
                    style={{
                      display: 'block',
                      fontSize: 12,
                      color: '#A0AEC0',
                      marginBottom: 5,
                      fontWeight: 600
                    }}
                  >
                    {label}
                  </label>
                  <input
                    type="password"
                    value={pwForm[key]}
                    onChange={e => setPwForm(p => ({ ...p, [key]: e.target.value }))}
                    placeholder={placeholder}
                    style={inputStyle}
                  />
                </div>
              ))}

              {pwMsg && (
                <div
                  style={{
                    padding: '10px 14px',
                    borderRadius: 8,
                    marginBottom: 12,
                    background: pwMsg.startsWith('✅') ? 'rgba(0,212,170,0.1)' : 'rgba(239,68,68,0.1)',
                    border: `1px solid ${pwMsg.startsWith('✅') ? '#00D4AA' : '#EF4444'}`,
                    color: pwMsg.startsWith('✅') ? '#00D4AA' : '#EF4444',
                    fontSize: 13
                  }}
                >
                  {pwMsg}
                </div>
              )}

              <button onClick={handlePasswordChange} disabled={saving} style={primaryBtn}>
                🔒 Update Password
              </button>
            </SectionCard>

            <SectionCard title="Account" style={{ marginTop: 16 }}>
              <div style={{ marginBottom: 14 }}>
                <label
                  style={{
                    display: 'block',
                    fontSize: 12,
                    color: '#A0AEC0',
                    marginBottom: 5,
                    fontWeight: 600
                  }}
                >
                  Delete Account Confirmation
                </label>
                <input
                  type="password"
                  value={deletePassword}
                  onChange={e => setDeletePassword(e.target.value)}
                  placeholder="Enter password to permanently delete account"
                  style={inputStyle}
                />
              </div>

              {deleteMsg && (
                <div
                  style={{
                    padding: '10px 14px',
                    borderRadius: 8,
                    marginBottom: 12,
                    background: deleteMsg.startsWith('✅') ? 'rgba(0,212,170,0.1)' : 'rgba(239,68,68,0.1)',
                    border: `1px solid ${deleteMsg.startsWith('✅') ? '#00D4AA' : '#EF4444'}`,
                    color: deleteMsg.startsWith('✅') ? '#00D4AA' : '#EF4444',
                    fontSize: 13
                  }}
                >
                  {deleteMsg}
                </div>
              )}
              <button
                onClick={handleLogout}
                style={{
                  width: '100%',
                  padding: '12px',
                  borderRadius: 10,
                  cursor: 'pointer',
                  background: 'rgba(239,68,68,0.1)',
                  border: '1px solid rgba(239,68,68,0.3)',
                  color: '#EF4444',
                  fontWeight: 700,
                  fontSize: 14
                }}
              >
                🚪 Logout
              </button>
            </SectionCard>
          </div>
        )}
      </div>
    </div>
  );
}

function HistoryTab({ userId }) {
  const [tab, setTab] = useState('bought');
  const [bought, setBought] = useState([]);
  const [sold, setSold] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    Promise.all([getBuyerOrders(userId), getSellerOrders(userId)])
      .then(([b, s]) => {
        setBought((b.data || []).filter(o => o.status === 'RELEASED'));
        setSold((s.data || []).filter(o => o.status === 'RELEASED'));
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, [userId]);

  const list = tab === 'bought' ? bought : sold;

  return (
    <div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
        {['bought', 'sold'].map(t => (
          <button
            key={t}
            onClick={() => setTab(t)}
            style={{
              padding: '8px 22px',
              borderRadius: 20,
              fontSize: 13,
              fontWeight: 700,
              cursor: 'pointer',
              textTransform: 'capitalize',
              background: tab === t ? '#5B4BFF' : 'rgba(255,255,255,0.05)',
              color: tab === t ? '#fff' : '#718096',
              border: `1px solid ${tab === t ? '#5B4BFF' : 'rgba(255,255,255,0.1)'}`
            }}
          >
            {t === 'bought' ? '🛒 Buying History' : '💰 Selling History'}
          </button>
        ))}
        <span style={{ alignSelf: 'center', color: '#718096', fontSize: 12, marginLeft: 'auto' }}>
          {list.length} records
        </span>
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: 40, color: '#718096' }}>Loading...</div>
      ) : list.length === 0 ? (
        <EmptyState
          icon={tab === 'bought' ? '🛒' : '💰'}
          text={tab === 'bought' ? 'No purchases yet' : 'No sales yet'}
          sub={tab === 'bought' ? 'Items you buy will appear here' : 'Items you sell will appear here'}
        />
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {list.map(tx => {
            const item = tx.item;
            const person = tab === 'bought' ? tx.seller : tx.buyer;
            const img = item?.imageUrls?.[0] || null;
            const date = tx.createdAt
              ? new Date(tx.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
              : 'N/A';

            const statusColor = {
              RELEASED: '#00D4AA',
              COMPLETED: '#00D4AA',
              PENDING: '#F6AD55',
              CANCELLED: '#EF4444'
            };

            return (
              <div
                key={tx.id}
                style={{
                  background: '#0F1320',
                  border: '1px solid rgba(255,255,255,0.07)',
                  borderRadius: 12,
                  padding: 14,
                  display: 'flex',
                  gap: 14,
                  alignItems: 'center'
                }}
              >
                <div
                  style={{
                    width: 68,
                    height: 68,
                    borderRadius: 10,
                    overflow: 'hidden',
                    background: '#1E2438',
                    flexShrink: 0,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}
                >
                  {img ? (
                    <img src={img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  ) : (
                    <span style={{ fontSize: 24 }}>📦</span>
                  )}
                </div>

                <div style={{ flex: 1, minWidth: 0 }}>
                  <div
                    style={{
                      fontWeight: 700,
                      fontSize: 14,
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap'
                    }}
                  >
                    {item?.title || 'Item'}
                  </div>
                  <div style={{ color: '#5B4BFF', fontWeight: 800, marginTop: 2 }}>
                    ₹{tx.amount || item?.price}
                  </div>
                  <div style={{ color: '#718096', fontSize: 12, marginTop: 3 }}>
                    {tab === 'bought' ? '🏪 Seller: ' : '👤 Buyer: '}
                    <span style={{ color: '#A0AEC0' }}>{person?.name || 'Unknown'}</span>
                    <span style={{ margin: '0 8px', color: '#4A5568' }}>·</span>
                    <span>{date}</span>
                  </div>
                </div>

                <div style={{ flexShrink: 0, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
                  <span
                    style={{
                      background: `${statusColor[tx.status] || '#718096'}22`,
                      color: statusColor[tx.status] || '#718096',
                      border: `1px solid ${statusColor[tx.status] || '#718096'}44`,
                      borderRadius: 20,
                      padding: '2px 10px',
                      fontSize: 11,
                      fontWeight: 700
                    }}
                  >
                    {tx.status}
                  </span>
                  <button
                    onClick={() => navigate(`/item/${item?.id}`)}
                    style={{
                      background: 'none',
                      border: '1px solid rgba(255,255,255,0.1)',
                      borderRadius: 8,
                      padding: '4px 10px',
                      cursor: 'pointer',
                      color: '#A0AEC0',
                      fontSize: 11
                    }}
                  >
                    View Item
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function SectionCard({ title, children, style = {} }) {
  return (
    <div
      style={{
        background: '#0F1320',
        border: '1px solid rgba(255,255,255,0.07)',
        borderRadius: 14,
        padding: 20,
        marginBottom: 16,
        ...style
      }}
    >
      <h3 style={{ margin: '0 0 16px', fontSize: 15, fontWeight: 700, color: '#fff' }}>{title}</h3>
      {children}
    </div>
  );
}

function MiniItemCard({ item, navigate }) {
  const img = item.imageUrls?.[0] || null;

  return (
    <div
      onClick={() => navigate(`/item/${item.id}`)}
      style={{
        background: '#0F1320',
        border: '1px solid rgba(255,255,255,0.07)',
        borderRadius: 12,
        overflow: 'hidden',
        cursor: 'pointer',
        transition: 'transform 0.2s'
      }}
      onMouseEnter={e => (e.currentTarget.style.transform = 'translateY(-3px)')}
      onMouseLeave={e => (e.currentTarget.style.transform = 'translateY(0)')}
    >
      <div
        style={{
          height: 110,
          background: '#1E2438',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          overflow: 'hidden'
        }}
      >
        {img ? (
          <img src={img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        ) : (
          <span style={{ fontSize: 30 }}>📦</span>
        )}
      </div>
      <div style={{ padding: '10px 12px' }}>
        <div
          style={{
            fontSize: 13,
            fontWeight: 700,
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis'
          }}
        >
          {item.title}
        </div>
        <div style={{ color: '#5B4BFF', fontWeight: 800, fontSize: 14, marginTop: 3 }}>₹{item.price}</div>
        <StatusBadge status={item.status} />
      </div>
    </div>
  );
}

function WishlistCard({ w, navigate, onRemove }) {
  const item = w.item;
  const img = item.imageUrls?.[0] || null;

  return (
    <div style={{ background: '#0F1320', border: '1px solid rgba(255,255,255,0.07)', borderRadius: 14, overflow: 'hidden' }}>
      <div onClick={() => navigate(`/item/${item.id}`)} style={{ cursor: 'pointer' }}>
        <div
          style={{
            height: 130,
            background: '#1E2438',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            overflow: 'hidden',
            position: 'relative'
          }}
        >
          {img ? (
            <img src={img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          ) : (
            <span style={{ fontSize: 36 }}>📦</span>
          )}

          {item.status === 'SOLD' && (
            <div
              style={{
                position: 'absolute',
                inset: 0,
                background: 'rgba(0,0,0,0.6)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}
            >
              <span
                style={{
                  background: '#EF4444',
                  color: '#fff',
                  padding: '4px 14px',
                  borderRadius: 20,
                  fontWeight: 800,
                  fontSize: 13
                }}
              >
                SOLD
              </span>
            </div>
          )}
        </div>

        <div style={{ padding: '12px 14px' }}>
          <div style={{ fontWeight: 700, fontSize: 14 }}>{item.title}</div>
          <div style={{ color: '#5B4BFF', fontWeight: 800, fontSize: 15, marginTop: 3 }}>₹{item.price}</div>
        </div>
      </div>

      <div style={{ padding: '0 14px 14px' }}>
        <button
          onClick={onRemove}
          style={{
            width: '100%',
            padding: '8px',
            borderRadius: 8,
            cursor: 'pointer',
            background: 'rgba(239,68,68,0.08)',
            border: '1px solid rgba(239,68,68,0.2)',
            color: '#EF4444',
            fontSize: 12,
            fontWeight: 700
          }}
        >
          🗑 Remove
        </button>
      </div>
    </div>
  );
}

function ListingRow({ item, navigate }) {
  const img = item.imageUrls?.[0] || null;

  return (
    <div
      style={{
        background: '#0F1320',
        border: '1px solid rgba(255,255,255,0.07)',
        borderRadius: 12,
        padding: 14,
        display: 'flex',
        gap: 14,
        alignItems: 'center'
      }}
    >
      <div
        style={{
          width: 72,
          height: 72,
          borderRadius: 10,
          overflow: 'hidden',
          background: '#1E2438',
          flexShrink: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center'
        }}
      >
        {img ? (
          <img src={img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        ) : (
          <span style={{ fontSize: 24 }}>📦</span>
        )}
      </div>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            fontWeight: 700,
            fontSize: 14,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap'
          }}
        >
          {item.title}
        </div>
        <div style={{ color: '#5B4BFF', fontWeight: 800, marginTop: 3 }}>₹{item.price}</div>
        <div style={{ display: 'flex', gap: 10, marginTop: 6, alignItems: 'center' }}>
          <StatusBadge status={item.status} />
          <span style={{ color: '#718096', fontSize: 11 }}>👁 {item.viewCount || 0} views</span>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
        <button onClick={() => navigate(`/item/${item.id}`)} style={ghostBtn}>View</button>
        <button onClick={() => navigate(`/edit-item/${item.id}`)} style={ghostBtn}>✏️</button>
      </div>
    </div>
  );
}

function StatusBadge({ status }) {
  const colors = { AVAILABLE: '#00D4AA', SOLD: '#EF4444', RESERVED: '#5B4BFF' };

  return (
    <span
      style={{
        background: `${colors[status] || '#718096'}22`,
        color: colors[status] || '#718096',
        border: `1px solid ${colors[status] || '#718096'}44`,
        borderRadius: 20,
        padding: '2px 10px',
        fontSize: 11,
        fontWeight: 700
      }}
    >
      {status}
    </span>
  );
}

function EmptyState({ icon, text, sub }) {
  return (
    <div style={{ textAlign: 'center', padding: '48px 20px' }}>
      <div style={{ fontSize: 48, marginBottom: 12 }}>{icon}</div>
      <div style={{ fontWeight: 700, fontSize: 16, color: '#fff' }}>{text}</div>
      <div style={{ color: '#718096', fontSize: 13, marginTop: 6 }}>{sub}</div>
    </div>
  );
}

const inputStyle = {
  width: '100%',
  padding: '10px 14px',
  borderRadius: 10,
  fontSize: 14,
  background: '#080B14',
  border: '1px solid rgba(255,255,255,0.1)',
  color: '#fff',
  outline: 'none',
  boxSizing: 'border-box',
  fontFamily: 'inherit',
  resize: 'vertical'
};

const primaryBtn = {
  width: '100%',
  padding: '12px',
  borderRadius: 10,
  cursor: 'pointer',
  background: 'linear-gradient(135deg,#5B4BFF,#4338CA)',
  border: 'none',
  color: '#fff',
  fontWeight: 700,
  fontSize: 14
};

const ghostBtn = {
  padding: '6px 14px',
  borderRadius: 8,
  cursor: 'pointer',
  fontSize: 12,
  fontWeight: 600,
  background: 'rgba(255,255,255,0.05)',
  border: '1px solid rgba(255,255,255,0.1)',
  color: '#A0AEC0'
};

function ReservationCard({ item, navigate, onUnreserve }) {
  const img = item.imageUrls?.[0] || null;

  return (
    <div style={{ background: '#0F1320', border: '1px solid rgba(255,255,255,0.07)', borderRadius: 14, overflow: 'hidden' }}>
      <div onClick={() => navigate(`/item/${item.id}`)} style={{ cursor: 'pointer' }}>
        <div
          style={{
            height: 130,
            background: '#1E2438',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            overflow: 'hidden',
            position: 'relative'
          }}
        >
          {img ? (
            <img src={img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          ) : (
            <span style={{ fontSize: 36 }}>📦</span>
          )}
          <div
            style={{
              position: 'absolute',
              inset: 0,
              background: 'rgba(91,75,255,0.15)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              pointerEvents: 'none'
            }}
          >
            <span
              style={{
                background: '#5B4BFF',
                color: '#fff',
                padding: '4px 14px',
                borderRadius: 20,
                fontWeight: 800,
                fontSize: 13
              }}
            >
              🔒 RESERVED
            </span>
          </div>
        </div>

        <div style={{ padding: '12px 14px' }}>
          <div style={{ fontWeight: 700, fontSize: 14 }}>{item.title}</div>
          <div style={{ color: '#5B4BFF', fontWeight: 800, fontSize: 15, marginTop: 3 }}>₹{item.price}</div>
          {item.seller && (
            <div style={{ color: '#718096', fontSize: 12, marginTop: 4 }}>
              <strong>Seller:</strong> {item.seller.name}
            </div>
          )}
        </div>
      </div>

      <div style={{ padding: '0 14px 14px', display: 'flex', gap: 8 }}>
        <button
          onClick={() => navigate(`/item/${item.id}`)}
          style={{
            flex: 1,
            padding: '8px',
            borderRadius: 8,
            cursor: 'pointer',
            background: '#5B4BFF',
            border: 'none',
            color: '#fff',
            fontSize: 12,
            fontWeight: 700
          }}
        >
          View Details
        </button>
        <button
          onClick={onUnreserve}
          style={{
            flex: 1,
            padding: '8px',
            borderRadius: 8,
            cursor: 'pointer',
            background: 'rgba(239,68,68,0.08)',
            border: '1px solid rgba(239,68,68,0.2)',
            color: '#EF4444',
            fontSize: 12,
            fontWeight: 700
          }}
        >
          Cancel
        </button>
      </div>
    </div>
  );
}
