import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../models/item_model.dart';
import '../models/student_model.dart';
import '../services/api_service.dart';
import '../widgets/app_image.dart';
import '../utils/app_logger.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiService();

  Map<String, dynamic> _stats = {
    'totalListings': 0,
    'soldItems': 0,
    'wishlistCount': 0,
    'totalViews': 0,
    'avgRating': 0,
    'totalReviews': 0,
    'boughtCount': 0,
  };

  List<dynamic> _listings = [];
  List<dynamic> _wishlist = [];
  List<dynamic> _reservations = [];
  List<dynamic> _boughtHistory = [];
  List<dynamic> _soldHistory = [];

  String _listFilter = 'ALL';
  String _historyTab = 'bought';
  String _pwMsg = '';

  bool _loading = true;
  String _msg = '';
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _hostelCtrl = TextEditingController();
  final _collegeIdCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String _profilePic = '';

  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _branchCtrl,
      _hostelCtrl,
      _collegeIdCtrl,
      _bioCtrl,
      _currentPwCtrl,
      _newPwCtrl,
      _confirmPwCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _init() {
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    _nameCtrl.text = user.name;
    _phoneCtrl.text = user.phone ?? '';
    _branchCtrl.text = user.branch ?? '';
    _hostelCtrl.text = user.hostel ?? '';
    _collegeIdCtrl.text = user.collegeId ?? '';
    _bioCtrl.text = user.bio ?? '';
    _profilePic = user.profilePic ?? '';
    _loadData(user.id);
  }

  Future<void> _loadData(int userId) async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getStudentStats(userId),
        _api.getItemsBySeller(userId),
        _api.getWishlist(userId),
        _api.getReservedItems(userId),
        _api.getBoughtHistory(userId),
        _api.getSoldHistory(userId),
      ]);

      setState(() {
        _stats = Map<String, dynamic>.from(results[0] as Map);
        _listings = (results[1] as List<Item>).map((item) => item.toJson()).toList();
        _wishlist = List.from(results[2] as List);
        _reservations =
            (results[3] as List<Item>).map((item) => item.toJson()).toList();
        _boughtHistory = List.from(results[4] as List);
        _soldHistory = List.from(results[5] as List);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  int get _completion {
    final fields = [
      _nameCtrl.text,
      _phoneCtrl.text,
      _branchCtrl.text,
      _hostelCtrl.text,
      _collegeIdCtrl.text,
      _bioCtrl.text,
      _profilePic,
      context.read<AuthProvider>().user?.email ?? '',
    ];

    final filled = fields.where((f) => f.trim().isNotEmpty).length;
    return ((filled / fields.length) * 100).round();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF141B2D),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF5B4BFF)),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
              const Icon(Icons.photo_library, color: Color(0xFF5B4BFF)),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (src == null) return;

    final img =
    await picker.pickImage(source: src, maxWidth: 512, imageQuality: 70);
    if (img == null) return;

    final bytes = await File(img.path).readAsBytes();
    final base64Pic = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    
    setState(() {
      _profilePic = base64Pic;
    });
    
    // 🚀 AUTO-SAVE IMMEDIATELY!
    _autoSaveImage(base64Pic);
  }

  Future<void> _autoSaveImage(String base64Pic) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() {
      _saving = true;
    });

    try {
      // ✅ USE APISERVICE WITH AUTHORIZATION
      final api = ApiService();
      final res = await api.updateProfile(user.id, {
        'name': _nameCtrl.text,
        'phone': _phoneCtrl.text,
        'branch': _branchCtrl.text,
        'hostel': _hostelCtrl.text,
        'collegeId': _collegeIdCtrl.text,
        'bio': _bioCtrl.text,
        'profilePic': base64Pic,
        'email': user.email,
      });

      // Merge: local profilePic + backend data
      final updated = res.copyWith(profilePic: base64Pic);
      
      await context.read<AuthProvider>().refreshUser(updated);

      setState(() {
        _msg = '✅ Image saved!';
        _saving = false;
        _profilePic = base64Pic;
      });
      
      AppLogger.debug('[Profile] Image auto-saved.');
    } catch (e) {
      setState(() {
        _msg = '❌ Image save failed';
        _saving = false;
      });
      AppLogger.error('[Profile] Auto-save error.', e);
    }
  }

  Future<void> _saveProfile() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() {
      _saving = true;
      _msg = '';
    });

    try {
      // ✅ USE APISERVICE WITH AUTHORIZATION
      final api = ApiService();
      await api.updateProfile(user.id, {
        'name': _nameCtrl.text,
        'phone': _phoneCtrl.text,
        'branch': _branchCtrl.text,
        'hostel': _hostelCtrl.text,
        'collegeId': _collegeIdCtrl.text,
        'bio': _bioCtrl.text,
        'profilePic': _profilePic,
        'email': user.email,
      });

      // Fetch fresh data from backend
      final freshUser = await api.getStudentById(user.id);
      
      // Merge: backend data + local profilePic (preserve local if backend returns NULL)
      final updated = freshUser.copyWith(
        profilePic: _profilePic.isNotEmpty ? _profilePic : freshUser.profilePic,
      );
      
      await context.read<AuthProvider>().refreshUser(updated);

      setState(() {
        _msg = '✅ Profile updated!';
        _saving = false;
      });
      
      AppLogger.debug('[Profile] Profile saved with profilePic.');
    } catch (e) {
      AppLogger.error('[Profile] Save error.', e);
      setState(() {
        _msg = '❌ Update failed';
        _saving = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    if (_newPwCtrl.text.length < 6) {
      setState(() => _pwMsg = '❌ Min 6 characters required');
      return;
    }

    if (_newPwCtrl.text != _confirmPwCtrl.text) {
      setState(() => _pwMsg = '❌ Passwords do not match');
      return;
    }

    setState(() {
      _saving = true;
      _pwMsg = '';
    });

    try {
      // ✅ USE APISERVICE WITH AUTHORIZATION
      await ApiService().changePassword(
        user.id,
        currentPassword: _currentPwCtrl.text,
        newPassword: _newPwCtrl.text,
      );

      setState(() {
        _pwMsg = '✅ Password changed!';
        _saving = false;
      });

      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
    } catch (e) {
      String errMsg = 'Incorrect password';
      if (e is Exception) {
        errMsg = e.toString();
        if (errMsg.contains('Incorrect password')) {
          errMsg = 'Incorrect current password';
        }
      }
      setState(() {
        _pwMsg = '❌ $errMsg';
        _saving = false;
      });
    }
  }

  Future<void> _removeWishlist(int studentId, int itemId) async {
    try {
      await _api.removeFromWishlist(studentId, itemId);
      setState(() {
        _wishlist.removeWhere((w) => w['item']['id'] == itemId);
      });
    } catch (_) {}
  }

  Future<void> _unreserveItem(int itemId) async {
    try {
      // ✅ USE APISERVICE WITH AUTHORIZATION
      await ApiService().unreserveItem(itemId);
      setState(() {
        _msg = '✅ Reservation cancelled!';
        _reservations.removeWhere((r) => r['id'] == itemId);
      });
    } catch (e) {
      setState(() {
        _msg = '❌ Failed to cancel reservation';
      });
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    context.read<AuthProvider>().logout();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _deleteAccount() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final passwordCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B2D),
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ye action permanent hai. Password enter karke confirm karo.',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Current password',
                hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                filled: true,
                fillColor: const Color(0xFF080B14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1E2438)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _msg = '';
    });

    try {
      await ApiService().deleteAccount(user.id, passwordCtrl.text);
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      setState(() {
        _msg = '❌ ${e.toString().replaceFirst('Exception: ', '')}';
        _saving = false;
      });
    }
  }

  List<dynamic> get _filteredListings =>
      _listings.where((i) => _listFilter == 'ALL' ? true : i['status'] == _listFilter).toList();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF080B14),
        body: Center(
          child: Text(
            'Please login first',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final name = user.name.isNotEmpty ? user.name : 'Student';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(child: _buildHeader(user, letter)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF5B4BFF),
                unselectedLabelColor: const Color(0xFF718096),
                indicatorColor: const Color(0xFF5B4BFF),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Listings'),
                  Tab(text: 'Wishlist'),
                  Tab(text: 'Reservations'),
                  Tab(text: 'History'),
                  Tab(text: 'Settings'),
                ],
              ),
            ),
          ),
        ],
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF5B4BFF)),
        )
            : TabBarView(
          controller: _tabController,
          children: [
            _buildOverview(),
            _buildListings(),
            _buildWishlist(user),
            _buildReservations(),
            _buildHistory(),
            _buildSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Student user, String letter) {
    final identityVerified = user.identityVerified ||
        (user.emailVerified &&
            user.phoneVerified &&
            user.isActive &&
            !user.isBanned);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A5F),
            Color(0xFF0F1320),
            Color(0xFF080B14),
          ],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 16,
        16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF5B4BFF), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5B4BFF).withOpacity(0.3),
                            blurRadius: 16,
                          ),
                        ],
                        gradient: _profilePic.isEmpty
                            ? const LinearGradient(
                          colors: [Color(0xFF5B4BFF), Color(0xFF00D4AA)],
                        )
                            : null,
                      ),
                      child: ClipOval(
                        child: _profilePic.isNotEmpty
                            ? AppImage(
                                source: _profilePic,
                                fit: BoxFit.cover,
                              )
                            : Center(
                          child: Text(
                            letter,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF5B4BFF),
                          border: Border.all(
                            color: const Color(0xFF080B14),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (identityVerified
                                    ? const Color(0xFF00D4AA)
                                    : const Color(0xFFF6AD55))
                                .withOpacity(0.15),
                            border: Border.all(
                              color: (identityVerified
                                      ? const Color(0xFF00D4AA)
                                      : const Color(0xFFF6AD55))
                                  .withOpacity(0.4),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            identityVerified ? '✅ Verified' : '⚠ Pending',
                            style: TextStyle(
                              fontSize: 10,
                              color: identityVerified
                                  ? const Color(0xFF00D4AA)
                                  : const Color(0xFFF6AD55),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [user.branch, user.hostel]
                          .where((s) => s != null && s.toString().isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA0AEC0),
                      ),
                    ),
                    if (user.collegeId != null && user.collegeId!.isNotEmpty)
                      Text(
                        '#${user.collegeId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5B4BFF),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statChip('${_stats['totalListings'] ?? 0}', 'Listings', const Color(0xFF5B4BFF)),
              _statChip('${_stats['soldItems'] ?? 0}', 'Sold', const Color(0xFF00D4AA)),
              _statChip('${_stats['wishlistCount'] ?? 0}', 'Saved', const Color(0xFFEF4444)),
              _statChip('${_stats['boughtCount'] ?? 0}', 'Bought', const Color(0xFFF6AD55)),
              _statChip('${_stats['totalViews'] ?? 0}', 'Views', const Color(0xFF5B4BFF)),
              _statChip('${_stats['avgRating'] ?? 0}⭐', 'Rating', const Color(0xFFFBD38D)),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _statChip(String val, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            val,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF718096),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    final comp = _completion;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile Completion',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '$comp%',
                    style: const TextStyle(
                      color: Color(0xFF5B4BFF),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: comp / 100,
                  backgroundColor: const Color(0xFF1E2438),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF5B4BFF)),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/my-orders'),
                  icon: const Icon(Icons.shopping_bag),
                  label: const Text('My Orders'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4BFF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/my-items'),
                  icon: const Icon(Icons.storefront),
                  label: const Text('My Items'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4AA),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'RECENT LISTINGS',
          style: TextStyle(
            color: Color(0xFFA0AEC0),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        if (_listings.isEmpty)
          _emptyState('📦', 'No listings yet', 'Start selling!')
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _listings.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _miniCard(_listings[i]),
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          'RECENTLY SAVED',
          style: TextStyle(
            color: Color(0xFFA0AEC0),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        if (_wishlist.isEmpty)
          _emptyState('💝', 'Nothing saved yet', 'Heart items you like!')
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _wishlist.take(4).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _miniCard(_wishlist[i]['item']),
            ),
          ),
      ],
    );
  }

  Widget _buildListings() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: ['ALL', 'AVAILABLE', 'SOLD']
                .map(
                  (f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _listFilter = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _listFilter == f
                          ? const Color(0xFF5B4BFF)
                          : const Color(0xFF0F1320),
                      border: Border.all(
                        color: _listFilter == f
                            ? const Color(0xFF5B4BFF)
                            : const Color(0xFF2A3550),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: _listFilter == f ? Colors.white : const Color(0xFF718096),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            )
                .toList(),
          ),
        ),
        Expanded(
          child: _filteredListings.isEmpty
              ? _emptyState('📦', 'No items', 'Add a listing!')
              : ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredListings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _listingRow(_filteredListings[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildWishlist(Student user) {
    return _wishlist.isEmpty
        ? _emptyState('💝', 'Wishlist is empty', 'Save items you like!')
        : GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _wishlist.length,
      itemBuilder: (_, i) {
        final item = _wishlist[i]['item'];
        return _wishlistCard(
          item,
              () => _removeWishlist(user.id, item['id']),
        );
      },
    );
  }

  Widget _buildReservations() {
    return _reservations.isEmpty
        ? _emptyState('🔒', 'No reserved items yet', 'Browse and reserve items you like!')
        : GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: _reservations.length,
      itemBuilder: (_, i) {
        final item = _reservations[i];
        return _reservationCard(
          item,
              () => _unreserveItem(item['id']),
        );
      },
    );
  }

  Widget _buildHistory() {
    final list = _historyTab == 'bought' ? _boughtHistory : _soldHistory;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: ['bought', 'sold']
                .map(
                  (t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _historyTab = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _historyTab == t
                          ? const Color(0xFF5B4BFF)
                          : const Color(0xFF0F1320),
                      border: Border.all(
                        color: _historyTab == t
                            ? const Color(0xFF5B4BFF)
                            : const Color(0xFF2A3550),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t == 'bought' ? '🛒 Buying' : '💰 Selling',
                      style: TextStyle(
                        color: _historyTab == t ? Colors.white : const Color(0xFF718096),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            )
                .toList(),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? _emptyState(
            _historyTab == 'bought' ? '🛒' : '💰',
            _historyTab == 'bought' ? 'No purchases yet' : 'No sales yet',
            _historyTab == 'bought'
                ? 'Items you buy appear here'
                : 'Items you sell appear here',
          )
              : ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _txCard(list[i]),
          ),
        ),
      ],
    );
  }

  Widget _txCard(Map tx) {
    final item = tx['item'] as Map?;
    final person = _historyTab == 'bought'
        ? tx['seller'] as Map?
        : tx['buyer'] as Map?;
    final imgs = item?['imageUrls'] as List?;
    final img = imgs?.isNotEmpty == true ? imgs![0] : null;

    final statusColors = {
      'COMPLETED': const Color(0xFF00D4AA),
      'PENDING': const Color(0xFF5B4BFF),
      'CANCELLED': const Color(0xFFEF4444),
    };

    final status = tx['status'] ?? 'COMPLETED';
    final color = statusColors[status] ?? const Color(0xFF718096);

    String dateStr = '';
    try {
      final dt = DateTime.parse(tx['createdAt']);
      dateStr = DateFormat('d MMM yyyy').format(dt);
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1320),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2438)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: img != null && img.toString().startsWith('data:')
                  ? Image.memory(
                base64Decode(img.split(',').last),
                fit: BoxFit.cover,
              )
                  : Container(
                color: const Color(0xFF1E2438),
                child: const Icon(
                  Icons.inventory_2,
                  color: Color(0xFF4A5568),
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
                  item?['title'] ?? 'Item',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '₹${tx['amount'] ?? item?['price']}',
                  style: const TextStyle(
                    color: Color(0xFF5B4BFF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_historyTab == 'bought' ? '🏪 Seller' : '👤 Buyer'}: ${person?['name'] ?? 'Unknown'}  ·  $dateStr',
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_msg.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _msg.startsWith('✅')
                  ? const Color(0xFF00D4AA).withOpacity(0.1)
                  : const Color(0xFFEF4444).withOpacity(0.1),
              border: Border.all(
                color: _msg.startsWith('✅')
                    ? const Color(0xFF00D4AA)
                    : const Color(0xFFEF4444),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _msg,
              style: TextStyle(
                color: _msg.startsWith('✅')
                    ? const Color(0xFF00D4AA)
                    : const Color(0xFFEF4444),
                fontSize: 13,
              ),
            ),
          ),
        _settingsCard('Personal Information', [
          _field('Full Name', _nameCtrl, hint: 'Your full name'),
          _field('Phone', _phoneCtrl, hint: '+91 XXXXXXXXXX', type: TextInputType.phone),
          _field('Branch', _branchCtrl, hint: 'B.Tech CSE'),
          _field('Hostel', _hostelCtrl, hint: 'Hostel A / Block 3'),
          _field('College ID', _collegeIdCtrl, hint: 'Roll / Enrollment No.'),
          _field('Bio', _bioCtrl, hint: 'Tell something about yourself...', maxLines: 3),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4BFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _saving ? 'Saving...' : '💾 Save Changes',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _settingsCard('Change Password', [
          _field(
            'Current Password',
            _currentPwCtrl,
            hint: 'Enter current password',
            obscure: true,
          ),
          _field(
            'New Password',
            _newPwCtrl,
            hint: 'Minimum 6 characters',
            obscure: true,
          ),
          _field(
            'Confirm New Password',
            _confirmPwCtrl,
            hint: 'Re-enter new password',
            obscure: true,
          ),
          if (_pwMsg.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _pwMsg.startsWith('✅')
                    ? const Color(0xFF00D4AA).withOpacity(0.1)
                    : const Color(0xFFEF4444).withOpacity(0.1),
                border: Border.all(
                  color: _pwMsg.startsWith('✅')
                      ? const Color(0xFF00D4AA)
                      : const Color(0xFFEF4444),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _pwMsg,
                style: TextStyle(
                  fontSize: 12,
                  color: _pwMsg.startsWith('✅')
                      ? const Color(0xFF00D4AA)
                      : const Color(0xFFEF4444),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B4BFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                '🔒 Update Password',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _settingsCard('Account', [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B4BFF),
                side: const BorderSide(color: Color(0xFF5B4BFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Privacy & Settings',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B4BFF),
                side: const BorderSide(color: Color(0xFF5B4BFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Notification Center',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/support'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B4BFF),
                side: const BorderSide(color: Color(0xFF5B4BFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Support & Legal Hub',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _saving ? null : _deleteAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Delete Account',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                '🚪 Logout',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0F1320),
      border: Border.all(color: const Color(0xFF1E2438)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );

  Widget _settingsCard(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0F1320),
      border: Border.all(color: const Color(0xFF1E2438)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  Widget _field(
      String label,
      TextEditingController ctrl, {
        String hint = '',
        TextInputType? type,
        bool obscure = false,
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFA0AEC0),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            keyboardType: type,
            obscureText: obscure,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF5B4BFF)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniCard(Map item) {
    final img = (item['imageUrls'] as List?)?.isNotEmpty == true
        ? item['imageUrls'][0]
        : null;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/item',
        arguments: item['id'],
      ),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1320),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2438)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 90,
                width: 130,
                child: img != null && img.toString().startsWith('data:')
                    ? Image.memory(
                  base64Decode(img.split(',').last),
                  fit: BoxFit.cover,
                )
                    : Container(
                  color: const Color(0xFF1E2438),
                  child: const Icon(
                    Icons.inventory_2,
                    color: Color(0xFF4A5568),
                    size: 30,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '₹${item['price']}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5B4BFF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listingRow(Map item) {
    final img = (item['imageUrls'] as List?)?.isNotEmpty == true
        ? item['imageUrls'][0]
        : null;

    final statusColor = item['status'] == 'AVAILABLE'
        ? const Color(0xFF00D4AA)
        : item['status'] == 'SOLD'
        ? const Color(0xFFEF4444)
        : const Color(0xFF5B4BFF);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1320),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2438)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 68,
              height: 68,
              child: img != null && img.toString().startsWith('data:')
                  ? Image.memory(
                base64Decode(img.split(',').last),
                fit: BoxFit.cover,
              )
                  : Container(
                color: const Color(0xFF1E2438),
                child: const Icon(
                  Icons.inventory_2,
                  color: Color(0xFF4A5568),
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
                  item['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '₹${item['price']}',
                  style: const TextStyle(
                    color: Color(0xFF5B4BFF),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        border: Border.all(
                          color: statusColor.withOpacity(0.4),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item['status'] ?? '',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '👁 ${item['viewCount'] ?? 0}',
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF718096),
              size: 20,
            ),
            onPressed: () => Navigator.pushNamed(
              context,
              '/edit-item',
              arguments: Item.fromJson(Map<String, dynamic>.from(item)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wishlistCard(Map item, VoidCallback onRemove) {
    final img = (item['imageUrls'] as List?)?.isNotEmpty == true
        ? item['imageUrls'][0]
        : null;
    final isSold = item['status'] == 'SOLD';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1320),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2438)),
      ),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                '/item',
                arguments: item['id'],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: SizedBox(
                      width: double.infinity,
                      child: img != null && img.toString().startsWith('data:')
                          ? Image.memory(
                        base64Decode(img.split(',').last),
                        fit: BoxFit.cover,
                      )
                          : Container(
                        color: const Color(0xFF1E2438),
                        child: const Icon(
                          Icons.inventory_2,
                          size: 40,
                          color: Color(0xFF4A5568),
                        ),
                      ),
                    ),
                  ),
                  if (isSold)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'SOLD',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '₹${item['price']}',
                  style: const TextStyle(
                    color: Color(0xFF5B4BFF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onRemove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 0.8,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reservationCard(Map item, VoidCallback onUnreserve) {
    final img = (item['imageUrls'] as List?)?.isNotEmpty == true
        ? item['imageUrls'][0]
        : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1320),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2438)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: img != null && img.toString().startsWith('data:')
                      ? Image.memory(
                    base64Decode(img.split(',').last),
                    fit: BoxFit.cover,
                  )
                      : Container(
                    color: const Color(0xFF1E2438),
                    child: const Icon(
                      Icons.inventory_2,
                      color: Color(0xFF4A5568),
                      size: 30,
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: const Center(
                  child: Text(
                    '🔒 RESERVED',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '₹${item['price']}',
                  style: const TextStyle(
                    color: Color(0xFF5B4BFF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item['seller'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Seller: ${item['seller']['name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B4BFF),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onUnreserve,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(
                            color: Color(0xFFEF4444),
                            width: 0.8,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
    );
  }

  Widget _emptyState(String icon, String text, String sub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: const TextStyle(
                color: Color(0xFF718096),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF080B14),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabBar != tabBar;
}
