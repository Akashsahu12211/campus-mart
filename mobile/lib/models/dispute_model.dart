class Dispute {
  final int id;
  final int orderId;
  final int buyerId;
  final int sellerId;
  final String reason;
  final String? description;
  final String status; // OPEN, RESOLVED, CLOSED
  final String? resolution;
  final DateTime createdAt;
  final DateTime updatedAt;

  Dispute({
    required this.id,
    required this.orderId,
    required this.buyerId,
    required this.sellerId,
    required this.reason,
    this.description,
    required this.status,
    this.resolution,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Dispute.fromJson(Map<String, dynamic> json) {
    return Dispute(
      id: json['id'] as int,
      orderId: json['orderId'] as int,
      buyerId: json['buyerId'] as int,
      sellerId: json['sellerId'] as int,
      reason: json['reason'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      resolution: json['resolution'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'buyerId': buyerId,
    'sellerId': sellerId,
    'reason': reason,
    'description': description,
    'status': status,
    'resolution': resolution,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
