import api from './api';

export const getAdminStats = () => api.get('/admin/stats');

export const getUserGrowthChart = () => api.get('/admin/charts/users');

export const getListingsChart = () => api.get('/admin/charts/listings');

export const getCategoryDist = () => api.get('/admin/charts/categories');

export const getAdminUsers = (search = '') =>
  api.get('/admin/users', {
    params: search ? { search } : {},
  });

export const changeUserRole = (targetId, data) =>
  api.patch(`/admin/users/${targetId}/role`, data);

export const banUser = (targetId, data) =>
  api.patch(`/admin/users/${targetId}/ban`, data);

export const unbanUser = (targetId, data = {}) =>
  api.patch(`/admin/users/${targetId}/unban`, data);

export const deleteUserAdmin = (targetId) =>
  api.delete(`/admin/users/${targetId}`);

export const getAdminItems = (status = '') =>
  api.get('/admin/items', {
    params: status ? { status } : {},
  });

export const hideItemAdmin = (itemId, data) =>
  api.patch(`/admin/items/${itemId}/hide`, data);

export const restoreItemAdmin = (itemId, data = {}) =>
  api.patch(`/admin/items/${itemId}/restore`, data);

export const deleteItemAdmin = (itemId) =>
  api.delete(`/admin/items/${itemId}`);

export const getAdminReports = (pendingOnly = false) =>
  api.get('/admin/reports', {
    params: { pendingOnly },
  });

export const reviewReport = (reportId, data) =>
  api.patch(`/admin/reports/${reportId}`, data);

export const getAdminLogs = () => api.get('/admin/logs');

export const getAdminSupport = (status = '') =>
  api.get('/admin/support', {
    params: status ? { status } : {},
  });

export const updateAdminSupportStatus = (requestId, data) =>
  api.patch(`/admin/support/${requestId}`, data);

export const getAdminSiteSettings = () => api.get('/admin/site-settings');

export const updateAdminSiteSettings = (data) =>
  api.put('/admin/site-settings', data);

export const uploadAdminCartLogo = (file) => {
  const formData = new FormData();
  formData.append('file', file);
  return api.post('/admin/site-settings/cart-logo', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
};

export const submitReport = (data) => api.post('/reports', data);

export const getDisputedOrders = () => api.get('/admin/disputes');

export const resolveDispute = (orderId, data) =>
  api.patch(`/admin/disputes/${orderId}/resolve`, data);

export const refundPayment = (orderId, data) =>
  api.post(`/payments/${orderId}/refund`, data);
