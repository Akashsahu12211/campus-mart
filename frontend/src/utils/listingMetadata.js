const BOOK_CATEGORY_NAMES = new Set(['books & notes', 'books', 'notes']);
const BUNDLE_KEYWORDS = ['bundle', 'set', 'combo', 'lot', 'pack'];

const cleanText = (value) => (value || '').trim();

export const isBooksCategory = (categoryName = '') =>
  BOOK_CATEGORY_NAMES.has(categoryName.trim().toLowerCase());

export const inferBundleSize = (title = '', description = '') => {
  const text = `${title} ${description}`.toLowerCase();
  const match = text.match(/(\d+)\s*(book|books|note|notes|copy|copies)/);
  if (!match) {
    return null;
  }

  const size = Number.parseInt(match[1], 10);
  return Number.isFinite(size) && size > 1 ? size : null;
};

export const buildListingMetadata = ({
  categoryName = '',
  title = '',
  description = '',
  donation = false,
  bundle = null,
  bundleSize = null,
  bookAuthor = '',
  bookEdition = '',
  academicSubject = '',
  academicCourse = '',
  academicLevel = '',
  boardOrUniversity = '',
  publisher = '',
  isbn = '',
} = {}) => {
  const normalizedTitle = cleanText(title);
  const normalizedDescription = cleanText(description);
  const combined = `${normalizedTitle} ${normalizedDescription}`.toLowerCase();
  const inferredBundleSize = inferBundleSize(normalizedTitle, normalizedDescription);
  const resolvedBundleSize = bundleSize ?? inferredBundleSize;
  const isBundle = bundle ?? (resolvedBundleSize !== null || BUNDLE_KEYWORDS.some(keyword => combined.includes(keyword)));
  const isBook = isBooksCategory(categoryName);

  return {
    listingType: donation ? 'DONATION' : isBook ? 'BOOK' : 'GENERAL',
    donation,
    bundle: isBundle,
    bundleSize: isBundle ? resolvedBundleSize : null,
    academicSubject: cleanText(academicSubject) || (isBook ? normalizedTitle : null),
    academicCourse: cleanText(academicCourse) || null,
    academicLevel: cleanText(academicLevel) || null,
    boardOrUniversity: cleanText(boardOrUniversity) || null,
    bookAuthor: cleanText(bookAuthor) || null,
    bookEdition: cleanText(bookEdition) || null,
    publisher: cleanText(publisher) || null,
    isbn: cleanText(isbn) || null,
  };
};
