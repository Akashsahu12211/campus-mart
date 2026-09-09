import axios from 'axios';
import { API_BASE_URL } from '../config/runtimeConfig';
import { logger } from '../utils/logger';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: { 'Content-Type': 'application/json' },
});

const CATEGORY_CACHE_TTL_MS = 5 * 60 * 1000;
const ACCESS_TOKEN_KEY = 'campusmart_token';
const REFRESH_TOKEN_KEY = 'campusmart_refresh_token';
let cachedCategories = null;
let categoriesCachedAt = 0;

export const clearAuthStorage = () => {
  localStorage.removeItem(ACCESS_TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
  localStorage.removeItem('campusmart_user');
};

export const getAuthToken = () => localStorage.getItem(ACCESS_TOKEN_KEY);
export const getRefreshToken = () => localStorage.getItem(REFRESH_TOKEN_KEY);

export const persistAuthSession = (payload = {}) => {
  if (payload?.token) {
    localStorage.setItem(ACCESS_TOKEN_KEY, payload.token);
  }
  if (payload?.refreshToken) {
    localStorage.setItem(REFRESH_TOKEN_KEY, payload.refreshToken);
  } else {
    localStorage.removeItem(REFRESH_TOKEN_KEY);
  }
};

export const hasAuthSession = () => {
  const token = localStorage.getItem(ACCESS_TOKEN_KEY);
  const savedUser = localStorage.getItem('campusmart_user');
  return Boolean(token && savedUser);
};

// ── 🔥 Token auto-attach interceptor ──
api.interceptors.request.use(config => {
  const token = getAuthToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// ── 🔥 Token auto-refresh on 401 ──
let isRefreshing = false;
let failedQueue = [];

const processQueue = (error, token = null) => {
  failedQueue.forEach(prom => {
    if (error) {
      prom.reject(error);
    } else {
      prom.resolve(token);
    }
  });
  
  isRefreshing = false;
  failedQueue = [];
};

api.interceptors.response.use(
  response => response,
  error => {
    const status = error.response?.status;
    const originalRequest = error.config;
    const isRefreshRequest = originalRequest?.url?.includes('/auth/refresh');

    if (status === 401 && isRefreshRequest) {
      processQueue(error, null);
      clearAuthStorage();
      window.location.href = '/login';
      return Promise.reject(error);
    }

    if (status === 401 && !originalRequest?._retry) {
      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        })
          .then(token => {
            originalRequest.headers['Authorization'] = `Bearer ${token}`;
            return api(originalRequest);
          })
          .catch(err => Promise.reject(err));
      }

      originalRequest._retry = true;
      isRefreshing = true;

      const token = getAuthToken();
      const refreshToken = getRefreshToken();
      if (!refreshToken) {
        processQueue(new Error('No token'), null);
        clearAuthStorage();
        window.location.href = '/login';
        return Promise.reject(error);
      }

      return api
        .post('/auth/refresh', { refreshToken }, {
          headers: token ? { Authorization: `Bearer ${token}` } : {},
        })
        .then(res => {
          const newToken = res.data.token;
          persistAuthSession(res.data);
          
          api.defaults.headers.common['Authorization'] = `Bearer ${newToken}`;
          originalRequest.headers['Authorization'] = `Bearer ${newToken}`;
          
          processQueue(null, newToken);
          return api(originalRequest);
        })
        .catch(err => {
          processQueue(err, null);
          clearAuthStorage();
          window.location.href = '/login';
          return Promise.reject(err);
        });
    }

    // Handle other error statuses
    const message = String(
      error.response?.data?.error ||
      error.response?.data?.message ||
      error.message ||
      ''
    ).toLowerCase();

    if (status === 403 && message.includes('unauthorized')) {
      const protectedRoutes = ['/orders', '/wishlist', '/add-item', '/my-items', '/chat', '/profile'];
      const isProtectedRoute = protectedRoutes.some(route => window.location.pathname.startsWith(route));
      
      if (isProtectedRoute) {
        clearAuthStorage();
        window.location.href = '/login';
      }
    }
    
    return Promise.reject(error);
  }
);

// ── Students ──────────────────────────────────────────────

// 🔥 Login override (token save karega)
export const loginStudent = async (data) => {
  const res = await api.post('/auth/login', data);
  persistAuthSession(res.data);
  logger.debug('Login response received');
  return res;
};

export const socialLogin = async (data) => {
  const res = await api.post('/auth/social-login', data);
  persistAuthSession(res.data);
  return res;
};

// Logout
export const logoutUser = async ({ allDevices = false } = {}) => {
  const refreshToken = getRefreshToken();
  try {
    if (allDevices) {
      await api.post('/auth/logout-all');
    } else {
      await api.post('/auth/logout', refreshToken ? { refreshToken } : {});
    }
  } catch (error) {
    logger.warn('Logout request failed, clearing local session anyway');
  } finally {
    clearAuthStorage();
  }
};

// Register (same)
export const registerStudent = (data) => api.post('/auth/register', data);
export const getStudentById = (id) => api.get(`/students/${id}`);
export const updateStudent = (id, data) => api.put(`/students/${id}`, data);
export const changePassword = (id, data) => api.put(`/students/${id}/change-password`, data);
export const getStudentStats = (id) => api.get(`/students/${id}/stats`);
export const saveNotificationToken = (data) => api.post('/notifications/token', data);
export const clearNotificationToken = (data) => api.delete('/notifications/token', { data });
export const getNotifications = (userId) => api.get(`/notifications/${userId}`);
export const markNotificationRead = (userId, notificationId) =>
  api.patch(`/notifications/${userId}/${notificationId}/read`);
export const markAllNotificationsRead = (userId) =>
  api.patch(`/notifications/${userId}/read-all`);

// ── Items ─────────────────────────────────────────────────
export const getAllItems = () => api.get('/items');
export const getRecentItems = () => api.get('/items/recent');
export const getItemById = (id) => api.get(`/items/${id}`);
export const getSimilarItems = (id) => api.get(`/items/${id}/similar`);
export const getItemsByCategory = (catId) => api.get(`/items/category/${catId}`);
export const getItemsBySeller = (sellerId) => api.get(`/items/seller/${sellerId}`);
export const uploadItemImage = (file) => {
  const formData = new FormData();
  formData.append('file', file);
  return api.post('/items/images', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
};

// ✅ PAGINATION
export const getPaginatedItems = ({
  page = 0,
  pageSize = 20,
  sort = 'newest',
  q,
  categoryId,
  minPrice,
  maxPrice,
  condition,
  hostel,
  branch,
  userLat,
  userLng,
  radiusKm,
} = {}) =>
  api.get('/items/paginated', {
    params: {
      page,
      pageSize,
      sort,
      ...(q ? { q } : {}),
      ...(categoryId ? { categoryId } : {}),
      ...(minPrice !== '' && minPrice != null ? { minPrice } : {}),
      ...(maxPrice !== '' && maxPrice != null ? { maxPrice } : {}),
      ...(condition ? { condition } : {}),
      ...(hostel ? { hostel } : {}),
      ...(branch ? { branch } : {}),
      ...(userLat != null ? { userLat } : {}),
      ...(userLng != null ? { userLng } : {}),
      ...(radiusKm != null ? { radiusKm } : {}),
    },
  });
export const searchItems = ({
  q,
  minPrice,
  maxPrice,
  condition,
  hostel,
  branch,
  sort = 'newest',
  userLat,
  userLng,
  radiusKm,
}) =>
  api.get('/items/search', {
    params: {
      q,
      sort,
      ...(minPrice !== '' && minPrice != null ? { minPrice } : {}),
      ...(maxPrice !== '' && maxPrice != null ? { maxPrice } : {}),
      ...(condition ? { condition } : {}),
      ...(hostel ? { hostel } : {}),
      ...(branch ? { branch } : {}),
      ...(userLat != null ? { userLat } : {}),
      ...(userLng != null ? { userLng } : {}),
      ...(radiusKm != null ? { radiusKm } : {}),
    },
  });
export const addItem = (data) => api.post('/items', data);
export const updateItem = (id, data) => api.put(`/items/${id}`, data);
export const markAsSold = (id) => api.patch(`/items/${id}/sold`);
export const markAsReserved = (id) => api.patch(`/items/${id}/reserved`);
export const renewItem = (id) => api.patch(`/items/${id}/renew`);
export const deleteItem = (id) => api.delete(`/items/${id}`);

// Reserve item by buyer
export const reserveByBuyer = (itemId) =>
  api.patch(`/items/${itemId}/reserve-by-buyer`, {});

export const unreserveItem = (itemId) =>
  api.patch(`/items/${itemId}/unreserve`);

export const getReservedItems = (buyerId) =>
  api.get(`/items/reserved/buyer/${buyerId}`);

export const getReservedItemsBySeller = (sellerId) =>
  api.get(`/items/reserved/seller/${sellerId}`);

// ── 🔥 Wishlist ────────────────────────────────────────────
export const checkWishlist = (sid, iid) => api.get(`/wishlist/${sid}/check/${iid}`);
export const addToWishlist = (data) => api.post('/wishlist', data);
export const removeFromWishlist = (sid, iid) => api.delete(`/wishlist/${sid}/${iid}`);
export const getWishlist = (id) => api.get(`/wishlist/${id}`);
// ── 💰 Offers ─────────────────────────────────────────────
export const makeOffer = (data) => api.post('/offers', data);
export const getOffersForItem = (itemId) => api.get(`/offers/item/${itemId}`);
export const getOffersForBuyer = (buyerId) => api.get(`/offers/buyer/${buyerId}`);
export const getOffersForSeller = (sellerId) => api.get(`/offers/seller/${sellerId}`);
export const acceptOffer = (offerId) => api.patch(`/offers/${offerId}/accept`);
export const rejectOffer = (offerId) => api.patch(`/offers/${offerId}/reject`);
export const getOfferById = (offerId) => api.get(`/offers/${offerId}`);
// ── Categories ────────────────────────────────────────────
export const clearCategoryCache = () => {
  cachedCategories = null;
  categoriesCachedAt = 0;
};

export const getAllCategories = async ({ forceRefresh = false } = {}) => {
  const cacheIsFresh =
    !forceRefresh &&
    Array.isArray(cachedCategories) &&
    Date.now() - categoriesCachedAt < CATEGORY_CACHE_TTL_MS;

  if (cacheIsFresh) {
    return { data: cachedCategories };
  }

  const res = await api.get('/categories');
  cachedCategories = Array.isArray(res.data) ? res.data : [];
  categoriesCachedAt = Date.now();
  return res;
};

// ── Transactions ──────────────────────────────────────────
export const createTransaction = (data) => api.post('/transactions', data);
export const getTransactionsByBuyer = (buyerId) => api.get(`/transactions/buyer/${buyerId}`);




export const getBoughtHistory   = (id)   => api.get(`/transactions/bought/${id}`);
export const getSoldHistory     = (id)   => api.get(`/transactions/sold/${id}`);

export const submitFeedback = (data) =>
  api.post('/support/feedback', data);

export const submitProblemReport = (data) =>
  api.post('/support/report-problem', data);

export const submitContactMessage = (data) =>
  api.post('/support/contact', data);

export const getSupportTickets = (studentId) =>
  api.get(`/support/student/${studentId}`);

export const blockUser = (data) =>
  api.post('/blocks', data);

export const unblockUser = (blockedId, blockerId) =>
  api.delete(`/blocks/${blockedId}`, { params: { blockerId } });

export const checkBlockStatus = (viewerId, targetUserId) =>
  api.get('/blocks/check', { params: { viewerId, targetUserId } });

export const getBlockedUsers = (blockerId) =>
  api.get(`/blocks/${blockerId}`);

export const getActivityHistory = (userId) =>
  api.get(`/activity/${userId}`);

export const submitItemReport = (data) =>
  api.post('/reports', data);

export const requestForgotPassword = (data) =>
  api.post('/auth/forgot-password/request', data);

export const resetForgotPassword = (data) =>
  api.post('/auth/forgot-password/reset', data);

export const deleteAccount = (id, data) =>
  api.post(`/students/${id}/delete-account`, data);

export default api;

export const getSellerReviews = (sellerId) =>
  api.get(`/reviews/seller/${sellerId}`);

export const getItemReviews = (itemId) =>
  api.get(`/reviews/item/${itemId}`);

export const checkReview = (reviewerId, itemId) =>
  api.get(`/reviews/check?reviewerId=${reviewerId}&itemId=${itemId}`);

export const addReview = (data) =>
  api.post('/reviews', data);

export const updateReview = (id, data) =>
  api.put(`/reviews/${id}`, data);

export const deleteReview = (id) =>
  api.delete(`/reviews/${id}`);

// Auth endpoints
export const registerUser       = (data)        => api.post('/auth/register', data);
export const verifyEmailOtp     = (data)        => api.post('/auth/verify-email', data);
export const verifyPhoneOtp     = (data)        => api.post('/auth/verify-phone', data);
export const resendEmailOtp     = (data)        => api.post('/auth/resend-email-otp', data);
export const resendPhoneOtp     = (data)        => api.post('/auth/resend-phone-otp', data);
export const loginUser          = (data)        => api.post('/auth/login', data);

// ✅ OTP ENDPOINTS
export const requestEmailOtp = (data) => api.post('/auth/otp/request-email', data);
export const requestPhoneOtp = (data) => api.post('/auth/otp/request-phone', data);
export const verifyOtp = (data) => api.post('/auth/otp/verify', data);
export const resendOtp = (data) => api.post('/auth/otp/resend', data);

// ── Chat REST APIs ────────────────────────────────────────────
export const getConversation = (user1Id, user2Id, itemId) => {
  const params = new URLSearchParams({
    user1Id, user2Id,
    ...(itemId ? { itemId } : {})
  });
  return api.get(`/chat/conversation?${params}`);
};

export const getInbox     = (userId)          =>
  api.get(`/chat/inbox/${userId}`);

export const sendMessage  = (data)            =>
  api.post('/chat/send', data);

export const markAsRead   = (receiverId, senderId) =>
  api.post('/chat/mark-read', { receiverId, senderId });

export const getUnreadCount = (userId)        =>
  api.get(`/chat/unread/${userId}`);

// ── 💳 RAZORPAY PAYMENT GATEWAY ──────────────────────────────

export const createPaymentOrder  = (data)     =>
  api.post('/payments/create-order', data);

export const verifyPayment       = (data)     =>
  api.post('/payments/verify', data);

export const confirmDelivery     = (orderId) =>
  api.post(`/payments/${orderId}/confirm-delivery`, {});

export const raiseDispute        = (orderId, data)    =>
  api.post(`/payments/${orderId}/dispute`, data);

export const cancelOrder         = (orderId) =>
  api.post(`/payments/${orderId}/cancel`, {});

export const getBuyerOrders      = (buyerId)  =>
  api.get(`/payments/buyer/${buyerId}`);

export const getSellerOrders     = (sellerId) =>
  api.get(`/payments/seller/${sellerId}`);

export const getOrderTimeline    = (orderId)  =>
  api.get(`/payments/${orderId}/timeline`);

export const getPaymentConfig    = ()         =>
  api.get('/payments/config');

export const getMonetizationPlans = () =>
  api.get('/monetization/plans');

export const getMonetizationSummary = (studentId) =>
  api.get(`/monetization/summary/${studentId}`);

export const getMonetizationLedger = (studentId) =>
  api.get(`/monetization/ledger/${studentId}`);

export const activateMonetizationPlan = (planCode) =>
  api.post('/monetization/subscribe', { planCode });

export const boostMonetizedListing = (itemId) =>
  api.post(`/monetization/items/${itemId}/boost`);

//export const checkWishlist = (sid, iid) => api.get(`/wishlist/${sid}/check/${iid}`);
// export const addToWishlist = (data) => api.post('/wishlist', data);
// export const removeFromWishlist = (sid, iid) => api.delete(`/wishlist/${sid}/${iid}`);
// export const getWishlist = (id) => api.get(`/wishlist/${id}`);
