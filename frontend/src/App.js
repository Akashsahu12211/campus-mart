import React, { createContext, useContext, useEffect, useState, Suspense, lazy } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Navbar from './components/Navbar';
import ErrorBoundary from './components/ErrorBoundary';
import Footer from './components/Footer';
import { clearAuthStorage, logoutUser } from './api/api';
import NotificationToaster from './components/NotificationToaster';
import { initializeWebPushForUser, unregisterWebPush } from './services/webPushService';
import { LanguageProvider } from './context/LanguageContext';
import { ThemeProvider } from './context/ThemeContext';
import { SiteSettingsProvider } from './context/SiteSettingsContext';
import { logger } from './utils/logger';

// ── Eagerly loaded pages (frequently used, small footprint) ──
import Home from './pages/Home';
import Login from './pages/Login';
import Register from './pages/Register';
import About from './pages/About';
import Contact from './pages/Contact';
import PrivacyPolicy from './pages/PrivacyPolicy';
import TermsAndConditions from './pages/TermsAndConditions';
import CommunityGuidelines from './pages/CommunityGuidelines';
import Feedback from './pages/Feedback';
import ReportProblem from './pages/ReportProblem';

// ── Lazily loaded pages (reduce initial bundle) ──
const AddItem = lazy(() => import('./pages/AddItem'));
const ItemDetail = lazy(() => import('./pages/ItemDetail'));
const MyItems = lazy(() => import('./pages/MyItems'));
const MyOrders = lazy(() => import('./pages/MyOrders'));
const MyWishlist = lazy(() => import('./pages/MyWishlist'));
const MyReservations = lazy(() => import('./pages/MyReservations'));
const Profile = lazy(() => import('./pages/Profile'));
const EditItem = lazy(() => import('./pages/EditItem'));
const ChatInbox = lazy(() => import('./pages/ChatInbox'));
const ChatScreen = lazy(() => import('./pages/ChatScreen'));
const HelpCenter = lazy(() => import('./pages/HelpCenter'));
const FAQ = lazy(() => import('./pages/FAQ'));
const ForgotPassword = lazy(() => import('./pages/ForgotPassword'));
const Notifications = lazy(() => import('./pages/Notifications'));
const Settings = lazy(() => import('./pages/Settings'));
const ActivityHistory = lazy(() => import('./pages/ActivityHistory'));
const RefundPolicy = lazy(() => import('./pages/RefundPolicy'));
const CookiePolicy = lazy(() => import('./pages/CookiePolicy'));
const Disclaimer = lazy(() => import('./pages/Disclaimer'));
const SupportTickets = lazy(() => import('./pages/SupportTickets'));

// ── Admin pages (lazy loaded) ──
const AdminLayout = lazy(() => import('./pages/admin/AdminLayout'));
const AdminDashboard = lazy(() => import('./pages/admin/AdminDashboard'));
const AdminUsers = lazy(() => import('./pages/admin/AdminUsers'));
const AdminItems = lazy(() => import('./pages/admin/AdminItems'));
const AdminReports = lazy(() => import('./pages/admin/AdminReports'));
const AdminLogs = lazy(() => import('./pages/admin/AdminLogs'));
const AdminSupport = lazy(() => import('./pages/admin/AdminSupport'));
const AdminSiteSettings = lazy(() => import('./pages/admin/AdminSiteSettings'));

// ── Loading fallback ──
function LoadingFallback() {
  return (
    <div style={{ 
      display: 'flex', 
      justifyContent: 'center', 
      alignItems: 'center', 
      minHeight: '100vh',
      fontSize: '18px',
      color: '#666'
    }}>
      Loading...
    </div>
  );
}

export const AuthContext = createContext(null);
export const useAuth = () => useContext(AuthContext);

function PrivateRoute({ children }) {
  const { user } = useAuth();
  return user ? children : <Navigate to="/login" />;
}

function AdminRoute({ children }) {
  const { user } = useAuth();
  if (!user) {
    return <Navigate to="/login" />;
  }
  return user.role === 'ADMIN' ? children : <Navigate to="/" replace />;
}

export default function App() {
  const [user, setUser] = useState(() => {
    try {
      const token = localStorage.getItem('campusmart_token');
      const saved = localStorage.getItem('campusmart_user');
      if (!token || !saved) {
        clearAuthStorage();
        return null;
      }
      return JSON.parse(saved);
    } catch {
      clearAuthStorage();
      return null;
    }
  });

  const login = (u) => {
    setUser(u);
    localStorage.setItem('campusmart_user', JSON.stringify(u));
  };

  const logout = async ({ allDevices = false } = {}) => {
    if (user?.id) {
      void unregisterWebPush(user.id);
    }
    setUser(null);
    await logoutUser({ allDevices });
  };

  const refreshUser = (u) => {
    logger.debug('RefreshUser called', { ...u, profilePic: u.profilePic ? '...[exists]' : 'null' });
    setUser(u);
    localStorage.setItem('campusmart_user', JSON.stringify(u));
  };

  useEffect(() => {
    if (!user?.id || typeof Notification === 'undefined' || Notification.permission !== 'granted') {
      return;
    }

    void initializeWebPushForUser(user);
  }, [user]);

  return (
    <AuthContext.Provider value={{ user, login, logout, refreshUser }}>
      <ErrorBoundary>
        <ThemeProvider>
          <SiteSettingsProvider>
            <LanguageProvider>
              <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
                <Navbar />
                <NotificationToaster />
                <Suspense fallback={<LoadingFallback />}>
                  <Routes>
                    <Route path="/" element={<Home />} />
                    <Route path="/login" element={<Login />} />
                    <Route path="/register" element={<Register />} />
                    <Route path="/forgot-password" element={<ForgotPassword />} />
                    <Route path="/about" element={<About />} />
                    <Route path="/contact" element={<Contact />} />
                    <Route path="/help" element={<HelpCenter />} />
                    <Route path="/faq" element={<FAQ />} />
                    <Route path="/privacy-policy" element={<PrivacyPolicy />} />
                    <Route path="/terms-and-conditions" element={<TermsAndConditions />} />
                    <Route path="/community-guidelines" element={<CommunityGuidelines />} />
                    <Route path="/refund-policy" element={<RefundPolicy />} />
                    <Route path="/cookie-policy" element={<CookiePolicy />} />
                    <Route path="/disclaimer" element={<Disclaimer />} />
                    <Route path="/feedback" element={<Feedback />} />
                    <Route path="/report-problem" element={<ReportProblem />} />
                    <Route path="/notifications" element={<PrivateRoute><Notifications /></PrivateRoute>} />
                    <Route path="/settings" element={<PrivateRoute><Settings /></PrivateRoute>} />
                    <Route path="/support-tickets" element={<PrivateRoute><SupportTickets /></PrivateRoute>} />
                    <Route path="/activity" element={<PrivateRoute><ActivityHistory /></PrivateRoute>} />
                    <Route path="/item/:id" element={<ItemDetail />} />
                    <Route path="/add-item" element={<PrivateRoute><AddItem /></PrivateRoute>} />
                    <Route path="/edit-item/:id" element={<PrivateRoute><EditItem /></PrivateRoute>} />
                    <Route path="/my-items" element={<PrivateRoute><MyItems /></PrivateRoute>} />
                    <Route path="/orders" element={<PrivateRoute><MyOrders /></PrivateRoute>} />
                    <Route path="/wishlist" element={<PrivateRoute><MyWishlist /></PrivateRoute>} />
                    <Route path="/reservations" element={<PrivateRoute><MyReservations /></PrivateRoute>} />
                    <Route path="/profile" element={<PrivateRoute><Profile /></PrivateRoute>} />
                    <Route path="/chat" element={<PrivateRoute><ChatInbox /></PrivateRoute>} />
                    <Route path="/chat/room" element={<PrivateRoute><ChatScreen /></PrivateRoute>} />
                    <Route
                      path="/admin"
                      element={(
                        <AdminRoute>
                          <AdminLayout><AdminDashboard /></AdminLayout>
                        </AdminRoute>
                      )}
                    />
                    <Route
                      path="/admin/users"
                      element={(
                        <AdminRoute>
                          <AdminLayout><AdminUsers /></AdminLayout>
                        </AdminRoute>
                      )}
                    />
                    <Route
                      path="/admin/items"
                      element={(
                        <AdminRoute>
                          <AdminLayout><AdminItems /></AdminLayout>
                        </AdminRoute>
                      )}
                    />
                    <Route
                      path="/admin/reports"
                      element={(
                        <AdminRoute>
                          <AdminLayout><AdminReports /></AdminLayout>
                        </AdminRoute>
                      )}
                    />
                    <Route
                      path="/admin/support"
                      element={(
                        <AdminRoute>
                          <AdminLayout><AdminSupport /></AdminLayout>
                        </AdminRoute>
                      )}
                    />
                    <Route
                      path="/admin/logs"
                      element={(
                        <AdminRoute>
                          <AdminLayout><AdminLogs /></AdminLayout>
                        </AdminRoute>
                      )}
                    />
                    <Route
                      path="/admin/site-settings"
                      element={(
                        <AdminRoute>
                          <AdminLayout><AdminSiteSettings /></AdminLayout>
                        </AdminRoute>
                      )}
                    />
                  </Routes>
                </Suspense>
                <Footer />
              </BrowserRouter>
            </LanguageProvider>
          </SiteSettingsProvider>
        </ThemeProvider>
      </ErrorBoundary>
    </AuthContext.Provider>
  );
}
