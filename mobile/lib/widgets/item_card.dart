import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'app_image.dart';

class ItemCard extends StatefulWidget {
  final Item item;
  final VoidCallback? onTap;

  const ItemCard({super.key, required this.item, this.onTap});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  final _api = ApiService();
  bool _wishlisted = false;

  @override
  void initState() {
    super.initState();
    _checkWishlist();
  }

  Future<void> _checkWishlist() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      final res = await _api.checkWishlist(user.id, widget.item.id);
      if (mounted) {
        setState(() => _wishlisted = res);
      }
    } catch (_) {}
  }

  Future<void> _toggleWishlist() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    try {
      if (_wishlisted) {
        await _api.removeFromWishlist(user.id, widget.item.id);
      } else {
        await _api.addToWishlist(user.id, widget.item.id);
      }
      if (mounted) setState(() => _wishlisted = !_wishlisted);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final img = item.imageUrls.isNotEmpty ? item.imageUrls.first : null;
    final priceLabel = item.isDonationListing
        ? 'Free'
        : 'INR ${item.price.toStringAsFixed(0)}';
    final cond = item.condition ?? '';

    return GestureDetector(
      onTap: widget.onTap ??
          () => Navigator.pushNamed(
                context,
                '/item',
                arguments: item.id,
              ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1320),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E2438)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: AppImage(
                        source: img,
                        fit: BoxFit.cover,
                        cacheWidth: 384,
                        cacheHeight: 384,
                        placeholder: Container(
                          color: const Color(0xFF1E2438),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFF4A5568),
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _toggleWishlist,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: Icon(
                            _wishlisted
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _wishlisted
                                ? const Color(0xFFEF4444)
                                : Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.boostActive)
                          const _CardBadge(
                            label: 'BOOSTED',
                            color: Color(0xFFEF4444),
                          ),
                        if (item.negotiable && !item.isSold)
                          const _CardBadge(
                            label: 'NEGO',
                            color: Color(0xFF00D4AA),
                          ),
                        if (item.isDonationListing)
                          const _CardBadge(
                            label: 'DONATE',
                            color: Color(0xFFF59E0B),
                          ),
                        if (item.isBookListing)
                          const _CardBadge(
                            label: 'BOOK',
                            color: Color(0xFF5B4BFF),
                          ),
                        if (item.bundle)
                          _CardBadge(
                            label: item.bundleSize != null
                                ? 'BUNDLE ${item.bundleSize}'
                                : 'BUNDLE',
                            color: const Color(0xFF0EA5A4),
                          ),
                        if (item.status == 'SOLD')
                          const _CardBadge(
                            label: 'SOLD',
                            color: Color(0xFFEF4444),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          priceLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF5B4BFF),
                          ),
                        ),
                      ),
                      if (item.seller != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.seller!.name.split(' ')[0],
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5A6285),
                              ),
                            ),
                            if (item.seller!.collegeId != null &&
                                item.seller!.collegeId!.isNotEmpty)
                              Text(
                                '#${item.seller!.collegeId}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3D4566),
                                ),
                              ),
                            if (item.seller!.averageRating != null &&
                                item.seller!.averageRating! > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('⭐',
                                        style: TextStyle(fontSize: 10)),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${item.seller!.averageRating}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                                    if (item.seller!.totalReviews != null &&
                                        item.seller!.totalReviews! > 0)
                                      Text(
                                        ' (${item.seller!.totalReviews})',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF718096),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            else if (cond.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2438),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  cond,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF718096),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        )
                      else if (cond.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2438),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cond,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF718096),
                              fontWeight: FontWeight.w600,
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

class _CardBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CardBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
