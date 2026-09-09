import { getApp, getApps, initializeApp } from 'firebase/app';

function readEnv(name) {
  const value = process.env[name];
  if (typeof value !== 'string') {
    return '';
  }

  return value.trim().replace(/^['"]|['"]$/g, '');
}

function debugEnvStatus() {
  if (process.env.NODE_ENV === 'production') {
    return;
  }

  console.info('[PUSH CONFIG]', {
    apiKeyPresent: firebaseWebConfig.apiKey.length > 0,
    apiKeyLooksValid: firebaseWebConfig.apiKey.startsWith('AIza'),
    apiKeyLength: firebaseWebConfig.apiKey.length,
    authDomainPresent: firebaseWebConfig.authDomain.length > 0,
    projectId: firebaseWebConfig.projectId || '(missing)',
    senderId: firebaseWebConfig.messagingSenderId || '(missing)',
    appIdPresent: firebaseWebConfig.appId.length > 0,
    vapidKeyPresent: firebaseWebVapidKey.length > 0,
    vapidKeyLength: firebaseWebVapidKey.length,
  });
}

export const firebaseWebConfig = {
  apiKey: readEnv('REACT_APP_FIREBASE_API_KEY'),
  authDomain: readEnv('REACT_APP_FIREBASE_AUTH_DOMAIN'),
  projectId: readEnv('REACT_APP_FIREBASE_PROJECT_ID'),
  storageBucket: readEnv('REACT_APP_FIREBASE_STORAGE_BUCKET'),
  messagingSenderId: readEnv('REACT_APP_FIREBASE_MESSAGING_SENDER_ID'),
  appId: readEnv('REACT_APP_FIREBASE_APP_ID'),
  measurementId: readEnv('REACT_APP_FIREBASE_MEASUREMENT_ID'),
};

export const firebaseWebVapidKey = readEnv('REACT_APP_FIREBASE_VAPID_KEY');

debugEnvStatus();

export function getFirebaseWebConfigIssues() {
  const issues = [];

  if (!firebaseWebConfig.apiKey) {
    issues.push('Missing REACT_APP_FIREBASE_API_KEY');
  } else if (!firebaseWebConfig.apiKey.startsWith('AIza')) {
    issues.push('Firebase API key format looks invalid');
  }

  if (!firebaseWebConfig.authDomain) {
    issues.push('Missing REACT_APP_FIREBASE_AUTH_DOMAIN');
  }

  if (!firebaseWebConfig.projectId) {
    issues.push('Missing REACT_APP_FIREBASE_PROJECT_ID');
  }

  if (!firebaseWebConfig.messagingSenderId) {
    issues.push('Missing REACT_APP_FIREBASE_MESSAGING_SENDER_ID');
  }

  if (!firebaseWebConfig.appId) {
    issues.push('Missing REACT_APP_FIREBASE_APP_ID');
  } else if (!firebaseWebConfig.appId.includes(':web:')) {
    issues.push('Firebase app ID format looks invalid for web');
  }

  if (!firebaseWebVapidKey) {
    issues.push('Missing REACT_APP_FIREBASE_VAPID_KEY');
  }

  return issues;
}

export function hasFirebaseWebConfig() {
  return getFirebaseWebConfigIssues().length === 0;
}

export function getFirebaseWebApp() {
  if (!hasFirebaseWebConfig()) {
    return null;
  }

  if (getApps().length) {
    return getApp();
  }

  return initializeApp(firebaseWebConfig);
}
