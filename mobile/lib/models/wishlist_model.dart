import 'item_model.dart';

class WishlistModel {
  final int id;
  final int studentId;
  final Item item;
  final DateTime createdAt;

  WishlistModel({
    required this.id,
    required this.studentId,
    required this.item,
    required this.createdAt,
  });

  factory WishlistModel.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>?;
    return WishlistModel(
      id: json['id'] as int? ?? 0,
      studentId: json['studentId'] as int? ?? student?['id'] as int? ?? 0,
      item: Item.fromJson(json['item'] as Map<String, dynamic>? ?? {}),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'item': item.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
