import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/recent_items_storage.dart';
import '../widgets/item_card.dart';
import '../widgets/app_image.dart';
import '../widgets/custom_button.dart';
import 'offer_screen.dart';
import 'payment_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final int itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final _api = ApiService();

  Item? _item;
  bool _loading = true;
  int _activeImg = 0;
  String? _error;
  bool _wishlisted = false;
  List<Map<String, dynamic>> _offers = [];
  List<Item> _similarItems = [];
  bool _blocked = false;
  bool _blockedEitherWay = false;

  Map<String, dynamic> _reviewsData = {
    'reviews': [],
    'averageRating': 0,
    'totalReviews': 0,
  };
  Map<String, dynamic>? _sellerItemReview;
  int _newRating = 5;
  String _newComment = '';
  bool _alreadyReviewed = false;
  String _reviewMsg = '';
  final _commentCtrl = TextEditingController();

  static const _conditionLabels = {
    'NEW': '🌟 New',
    'LIKE_NEW': '✨ Like New',
    'GOOD': '👍 Good',
    'FAIR': '🔧 Fair',
    'POOR': '🔴 Poor',
  };

  @override
  void initState() {
    super.initState();
    _loadItem();
    _checkWishlist();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItem() async {
    try {
      final item = await _api.getItemById(widget.itemId);
      setState(() {
        _item = item;
        _loading = false;
      });
      await RecentItemsStorage.add(item);

      await _loadOffers(item);
      await _loadSimilarItems();

      if (item.seller?.id != null) {
        await _loadReviews(item.seller!.id);
        await _loadBlockStatus();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadSimilarItems() async {
    try {
      final items = await _api.getSimilarItems(widget.itemId);
      if (!mounted) {
        return;
      }
      setState(() => _similarItems = items);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _similarItems = []);
    }
  }

  Future<void> _loadOffers(Item item) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() => _offers = []);
      return;
    }

    try {
      final List<dynamic> offers;
      if (item.seller?.id == user.id) {
        offers = await _api.getOffersForItem(widget.itemId);
      } else {
        final buyerOffers = await _api.getOffersForBuyer(user.id);
        offers = buyerOffers.where((offer) {
          final offerItem = offer is Map ? offer['item'] : null;
          return offerItem is Map && offerItem['id'] == widget.itemId;
        }).toList();
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _offers = offers
            .map((offer) => Map<String, dynamic>.from(offer as Map))
            .toList();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _offers = []);
    }
  }

  Future<void> _loadReviews(int sellerId) async {
    final user = context.read<AuthProvider>().user;
    try {
      final r = await _api.getSellerReviews(sellerId);
      setState(() => _reviewsData = Map<String, dynamic>.from(r));

      // Load item-specific reviews (includes seller's self-review)
      final itemReviews = await _api.getItemReviews(widget.itemId);
      final reviews = (itemReviews['reviews'] as List?) ?? [];
      final sellerReview = reviews.firstWhere(
        (rv) => rv['reviewer']?['id'] == sellerId,
        orElse: () => null,
      );
      if (sellerReview != null) {
        setState(() => _sellerItemReview = sellerReview);
      }

      if (user != null) {
        final c = await _api.checkReview(user.id, widget.itemId);
        setState(() => _alreadyReviewed = c['reviewed'] ?? false);
      }
    } catch (_) {}
  }

  Future<void> _checkWishlist() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      final isWishlisted = await _api.checkWishlist(user.id, widget.itemId);
      setState(() => _wishlisted = isWishlisted);
    } catch (_) {}
  }

  Future<void> _loadBlockStatus() async {
    final user = context.read<AuthProvider>().user;
    final sellerId = _item?.seller?.id;
    if (user == null || sellerId == null || user.id == sellerId) return;
    try {
      final result = await _api.checkBlockStatus(user.id, sellerId);
      setState(() {
        _blocked = result['blocked'] == true;
        _blockedEitherWay = result['blockedEitherWay'] == true;
      });
    } catch (_) {}
  }

  Future<void> _toggleBlock() async {
    final user = context.read<AuthProvider>().user;
    final sellerId = _item?.seller?.id;
    if (user == null || sellerId == null) return;
    try {
      if (_blocked) {
        await _api.unblockUser(sellerId, user.id);
        setState(() {
          _blocked = false;
          _blockedEitherWay = false;
        });
        _showSnack('User unblocked', AppTheme.success);
      } else {
        await _api.blockUser(user.id, sellerId);
        setState(() {
          _blocked = true;
          _blockedEitherWay = true;
        });
        _showSnack('User blocked. Direct contact disabled.', AppTheme.warning);
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), AppTheme.danger);
    }
  }

  Future<void> _reportItem() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    String reason = 'SPAM';
    final detailsCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B2D),
        title:
            const Text('Report listing', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (ctx, setDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                dropdownColor: const Color(0xFF111728),
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'FAKE_ITEM',
                      child: Text('Fake item',
                          style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'WRONG_PRICE',
                      child: Text('Wrong price',
                          style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'SPAM',
                      child:
                          Text('Spam', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'INAPPROPRIATE',
                      child: Text('Inappropriate',
                          style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'ALREADY_SOLD',
                      child: Text('Already sold',
                          style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'OTHER',
                      child:
                          Text('Other', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (value) => setDialog(() => reason = value ?? reason),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Add details for moderators',
                  hintStyle: TextStyle(color: Color(0xFF4A5568)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.submitItemReport(
        itemId: widget.itemId,
        reason: reason,
        description: detailsCtrl.text.trim(),
      );
      _showSnack('Report submitted for review', AppTheme.success);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), AppTheme.danger);
    }
  }

  Future<void> _toggleWishlist() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    try {
      if (_wishlisted) {
        await _api.removeFromWishlist(user.id, widget.itemId);
      } else {
        await _api.addToWishlist(user.id, widget.itemId);
      }
      setState(() => _wishlisted = !_wishlisted);
    } catch (_) {}
  }

  Future<void> _markSold() async {
    try {
      final item = await _api.markAsSold(widget.itemId);
      setState(() => _item = item);
      _showSnack('✅ Marked as sold!', AppTheme.success);
    } catch (e) {
      _showSnack(e.toString(), AppTheme.danger);
    }
  }

  Future<void> _markReserved() async {
    try {
      final item = await _api.markAsReserved(widget.itemId);
      setState(() => _item = item);
      _showSnack('🔒 Marked as reserved!', AppTheme.warning);
    } catch (e) {
      _showSnack(e.toString(), AppTheme.danger);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Delete Listing?',
          style: TextStyle(color: AppTheme.textPrim),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: AppTheme.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _api.deleteItem(widget.itemId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        _showSnack(e.toString(), AppTheme.danger);
      }
    }
  }

  Future<void> _openWhatsApp() async {
    final phone = _item?.seller?.phone;
    final title = _item?.title;
    final price = _item?.price;

    if ((_item?.seller?.phoneVisibleToViewer ?? false) != true || phone == null) {
      _showSnack('No phone number', AppTheme.warning);
      return;
    }

    final msg = Uri.encodeComponent(
      'Hi! I\'m interested in "$title" listed on Campus Mart for ₹$price. Is it still available?',
    );
    final url = Uri.parse('https://wa.me/91$phone?text=$msg');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('WhatsApp not installed', AppTheme.warning);
    }
  }

  Future<void> _shareItem() async {
    final item = _item;
    if (item == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${item.title} on Campus Mart for INR ${item.price.toStringAsFixed(0)}',
        title: item.title,
      ),
    );
  }

  Future<void> _submitReview() async {
    final user = context.read<AuthProvider>().user;
    final sellerId = _item?.seller?.id;

    if (user == null || sellerId == null) return;

    try {
      await _api.addReview({
        'sellerId': sellerId,
        'itemId': widget.itemId,
        'rating': _newRating,
        'comment': _newComment,
      });

      setState(() {
        _alreadyReviewed = true;
        _reviewMsg = '✅ Review submitted!';
      });

      _commentCtrl.clear();
      _newComment = '';
      await _loadReviews(sellerId);
    } catch (_) {
      setState(() => _reviewMsg = '❌ Could not submit');
    }
  }

  void _openZoom(String imageData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ZoomScreen(imageData: imageData),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _openOffers() async {
    final item = _item;
    final user = context.read<AuthProvider>().user;
    if (item == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Offers')),
          body: OfferScreen(
            itemId: widget.itemId,
            item: {
              'id': item.id,
              'title': item.title,
              'price': item.price,
              'sellerId': item.seller?.id,
              'imageUrls': item.imageUrls,
              if (user != null) 'viewerId': user.id,
            },
          ),
        ),
      ),
    );

    if (!mounted) return;
    await _loadItem();
  }

  Widget _buildImage(String data) {
    if (data.startsWith('data:image')) {
      try {
        final bytes = base64Decode(data.split(',').last);
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        return const Icon(Icons.broken_image, color: Colors.grey);
      }
    }
    return AppImage(
      source: data,
      fit: BoxFit.contain,
      placeholder: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  Widget _buildReviews() {
    final user = context.read<AuthProvider>().user;
    final reviews = (_reviewsData['reviews'] as List?) ?? [];
    final avgRating = _reviewsData['averageRating'] ?? 0;
    final isSeller =
        user != null && _item != null && _item!.seller?.id == user.id;
    final isSold = _item?.status == 'SOLD';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(color: Color(0xFF1E2438)),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Seller Reviews',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            if (avgRating > 0) ...[
              Text(
                '$avgRating',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF6AD55),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '⭐ ${_reviewsData['totalReviews']} reviews',
                style: const TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Seller's Own Review
        if (_sellerItemReview != null)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1320),
              border:
                  Border.all(color: const Color(0xFF5B4BFF).withOpacity(0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF5B4BFF),
                      child: Text(
                        (_item?.seller?.name ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_item?.seller?.name ?? 'Unknown'} (Seller)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '⭐ ${_sellerItemReview!['rating'] ?? 0}/5',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5B4BFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _sellerItemReview!['comment'] ?? '',
                  style: const TextStyle(
                    color: Color(0xFFA0AEC0),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

        if (user != null && !isSeller && isSold && !_alreadyReviewed)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1320),
              border:
                  Border.all(color: const Color(0xFF5B4BFF).withOpacity(0.3)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Write a Review',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(
                    5,
                    (i) => GestureDetector(
                      onTap: () => setState(() => _newRating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Opacity(
                          opacity: i < _newRating ? 1.0 : 0.3,
                          child: const Text(
                            '⭐',
                            style: TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  onChanged: (v) => _newComment = v,
                  decoration: InputDecoration(
                    hintText: 'Share your experience...',
                    hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                    filled: true,
                    fillColor: const Color(0xFF080B14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2438)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1E2438)),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                if (_reviewMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _reviewMsg,
                      style: TextStyle(
                        fontSize: 12,
                        color: _reviewMsg.startsWith('✅')
                            ? const Color(0xFF00D4AA)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Submit Review',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            child: const Center(
              child: Text(
                'No reviews yet',
                style: TextStyle(color: Color(0xFF718096)),
              ),
            ),
          )
        else
          ...reviews
              .where((rv) =>
                  rv['reviewer']?['id'] != _item?.seller?.id ||
                  rv['itemId'] != widget.itemId)
              .map<Widget>((rv) {
            final isMyReview = user != null && rv['reviewer']?['id'] == user.id;

            // Local state ke liye StatefulBuilder use karo
            return _ReviewCard(
              key: ValueKey(rv['id']),
              review: rv,
              isMyReview: isMyReview,
              onChanged: () {
                if (_item?.seller?.id != null) {
                  _loadReviews(_item!.seller!.id);
                }
              },
            );
          }).toList(),
      ],
    );
  }

  Widget _buildSimilarItems() {
    if (_similarItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(color: Color(0xFF1E2438)),
        const SizedBox(height: 16),
        const Text(
          'Similar Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Same category ke aur active listings.',
          style: TextStyle(
            color: Color(0xFF718096),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _similarItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => SizedBox(
              width: 190,
              child: ItemCard(
                item: _similarItems[index],
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ItemDetailScreen(itemId: _similarItems[index].id),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isOwner =
        user != null && _item != null && user.id == _item!.seller?.id;

    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    if (_error != null || _item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            _error ?? 'Item not found',
            style: const TextStyle(color: AppTheme.danger),
          ),
        ),
      );
    }

    final item = _item!;
    final images = item.imageUrls;
    final sellerIdentityVerified = item.seller?.identityVerified == true ||
        ((item.seller?.emailVerified ?? false) &&
            (item.seller?.phoneVerified ?? false) &&
            (item.seller?.isActive ?? false) &&
            !(item.seller?.isBanned ?? false));
    final sellerPhoneVisible =
        (item.seller?.phoneVisibleToViewer ?? false) &&
        (item.seller?.phone?.isNotEmpty ?? false);
    final sellerMaskedPhone = item.seller?.maskedPhone;
    final sellerContactReason = item.seller?.contactRevealReason;
    final directChatAllowed = item.seller?.allowDirectChat ?? true;
    final acceptedBuyerOffer = user == null
        ? null
        : _offers.cast<Map<String, dynamic>?>().firstWhere(
              (offer) =>
                  offer?['buyer']?['id'] == user.id &&
                  offer?['status'] == 'ACCEPTED',
              orElse: () => null,
            );
    final isReservedForCurrentUser =
        user != null && item.reservedByStudent?.id == user.id;
    String contactNotice = '';
    if (!isOwner && !_blockedEitherWay) {
      if (!directChatAllowed) {
        contactNotice =
            'Seller has paused direct chat for now. You can still use offers and moderation tools.';
      } else if (!sellerPhoneVisible) {
        switch (sellerContactReason) {
          case 'SELLER_HIDDEN':
            contactNotice = 'Phone kept private by seller. Use in-app chat instead.';
            break;
          case 'SUBSCRIPTION_REQUIRED':
            contactNotice =
                'Seller phone is protected for paid access only. Free users can continue with in-app chat.';
            break;
          case 'LOGIN_REQUIRED':
            contactNotice =
                'Login first to use chat and continue safely inside the app.';
            break;
          default:
            contactNotice =
                'Seller phone is masked for safety. Continue with in-app chat.';
        }
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.bg,
            actions: [
              IconButton(
                icon: Icon(
                  _wishlisted ? Icons.favorite : Icons.favorite_border,
                  color: _wishlisted ? AppTheme.danger : AppTheme.muted,
                ),
                onPressed: _toggleWishlist,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  GestureDetector(
                    onTap: () => images.isNotEmpty
                        ? _openZoom(images[_activeImg])
                        : null,
                    child: Container(
                      color: AppTheme.surface,
                      child: images.isNotEmpty
                          ? _buildImage(images[_activeImg])
                          : const Center(
                              child: Text('📦', style: TextStyle(fontSize: 60)),
                            ),
                    ),
                  ),
                  if (images.length > 1) ...[
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _ArrowBtn(
                          icon: Icons.chevron_left,
                          onTap: () => setState(
                            () => _activeImg =
                                (_activeImg - 1 + images.length) %
                                    images.length,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _ArrowBtn(
                          icon: Icons.chevron_right,
                          onTap: () => setState(
                            () => _activeImg = (_activeImg + 1) % images.length,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (images.length > 1)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_activeImg + 1}/${images.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  if (images.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🔍 Tap to zoom',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (images.length > 1)
            SliverToBoxAdapter(
              child: Container(
                height: 68,
                color: AppTheme.surface,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: images.length,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => setState(() => _activeImg = i),
                    child: Container(
                      width: 52,
                      height: 52,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: i == _activeImg
                              ? AppTheme.accent
                              : AppTheme.border,
                          width: i == _activeImg ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: _buildImage(images[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      if (item.category != null) _InfoChip(item.category!.name),
                      if (item.condition != null)
                        _InfoChip(_conditionLabels[item.condition] ??
                            item.condition!),
                      _StatusChip(item.status),
                      if (item.isDonationListing) const _InfoChip('Donation'),
                      if (item.isBookListing) const _InfoChip('Book Listing'),
                      if (item.bundle)
                        _InfoChip(item.bundleSize != null
                            ? 'Bundle ${item.bundleSize}'
                            : 'Bundle'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppTheme.textPrim,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '₹${item.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: item.isSold ? AppTheme.muted : AppTheme.accent,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          decoration:
                              item.isSold ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (item.negotiable && !item.isSold)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.accent2.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppTheme.accent2.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'Negotiable',
                            style: TextStyle(
                              color: AppTheme.accent2,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _toggleWishlist,
                        icon: Icon(
                          _wishlisted ? Icons.favorite : Icons.favorite_border,
                          color: _wishlisted ? Colors.red : AppTheme.muted,
                          size: 18,
                        ),
                        label: Text(
                          _wishlisted ? 'Saved' : 'Save',
                          style: TextStyle(
                            color: _wishlisted ? Colors.red : AppTheme.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _wishlisted ? Colors.red : AppTheme.border2,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _shareItem,
                        icon: const Icon(Icons.share_outlined,
                            color: AppTheme.muted, size: 18),
                        label: const Text(
                          'Share',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.border2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                  if (item.viewCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '👁 ${item.viewCount} views',
                      style:
                          const TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                  ],
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description!,
                      style: const TextStyle(
                        color: AppTheme.textSec,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                  if (item.isDonationListing ||
                      item.academicSubject != null ||
                      item.bookAuthor != null ||
                      item.bookEdition != null ||
                      item.academicCourse != null ||
                      item.academicLevel != null ||
                      item.boardOrUniversity != null ||
                      item.publisher != null ||
                      item.isbn != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      item.isBookListing ? 'Book Details' : 'Listing Details',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (item.isDonationListing)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.25),
                          ),
                        ),
                        child: const Text(
                          'Seller is offering this item as a donation/free giveaway.',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ...[
                      ['Subject', item.academicSubject],
                      ['Author', item.bookAuthor],
                      ['Edition', item.bookEdition],
                      ['Course', item.academicCourse],
                      ['Level', item.academicLevel],
                      ['Board / University', item.boardOrUniversity],
                      ['Publisher', item.publisher],
                      ['ISBN', item.isbn],
                    ]
                        .where((entry) => entry[1] != null && entry[1]!.isNotEmpty)
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 128,
                                  child: Text(
                                    '${entry[0]}',
                                    style: const TextStyle(
                                      color: AppTheme.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${entry[1]}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: AppTheme.textPrim,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SELLER INFO',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.accent.withOpacity(0.2),
                              child: Text(
                                item.seller?.name
                                        .substring(0, 1)
                                        .toUpperCase() ??
                                    '?',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.seller?.name ?? 'Unknown',
                                    style: const TextStyle(
                                      color: AppTheme.textPrim,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (item.seller?.branch != null)
                                    Text(
                                      item.seller!.branch!,
                                      style: const TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (item.seller?.collegeId != null)
                                    Text(
                                      '#${item.seller!.collegeId}',
                                      style: const TextStyle(
                                        color: AppTheme.border2,
                                        fontSize: 11,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (sellerIdentityVerified
                                                  ? const Color(0xFF00D4AA)
                                                  : const Color(0xFFF6AD55))
                                              .withOpacity(0.12),
                                          border: Border.all(
                                            color: (sellerIdentityVerified
                                                    ? const Color(0xFF00D4AA)
                                                    : const Color(0xFFF6AD55))
                                                .withOpacity(0.32),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          sellerIdentityVerified
                                              ? 'Verified identity'
                                              : 'Partial verification',
                                          style: TextStyle(
                                            color: sellerIdentityVerified
                                                ? const Color(0xFF00D4AA)
                                                : const Color(0xFFF6AD55),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (!sellerPhoneVisible &&
                                          sellerMaskedPhone != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF5B4BFF)
                                                .withOpacity(0.12),
                                            border: Border.all(
                                              color: const Color(0xFF5B4BFF)
                                                  .withOpacity(0.28),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Phone: $sellerMaskedPhone',
                                            style: const TextStyle(
                                              color: Color(0xFFA89DFF),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
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
                        if (sellerPhoneVisible) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.phone,
                                  color: AppTheme.muted, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                item.seller!.phone!,
                                style: const TextStyle(
                                  color: AppTheme.textSec,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (item.seller?.hostel != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppTheme.muted, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                item.seller!.hostel!,
                                style: const TextStyle(
                                  color: AppTheme.textSec,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!isOwner && user != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon:
                                Icon(_blocked ? Icons.lock_open : Icons.block),
                            label:
                                Text(_blocked ? 'Unblock User' : 'Block User'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _blocked
                                  ? const Color(0xFF00D4AA)
                                  : const Color(0xFFEF4444),
                              side: BorderSide(
                                  color: _blocked
                                      ? const Color(0xFF00D4AA)
                                      : const Color(0xFFEF4444)),
                            ),
                            onPressed: _toggleBlock,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Report Item'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF6AD55),
                              side: const BorderSide(color: Color(0xFFF6AD55)),
                            ),
                            onPressed: _reportItem,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_blockedEitherWay)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        border: Border.all(color: const Color(0xFFEF4444)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Direct chat and contact are disabled because one of you has blocked the other user.',
                        style: TextStyle(color: Color(0xFFFCA5A5)),
                      ),
                    ),
                  if (!isOwner && user != null && _blockedEitherWay)
                    const SizedBox(height: 12),
                  if (!_blockedEitherWay && contactNotice.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B4BFF).withOpacity(0.08),
                        border: Border.all(
                          color: const Color(0xFF5B4BFF).withOpacity(0.24),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        contactNotice,
                        style: const TextStyle(color: Color(0xFFC9C2FF)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!item.isSold &&
                      !isOwner &&
                      !_blockedEitherWay)
                    Column(
                      children: [
                        if (sellerPhoneVisible &&
                            (!item.isReserved || acceptedBuyerOffer == null))
                          PrimaryButton(
                            label: 'Chat on WhatsApp',
                            icon: Icons.chat_rounded,
                            onPressed: _openWhatsApp,
                          ),
                        if (sellerPhoneVisible) const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.message_rounded, size: 18),
                            label: const Text('Chat in App'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF5B4BFF),
                              side: const BorderSide(color: Color(0xFF5B4BFF)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: directChatAllowed ? () {
                              Navigator.pushNamed(context, '/chat-room',
                                  arguments: {
                                    'otherUserId': item.seller!.id,
                                    'otherUserName': item.seller!.name,
                                    'otherUserPic': item.seller!.profilePic,
                                    'itemId': item.id,
                                    'itemTitle': item.title,
                                  });
                            } : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.local_offer_outlined,
                                size: 18),
                            label: Text(
                              acceptedBuyerOffer != null
                                  ? 'View Accepted Offer'
                                  : 'Make / View Offers',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF5B4BFF),
                              side: const BorderSide(color: Color(0xFF5B4BFF)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _openOffers,
                          ),
                        ),
                        if (!item.isReserved ||
                            isReservedForCurrentUser ||
                            acceptedBuyerOffer != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00D4AA).withOpacity(0.08),
                              border: Border.all(
                                  color:
                                      const Color(0xFF00D4AA).withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock,
                                    color: Color(0xFF00D4AA), size: 14),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Escrow payment - money held until you confirm delivery',
                                    style: TextStyle(
                                      color: AppTheme.textSec,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.payment_rounded),
                              label: Text(
                                acceptedBuyerOffer != null
                                    ? 'Pay Accepted Offer Rs ${((acceptedBuyerOffer['offeredPrice'] as num?)?.toDouble() ?? item.price).toStringAsFixed(0)}'
                                    : 'Pay Rs ${item.price.toStringAsFixed(0)} Securely',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentScreen(
                                    item: item,
                                    amountOverride:
                                        (acceptedBuyerOffer?['offeredPrice']
                                                as num?)
                                            ?.toDouble(),
                                    descriptionOverride:
                                        acceptedBuyerOffer != null
                                            ? '${item.title} (Accepted Offer)'
                                            : null,
                                  ),
                                ),
                              ).then((_) => _loadItem()),
                            ),
                          ),
                        ],
                      ],
                    ),

                  // Reserve Button for Buyers
                  if (item.status == 'AVAILABLE' &&
                      !isOwner &&
                      user != null &&
                      !_blockedEitherWay)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.lock_outline, size: 18),
                          label: const Text('Reserve This Item'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF6AD55),
                            side: const BorderSide(color: Color(0xFFF6AD55)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            try {
                              await _api.reserveByBuyer(
                                itemId: widget.itemId,
                              );
                              _showSnack('✅ Item reserved! Contact seller.',
                                  const Color(0xFFF6AD55));
                              await _loadItem();
                            } catch (e) {
                              _showSnack('Failed to reserve', AppTheme.danger);
                            }
                          },
                        ),
                      ),
                    ),

                  // Reserved indicator for buyers
                  if (item.status == 'RESERVED' &&
                      user != null &&
                      user.id != item.seller?.id)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isReservedForCurrentUser
                                  ? const Color(0xFF00D4AA)
                                  : const Color(0xFFF6AD55))
                              .withOpacity(0.08),
                          border: Border.all(
                            color: (isReservedForCurrentUser
                                    ? const Color(0xFF00D4AA)
                                    : const Color(0xFFF6AD55))
                                .withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isReservedForCurrentUser
                              ? 'This item is reserved for you. Complete payment to confirm the purchase.'
                              : 'This item is currently reserved',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isReservedForCurrentUser
                                ? const Color(0xFF00D4AA)
                                : const Color(0xFFF6AD55),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                  if (isOwner) ...[
                    Row(
                      children: [
                        if (!item.isSold && !item.isReserved) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Reserve'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.warning,
                                side: const BorderSide(color: AppTheme.warning),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _markReserved,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (!item.isSold) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Mark Sold'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.success,
                                side: const BorderSide(color: AppTheme.success),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: _markSold,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: const BorderSide(color: AppTheme.danger),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 14),
                          ),
                          onPressed: _delete,
                        ),
                      ],
                    ),
                  ],

                  _buildSimilarItems(),
                  _buildReviews(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSec,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;

    switch (status) {
      case 'AVAILABLE':
        c = AppTheme.success;
        label = '✓ Available';
        break;
      case 'SOLD':
        c = AppTheme.danger;
        label = 'Sold';
        break;
      case 'RESERVED':
        c = AppTheme.warning;
        label = 'Reserved';
        break;
      default:
        c = AppTheme.muted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ZoomScreen extends StatelessWidget {
  final String imageData;
  const _ZoomScreen({required this.imageData});

  @override
  Widget build(BuildContext context) {
    Widget img;

    if (imageData.startsWith('data:image')) {
      try {
        final bytes = base64Decode(imageData.split(',').last);
        img = Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {
        img = const Icon(Icons.broken_image, color: Colors.grey);
      }
    } else {
      img = Image.network(imageData, fit: BoxFit.contain);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: img,
        ),
      ),
    );
  }
}

class _ReviewCard extends StatefulWidget {
  final Map review;
  final bool isMyReview;
  final VoidCallback onChanged;

  const _ReviewCard({
    required Key key,
    required this.review,
    required this.isMyReview,
    required this.onChanged,
  }) : super(key: key);

  @override
  _ReviewCardState createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  late bool _editing;
  late int _editRating;
  late String _editComment;
  late TextEditingController _commentCtrl;
  @override
  void initState() {
    super.initState();
    _editing = false;
    _editRating = (widget.review['rating'] as int?) ?? 0;
    _editComment = (widget.review['comment'] as String?) ?? '';
    _commentCtrl = TextEditingController(text: _editComment);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEdit() async {
    try {
      await ApiService().updateReview(widget.review['id'] as int, {
        'rating': _editRating,
        'comment': _editComment,
      });
      setState(() {
        widget.review['rating'] = _editRating;
        widget.review['comment'] = _editComment;
        _editing = false;
      });
      widget.onChanged();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update review'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1320),
        title: const Text(
          'Delete Review?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: Color(0xFFA0AEC0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF718096))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().deleteReview(widget.review['id'] as int);
        widget.onChanged();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete review'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = '';
    try {
      dateStr = DateFormat('d MMM yyyy')
          .format(DateTime.parse(widget.review['createdAt']));
    } catch (_) {}

    if (_editing) {
      return Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1320),
          border: Border.all(color: const Color(0xFF5B4BFF).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Review',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => setState(() => _editRating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Opacity(
                      opacity: i < _editRating ? 1.0 : 0.3,
                      child: const Text(
                        '⭐',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (v) => _editComment = v,
              decoration: InputDecoration(
                hintText: 'Update your comment...',
                hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                filled: true,
                fillColor: const Color(0xFF080B14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E2438)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E2438)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _editing = false;
                      _editRating = (widget.review['rating'] as int?) ?? 0;
                      _editComment =
                          (widget.review['comment'] as String?) ?? '';
                      _commentCtrl.text = _editComment;
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF718096),
                      side: const BorderSide(color: Color(0xFF718096)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1320),
        border: Border.all(
          color: widget.isMyReview
              ? const Color(0xFF5B4BFF).withOpacity(0.3)
              : const Color(0xFF1E2438),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF5B4BFF),
                child: Text(
                  (widget.review['reviewer']?['name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.review['reviewer']?['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '⭐' * ((widget.review['rating'] as int?) ?? 0),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 11,
                    ),
                  ),
                  if (widget.isMyReview) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _editing = true),
                          child: const Icon(
                            Icons.edit,
                            color: Color(0xFF5B4BFF),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _delete,
                          child: const Icon(
                            Icons.delete,
                            color: Color(0xFFEF4444),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (widget.review['comment'] != null &&
              widget.review['comment'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.review['comment'],
              style: const TextStyle(
                color: Color(0xFFA0AEC0),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
