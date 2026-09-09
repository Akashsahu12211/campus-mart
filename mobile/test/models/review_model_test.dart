import 'package:campus_mart_app/models/review_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ReviewModel parses nested reviewer and item fields', () {
    final review = ReviewModel.fromJson({
      'id': 3,
      'item': {'id': 91},
      'reviewer': {'id': 12, 'name': 'Aarav'},
      'rating': 5,
      'comment': 'Great seller',
      'createdAt': '2026-04-22T11:15:00Z',
    });

    expect(review.id, 3);
    expect(review.itemId, 91);
    expect(review.reviewerId, 12);
    expect(review.reviewerName, 'Aarav');
    expect(review.rating, 5);
    expect(review.comment, 'Great seller');
  });
}
