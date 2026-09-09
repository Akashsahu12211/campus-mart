const STORAGE_KEY = 'campusmart_recent_items';
const MAX_RECENT_ITEMS = 12;

const isStorageAvailable = () => typeof window !== 'undefined' && Boolean(window.localStorage);

export const getRecentItems = () => {
  if (!isStorageAvailable()) {
    return [];
  }

  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return [];
    }

    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
};

export const addRecentItem = (item) => {
  if (!isStorageAvailable() || !item?.id) {
    return;
  }

  const existing = getRecentItems().filter(saved => saved?.id !== item.id);
  const snapshot = {
    id: item.id,
    title: item.title,
    price: item.price,
    donation: item.donation,
    bundle: item.bundle,
    bundleSize: item.bundleSize,
    listingType: item.listingType,
    condition: item.condition,
    status: item.status,
    imageUrls: Array.isArray(item.imageUrls) ? item.imageUrls : [],
    category: item.category || null,
    seller: item.seller || null,
    viewCount: item.viewCount || 0,
    academicSubject: item.academicSubject || null,
    viewedAt: new Date().toISOString(),
  };

  window.localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify([snapshot, ...existing].slice(0, MAX_RECENT_ITEMS))
  );
};
