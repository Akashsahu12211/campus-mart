import {
  FacebookAuthProvider,
  GoogleAuthProvider,
  getAuth,
  signInWithPopup,
  signOut,
} from 'firebase/auth';
import { getFirebaseWebApp, hasFirebaseWebConfig } from '../firebase/firebaseWebConfig';

function getAuthInstance() {
  const app = getFirebaseWebApp();
  if (!app || !hasFirebaseWebConfig()) {
    throw new Error('Firebase social login is not configured yet');
  }
  return getAuth(app);
}

export async function signInWithGooglePopup() {
  try {
    const auth = getAuthInstance();
    const provider = new GoogleAuthProvider();
    provider.setCustomParameters({ prompt: 'select_account' });
    const result = await signInWithPopup(auth, provider);
    const idToken = await result.user.getIdToken();
    await signOut(auth);
    return { idToken, provider: 'GOOGLE' };
  } catch (error) {
    throw new Error(
      error?.message || 'Google sign-in is not ready yet. Verify Firebase web config and Google provider setup.'
    );
  }
}

export async function signInWithFacebookPopup() {
  try {
    const auth = getAuthInstance();
    const provider = new FacebookAuthProvider();
    provider.addScope('email');
    const result = await signInWithPopup(auth, provider);
    const idToken = await result.user.getIdToken();
    await signOut(auth);
    return { idToken, provider: 'FACEBOOK' };
  } catch (error) {
    throw new Error(
      error?.message || 'Facebook sign-in is not ready yet. Verify Firebase, Facebook app setup, and authorized domains.'
    );
  }
}
