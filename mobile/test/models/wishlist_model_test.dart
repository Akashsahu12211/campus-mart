import 'package:campus_mart_app/models/wishlist_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WishlistModel parses nested student id and item payload', () {
    final wishlist = WishlistModel.fromJson({
      'id': 7,
      'student': {'id': 15},
      'item': {
        'id': 99,
        'title': 'Laptop Stand',
        'price': 799.0,
        'imageUrls': ['a.jpg'],
        'status': 'AVAILABLE',
        'negotiable': true,
        'viewCount': 3,
      },
      'createdAt': '2026-04-22T10:30:00Z',
    });

    expect(wishlist.id, 7);
    expect(wishlist.studentId, 15);
    expect(wishlist.item.id, 99);
    expect(wishlist.item.title, 'Laptop Stand');
    expect(wishlist.item.imageUrls, ['a.jpg']);
  });
}
