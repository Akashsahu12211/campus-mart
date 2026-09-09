class ListingMetadata {
  final String listingType;
  final bool donation;
  final bool bundle;
  final int? bundleSize;
  final String? academicSubject;
  final String? academicCourse;
  final String? academicLevel;
  final String? boardOrUniversity;
  final String? bookAuthor;
  final String? bookEdition;
  final String? publisher;
  final String? isbn;

  const ListingMetadata({
    required this.listingType,
    required this.donation,
    required this.bundle,
    required this.bundleSize,
    required this.academicSubject,
    required this.academicCourse,
    required this.academicLevel,
    required this.boardOrUniversity,
    required this.bookAuthor,
    required this.bookEdition,
    required this.publisher,
    required this.isbn,
  });

  Map<String, dynamic> toJson() {
    return {
      'listingType': listingType,
      'donation': donation,
      'bundle': bundle,
      'bundleSize': bundleSize,
      'academicSubject': academicSubject,
      'academicCourse': academicCourse,
      'academicLevel': academicLevel,
      'boardOrUniversity': boardOrUniversity,
      'bookAuthor': bookAuthor,
      'bookEdition': bookEdition,
      'publisher': publisher,
      'isbn': isbn,
    };
  }
}

const Set<String> _bookCategoryNames = {
  'books & notes',
  'books',
  'notes',
};

const List<String> _bundleKeywords = [
  'bundle',
  'set',
  'combo',
  'lot',
  'pack',
];

bool isBooksCategory(String? categoryName) {
  final normalized = (categoryName ?? '').trim().toLowerCase();
  return _bookCategoryNames.contains(normalized);
}

int? inferBundleSize(String title, String description) {
  final combined = '$title $description'.toLowerCase();
  final match = RegExp(r'(\d+)\s*(book|books|note|notes|copy|copies)')
      .firstMatch(combined);
  if (match == null) {
    return null;
  }

  final size = int.tryParse(match.group(1) ?? '');
  if (size == null || size <= 1) {
    return null;
  }

  return size;
}

ListingMetadata buildListingMetadata({
  String? categoryName,
  required String title,
  required String description,
  bool donation = false,
  bool? bundle,
  int? bundleSize,
  String? bookAuthor,
  String? bookEdition,
  String? academicSubject,
  String? academicCourse,
  String? academicLevel,
  String? boardOrUniversity,
  String? publisher,
  String? isbn,
}) {
  final normalizedTitle = title.trim();
  final normalizedDescription = description.trim();
  final combined = '$normalizedTitle $normalizedDescription'.toLowerCase();
  final inferredBundleSize = inferBundleSize(normalizedTitle, normalizedDescription);
  final resolvedBundleSize = bundleSize ?? inferredBundleSize;
  final resolvedBundle = bundle ??
      resolvedBundleSize != null ||
      _bundleKeywords.any((keyword) => combined.contains(keyword));
  final isBook = isBooksCategory(categoryName);

  return ListingMetadata(
    listingType: donation ? 'DONATION' : (isBook ? 'BOOK' : 'GENERAL'),
    donation: donation,
    bundle: resolvedBundle,
    bundleSize: resolvedBundle ? resolvedBundleSize : null,
    academicSubject: (academicSubject ?? '').trim().isNotEmpty
        ? academicSubject!.trim()
        : (isBook ? normalizedTitle : null),
    academicCourse:
        (academicCourse ?? '').trim().isNotEmpty ? academicCourse!.trim() : null,
    academicLevel:
        (academicLevel ?? '').trim().isNotEmpty ? academicLevel!.trim() : null,
    boardOrUniversity: (boardOrUniversity ?? '').trim().isNotEmpty
        ? boardOrUniversity!.trim()
        : null,
    bookAuthor:
        (bookAuthor ?? '').trim().isNotEmpty ? bookAuthor!.trim() : null,
    bookEdition:
        (bookEdition ?? '').trim().isNotEmpty ? bookEdition!.trim() : null,
    publisher: (publisher ?? '').trim().isNotEmpty ? publisher!.trim() : null,
    isbn: (isbn ?? '').trim().isNotEmpty ? isbn!.trim() : null,
  );
}
