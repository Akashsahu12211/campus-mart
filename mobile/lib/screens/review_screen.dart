import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/review_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ReviewScreen extends StatefulWidget {
  final int itemId;
  final int sellerId;
  final String itemTitle;
  final String sellerName;

  const ReviewScreen({
    super.key,
    required this.itemId,
    required this.sellerId,
    required this.itemTitle,
    required this.sellerName,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final ApiService _apiService = ApiService();
  final _reviewController = TextEditingController();

  late Future<List<ReviewModel>> _reviewsFuture;
  double _userRating = 0;
  bool _isSubmitting = false;
  bool _userAlreadyReviewed = false;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _loadReviews();
    _checkUserReview();
  }

  Future<List<ReviewModel>> _loadReviews() async {
    final response = await _apiService.getItemReviews(widget.itemId);
    final reviews = (response['reviews'] as List? ?? const []);
    return reviews
        .map((item) => ReviewModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> _checkUserReview() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    try {
      final response = await _apiService.checkReview(userId, widget.itemId);
      if (!mounted) return;
      setState(() {
        _userAlreadyReviewed = response['reviewed'] as bool? ?? false;
      });
    } catch (_) {}
  }

  Future<void> _refreshReviews() async {
    setState(() {
      _reviewsFuture = _loadReviews();
    });
    await _checkUserReview();
  }

  Future<void> _submitReview() async {
    if (_userRating == 0 || _reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rating and review text')),
      );
      return;
    }

    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _apiService.addReview({
        'itemId': widget.itemId,
        'sellerId': widget.sellerId,
        'rating': _userRating.toInt(),
        'comment': _reviewController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully')),
      );
      _reviewController.clear();
      setState(() {
        _userRating = 0;
        _userAlreadyReviewed = true;
      });
      await _refreshReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1320),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16192E),
        elevation: 0,
        title: const Text(
          'Reviews & Ratings',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Syne',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F3A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2A3455), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.itemTitle,
                      style: const TextStyle(
                        color: Color(0xFF5B4BFF),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seller: ${widget.sellerName}',
                      style: const TextStyle(color: Color(0xFFA0A8C8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!_userAlreadyReviewed) ...[
                const Text(
                  'Share Your Experience',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Syne',
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F3A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A3455), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Rating: ',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () => setState(() => _userRating = (index + 1).toDouble()),
                                child: Icon(
                                  index < _userRating ? Icons.star : Icons.star_outline,
                                  color: const Color(0xFFFFC107),
                                  size: 28,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _reviewController,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Share your thoughts about this item...',
                          hintStyle: const TextStyle(color: Color(0xFF5A6285)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2A3455)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2A3455)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF5B4BFF)),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0F1320),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B4BFF),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _isSubmitting ? null : _submitReview,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Submit Review',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Text(
                'All Reviews',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Syne',
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<ReviewModel>>(
                future: _reviewsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B4BFF)),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading reviews: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final reviews = snapshot.data ?? [];
                  if (reviews.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F3A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2A3455), width: 1),
                      ),
                      child: const Center(
                        child: Text(
                          'No reviews yet',
                          style: TextStyle(color: Color(0xFFA0A8C8), fontSize: 14),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    itemBuilder: (context, index) => _buildReviewCard(reviews[index]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3455), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  review.reviewerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star : Icons.star_outline,
                    color: const Color(0xFFFFC107),
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.comment,
            style: const TextStyle(color: Color(0xFFA0A8C8), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '${review.createdAt.toString().split(' ')[0]}',
            style: const TextStyle(color: Color(0xFF5A6285), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
