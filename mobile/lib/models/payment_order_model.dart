class PaymentOrder {
  final int id;
  final int buyerId;
  final int sellerId;
  final int itemId;
  final String itemTitle;
  final String? buyerName;
  final String? sellerName;
  final double amount;
  final String status;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? releaseDeadline;
  final String notes;
  final double platformFeePercent;
  final double platformFeeAmount;
  final double sellerNetAmount;
  final String sellerSubscriptionCode;

  PaymentOrder({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.itemId,
    required this.itemTitle,
    this.buyerName,
    this.sellerName,
    required this.amount,
    required this.status,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    required this.createdAt,
    required this.updatedAt,
    this.releaseDeadline,
    required this.notes,
    this.platformFeePercent = 0,
    this.platformFeeAmount = 0,
    this.sellerNetAmount = 0,
    this.sellerSubscriptionCode = 'FREE',
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final buyer = json['buyer'] is Map ? Map<String, dynamic>.from(json['buyer']) : null;
    final seller = json['seller'] is Map ? Map<String, dynamic>.from(json['seller']) : null;
    final item = json['item'] is Map ? Map<String, dynamic>.from(json['item']) : null;

    return PaymentOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      buyerId: (json['buyerId'] as num?)?.toInt() ?? (buyer?['id'] as num?)?.toInt() ?? 0,
      sellerId: (json['sellerId'] as num?)?.toInt() ?? (seller?['id'] as num?)?.toInt() ?? 0,
      itemId: (json['itemId'] as num?)?.toInt() ?? (item?['id'] as num?)?.toInt() ?? 0,
      itemTitle: item?['title']?.toString() ?? json['itemTitle']?.toString() ?? 'Marketplace item',
      buyerName: buyer?['name']?.toString() ?? json['buyerName']?.toString(),
      sellerName: seller?['name']?.toString() ?? json['sellerName']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'CREATED',
      razorpayOrderId: json['razorpayOrderId']?.toString(),
      razorpayPaymentId: json['razorpayPaymentId']?.toString(),
      razorpaySignature: json['razorpaySignature']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      releaseDeadline: DateTime.tryParse(json['releaseDeadline']?.toString() ?? ''),
      notes: json['notes']?.toString() ?? '',
      platformFeePercent: (json['platformFeePercent'] as num?)?.toDouble() ?? 0,
      platformFeeAmount: (json['platformFeeAmount'] as num?)?.toDouble() ?? 0,
      sellerNetAmount: (json['sellerNetAmount'] as num?)?.toDouble() ?? 0,
      sellerSubscriptionCode: json['sellerSubscriptionCode']?.toString() ?? 'FREE',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'itemId': itemId,
        'itemTitle': itemTitle,
        'buyerName': buyerName,
        'sellerName': sellerName,
        'amount': amount,
        'status': status,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'releaseDeadline': releaseDeadline?.toIso8601String(),
        'notes': notes,
        'platformFeePercent': platformFeePercent,
        'platformFeeAmount': platformFeeAmount,
        'sellerNetAmount': sellerNetAmount,
        'sellerSubscriptionCode': sellerSubscriptionCode,
      };

  bool get isCompleted => status == 'RELEASED';
  bool get isPending => ['PAID', 'ESCROW_HOLD'].contains(status);
  bool get isFailed => ['FAILED', 'DISPUTED'].contains(status);
  bool get isCancelled => status == 'CANCELLED';
  bool get isCreated => status == 'CREATED';
  double get grossAmount => amount;
  double get sellerNet => sellerNetAmount > 0 ? sellerNetAmount : amount;
}
