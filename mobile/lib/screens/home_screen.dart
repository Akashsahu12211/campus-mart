import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/category_model.dart';
import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/site_settings_provider.dart';
import '../services/api_service.dart';
import '../utils/recent_items_storage.dart';
import '../widgets/brand_mark.dart';
import '../widgets/custom_button.dart';
import '../widgets/item_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();
  final _hostelCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();

  List<Item> _items = [];
  List<Item> _recentlyViewed = [];
  List<Category> _categories = [];
  bool _loading = true;
  int? _activeCat;
  String _searchQuery = '';
  int _totalItems = 0;
  int _currentPage = 0;
  final int _pageSize = 8;
  int _totalPages = 0;
  String _sortBy = 'newest';
  String _condition = '';
  double? _userLat;
  double? _userLng;
  double? _radiusKm;
  String? _locationSource;

  static const Map<String, String> _categoryIcons = {
    'Books & Notes': '📚',
    'Electronics': '💻',
    'Cycles & Vehicles': '🚲',
    'Room Items': '🛏️',
    'Clothes': '👕',
    'Sports': '⚽',
    'Stationery': '🖊️',
    'Other': '📦',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SiteSettingsProvider>().refreshSettings();
    });
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _currentPage = 0;
    });

    try {
      final cats = await _safeLoadCategories();
      final paginatedData = await _fetchPaginatedItems(page: _currentPage);
      final recent = await RecentItemsStorage.load();

      if (!mounted) return;
      setState(() {
        _items = (paginatedData['content'] as List)
            .map((j) => Item.fromJson(j))
            .toList();
        _recentlyViewed = recent;
        _categories = cats;
        _totalItems = paginatedData['totalElements'] ?? 0;
        _totalPages = paginatedData['totalPages'] ?? 1;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<List<Category>> _safeLoadCategories() async {
    try {
      return await _api.getCategories();
    } catch (_) {
      return <Category>[];
    }
  }

  Future<Map<String, dynamic>> _fetchPaginatedItems({required int page}) {
    return _api.getPaginatedItems(
      page: page,
      pageSize: _pageSize,
      sort: _sortBy,
      q: _searchQuery.isEmpty ? null : _searchQuery,
      categoryId: _activeCat,
      minPrice: double.tryParse(_minPriceCtrl.text.trim()),
      maxPrice: double.tryParse(_maxPriceCtrl.text.trim()),
      condition: _condition.isEmpty ? null : _condition,
      hostel: _hostelCtrl.text.trim().isEmpty ? null : _hostelCtrl.text.trim(),
      branch: _branchCtrl.text.trim().isEmpty ? null : _branchCtrl.text.trim(),
      userLat: _userLat,
      userLng: _userLng,
      radiusKm: _radiusKm,
    );
  }

  Future<void> _filterByCategory(int? catId) async {
    setState(() {
      _activeCat = catId;
      _currentPage = 0;
    });
    await _loadAll();
  }

  Future<void> _nextPage() async {
    if (_currentPage >= _totalPages - 1) return;
    await _loadPage(_currentPage + 1);
  }

  Future<void> _prevPage() async {
    if (_currentPage <= 0) return;
    await _loadPage(_currentPage - 1);
  }

  Future<void> _loadPage(int page) async {
    setState(() {
      _currentPage = page;
      _loading = true;
    });

    try {
      final paginatedData = await _fetchPaginatedItems(page: page);
      if (!mounted) return;
      setState(() {
        _items = (paginatedData['content'] as List)
            .map((j) => Item.fromJson(j))
            .toList();
        _totalItems = paginatedData['totalElements'] ?? _totalItems;
        _totalPages = paginatedData['totalPages'] ?? _totalPages;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _setSortBy(String sort) async {
    setState(() {
      _sortBy = sort;
      _currentPage = 0;
    });
    await _loadAll();
  }

  Future<void> _search() async {
    _searchQuery = _searchCtrl.text.trim();
    await _loadAll();
  }

  Future<void> _applyFilters() async {
    setState(() => _currentPage = 0);
    await _loadAll();
  }

  Future<void> _clearFilters() async {
    _searchCtrl.clear();
    _minPriceCtrl.clear();
    _maxPriceCtrl.clear();
    _hostelCtrl.clear();
    _branchCtrl.clear();

    setState(() {
      _searchQuery = '';
      _condition = '';
      _activeCat = null;
      _sortBy = 'newest';
      _currentPage = 0;
      _userLat = null;
      _userLng = null;
      _radiusKm = null;
      _locationSource = null;
    });

    await _loadAll();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_minPriceCtrl.text.trim().isNotEmpty) count++;
    if (_maxPriceCtrl.text.trim().isNotEmpty) count++;
    if (_condition.isNotEmpty) count++;
    if (_hostelCtrl.text.trim().isNotEmpty) count++;
    if (_branchCtrl.text.trim().isNotEmpty) count++;
    if (_userLat != null && _userLng != null && _radiusKm != null) count++;
    return count;
  }

  Future<void> _enableNearMe() async {
    final fallbackUser = context.read<AuthProvider>().user;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
        _radiusKm = 8;
        _locationSource = 'current';
        _sortBy = 'nearby';
      });
      await _loadAll();
    } catch (_) {
      if (fallbackUser?.latitude != null && fallbackUser?.longitude != null) {
        setState(() {
          _userLat = fallbackUser!.latitude;
          _userLng = fallbackUser.longitude;
          _radiusKm = 8;
          _locationSource = 'saved';
          _sortBy = 'nearby';
        });
        await _loadAll();
      }
    }
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'nearby':
        return 'Nearby';
      case 'price_low':
        return 'Price Low';
      case 'price_high':
        return 'Price High';
      default:
        return 'Newest';
    }
  }

  String _selectedCategoryName() {
    if (_activeCat == null) return 'All Items';
    final match = _categories.where((c) => c.id == _activeCat);
    return match.isEmpty ? 'Category' : match.first.name;
  }

  Future<void> _useSavedArea() async {
    final savedUser = context.read<AuthProvider>().user;
    if (savedUser?.latitude == null || savedUser?.longitude == null) {
      return;
    }
    setState(() {
      _userLat = savedUser!.latitude;
      _userLng = savedUser.longitude;
      _radiusKm = 8;
      _locationSource = 'saved';
      _sortBy = 'nearby';
      _currentPage = 0;
    });
    await _loadAll();
  }

  Widget _buildHorizontalDiscoverySection({
    required String title,
    required String subtitle,
    required List<Item> items,
  }) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrim,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSec,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 242,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => SizedBox(
                width: 182,
                child: ItemCard(
                  item: items[index],
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/item',
                    arguments: items[index].id,
                  ).then((_) => _loadAll()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategorySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Browse Categories',
                  style: TextStyle(
                    color: AppTheme.textPrim,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Jump straight to the kind of item you want.',
                  style: TextStyle(color: AppTheme.textSec, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildCategoryActionChip(
                      label: 'All Items',
                      selected: _activeCat == null,
                      icon: '🛍️',
                      onTap: () {
                        Navigator.pop(context);
                        _filterByCategory(null);
                      },
                    ),
                    ..._categories.map((cat) => _buildCategoryActionChip(
                          label: cat.name,
                          selected: _activeCat == cat.id,
                          icon: _categoryIcons[cat.name] ?? '📦',
                          onTap: () {
                            Navigator.pop(context);
                            _filterByCategory(cat.id);
                          },
                        )),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryActionChip({
    required String label,
    required bool selected,
    required String icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.16)
                : AppTheme.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.accent : AppTheme.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSec,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filters',
                            style: TextStyle(
                              color: AppTheme.textPrim,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _clearFilters();
                          },
                          child: const Text('Reset All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Refine by price, condition and campus details.',
                      style: TextStyle(color: AppTheme.textSec, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minPriceCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.textPrim),
                            decoration: const InputDecoration(
                              labelText: 'Min Price',
                              prefixText: '₹ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _maxPriceCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.textPrim),
                            decoration: const InputDecoration(
                              labelText: 'Max Price',
                              prefixText: '₹ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _condition.isEmpty ? null : _condition,
                      dropdownColor: AppTheme.surface2,
                      style: const TextStyle(color: AppTheme.textPrim),
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'NEW', child: Text('New')),
                        DropdownMenuItem(
                          value: 'LIKE_NEW',
                          child: Text('Like New'),
                        ),
                        DropdownMenuItem(value: 'GOOD', child: Text('Good')),
                        DropdownMenuItem(value: 'FAIR', child: Text('Fair')),
                        DropdownMenuItem(value: 'POOR', child: Text('Poor')),
                      ],
                      onChanged: (value) {
                        sheetSetState(() => _condition = value ?? '');
                        setState(() => _condition = value ?? '');
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _hostelCtrl,
                      style: const TextStyle(color: AppTheme.textPrim),
                      decoration: const InputDecoration(
                        labelText: 'Hostel',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _branchCtrl,
                      style: const TextStyle(color: AppTheme.textPrim),
                      decoration: const InputDecoration(
                        labelText: 'Department / Branch',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSec,
                              side: const BorderSide(color: AppTheme.border2),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              await _applyFilters();
                            },
                            icon: const Icon(Icons.tune_rounded),
                            label: const Text('Apply Filters'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleQuickMenu(String value) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (value == 'logout') {
      await auth.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      return;
    }

    if (user == null && value != 'browse') {
      if (!mounted) return;
      Navigator.pushNamed(context, '/login');
      return;
    }

    if (!mounted) return;

    switch (value) {
      case 'browse':
        _loadAll();
        break;
      case 'my-items':
        Navigator.pushNamed(context, '/my-items').then((_) => _loadAll());
        break;
      case 'orders':
        Navigator.pushNamed(context, '/my-orders');
        break;
      case 'wishlist':
        Navigator.pushNamed(context, '/wishlist');
        break;
      case 'reservations':
        Navigator.pushNamed(context, '/reservations');
        break;
      case 'chat':
        Navigator.pushNamed(context, '/chat');
        break;
      case 'profile':
        Navigator.pushNamed(context, '/profile');
        break;
      case 'admin':
        Navigator.pushNamed(context, '/admin');
        break;
    }
  }

  Future<void> _handleBottomNavTap(int index) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    switch (index) {
      case 0:
        await _loadAll();
        break;
      case 1:
        await _showCategorySheet();
        break;
      case 2:
        if (user == null) {
          if (!mounted) return;
          Navigator.pushNamed(context, '/login');
          return;
        }
        if (!mounted) return;
        Navigator.pushNamed(context, '/add-item').then((_) => _loadAll());
        break;
      case 3:
        if (user == null) {
          if (!mounted) return;
          Navigator.pushNamed(context, '/login');
          return;
        }
        if (!mounted) return;
        Navigator.pushNamed(context, '/my-orders');
        break;
      case 4:
        if (!mounted) return;
        Navigator.pushNamed(context, user == null ? '/login' : '/profile');
        break;
    }
  }

  Widget _buildCounterChip(String icon, String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: const TextStyle(
              color: AppTheme.textPrim,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSec,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.surface,
    Color borderColor = AppTheme.border,
    Color textColor = AppTheme.textPrim,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textPrim,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onTap,
            child: const Icon(Icons.close_rounded,
                size: 16, color: AppTheme.textSec),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoHeader(BuildContext context, bool loggedIn) {
    final savedUser = context.watch<AuthProvider>().user;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF11162A),
            AppTheme.surface,
            AppTheme.accent.withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
            ),
            child: const Text(
              '🎓 STUDENT MARKETPLACE',
              style: TextStyle(
                color: Color(0xFFA89DFF),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Shop smarter\non your campus',
            style: TextStyle(
              color: AppTheme.textPrim,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Books, gadgets, cycles and room essentials from students around you.',
            style: TextStyle(
              color: AppTheme.textSec,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildActionPill(
                icon: Icons.tune_rounded,
                label: _activeFilterCount == 0
                    ? 'Filters'
                    : 'Filters ($_activeFilterCount)',
                onTap: _showFilterSheet,
              ),
              _buildActionPill(
                icon: Icons.grid_view_rounded,
                label: _selectedCategoryName(),
                onTap: _showCategorySheet,
              ),
              _buildActionPill(
                icon: Icons.add_rounded,
                label: loggedIn ? 'Sell Item' : 'Login to Sell',
                onTap: () => _handleBottomNavTap(2),
                color: AppTheme.accent,
                borderColor: AppTheme.accent,
                textColor: Colors.white,
              ),
              if (savedUser?.latitude != null && savedUser?.longitude != null)
                _buildActionPill(
                  icon: Icons.my_location_rounded,
                  label: 'Saved Area',
                  onTap: _useSavedArea,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _hostelCtrl.dispose();
    _branchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    final activeFilterWidgets = <Widget>[
      if (_minPriceCtrl.text.trim().isNotEmpty)
        _buildActiveFilterChip(
          'Min ₹${_minPriceCtrl.text.trim()}',
          () {
            _minPriceCtrl.clear();
            _applyFilters();
          },
        ),
      if (_maxPriceCtrl.text.trim().isNotEmpty)
        _buildActiveFilterChip(
          'Max ₹${_maxPriceCtrl.text.trim()}',
          () {
            _maxPriceCtrl.clear();
            _applyFilters();
          },
        ),
      if (_condition.isNotEmpty)
        _buildActiveFilterChip(
          _condition.replaceAll('_', ' '),
          () {
            setState(() => _condition = '');
            _applyFilters();
          },
        ),
      if (_hostelCtrl.text.trim().isNotEmpty)
        _buildActiveFilterChip(
          _hostelCtrl.text.trim(),
          () {
            _hostelCtrl.clear();
            _applyFilters();
          },
        ),
      if (_branchCtrl.text.trim().isNotEmpty)
        _buildActiveFilterChip(
          _branchCtrl.text.trim(),
          () {
            _branchCtrl.clear();
            _applyFilters();
          },
        ),
      if (_locationSource != null)
        _buildActiveFilterChip(
          _locationSource == 'saved'
              ? 'Saved area${user?.locationLabel != null ? ' • ${user!.locationLabel}' : ''}'
              : 'Current location',
          () {
            setState(() {
              _userLat = null;
              _userLng = null;
              _radiusKm = null;
              _locationSource = null;
            });
            _applyFilters();
          },
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accent, AppTheme.accent2],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: BrandMark(size: 24),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: const TextSpan(
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  children: [
                    TextSpan(
                        text: 'Campus',
                        style: TextStyle(color: AppTheme.textPrim)),
                    TextSpan(
                        text: 'Mart', style: TextStyle(color: AppTheme.accentH)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (user != null &&
              (user.role == 'ADMIN' || user.role == 'MODERATOR'))
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded,
                  color: Color(0xFFF97316)),
              onPressed: () => Navigator.pushNamed(context, '/admin'),
            ),
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.accent.withValues(alpha: 0.18),
              child: user != null
                  ? Text(
                      user.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.accentH,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    )
                  : const Icon(Icons.person_outline_rounded,
                      color: AppTheme.accent, size: 16),
            ),
            onPressed: () => Navigator.pushNamed(
              context,
              user != null ? '/profile' : '/login',
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrim),
            color: AppTheme.surface,
            onSelected: _handleQuickMenu,
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'browse',
                child: Text('Browse', style: TextStyle(color: Colors.white)),
              ),
              if (user != null)
                const PopupMenuItem<String>(
                  value: 'my-items',
                  child: Text('My Listings',
                      style: TextStyle(color: Colors.white)),
                ),
              if (user != null)
                const PopupMenuItem<String>(
                  value: 'orders',
                  child: Text('Orders', style: TextStyle(color: Colors.white)),
                ),
              if (user != null)
                const PopupMenuItem<String>(
                  value: 'wishlist',
                  child:
                      Text('Wishlist', style: TextStyle(color: Colors.white)),
                ),
              if (user != null)
                const PopupMenuItem<String>(
                  value: 'chat',
                  child: Text('Chat', style: TextStyle(color: Colors.white)),
                ),
              if (user != null &&
                  (user.role == 'ADMIN' || user.role == 'MODERATOR'))
                const PopupMenuItem<String>(
                  value: 'admin',
                  child: Text('Admin', style: TextStyle(color: Colors.white)),
                ),
              if (user != null)
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Logout', style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.accent.withValues(alpha: 0.18),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: 0,
        onDestinationSelected: _handleBottomNavTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Category',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box_rounded),
            label: 'Sell',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _loadAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _buildPromoHeader(context, user != null),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: AppTheme.textPrim),
                        decoration: InputDecoration(
                          hintText: 'Search books, laptop, cycle...',
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: AppTheme.muted),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _search();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded,
                                      color: AppTheme.muted),
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                        onFieldSubmitted: (_) => _search(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _search,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionPill(
                        icon: Icons.tune_rounded,
                        label: _activeFilterCount == 0
                            ? 'Open Filters'
                            : 'Filters ($_activeFilterCount)',
                        onTap: _showFilterSheet,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionPill(
                        icon: Icons.swap_vert_rounded,
                        label: _sortLabel(_sortBy),
                        onTap: () async {
                          final selected = await showMenu<String>(
                            context: context,
                            color: AppTheme.surface,
                            position:
                                const RelativeRect.fromLTRB(100, 150, 16, 0),
                            items: const [
                              PopupMenuItem(
                                value: 'nearby',
                                child: Text('Nearby First',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              PopupMenuItem(
                                value: 'newest',
                                child: Text('Newest First',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              PopupMenuItem(
                                value: 'price_low',
                                child: Text('Price: Low to High',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              PopupMenuItem(
                                value: 'price_high',
                                child: Text('Price: High to Low',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          );
                          if (selected != null) {
                            await _setSortBy(selected);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionPill(
                        icon: Icons.near_me_rounded,
                        label: _locationSource == 'saved'
                            ? 'Saved Area'
                            : _userLat != null
                                ? 'Near Me On'
                                : 'Near Me',
                        onTap: _enableNearMe,
                        color: _userLat != null
                            ? AppTheme.accent.withValues(alpha: 0.12)
                            : AppTheme.surface,
                        borderColor: _userLat != null
                            ? AppTheme.accent
                            : AppTheme.border,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (activeFilterWidgets.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...activeFilterWidgets.expand((chip) => [
                              chip,
                              const SizedBox(width: 8),
                            ]),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: Row(
                  children: [
                    const Text(
                      'Shop by category',
                      style: TextStyle(
                        color: AppTheme.textPrim,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _showCategorySheet,
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 58,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    CategoryChip(
                      label: 'All',
                      selected: _activeCat == null,
                      onTap: () => _filterByCategory(null),
                    ),
                    ..._categories.map(
                      (cat) => CategoryChip(
                        label:
                            '${_categoryIcons[cat.name] ?? '📦'} ${cat.name}',
                        selected: _activeCat == cat.id,
                        onTap: () => _filterByCategory(cat.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCounterChip('📦', 'Items', _totalItems),
                      const SizedBox(width: 10),
                      _buildCounterChip(
                          '🗂️', 'Categories', _categories.length),
                      const SizedBox(width: 10),
                      _buildCounterChip('🔎', 'Shown', _items.length),
                    ],
                  ),
                ),
              ),
            ),
            if (_recentlyViewed.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildHorizontalDiscoverySection(
                  title: 'Recently Viewed',
                  subtitle: 'Jump back into the listings you opened last.',
                  items: _recentlyViewed.take(6).toList(),
                ),
              ),
            if (_items.any((item) => item.isBookListing))
              SliverToBoxAdapter(
                child: _buildHorizontalDiscoverySection(
                  title: 'Book Spotlight',
                  subtitle: 'Active book listings surfaced from your current discovery feed.',
                  items: _items.where((item) => item.isBookListing).take(6).toList(),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _loading ? 'Loading products...' : 'Fresh picks',
                            style: const TextStyle(
                              color: AppTheme.textPrim,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _loading
                                ? 'Please wait'
                                : '$_totalItems results • Page ${_currentPage + 1} of ${_totalPages == 0 ? 1 : _totalPages}',
                            style: const TextStyle(
                              color: AppTheme.textSec,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user != null)
                      TextButton.icon(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/my-items'),
                        icon: const Icon(Icons.storefront_rounded, size: 16),
                        label: const Text('My Listings'),
                      ),
                  ],
                ),
              ),
            ),
            _loading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    ),
                  )
                : _items.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  MediaQuery.of(context).size.height * 0.45,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: const Icon(
                                      Icons.search_off_rounded,
                                      color: AppTheme.accent,
                                      size: 42,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'No items found',
                                    style: TextStyle(
                                      color: AppTheme.textPrim,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Try another category or open filters to widen your search.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppTheme.textSec,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      OutlinedButton(
                                        onPressed: _clearFilters,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.textSec,
                                          side: const BorderSide(
                                              color: AppTheme.border2),
                                        ),
                                        child: const Text('Reset Search'),
                                      ),
                                      if (user != null)
                                        ElevatedButton(
                                          onPressed: () => Navigator.pushNamed(
                                              context, '/add-item'),
                                          child: const Text('+ List Item'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => ItemCard(
                              item: _items[i],
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/item',
                                arguments: _items[i].id,
                              ).then((_) => _loadAll()),
                            ),
                            childCount: _items.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.69,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                          ),
                        ),
                      ),
            if (_totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _currentPage > 0 ? _prevPage : null,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Prev'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSec,
                            side: const BorderSide(color: AppTheme.border2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          '${_currentPage + 1}/$_totalPages',
                          style: const TextStyle(
                            color: AppTheme.textPrim,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _currentPage < _totalPages - 1 ? _nextPage : null,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Next'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
