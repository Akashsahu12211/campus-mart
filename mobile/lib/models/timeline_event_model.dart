class TimelineEvent {
  final int id;
  final int orderId;
  final String eventType; // CREATED, PAYMENT_INITIATED, PAYMENT_VERIFIED, ESCROW_HOLD, RELEASED, DISPUTE_RAISED, DISPUTE_RESOLVED, CANCELLED, REFUNDED
  final String description;
  final DateTime timestamp;
  final String? metadata;

  TimelineEvent({
    required this.id,
    required this.orderId,
    required this.eventType,
    required this.description,
    required this.timestamp,
    this.metadata,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      id: json['id'] as int,
      orderId: json['orderId'] as int,
      eventType: json['eventType'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'eventType': eventType,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  String get icon {
    switch (eventType) {
      case 'CREATED':
        return '📦';
      case 'PAYMENT_INITIATED':
        return '💳';
      case 'PAYMENT_VERIFIED':
        return '✅';
      case 'ESCROW_HOLD':
        return '🔒';
      case 'RELEASED':
        return '🎉';
      case 'DISPUTE_RAISED':
        return '⚠️';
      case 'DISPUTE_RESOLVED':
        return '✔️';
      case 'CANCELLED':
        return '❌';
      case 'REFUNDED':
        return '💰';
      default:
        return '📍';
    }
  }
}
