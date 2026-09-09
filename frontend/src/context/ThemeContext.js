import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';

const ThemeContext = createContext({
  themeMode: 'dark',
  setThemeMode: () => {},
  resolvedTheme: 'dark',
});

const STORAGE_KEY = 'campusmart_theme_mode';

const resolveTheme = (mode) => {
  if (mode === 'system') {
    return window.matchMedia?.('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
  }
  return mode;
};

export function ThemeProvider({ children }) {
  const [themeMode, setThemeModeState] = useState(() => localStorage.getItem(STORAGE_KEY) || 'dark');
  const [resolvedTheme, setResolvedTheme] = useState(() => resolveTheme(localStorage.getItem(STORAGE_KEY) || 'dark'));

  useEffect(() => {
    const media = window.matchMedia?.('(prefers-color-scheme: light)');
    const applyTheme = (mode) => {
      const nextResolved = resolveTheme(mode);
      setResolvedTheme(nextResolved);
      document.documentElement.dataset.theme = nextResolved;
      document.body.dataset.theme = nextResolved;
    };

    applyTheme(themeMode);

    if (!media) return undefined;
    const handleChange = () => {
      if (themeMode === 'system') {
        applyTheme('system');
      }
    };

    if (media.addEventListener) {
      media.addEventListener('change', handleChange);
      return () => media.removeEventListener('change', handleChange);
    }

    media.addListener(handleChange);
    return () => media.removeListener(handleChange);
  }, [themeMode]);

  const setThemeMode = (mode) => {
    setThemeModeState(mode);
    localStorage.setItem(STORAGE_KEY, mode);
  };

  const value = useMemo(() => ({
    themeMode,
    setThemeMode,
    resolvedTheme,
  }), [themeMode, resolvedTheme]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export const useTheme = () => useContext(ThemeContext);
