import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../models/wishlist_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_image.dart';
import 'item_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<WishlistModel>> _wishlistFuture;

  @override
  void initState() {
    super.initState();
    _wishlistFuture = _fetchWishlist();
  }

  Future<List<WishlistModel>> _fetchWishlist() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      return [];
    }
    final data = await _apiService.getWishlist(userId);
    return data
        .map((item) => WishlistModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> _reload() async {
    setState(() {
      _wishlistFuture = _fetchWishlist();
    });
  }

  Future<void> _removeFromWishlist(WishlistModel wishlist) async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    try {
      await _apiService.removeFromWishlist(userId, wishlist.item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from wishlist')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1320),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16192E),
        elevation: 0,
        title: const Text(
          'My Wishlist',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Syne',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<WishlistModel>>(
        future: _wishlistFuture,
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Error loading wishlist',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final wishlists = snapshot.data ?? [];
          if (wishlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Empty wishlist', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text(
                    'Start adding items you like!',
                    style: TextStyle(color: Color(0xFFA0A8C8), fontSize: 14),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4BFF),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Browse Items',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: wishlists.length,
              itemBuilder: (context, index) {
                final wishlist = wishlists[index];
                return _buildWishlistCard(wishlist.item, wishlist);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildWishlistCard(Item item, WishlistModel wishlist) {
    String statusLabel = 'Available';
    Color statusColor = const Color(0xFF4CAF50);

    if (item.status == 'SOLD') {
      statusLabel = 'Sold';
      statusColor = const Color(0xFFF44336);
    } else if (item.status == 'RESERVED') {
      statusLabel = 'Reserved';
      statusColor = const Color(0xFFFFC107);
    }

    return Card(
      color: const Color(0xFF1A1F3A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ItemDetailScreen(itemId: item.id),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppImage(
                  source: item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1320),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Color(0xFF5A6285),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category?.name ?? 'Other',
                    style: const TextStyle(
                      color: Color(0xFF8892B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Syne',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${item.price}',
                        style: const TextStyle(
                          color: Color(0xFF5B4BFF),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Syne',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(51),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withAlpha(102), width: 0.5),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.seller?.name ?? 'Unknown seller',
                    style: const TextStyle(color: Color(0xFFA0A8C8), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(color: Color(0xFF5B4BFF), width: 1),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ItemDetailScreen(itemId: item.id),
                              ),
                            );
                          },
                          child: const Text(
                            'View Details',
                            style: TextStyle(
                              color: Color(0xFF5B4BFF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF44336).withAlpha(38),
                            side: const BorderSide(color: Color(0xFFF44336), width: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          onPressed: () => _removeFromWishlist(wishlist),
                          child: const Text(
                            'Remove',
                            style: TextStyle(
                              color: Color(0xFFF44336),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
