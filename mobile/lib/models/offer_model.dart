// lib/models/offer_model.dart

class Offer {
  final int? id;
  final int? itemId;
  final int? buyerId;
  final int? sellerId;
  final double offeredPrice;
  final String? note;
  final String status; // PENDING, ACCEPTED, REJECTED
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? item;
  final Map<String, dynamic>? buyer;
  final Map<String, dynamic>? seller;

  Offer({
    this.id,
    this.itemId,
    this.buyerId,
    this.sellerId,
    required this.offeredPrice,
    this.note,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.item,
    this.buyer,
    this.seller,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'] as int?,
      itemId: json['itemId'] as int?,
      buyerId: json['buyerId'] as int?,
      sellerId: json['sellerId'] as int?,
      offeredPrice: (json['offeredPrice'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      item: json['item'] as Map<String, dynamic>?,
      buyer: json['buyer'] as Map<String, dynamic>?,
      seller: json['seller'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemId': itemId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'offeredPrice': offeredPrice,
      'note': note,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'item': item,
      'buyer': buyer,
      'seller': seller,
    };
  }

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isRejected => status == 'REJECTED';
}
