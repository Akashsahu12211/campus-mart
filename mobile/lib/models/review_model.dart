class ReviewModel {
  final int id;
  final int itemId;
  final int reviewerId;
  final String reviewerName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReviewModel({
    required this.id,
    required this.itemId,
    required this.reviewerId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final reviewer = json['reviewer'] as Map<String, dynamic>?;
    final item = json['item'] as Map<String, dynamic>?;
    return ReviewModel(
      id: json['id'] as int? ?? 0,
      itemId: json['itemId'] as int? ?? item?['id'] as int? ?? 0,
      reviewerId: json['reviewerId'] as int? ?? reviewer?['id'] as int? ?? 0,
      reviewerName: json['reviewerName'] as String? ?? reviewer?['name'] as String? ?? 'Anonymous',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemId': itemId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
