import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';

const STORAGE_KEY = 'campusmart_language';

const dictionaries = {
  EN: {
    browse: 'Browse',
    help: 'Help',
    settings: 'Settings',
    loginTitle: 'Welcome Back',
    loginSubtitle: 'Campus Mart - Sign in to your account',
    loginButton: 'Sign In ->',
    searchPlaceholder: 'Search items - books, laptop, cycle...',
    search: 'Search',
    locationNearMe: 'Near Me',
    locationSaved: 'Saved Area',
    activity: 'Activity',
  },
  HI: {
    browse: 'Browse',
    help: 'Madad',
    settings: 'Settings',
    loginTitle: 'Wapas Swagat Hai',
    loginSubtitle: 'Campus Mart - apne account me sign in karein',
    loginButton: 'Sign In ->',
    searchPlaceholder: 'Items dhundho - books, laptop, cycle...',
    search: 'Search',
    locationNearMe: 'Mere paas',
    locationSaved: 'Saved Area',
    activity: 'Activity',
  },
  HINGLISH: {
    browse: 'Browse',
    help: 'Help',
    settings: 'Settings',
    loginTitle: 'Welcome Back',
    loginSubtitle: 'Campus Mart - apne account me sign in karo',
    loginButton: 'Sign In ->',
    searchPlaceholder: 'Items search karo - books, laptop, cycle...',
    search: 'Search',
    locationNearMe: 'Near Me',
    locationSaved: 'Saved Area',
    activity: 'Activity',
  },
};

const LanguageContext = createContext({
  language: 'EN',
  setLanguage: () => {},
  t: (key, fallback) => fallback ?? key,
});

export function LanguageProvider({ children }) {
  const [language, setLanguageState] = useState(() => localStorage.getItem(STORAGE_KEY) || 'EN');

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, language);
  }, [language]);

  const value = useMemo(() => ({
    language,
    setLanguage: setLanguageState,
    t: (key, fallback) => dictionaries[language]?.[key] || fallback || key,
  }), [language]);

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguage() {
  return useContext(LanguageContext);
}
