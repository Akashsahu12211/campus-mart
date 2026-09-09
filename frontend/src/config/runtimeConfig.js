const trimValue = (value) => (typeof value === 'string' ? value.trim() : '');

const isLocalHost = (hostname) =>
  hostname === 'localhost' || hostname === '127.0.0.1' || hostname.endsWith('.local');

const buildProductionOrigin = (fallbackPath) => {
  if (fallbackPath === '/api') {
    return 'https://api.mycampusmart.in/api';
  }

  if (fallbackPath === '/ws') {
    return 'https://api.mycampusmart.in/ws';
  }

  return fallbackPath;
};

const normalizeBaseUrl = (value, fallbackPath) => {
  const trimmed = trimValue(value);
  if (trimmed) {
    const normalized = trimmed.replace(/\/+$/, '');
    if (typeof window !== 'undefined' && window.location?.protocol === 'https:' && normalized.startsWith('http://')) {
      return `https://${normalized.slice('http://'.length)}`;
    }
    return normalized;
  }

  if (typeof window !== 'undefined' && window.location?.origin) {
    const { origin, hostname } = window.location;
    if (!isLocalHost(hostname) && hostname.endsWith('mycampusmart.in')) {
      return buildProductionOrigin(fallbackPath);
    }
    return `${origin}${fallbackPath}`;
  }

  return buildProductionOrigin(fallbackPath);
};

export const API_BASE_URL = normalizeBaseUrl(process.env.REACT_APP_API_URL, '/api');
export const WS_BASE_URL = normalizeBaseUrl(process.env.REACT_APP_WS_URL, '/ws');

export const IS_PRODUCTION = process.env.NODE_ENV === 'production';
export const DEBUG_LOGS_ENABLED =
  process.env.REACT_APP_ENABLE_DEBUG_LOGS === 'true' || !IS_PRODUCTION;
