import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  activateMonetizationPlan,
  getBlockedUsers,
  getMonetizationSummary,
  unblockUser,
  updateStudent,
} from '../api/api';
import { useAuth } from '../App';
import { useLanguage } from '../context/LanguageContext';
import { useTheme } from '../context/ThemeContext';
import { useSiteSettings } from '../context/SiteSettingsContext';
import {
  SUPPORT_EMAIL,
  SUPPORT_WHATSAPP_LINK,
} from '../config/support';
import { SOCIAL_LINKS, buildSocialLinksFromSettings } from '../config/socials';

export default function Settings() {
  const { user, refreshUser } = useAuth();
  const { language, setLanguage } = useLanguage();
  const { themeMode, setThemeMode } = useTheme();
  const { settings } = useSiteSettings();
  const [form, setForm] = useState({
    pushNotificationsEnabled: true,
    emailNotificationsEnabled: true,
    showPhoneOnListings: true,
    allowDirectChat: true,
    privacyMode: 'CAMPUS_ONLY',
    preferredLanguage: 'EN',
    locationLabel: '',
    latitude: null,
    longitude: null,
  });
  const [blockedUsers, setBlockedUsers] = useState([]);
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState('');
  const [monetization, setMonetization] = useState(null);
  const [monetizationLoading, setMonetizationLoading] = useState(false);
  const [activatingPlan, setActivatingPlan] = useState('');
  const socialLinks = buildSocialLinksFromSettings(settings);
  const identityVerified = Boolean(
    user?.identityVerified ??
    (user?.emailVerified && user?.phoneVerified && user?.isActive && !user?.isBanned)
  );

  useEffect(() => {
    if (!user) return;
    setForm({
      pushNotificationsEnabled: user.pushNotificationsEnabled ?? true,
      emailNotificationsEnabled: user.emailNotificationsEnabled ?? true,
      showPhoneOnListings: user.showPhoneOnListings ?? true,
      allowDirectChat: user.allowDirectChat ?? true,
      privacyMode: user.privacyMode || 'CAMPUS_ONLY',
      preferredLanguage: user.preferredLanguage || language,
      locationLabel: user.locationLabel || '',
      latitude: user.latitude ?? null,
      longitude: user.longitude ?? null,
    });
  }, [user, language]);

  useEffect(() => {
    if (!user?.id) return;
    getBlockedUsers(user.id)
      .then((res) => setBlockedUsers(res.data || []))
      .catch(() => setBlockedUsers([]));
  }, [user?.id]);

  useEffect(() => {
    if (!user?.id) return;
    setMonetizationLoading(true);
    getMonetizationSummary(user.id)
      .then((res) => setMonetization(res.data))
      .catch(() => setMonetization(null))
      .finally(() => setMonetizationLoading(false));
  }, [user?.id]);

  const handleToggle = async (key, value) => {
    if (!user?.id) return;
    const next = { ...form, [key]: value };
    setForm(next);
    setSaving(true);
    setStatus('');
    try {
      await updateStudent(user.id, next);
      const merged = { ...user, ...next };
      refreshUser(merged);
      if (key === 'preferredLanguage') {
        setLanguage(value);
      }
      setStatus('Settings updated');
    } catch (err) {
      setStatus(err.response?.data?.error || 'Could not update settings');
      setForm(form);
    }
    setSaving(false);
  };

  const handleUnblock = async (blockedId) => {
    if (!user?.id) return;
    try {
      await unblockUser(blockedId, user.id);
      setBlockedUsers((prev) => prev.filter((entry) => entry.blocked?.id !== blockedId));
    } catch (err) {
      setStatus(err.response?.data?.error || 'Could not unblock user');
    }
  };

  const handleActivatePlan = async (planCode) => {
    if (!user?.id) return;
    setActivatingPlan(planCode);
    setStatus('');
    try {
      const res = await activateMonetizationPlan(planCode);
      if (res.data?.student) {
        refreshUser(res.data.student);
      }
      if (res.data?.summary) {
        setMonetization(res.data.summary);
      }
      setStatus(res.data?.message || 'Plan updated');
    } catch (err) {
      setStatus(err.response?.data?.error || 'Could not update plan');
    } finally {
      setActivatingPlan('');
    }
  };

  const handleSaveLocation = () => {
    if (!navigator.geolocation || !user?.id) {
      setStatus('Location access is not available in this browser');
      return;
    }

    navigator.geolocation.getCurrentPosition(async (position) => {
      const next = {
        ...form,
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
      };
      setForm(next);
      setSaving(true);
      setStatus('');
      try {
        await updateStudent(user.id, next);
        refreshUser({ ...user, ...next });
        setStatus('Settings updated');
      } catch (err) {
        setStatus(err.response?.data?.error || 'Could not update settings');
      }
      setSaving(false);
    }, () => setStatus('Could not access your location'));
  };

  const formatCurrency = (value) => `INR ${Number(value || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
  const activePlanCode = monetization?.activeSubscriptionCode || user?.activeSubscriptionCode || 'FREE';

  return (
    <div style={{ minHeight: '100vh', background: 'var(--page-bg)', color: 'var(--text)', padding: '96px 20px 40px' }}>
      <div style={{ maxWidth: 980, margin: '0 auto' }}>
        <div style={{ marginBottom: 24 }}>
          <h1 style={{ margin: 0, fontFamily: "'Syne',sans-serif", fontSize: '2rem' }}>Settings</h1>
          <p style={{ margin: '8px 0 0', color: 'var(--text2)' }}>
            Privacy, safety, notifications, and support preferences for your Campus Mart account.
          </p>
        </div>

        {status && (
          <div className={status === 'Settings updated' ? 'alert alert-success' : 'alert alert-error'} style={{ marginBottom: 16 }}>
            {status}
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16 }}>
          <SettingsCard title="Notification Preferences">
            <ToggleRow label="Push notifications" sub="New chat, offer, item and order updates" checked={form.pushNotificationsEnabled} onChange={(v) => handleToggle('pushNotificationsEnabled', v)} />
            <ToggleRow label="Email notifications" sub="Important account and marketplace alerts" checked={form.emailNotificationsEnabled} onChange={(v) => handleToggle('emailNotificationsEnabled', v)} />
            <LinkRow to="/notifications" title="Open notification center" text="Review inbox alerts and mark updates read." />
          </SettingsCard>

          <SettingsCard title="Display & Personalization">
            <div>
              <div style={labelStyle}>Theme mode</div>
              <select value={themeMode} onChange={(e) => setThemeMode(e.target.value)} style={inputStyle}>
                <option value="dark">Dark</option>
                <option value="light">Light</option>
                <option value="system">System</option>
              </select>
              <div style={{ color: 'var(--muted)', fontSize: 13, marginTop: 6 }}>
                Switch between default dark marketplace mode, a cleaner light mode, or automatic system preference.
              </div>
            </div>
            <LinkRow to="/activity" title="Activity history" text="Track notifications, listings, support actions, and order events." />
          </SettingsCard>

          <SettingsCard title="Privacy Controls">
            <ToggleRow label="Show phone on listings" sub="Let buyers contact you directly from listing pages" checked={form.showPhoneOnListings} onChange={(v) => handleToggle('showPhoneOnListings', v)} />
            <ToggleRow label="Allow direct chat" sub="Turn this off if you only want contact through listings and offers" checked={form.allowDirectChat} onChange={(v) => handleToggle('allowDirectChat', v)} />
            <div style={{
              padding: 14,
              borderRadius: 14,
              border: '1px solid rgba(91,75,255,0.22)',
              background: 'rgba(91,75,255,0.08)',
              color: '#D9D5FF',
              lineHeight: 1.6,
              fontSize: 13,
            }}>
              Verification: <strong>{identityVerified ? 'Fully verified' : 'Partial verification'}</strong><br />
              Contact plan: <strong>{user?.contactAccessTier || 'FREE'}</strong>
              {user?.contactAccessExpiresAt ? ` until ${new Date(user.contactAccessExpiresAt).toLocaleDateString('en-IN')}` : ''}
              <br />
              Seller phone visibility now follows both seller preference and launch safety policy. In-app chat remains the default safe path for free users.
            </div>
            <div>
              <div style={labelStyle}>Privacy mode</div>
              <select
                value={form.privacyMode}
                onChange={(e) => handleToggle('privacyMode', e.target.value)}
                style={inputStyle}
              >
                <option value="CAMPUS_ONLY">Campus Only</option>
                <option value="LIMITED">Limited Visibility</option>
                <option value="PUBLIC">Public Profile</option>
              </select>
            </div>
            <div>
              <div style={labelStyle}>Language</div>
              <select
                value={form.preferredLanguage}
                onChange={(e) => handleToggle('preferredLanguage', e.target.value)}
                style={inputStyle}
              >
                <option value="EN">English</option>
                <option value="HI">Hindi</option>
                <option value="HINGLISH">Hinglish</option>
              </select>
            </div>
            <div>
              <div style={labelStyle}>Saved location label</div>
              <input
                value={form.locationLabel}
                onChange={(e) => setForm((prev) => ({ ...prev, locationLabel: e.target.value }))}
                onBlur={(e) => handleToggle('locationLabel', e.target.value)}
                placeholder="Campus gate, hostel area, city"
                style={inputStyle}
              />
            </div>
            <button onClick={handleSaveLocation} style={saveButtonStyle}>Use current location for nearby filters</button>
          </SettingsCard>

          <SettingsCard title="Monetization & Plans">
            <div style={{
              padding: 14,
              borderRadius: 14,
              border: '1px solid rgba(0,212,170,0.22)',
              background: 'rgba(0,212,170,0.08)',
              color: '#C8F5EA',
              lineHeight: 1.6,
            }}>
              Current plan: <strong>{activePlanCode}</strong>
              {monetization?.contactAccessExpiresAt ? ` until ${new Date(monetization.contactAccessExpiresAt).toLocaleDateString('en-IN')}` : ''}
              <br />
              Seller fee: <strong>{Number(monetization?.commissionPercent ?? user?.currentCommissionPercent ?? 7).toFixed(2)}%</strong>
              {' · '}
              Boost credits left: <strong>{monetization?.availableBoostCredits ?? user?.availableBoostCredits ?? 0}</strong>
              <br />
              Released platform fees tracked: <strong>{formatCurrency(monetization?.releasedPlatformFees)}</strong>
              {' · '}
              Pending seller net: <strong>{formatCurrency(monetization?.pendingSellerNet)}</strong>
            </div>

            {monetizationLoading ? (
              <div style={{ color: 'var(--text2)' }}>Loading monetization summary...</div>
            ) : (
              <>
                <div style={{ display: 'grid', gap: 10 }}>
                  {(monetization?.plans || []).map((plan) => {
                    const isActive = activePlanCode === plan.code;
                    return (
                      <div key={plan.code} style={{
                        padding: 14,
                        borderRadius: 14,
                        border: isActive ? '1px solid rgba(91,75,255,0.45)' : '1px solid rgba(255,255,255,0.08)',
                        background: isActive ? 'rgba(91,75,255,0.10)' : 'var(--surface2)',
                      }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, alignItems: 'flex-start' }}>
                          <div>
                            <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                              <strong>{plan.name}</strong>
                              {plan.highlight && (
                                <span style={{
                                  padding: '2px 8px',
                                  borderRadius: 999,
                                  background: 'rgba(245,158,11,0.16)',
                                  color: '#F59E0B',
                                  fontSize: 12,
                                  fontWeight: 700,
                                }}>
                                  {plan.highlight}
                                </span>
                              )}
                            </div>
                            <div style={{ color: 'var(--text2)', fontSize: 13, marginTop: 6 }}>{plan.description}</div>
                            <div style={{ color: '#A0A8C8', fontSize: 13, marginTop: 8 }}>
                              {formatCurrency(plan.price)} · {plan.durationDays || 'No expiry'} days · {plan.commissionPercent}% seller fee · {plan.boostCredits} boosts
                            </div>
                            {Array.isArray(plan.features) && plan.features.length > 0 && (
                              <div style={{ color: '#8FA0C4', fontSize: 12, marginTop: 8 }}>
                                {plan.features.join(' · ')}
                              </div>
                            )}
                          </div>
                          <button
                            disabled={Boolean(activatingPlan) || isActive}
                            onClick={() => handleActivatePlan(plan.code)}
                            style={{
                              ...saveButtonStyle,
                              opacity: Boolean(activatingPlan) || isActive ? 0.65 : 1,
                              cursor: Boolean(activatingPlan) || isActive ? 'not-allowed' : 'pointer',
                              minWidth: 118,
                            }}
                          >
                            {isActive ? 'Active' : activatingPlan === plan.code ? 'Activating...' : 'Test Activate'}
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>

                {Array.isArray(monetization?.recentLedger) && monetization.recentLedger.length > 0 && (
                  <div style={{ display: 'grid', gap: 10 }}>
                    <div style={{ ...labelStyle, marginBottom: 0 }}>Recent Commission Ledger</div>
                    {monetization.recentLedger.slice(0, 4).map((entry) => (
                      <div key={entry.id} style={{
                        padding: 12,
                        borderRadius: 12,
                        background: 'var(--surface2)',
                        border: '1px solid rgba(255,255,255,0.08)',
                      }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, marginBottom: 4 }}>
                          <strong>{entry.entryType}</strong>
                          <span style={{ color: 'var(--text2)', fontSize: 12 }}>
                            {entry.createdAt ? new Date(entry.createdAt).toLocaleDateString('en-IN') : ''}
                          </span>
                        </div>
                        <div style={{ color: '#A0A8C8', fontSize: 13 }}>
                          Fee {formatCurrency(entry.platformFeeAmount)} · Seller net {formatCurrency(entry.sellerNetAmount)}
                        </div>
                        {entry.itemTitle && (
                          <div style={{ color: '#8FA0C4', fontSize: 12, marginTop: 4 }}>
                            {entry.itemTitle}
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </>
            )}
          </SettingsCard>

          <SettingsCard title="Safety Controls">
            {blockedUsers.length === 0 ? (
              <div style={{ color: 'var(--text2)' }}>You have not blocked anyone yet.</div>
            ) : (
              <div style={{ display: 'grid', gap: 10 }}>
                {blockedUsers.map((entry) => (
                  <div key={entry.id} style={blockedRowStyle}>
                    <div>
                      <div style={{ fontWeight: 700 }}>{entry.blocked?.name || 'User'}</div>
                      <div style={{ color: '#8FA0C4', fontSize: 13 }}>{entry.blocked?.email || 'Blocked user'}</div>
                    </div>
                    <button onClick={() => handleUnblock(entry.blocked?.id)} style={dangerGhostStyle}>Unblock</button>
                  </div>
                ))}
              </div>
            )}
            <LinkRow to="/help" title="Need urgent support?" text="Use help center, feedback, and report tools for unsafe marketplace behavior." />
          </SettingsCard>

          <SettingsCard title="Support Shortcuts">
            <div style={{ display: 'grid', gap: 10 }}>
              <LinkRow to="/support-tickets" title="My support tickets" text="Track every feedback, bug report, or contact request with ticket status." />
              <LinkRow to="/contact" title="Email support" text="Reach the team for account and product help." />
              <LinkRow to="/feedback" title="Send feedback" text="Share UI, speed, and product improvement ideas." />
              <LinkRow to="/report-problem" title="Report a problem" text="Escalate bugs, suspicious activity, or broken flows." />
              <LinkRow to="/refund-policy" title="Refund policy" text="Review how disputes and refunds are handled." />
            </div>
            <div style={{
              marginTop: 14,
              padding: 14,
              borderRadius: 14,
              border: '1px solid rgba(0,212,170,0.22)',
              background: 'rgba(0,212,170,0.08)',
              color: '#C8F5EA',
            }}>
              Email support: <a href={`mailto:${SUPPORT_EMAIL}`} style={{ color: '#00D4AA' }}>{SUPPORT_EMAIL}</a>
              {SUPPORT_WHATSAPP_LINK && (
                <span> | WhatsApp support: <a href={SUPPORT_WHATSAPP_LINK} target="_blank" rel="noreferrer" style={{ color: '#00D4AA' }}>Open chat</a></span>
              )}
            </div>
          </SettingsCard>

          <SettingsCard title="Social & Community">
            {(socialLinks.length > 0 ? socialLinks : SOCIAL_LINKS).length > 0 ? (
              <div style={{ display: 'grid', gap: 10 }}>
                {(socialLinks.length > 0 ? socialLinks : SOCIAL_LINKS).map((social) => (
                  <a
                    key={social.key}
                    href={social.href}
                    target="_blank"
                    rel="noreferrer"
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      gap: 12,
                      alignItems: 'center',
                      padding: 14,
                      borderRadius: 14,
                      border: '1px solid rgba(255,255,255,0.08)',
                      background: 'var(--surface2)',
                      color: 'var(--text)',
                      textDecoration: 'none',
                    }}
                  >
                    <span style={{ fontWeight: 700 }}>{social.label}</span>
                    <span style={{ color: 'var(--text2)', fontSize: 13 }}>{social.short}</span>
                  </a>
                ))}
              </div>
            ) : (
              <div style={{ color: 'var(--text2)', lineHeight: 1.6 }}>
                Social handles can be published from deploy configuration when your startup brand accounts are ready.
              </div>
            )}
          </SettingsCard>
        </div>

        {saving && <div style={{ color: 'var(--text2)', marginTop: 14 }}>Saving changes...</div>}
      </div>
    </div>
  );
}

function SettingsCard({ title, children }) {
  return (
    <div style={{
      background: 'var(--surface)',
      border: '1px solid var(--border)',
      borderRadius: 18,
      padding: 18,
    }}>
      <h2 style={{ margin: '0 0 16px', fontSize: 18, fontWeight: 800 }}>{title}</h2>
      <div style={{ display: 'grid', gap: 16 }}>{children}</div>
    </div>
  );
}

function ToggleRow({ label, sub, checked, onChange }) {
  return (
    <label style={{
      display: 'flex',
      justifyContent: 'space-between',
      gap: 12,
      alignItems: 'center',
        padding: 14,
        borderRadius: 14,
        border: '1px solid rgba(255,255,255,0.08)',
        background: 'var(--surface2)',
        cursor: 'pointer',
      }}>
      <div>
        <div style={{ fontWeight: 700 }}>{label}</div>
        <div style={{ color: 'var(--text2)', fontSize: 13, marginTop: 4 }}>{sub}</div>
      </div>
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
    </label>
  );
}

function LinkRow({ to, title, text }) {
  return (
    <Link to={to} style={{
      display: 'block',
      textDecoration: 'none',
      padding: 14,
      borderRadius: 14,
      border: '1px solid rgba(255,255,255,0.08)',
      background: 'var(--surface2)',
      color: 'var(--text)',
    }}>
      <div style={{ fontWeight: 700 }}>{title}</div>
      <div style={{ color: 'var(--text2)', fontSize: 13, marginTop: 4 }}>{text}</div>
    </Link>
  );
}

const labelStyle = {
  color: 'var(--text2)',
  fontSize: 12,
  marginBottom: 6,
  fontWeight: 700,
};

const inputStyle = {
  width: '100%',
  padding: '12px 14px',
  borderRadius: 12,
  background: 'var(--surface2)',
  border: '1px solid rgba(255,255,255,0.08)',
  color: 'var(--text)',
};

const blockedRowStyle = {
  display: 'flex',
  justifyContent: 'space-between',
  gap: 12,
  alignItems: 'center',
  padding: 12,
  borderRadius: 12,
  background: 'var(--surface2)',
  border: '1px solid rgba(255,255,255,0.08)',
};

const dangerGhostStyle = {
  padding: '8px 12px',
  borderRadius: 10,
  border: '1px solid rgba(239,68,68,0.3)',
  background: 'rgba(239,68,68,0.12)',
  color: '#EF4444',
  fontWeight: 700,
  cursor: 'pointer',
};

const saveButtonStyle = {
  padding: '10px 14px',
  borderRadius: 10,
  border: '1px solid rgba(91,75,255,0.35)',
  background: 'rgba(91,75,255,0.12)',
  color: '#C9C2FF',
  fontWeight: 700,
  cursor: 'pointer',
};
