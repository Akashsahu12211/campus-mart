import {
  deleteToken,
  getMessaging,
  getToken,
  isSupported,
  onMessage,
} from 'firebase/messaging';
import { clearNotificationToken, saveNotificationToken } from '../api/api';
import {
  firebaseWebConfig,
  firebaseWebVapidKey,
  getFirebaseWebConfigIssues,
  getFirebaseWebApp,
  hasFirebaseWebConfig,
} from '../firebase/firebaseWebConfig';

const TOKEN_STORAGE_KEY = 'campusmart_web_push_token';
const DISABLED_STORAGE_KEY = 'campusmart_web_push_disabled';
const PLATFORM = 'WEB';

let messageListenerBound = false;
let configWarningShown = false;
let serviceWorkerWarningShown = false;

function logConfigIssuesOnce(context) {
  if (configWarningShown || process.env.NODE_ENV === 'production') {
    return;
  }

  const issues = getFirebaseWebConfigIssues();
  if (!issues.length) {
    return;
  }

  console.warn(`[PUSH CONFIG] ${context}: push setup skipped`, issues);
  configWarningShown = true;
}

function canUseBrowserPush() {
  return (
    typeof window !== 'undefined' &&
    typeof navigator !== 'undefined' &&
    'serviceWorker' in navigator &&
    'Notification' in window
  );
}

function waitForInstallingWorker(worker) {
  return new Promise((resolve, reject) => {
    if (!worker) {
      resolve(null);
      return;
    }

    const timeoutId = window.setTimeout(() => {
      reject(new Error('Service worker activation timed out'));
    }, 10000);

    worker.addEventListener('statechange', () => {
      if (worker.state === 'activated') {
        window.clearTimeout(timeoutId);
        resolve(worker);
      }
    });
  });
}

async function ensureActiveServiceWorker(registration) {
  if (registration.active) {
    return registration;
  }

  if (registration.installing) {
    await waitForInstallingWorker(registration.installing);
  } else if (registration.waiting) {
    await navigator.serviceWorker.ready;
  } else {
    await navigator.serviceWorker.ready;
  }

  const refreshedRegistration = await navigator.serviceWorker.getRegistration(registration.scope);
  if (refreshedRegistration?.active) {
    return refreshedRegistration;
  }

  throw new Error('No active service worker available for web push');
}

function getStoredToken() {
  return localStorage.getItem(TOKEN_STORAGE_KEY);
}

function isPushDisabled() {
  return localStorage.getItem(DISABLED_STORAGE_KEY) === 'true';
}

function setPushDisabled(disabled) {
  if (disabled) {
    localStorage.setItem(DISABLED_STORAGE_KEY, 'true');
    return;
  }

  localStorage.removeItem(DISABLED_STORAGE_KEY);
}

function storeToken(token) {
  if (token) {
    localStorage.setItem(TOKEN_STORAGE_KEY, token);
    return;
  }
  localStorage.removeItem(TOKEN_STORAGE_KEY);
}

function isKnownMessagingAuthIssue(error) {
  const code = String(error?.code || '');
  const message = String(error?.message || '').toLowerCase();

  return (
    code.includes('messaging/token-subscribe-failed') ||
    message.includes('messaging/token-subscribe-failed') ||
    message.includes('missing required authentication credential') ||
    message.includes('request is missing required authentication credential')
  );
}

async function registerMessagingServiceWorker() {
  const params = new URLSearchParams({
    apiKey: firebaseWebConfig.apiKey || '',
    authDomain: firebaseWebConfig.authDomain || '',
    projectId: firebaseWebConfig.projectId || '',
    storageBucket: firebaseWebConfig.storageBucket || '',
    messagingSenderId: firebaseWebConfig.messagingSenderId || '',
    appId: firebaseWebConfig.appId || '',
    measurementId: firebaseWebConfig.measurementId || '',
  });

  const registration = await navigator.serviceWorker.register(`/firebase-messaging-sw.js?${params.toString()}`, {
    scope: '/',
    updateViaCache: 'none',
  });

  return ensureActiveServiceWorker(registration);
}

function bindForegroundListener(messaging) {
  if (messageListenerBound) {
    return;
  }

  onMessage(messaging, (payload) => {
    const title = payload?.notification?.title || payload?.data?.title || 'Campus Mart';
    const body = payload?.notification?.body || payload?.data?.body || 'You have a new update.';
    const clickAction = payload?.data?.click_action || payload?.data?.clickAction || '/';

    window.dispatchEvent(new CustomEvent('campusmart:push-message', {
      detail: { title, body, clickAction, payload },
    }));

    if (Notification.permission === 'granted') {
      const notification = new Notification(title, {
        body,
        icon: '/favicon.ico',
      });
      notification.onclick = () => {
        window.focus();
        window.location.assign(clickAction);
      };
    }
  });

  messageListenerBound = true;
}

async function getMessagingContext() {
  if (!canUseBrowserPush() || !hasFirebaseWebConfig()) {
    logConfigIssuesOnce('messaging-init');
    return null;
  }

  const supported = await isSupported().catch(() => false);
  if (!supported) {
    return null;
  }

  const app = getFirebaseWebApp();
  if (!app) {
    logConfigIssuesOnce('firebase-app');
    return null;
  }
  const registration = await registerMessagingServiceWorker();
  const messaging = getMessaging(app);
  bindForegroundListener(messaging);

  return { messaging, registration };
}

async function syncCurrentToken(userId, permissionMode) {
  if (!userId || !hasFirebaseWebConfig() || !canUseBrowserPush() || isPushDisabled()) {
    return false;
  }

  const permission = permissionMode || Notification.permission;
  if (permission !== 'granted') {
    return false;
  }

  const context = await getMessagingContext();
  if (!context) {
    return false;
  }

  let token;
  try {
    token = await getToken(context.messaging, {
      vapidKey: firebaseWebVapidKey,
      serviceWorkerRegistration: context.registration,
    });
  } catch (error) {
    if (isKnownMessagingAuthIssue(error)) {
      setPushDisabled(true);
      if (!serviceWorkerWarningShown && process.env.NODE_ENV !== 'production') {
        console.warn('Web push disabled: Firebase messaging credentials are not fully configured.');
        serviceWorkerWarningShown = true;
      }
      return false;
    }
    throw error;
  }

  if (!token) {
    return false;
  }

  const previousToken = getStoredToken();
  if (previousToken === token) {
    return true;
  }

  await saveNotificationToken({
    userId,
    fcmToken: token,
    platform: PLATFORM,
  });
  storeToken(token);
  setPushDisabled(false);
  return true;
}

export async function initializeWebPushForUser(user) {
  try {
    if (!user?.id) {
      return false;
    }

    if (typeof Notification === 'undefined' || Notification.permission !== 'granted') {
      return false;
    }

    if (!hasFirebaseWebConfig()) {
      logConfigIssuesOnce('initialize-user');
      return false;
    }

    return await syncCurrentToken(user.id);
  } catch (error) {
    console.error('Web push initialization skipped:', error);
    return false;
  }
}

export async function requestWebPushPermissionAndSync(user) {
  try {
    if (!user?.id || !canUseBrowserPush() || isPushDisabled()) {
      return false;
    }

    if (!hasFirebaseWebConfig()) {
      logConfigIssuesOnce('permission-request');
      return false;
    }

    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      return false;
    }

    return await syncCurrentToken(user.id, permission);
  } catch (error) {
    if (!serviceWorkerWarningShown || process.env.NODE_ENV === 'production') {
      console.error('Web push permission flow failed:', error);
      serviceWorkerWarningShown = true;
    }
    return false;
  }
}

export async function unregisterWebPush(userId) {
  try {
    if (!userId) {
      storeToken(null);
      setPushDisabled(false);
      return false;
    }

    const storedToken = getStoredToken();
    if (storedToken) {
      await clearNotificationToken({
        userId,
        fcmToken: storedToken,
        platform: PLATFORM,
      }).catch(() => {});
    }

    if (!hasFirebaseWebConfig() || !canUseBrowserPush()) {
      logConfigIssuesOnce('cleanup');
      storeToken(null);
      return false;
    }

    const context = await getMessagingContext();
    if (!context) {
      storeToken(null);
      return false;
    }

    await deleteToken(context.messaging).catch(() => false);
    storeToken(null);
    return true;
  } catch (error) {
    console.error('Web push cleanup failed:', error);
    storeToken(null);
    return false;
  }
}
