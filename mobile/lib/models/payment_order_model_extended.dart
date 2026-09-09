/// Represents a Payment Order (matches backend PaymentOrder entity)
class PaymentOrder {
  final int id;
  final int buyerId;
  final int sellerId;
  final int itemId;
  final double amount;
  final String status; // CREATED, PAID, ESCROW_HOLD, RELEASED, DISPUTED, FAILED, CANCELLED, REFUNDED
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? failureReason;
  final List<TimelineEvent>? timeline;
  
  // Related objects
  final ItemPreview? item;
  final StudentPreview? buyer;
  final StudentPreview? seller;
  final Dispute? dispute;

  PaymentOrder({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.itemId,
    required this.amount,
    required this.status,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    required this.createdAt,
    this.updatedAt,
    this.failureReason,
    this.timeline,
    this.item,
    this.buyer,
    this.seller,
    this.dispute,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    return PaymentOrder(
      id: json['id'] as int? ?? 0,
      buyerId: json['buyerId'] as int? ?? 0,
      sellerId: json['sellerId'] as int? ?? 0,
      itemId: json['itemId'] as int? ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'CREATED',
      razorpayOrderId: json['razorpayOrderId'] as String?,
      razorpayPaymentId: json['razorpayPaymentId'] as String?,
      razorpaySignature: json['razorpaySignature'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      failureReason: json['failureReason'] as String?,
      timeline: (json['timeline'] as List?)
          ?.map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      item: json['item'] != null
          ? ItemPreview.fromJson(json['item'] as Map<String, dynamic>)
          : null,
      buyer: json['buyer'] != null
          ? StudentPreview.fromJson(json['buyer'] as Map<String, dynamic>)
          : null,
      seller: json['seller'] != null
          ? StudentPreview.fromJson(json['seller'] as Map<String, dynamic>)
          : null,
      dispute: json['dispute'] != null
          ? Dispute.fromJson(json['dispute'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'itemId': itemId,
      'amount': amount,
      'status': status,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'failureReason': failureReason,
      'timeline': timeline?.map((e) => e.toJson()).toList(),
      'item': item?.toJson(),
      'buyer': buyer?.toJson(),
      'seller': seller?.toJson(),
      'dispute': dispute?.toJson(),
    };
  }

  bool get isPaid => ['PAID', 'ESCROW_HOLD', 'RELEASED', 'REFUNDED'].contains(status);
  bool get isCompleted => status == 'RELEASED';
  bool get isDisputed => status == 'DISPUTED';
  bool get isFailed => status == 'FAILED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isRefunded => status == 'REFUNDED';
}

/// Timeline event for order tracking
class TimelineEvent {
  final int id;
  final String status;
  final String description;
  final DateTime timestamp;
  final String? notes;

  TimelineEvent({
    required this.id,
    required this.status,
    required this.description,
    required this.timestamp,
    this.notes,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      id: json['id'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }
}

/// Dispute tracking
class Dispute {
  final int id;
  final int orderId;
  final int raisedBy; // buyer or seller ID
  final String reason;
  final String description;
  final String status; // PENDING, RESOLVED, REFUNDED
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolution;

  Dispute({
    required this.id,
    required this.orderId,
    required this.raisedBy,
    required this.reason,
    required this.description,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolution,
  });

  factory Dispute.fromJson(Map<String, dynamic> json) {
    return Dispute(
      id: json['id'] as int? ?? 0,
      orderId: json['orderId'] as int? ?? 0,
      raisedBy: json['raisedBy'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      resolution: json['resolution'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'raisedBy': raisedBy,
      'reason': reason,
      'description': description,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolution': resolution,
    };
  }
}

/// Lightweight item preview for orders
class ItemPreview {
  final int id;
  final String title;
  final double price;
  final String? imageUrl;
  final String status;

  ItemPreview({
    required this.id,
    required this.title,
    required this.price,
    this.imageUrl,
    required this.status,
  });

  factory ItemPreview.fromJson(Map<String, dynamic> json) {
    return ItemPreview(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: (json['imageUrls'] as List?)?.firstOrNull as String? ?? json['imageUrl'] as String?,
      status: json['status'] as String? ?? 'AVAILABLE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'imageUrl': imageUrl,
      'status': status,
    };
  }
}

/// Lightweight student preview for orders
class StudentPreview {
  final int id;
  final String name;
  final String? profilePic;
  final double? averageRating;
  final int? totalReviews;

  StudentPreview({
    required this.id,
    required this.name,
    this.profilePic,
    this.averageRating,
    this.totalReviews,
  });

  factory StudentPreview.fromJson(Map<String, dynamic> json) {
    return StudentPreview(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      profilePic: json['profilePic'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      totalReviews: json['totalReviews'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profilePic': profilePic,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
    };
  }
}
