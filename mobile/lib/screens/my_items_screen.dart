// lib/screens/my_items_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'offer_screen.dart';

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});
  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  final _api = ApiService();
  List<Item> _items = [];
  List<Item> _reservedItems = [];
  bool _loading = true;
  String _filter = 'ALL';
  String _tab = 'listings'; // 'listings' or 'reserved'
  Map<String, dynamic>? _monetization;
  int? _boostingItemId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final items = await _api.getItemsBySeller(user.id);
      final reserved = await _api.getReservedItemsBySeller(user.id);
      final monetization = await _api.getMonetizationSummary(user.id);
      setState(() {
        _items = items;
        _reservedItems = reserved;
        _monetization = monetization;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title:
            const Text('Delete?', style: TextStyle(color: AppTheme.textPrim)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppTheme.textSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok == true) {
      try {
        // ✅ TRY TO DELETE - WILL HANDLE 401/403 IN API SERVICE
        await _api.deleteItem(id);
        _load();
      } on Exception catch (e) {
        // ✅ HANDLE ERRORS - AUTHORIZATION ERRORS ALREADY HANDLED BY INTERCEPTOR
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.toString()), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  Future<void> _markSold(int id) async {
    try {
      // ✅ WITH AUTHORIZATION
      await _api.markAsSold(id);
      _load();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _cancelReservation(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Cancel Reservation?',
            style: TextStyle(color: AppTheme.textPrim)),
        content: const Text('This will free up the item for other buyers.',
            style: TextStyle(color: AppTheme.textSec)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (ok == true) {
      try {
        // ✅ WITH AUTHORIZATION
        await _api.unreserveItem(id);
        _load();
      } on Exception catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.toString()), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  Future<void> _renew(int id) async {
    try {
      await _api.renewItem(id);
      _showMessage('Listing renewed successfully.', AppTheme.success);
      _load();
    } on Exception catch (e) {
      _showMessage(e.toString(), AppTheme.danger);
    }
  }

  Future<void> _boost(int id) async {
    setState(() => _boostingItemId = id);
    try {
      final result = await _api.boostMonetizedListing(id);
      _showMessage(
        result['message']?.toString() ?? 'Listing boosted successfully.',
        AppTheme.success,
      );
      await _load();
    } on Exception catch (e) {
      _showMessage(e.toString(), AppTheme.danger);
    }
    if (mounted) {
      setState(() => _boostingItemId = null);
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  List<Item> get _filtered {
    if (_filter == 'ALL') return _items;
    return _items.where((i) => i.status == _filter).toList();
  }

  String _formatCurrency(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return 'INR ${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
  }

  Widget _buildThumb(Item item) {
    final img = item.imageUrls.isNotEmpty ? item.imageUrls.first : null;
    if (img == null)
      return const Center(child: Text('📦', style: TextStyle(fontSize: 22)));
    if (img.startsWith('data:image')) {
      try {
        return Image.memory(base64Decode(img.split(',').last),
            fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.image);
      }
    }
    return Image.network(img, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final stats = {
      'Total': _items.length,
      'Active': _items.where((i) => i.isAvailable).length,
      'Sold': _items.where((i) => i.isSold).length,
      'Reserved': _items.where((i) => i.isReserved).length,
      'Expired': _items.where((i) => i.status == 'EXPIRED').length,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () =>
                Navigator.pushNamed(context, '/add-item').then((_) => _load()),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // Tabs
            SliverToBoxAdapter(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(
                    child: GestureDetector(
                  onTap: () => setState(() {
                    _tab = 'listings';
                    _filter = 'ALL';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                        color: _tab == 'listings'
                            ? AppTheme.accent
                            : Colors.transparent,
                        width: 2,
                      )),
                    ),
                    child: Text('📦 My Listings',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _tab == 'listings'
                              ? AppTheme.accent
                              : AppTheme.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: GestureDetector(
                  onTap: () => setState(() => _tab = 'reserved'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                        color: _tab == 'reserved'
                            ? AppTheme.accent
                            : Colors.transparent,
                        width: 2,
                      )),
                    ),
                    child: Text('🔒 Reserved (${_reservedItems.length})',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _tab == 'reserved'
                              ? AppTheme.accent
                              : AppTheme.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                  ),
                )),
              ]),
            )),

            if (_tab == 'listings')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withOpacity(0.16),
                          AppTheme.success.withOpacity(0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seller Plan: ${_monetization?['activeSubscriptionCode'] ?? context.read<AuthProvider>().user?.activeSubscriptionCode ?? 'FREE'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Fee ${((_monetization?['commissionPercent'] as num?)?.toDouble() ?? context.read<AuthProvider>().user?.currentCommissionPercent ?? 7).toStringAsFixed(2)}% · '
                                'Boost credits ${_monetization?['availableBoostCredits'] ?? context.read<AuthProvider>().user?.availableBoostCredits ?? 0} · '
                                'Active boosts ${_monetization?['activeBoostedListings'] ?? 0}',
                                style: const TextStyle(
                                  color: Color(0xFFA0A8C8),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Released net',
                              style: TextStyle(
                                color: AppTheme.success.withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(_monetization?['releasedSellerNet']),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Stats bar (only for listings tab)
            if (_tab == 'listings')
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: stats.entries
                      .map((e) => Expanded(
                              child: GestureDetector(
                            onTap: () => setState(() => _filter =
                                e.key == 'Total' ? 'ALL' : e.key.toUpperCase()),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _filter ==
                                        (e.key == 'Total'
                                            ? 'ALL'
                                            : e.key.toUpperCase())
                                    ? AppTheme.accent.withOpacity(0.1)
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _filter ==
                                          (e.key == 'Total'
                                              ? 'ALL'
                                              : e.key.toUpperCase())
                                      ? AppTheme.accent
                                      : AppTheme.border,
                                ),
                              ),
                              child: Column(children: [
                                Text('${e.value}',
                                    style: const TextStyle(
                                        color: AppTheme.accent,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                                Text(e.key,
                                    style: const TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          )))
                      .toList(),
                ),
              )),

            // LISTINGS TAB
            if (_tab == 'listings')
              if (_loading)
                const SliverFillRemaining(
                    child: Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.accent)))
              else if (_filtered.isEmpty)
                SliverFillRemaining(
                    child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('📦', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('No listings yet',
                        style: TextStyle(
                            color: AppTheme.textSec,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/add-item'),
                      child: const Text('+ List First Item'),
                    ),
                  ]),
                ))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final item = _filtered[i];
                      final sellerId = context.read<AuthProvider>().user?.id;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                                width: 56,
                                height: 56,
                                child: _buildThumb(item)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppTheme.textPrim,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                    '₹${item.price.toStringAsFixed(0)} · ${item.category?.name ?? ""}',
                                    style: const TextStyle(
                                        color: AppTheme.muted, fontSize: 12)),
                              ])),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _StatusDot(item.status),
                                if (item.boostActive) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.danger.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppTheme.danger.withOpacity(0.28),
                                      ),
                                    ),
                                    child: const Text(
                                      'BOOSTED',
                                      style: TextStyle(
                                        color: AppTheme.danger,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(children: [
                                  _ActionBtn(
                                    icon: Icons.visibility_outlined,
                                    color: AppTheme.accent,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/item',
                                      arguments: item.id,
                                    ).then((_) => _load()),
                                  ),
                                  _ActionBtn(
                                    icon: Icons.local_offer_outlined,
                                    color: AppTheme.warning,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => Scaffold(
                                          appBar: AppBar(
                                              title: const Text('Offers')),
                                          body: OfferScreen(
                                            itemId: item.id,
                                            item: {
                                              'id': item.id,
                                              'title': item.title,
                                              'price': item.price,
                                              'sellerId': sellerId,
                                              'imageUrls': item.imageUrls,
                                            },
                                          ),
                                        ),
                                      ),
                                    ).then((_) => _load()),
                                  ),
                                  if (item.status == 'EXPIRED')
                                    _ActionBtn(
                                      icon: Icons.refresh_outlined,
                                      color: AppTheme.accent2,
                                      onTap: () => _renew(item.id),
                                    ),
                                  if (item.isAvailable)
                                    _ActionBtn(
                                      icon: Icons.local_fire_department_outlined,
                                      color: AppTheme.danger,
                                      disabled: _boostingItemId != null ||
                                          item.boostActive ||
                                          ((_monetization?['availableBoostCredits']
                                                      as num?)
                                                  ?.toInt() ??
                                              0) <=
                                              0,
                                      onTap: () => _boost(item.id),
                                    ),
                                  if (item.isAvailable)
                                    _ActionBtn(
                                      icon: Icons.check_circle_outline,
                                      color: AppTheme.success,
                                      onTap: () => _markSold(item.id),
                                    ),
                                  _ActionBtn(
                                    icon: Icons.delete_outline,
                                    color: AppTheme.danger,
                                    onTap: () => _delete(item.id),
                                  ),
                                ]),
                              ]),
                        ]),
                      );
                    },
                    childCount: _filtered.length,
                  ),
                ),

            // RESERVED ITEMS TAB
            if (_tab == 'reserved')
              if (_reservedItems.isEmpty)
                SliverFillRemaining(
                    child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🔓', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('No reserved items',
                        style: TextStyle(
                            color: AppTheme.textSec,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text(
                        'When someone reserves your items, they will appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.muted, fontSize: 13)),
                  ]),
                ))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final item = _reservedItems[i];
                      final reserver = item.reservedByStudent;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Item header
                              Row(children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: _buildThumb(item)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppTheme.textPrim,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                          '₹${item.price.toStringAsFixed(0)} · ${item.category?.name ?? ""}',
                                          style: const TextStyle(
                                              color: AppTheme.muted,
                                              fontSize: 12)),
                                    ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color:
                                            AppTheme.accent.withOpacity(0.3)),
                                  ),
                                  child: const Text('RESERVED',
                                      style: TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ]),

                              const SizedBox(height: 12),
                              const Divider(color: AppTheme.border, height: 1),
                              const SizedBox(height: 12),

                              // Reserver card
                              if (reserver != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color:
                                            AppTheme.accent.withOpacity(0.3)),
                                  ),
                                  child: Row(children: [
                                    // Avatar
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            AppTheme.textSec.withOpacity(0.1),
                                        border: Border.all(
                                            color: AppTheme.accent, width: 2),
                                      ),
                                      child: reserver.profilePic != null &&
                                              reserver.profilePic!.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                reserver.profilePic!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Center(
                                                        child: Text(reserver
                                                            .name[0]
                                                            .toUpperCase())),
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                  reserver.name[0]
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    color: AppTheme.accent,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 18,
                                                  )),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(
                                              '🔒 Reserved by ${reserver.name}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppTheme.textPrim,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              )),
                                          const SizedBox(height: 2),
                                          Text('📧 ${reserver.email}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppTheme.muted,
                                                fontSize: 11,
                                              )),
                                          if (reserver.phone != null &&
                                              reserver.phone!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text('📱 ${reserver.phone}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppTheme.muted,
                                                  fontSize: 11,
                                                )),
                                          ],
                                        ])),
                                    const SizedBox(width: 8),
                                    // Contact button
                                    ElevatedButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Contact: ${reserver.email}')),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accent,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                      ),
                                      child: const Text(
                                        '✉️ Contact',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ]),
                                ),

                              const SizedBox(height: 12),

                              // Cancel button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _cancelReservation(item.id),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Cancel Reservation'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppTheme.danger.withOpacity(0.2),
                                    foregroundColor: AppTheme.danger,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                ),
                              ),
                            ]),
                      );
                    },
                    childCount: _reservedItems.length,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot(this.status);
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'AVAILABLE':
        c = AppTheme.success;
        break;
      case 'SOLD':
        c = AppTheme.danger;
        break;
      case 'RESERVED':
        c = AppTheme.warning;
        break;
      case 'EXPIRED':
        c = AppTheme.accent;
        break;
      default:
        c = AppTheme.muted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(status,
          style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool disabled;
  const _ActionBtn(
      {required this.icon,
      required this.color,
      required this.onTap,
      this.disabled = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(disabled ? 0.04 : 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(disabled ? 0.12 : 0.3)),
          ),
          child: Icon(
            icon,
            color: disabled ? color.withOpacity(0.45) : color,
            size: 16,
          ),
        ),
      );
}
