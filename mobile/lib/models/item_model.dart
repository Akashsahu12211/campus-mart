import 'student_model.dart';
import 'category_model.dart';

class Item {
  final int id;
  final String title;
  final String? description;
  final double price;
  final List<String> imageUrls;
  final String status;
  final String? condition;
  final String listingType;
  final bool negotiable;
  final bool donation;
  final bool bundle;
  final int? bundleSize;
  final String? bookAuthor;
  final String? bookEdition;
  final String? academicSubject;
  final String? academicCourse;
  final String? academicLevel;
  final String? boardOrUniversity;
  final String? publisher;
  final String? isbn;
  final int boostLevel;
  final String? boostedAt;
  final String? boostExpiresAt;
  final bool boostActive;
  final int viewCount;
  final Category? category;
  final Student? seller;
  final Student? reservedByStudent;
  final String? createdAt;

  Item({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.imageUrls,
    required this.status,
    this.condition,
    this.listingType = 'GENERAL',
    required this.negotiable,
    this.donation = false,
    this.bundle = false,
    this.bundleSize,
    this.bookAuthor,
    this.bookEdition,
    this.academicSubject,
    this.academicCourse,
    this.academicLevel,
    this.boardOrUniversity,
    this.publisher,
    this.isbn,
    this.boostLevel = 0,
    this.boostedAt,
    this.boostExpiresAt,
    this.boostActive = false,
    required this.viewCount,
    this.category,
    this.seller,
    this.reservedByStudent,
    this.createdAt,
  });

  bool get isAvailable => status == 'AVAILABLE';
  bool get isSold => status == 'SOLD';
  bool get isReserved => status == 'RESERVED';
  bool get isBookListing => listingType == 'BOOK';
  bool get isDonationListing => donation || listingType == 'DONATION';

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      imageUrls: json['imageUrls'] != null ? List<String>.from(json['imageUrls']) : [],
      status: json['status'] ?? 'AVAILABLE',
      condition: json['condition'],
      listingType: json['listingType']?.toString() ?? 'GENERAL',
      negotiable: json['negotiable'] ?? false,
      donation: json['donation'] ?? false,
      bundle: json['bundle'] ?? false,
      bundleSize: json['bundleSize'] as int?,
      bookAuthor: json['bookAuthor']?.toString(),
      bookEdition: json['bookEdition']?.toString(),
      academicSubject: json['academicSubject']?.toString(),
      academicCourse: json['academicCourse']?.toString(),
      academicLevel: json['academicLevel']?.toString(),
      boardOrUniversity: json['boardOrUniversity']?.toString(),
      publisher: json['publisher']?.toString(),
      isbn: json['isbn']?.toString(),
      boostLevel: (json['boostLevel'] as num?)?.toInt() ?? 0,
      boostedAt: json['boostedAt']?.toString(),
      boostExpiresAt: json['boostExpiresAt']?.toString(),
      boostActive: json['boostActive'] ?? false,
      viewCount: json['viewCount'] ?? 0,
      category: json['category'] != null ? Category.fromJson(json['category']) : null,
      seller: json['seller'] != null ? Student.fromJson(json['seller']) : null,
      reservedByStudent: json['reservedByStudent'] != null ? Student.fromJson(json['reservedByStudent']) : null,
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'imageUrls': imageUrls,
      'status': status,
      'condition': condition,
      'listingType': listingType,
      'negotiable': negotiable,
      'donation': donation,
      'bundle': bundle,
      'bundleSize': bundleSize,
      'bookAuthor': bookAuthor,
      'bookEdition': bookEdition,
      'academicSubject': academicSubject,
      'academicCourse': academicCourse,
      'academicLevel': academicLevel,
      'boardOrUniversity': boardOrUniversity,
      'publisher': publisher,
      'isbn': isbn,
      'boostLevel': boostLevel,
      'boostedAt': boostedAt,
      'boostExpiresAt': boostExpiresAt,
      'boostActive': boostActive,
      'viewCount': viewCount,
      'category': category?.toJson(),
      'seller': seller?.toJson(),
      'reservedByStudent': reservedByStudent?.toJson(),
      'createdAt': createdAt,
    };
  }
}
