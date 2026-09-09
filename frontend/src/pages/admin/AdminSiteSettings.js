import React, { useEffect, useState } from 'react';
import { useAuth } from '../../App';
import { getAdminSiteSettings, updateAdminSiteSettings, uploadAdminCartLogo } from '../../api/admin_api';
import { useSiteSettings } from '../../context/SiteSettingsContext';

const fieldGroups = [
  {
    title: 'Brand & Contact',
    fields: [
      ['companyName', 'Company name'],
      ['companyTagline', 'Tagline'],
      ['cartLogoUrl', 'Cart logo image URL'],
      ['aboutSummary', 'About summary', true],
      ['supportEmail', 'Support email'],
      ['businessEmail', 'Business email'],
      ['supportWhatsappNumber', 'WhatsApp number'],
      ['supportHours', 'Support hours'],
      ['officeAddress', 'Office address', true],
    ],
  },
  {
    title: 'Social Links',
    fields: [
      ['instagramUrl', 'Instagram URL'],
      ['linkedinUrl', 'LinkedIn URL'],
      ['youtubeUrl', 'YouTube URL'],
      ['xUrl', 'X / Twitter URL'],
      ['githubUrl', 'GitHub URL'],
    ],
  },
  {
    title: 'Policy Placeholders',
    fields: [
      ['privacyPolicyContent', 'Privacy policy', true],
      ['termsContent', 'Terms & conditions', true],
      ['refundPolicyContent', 'Refund policy', true],
      ['cookiePolicyContent', 'Cookie policy', true],
      ['disclaimerContent', 'Disclaimer', true],
    ],
  },
];

export default function AdminSiteSettings() {
  const { user } = useAuth();
  const { refreshSettings } = useSiteSettings();
  const [form, setForm] = useState({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [uploadingLogo, setUploadingLogo] = useState(false);
  const [status, setStatus] = useState('');

  useEffect(() => {
    if (!user?.id) return;
    setLoading(true);
    getAdminSiteSettings()
      .then((res) => {
        setForm(res.data || {});
        setStatus('');
      })
      .catch((err) => {
        setStatus(err.response?.data?.error || 'Could not load site settings');
      })
      .finally(() => setLoading(false));
  }, [user?.id]);

  const updateField = (key, value) => {
    setForm((current) => ({ ...current, [key]: value }));
  };

  const handleLogoFileChange = async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      setStatus('Please choose a valid image file for the cart logo');
      event.target.value = '';
      return;
    }

    if (!user?.id) {
      event.target.value = '';
      return;
    }

    setUploadingLogo(true);
    setStatus('');

    try {
      const res = await uploadAdminCartLogo(file);
      updateField('cartLogoUrl', res.data?.cartLogoUrl || '');
      setStatus('Cart logo uploaded. Save site settings to publish it.');
    } catch (err) {
      setStatus(err.response?.data?.error || 'Could not upload the selected cart logo image');
    } finally {
      setUploadingLogo(false);
    }

    event.target.value = '';
  };

  const handleSave = async () => {
    if (!user?.id) return;
    setSaving(true);
    setStatus('');
    try {
      await updateAdminSiteSettings(form);
      await refreshSettings();
      setStatus('Site settings saved successfully');
    } catch (err) {
      setStatus(err.response?.data?.error || 'Could not save site settings');
    }
    setSaving(false);
  };

  return (
    <div>
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontFamily: "'Syne',sans-serif", fontSize: '1.9rem', color: '#e8eaf6' }}>
          Site Settings
        </h1>
        <p style={{ color: '#8fa0c4', maxWidth: 760 }}>
          Yahin se company/startup details, support contacts, social links, aur policy placeholders update karo.
          Web aur app ke public sections isi data ko consume karenge.
        </p>
      </div>

      {status && (
        <div className={status.includes('successfully') ? 'alert alert-success' : 'alert alert-error'} style={{ marginBottom: 18 }}>
          {status}
        </div>
      )}

      {loading ? (
        <div className="loading-wrap"><div className="spinner" /></div>
      ) : (
        <>
          <div style={{ display: 'grid', gap: 16 }}>
            {fieldGroups.map((group) => (
              <section key={group.title} style={sectionStyle}>
                <h2 style={{ margin: '0 0 16px', color: '#fff', fontSize: '1.08rem' }}>{group.title}</h2>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(260px,1fr))', gap: 14 }}>
                  {group.fields.map(([key, label, isTextArea]) => (
                    <label key={key} style={{ display: 'grid', gap: 8 }}>
                      <span style={{ color: '#8fa0c4', fontSize: 13, fontWeight: 700 }}>{label}</span>
                      {isTextArea ? (
                        <textarea
                          value={form[key] || ''}
                          onChange={(e) => updateField(key, e.target.value)}
                          rows={5}
                          style={inputStyle}
                        />
                      ) : (
                        <input
                          value={form[key] || ''}
                          onChange={(e) => updateField(key, e.target.value)}
                          style={inputStyle}
                          placeholder={key === 'cartLogoUrl' ? 'https://your-domain.com/assets/cart-logo.png or upload below' : ''}
                        />
                      )}
                      {key === 'cartLogoUrl' && (
                        <>
                          <span style={{ color: '#6f7fa5', fontSize: 12 }}>
                            Admin yahan direct image upload ya image URL dono use kar sakta hai. Yehi small cart logo web aur Flutter dono me use hoga.
                          </span>
                          <label style={uploadWrapStyle}>
                            <span style={uploadButtonStyle}>{uploadingLogo ? 'Uploading...' : 'Upload Cart Logo'}</span>
                            <input
                              type="file"
                              accept="image/*"
                              onChange={handleLogoFileChange}
                              disabled={uploadingLogo}
                              style={{ display: 'none' }}
                            />
                          </label>
                          <div style={logoPreviewWrapStyle}>
                            <div style={logoPreviewBadgeStyle}>
                              {form[key] ? (
                                <img
                                  src={form[key]}
                                  alt="Cart logo preview"
                                  style={{ width: 30, height: 30, objectFit: 'contain' }}
                                  onError={(e) => {
                                    e.currentTarget.style.display = 'none';
                                    const fallback = e.currentTarget.nextElementSibling;
                                    if (fallback) fallback.style.display = 'block';
                                  }}
                                />
                              ) : null}
                              <span style={{ display: form[key] ? 'none' : 'block' }}>
                                Placeholder
                              </span>
                              <span style={{ display: 'none' }}>
                                Invalid image URL
                              </span>
                            </div>
                          </div>
                        </>
                      )}
                    </label>
                  ))}
                </div>
              </section>
            ))}
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 18 }}>
            <button onClick={handleSave} disabled={saving} className="btn btn-primary">
              {saving ? 'Saving...' : 'Save Site Settings'}
            </button>
          </div>
        </>
      )}
    </div>
  );
}

const sectionStyle = {
  background: '#0f1320',
  border: '1px solid #1e2438',
  borderRadius: 18,
  padding: 18,
};

const inputStyle = {
  width: '100%',
  padding: '12px 14px',
  borderRadius: 12,
  border: '1px solid rgba(255,255,255,0.08)',
  background: '#12172A',
  color: '#fff',
  resize: 'vertical',
};

const logoPreviewWrapStyle = {
  display: 'flex',
  alignItems: 'center',
  marginTop: 2,
};

const logoPreviewBadgeStyle = {
  minHeight: 52,
  minWidth: 140,
  padding: '10px 14px',
  borderRadius: 14,
  border: '1px dashed rgba(114,101,255,0.45)',
  background: 'rgba(18,23,42,0.9)',
  color: '#8fa0c4',
  fontSize: 12,
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  gap: 8,
};

const uploadWrapStyle = {
  display: 'inline-flex',
  width: 'fit-content',
  marginTop: 4,
};

const uploadButtonStyle = {
  padding: '10px 14px',
  borderRadius: 12,
  background: 'rgba(91,75,255,0.14)',
  border: '1px solid rgba(114,101,255,0.28)',
  color: '#d7d1ff',
  fontSize: 13,
  fontWeight: 700,
  cursor: 'pointer',
};
