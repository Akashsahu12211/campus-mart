import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/brand_mark.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {

  final _api = ApiService();
  late final TabController _tabs;

  Map<String, dynamic>? _stats;
  List<dynamic> _users   = [];
  List<dynamic> _items   = [];
  List<dynamic> _reports = [];
  List<dynamic> _logs    = [];

  bool _loadingStats   = true;
  bool _loadingUsers   = true;
  bool _loadingItems   = true;
  bool _loadingReports = true;
  bool _loadingLogs    = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _checkAccess();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _checkAccess() {
    final user = context.read<AuthProvider>().user;
    if (user == null ||
        (user.role != 'ADMIN' && user.role != 'MODERATOR')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Access denied'),
          backgroundColor: AppTheme.danger));
      });
      return;
    }
    _loadAll();
  }

  Future<void> _loadAll() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    _loadStats();
    _loadUsers();
    _loadItems();
    _loadReports();
    _loadLogs();
  }

  Future<void> _loadStats() async {
    try {
      final s = await _api.getAdminStats();
      setState(() { _stats = s; _loadingStats = false; });
    } catch (_) { setState(() => _loadingStats = false); }
  }

  Future<void> _loadUsers() async {
    try {
      final u = await _api.getAdminUsers();
      setState(() { _users = u; _loadingUsers = false; });
    } catch (_) { setState(() => _loadingUsers = false); }
  }

  Future<void> _loadItems() async {
    try {
      final it = await _api.getAdminItems();
      setState(() { _items = it; _loadingItems = false; });
    } catch (_) { setState(() => _loadingItems = false); }
  }

  Future<void> _loadReports() async {
    try {
      final r = await _api.getAdminReports(pendingOnly: true);
      setState(() { _reports = r; _loadingReports = false; });
    } catch (_) { setState(() => _loadingReports = false); }
  }

  Future<void> _loadLogs() async {
    try {
      final l = await _api.getAdminLogs();
      setState(() { _logs = l; _loadingLogs = false; });
    } catch (_) { setState(() => _loadingLogs = false); }
  }

  void _showMsg(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.success,
      behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      body: Stack(
        children: [
          // 🔴 RED STRIPE AT TOP
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.danger, Color(0xFFF59E0B), AppTheme.danger],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.danger,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),

          // MAIN CONTENT
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: AppTheme.bg,
                  title: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accent2]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(child: BrandMark(size: 18)),
                    ),
                    const SizedBox(width: 10),
                    RichText(text: const TextSpan(
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      children: [
                        TextSpan(text: 'Campus', style: TextStyle(color: Colors.white)),
                        TextSpan(text: 'Mart', style: TextStyle(color: AppTheme.accentH)),
                      ],
                    )),
                    const SizedBox(width: 4),
                    const Text('ADMIN',
                      style: TextStyle(fontSize: 10, color: AppTheme.danger,
                        fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ]),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: IconButton(
                        icon: const Icon(Icons.home_outlined, color: AppTheme.muted),
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context, '/', (route) => false),
                      ),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(120),
                    child: Column(
                      children: [
                        // 🔴 ADMIN MODE BANNER
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFEF4444).withOpacity(0.1),
                                const Color(0xFFF59E0B).withOpacity(0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: AppTheme.danger.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Text('🔐', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('ADMIN MODE ACTIVE',
                                      style: TextStyle(
                                        color: Color(0xFFfca5a5),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      )),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Full access to platform management',
                                      style: TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.danger.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AppTheme.danger,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text('LIVE',
                                      style: TextStyle(
                                        color: Color(0xFFfca5a5),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      )),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // TABS
                        TabBar(
                          controller: _tabs,
                          labelColor: AppTheme.accentH,
                          unselectedLabelColor: AppTheme.muted,
                          indicatorColor: AppTheme.accent,
                          tabs: [
                            const Tab(icon: Icon(Icons.dashboard, size: 18),
                              text: 'Dashboard'),
                            Tab(icon: Badge(
                                label: Text('${_users.length}'),
                                child: const Icon(Icons.people, size: 18)),
                              text: 'Users'),
                            const Tab(icon: Icon(Icons.inventory_2, size: 18),
                              text: 'Items'),
                            Tab(
                              icon: Badge(
                                label: Text('${_reports.length}',
                                  style: const TextStyle(fontSize: 10)),
                                backgroundColor: AppTheme.danger,
                                isLabelVisible: _reports.isNotEmpty,
                                child: const Icon(Icons.report, size: 18)),
                              text: 'Reports'),
                            const Tab(icon: Icon(Icons.history, size: 18),
                              text: 'Logs'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabs,
              children: [
                _buildDashboard(),
                _buildUsers(user),
                _buildItems(user),
                _buildReports(user),
                _buildLogs(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    if (_loadingStats) return const Center(
      child: CircularProgressIndicator(color: AppTheme.accent));

    final u = _stats?['users']    as Map? ?? {};
    final i = _stats?['items']    as Map? ?? {};
    final r = _stats?['reports']  as Map? ?? {};
    final p = _stats?['platform'] as Map? ?? {};
    final m = _stats?['monetization'] as Map? ?? {};

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔴 ADMIN MODE BANNER
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFEF4444).withOpacity(0.1),
                  const Color(0xFFF59E0B).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppTheme.danger.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('🔐', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ADMIN MODE ACTIVE',
                        style: TextStyle(
                          color: Color(0xFFfca5a5),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        )),
                      const SizedBox(height: 2),
                      const Text(
                        'You have full access to platform management tools',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Text('Overview',
            style: TextStyle(color: AppTheme.textSec,
              fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              _statCard('👥 Users', '${u['total'] ?? 0}',
                '${u['today'] ?? 0} today', AppTheme.accent),
              _statCard('🚫 Banned', '${u['banned'] ?? 0}',
                'Active bans', AppTheme.danger),
              _statCard('📦 Items', '${i['total'] ?? 0}',
                '${i['today'] ?? 0} today', AppTheme.accent2),
              _statCard('✅ Sold', '${i['sold'] ?? 0}',
                '${i['available'] ?? 0} available', AppTheme.success),
              _statCard('🚨 Reports', '${r['pending'] ?? 0}',
                'Pending review', AppTheme.warning),
              _statCard('💬 Messages',
                '${p['totalMessages'] ?? 0}',
                '${p['totalOffers'] ?? 0} offers', AppTheme.accentH),
              _statCard('Paid Subscribers', '${m['paidSubscribers'] ?? 0}',
                '${m['plusSubscribers'] ?? 0} plus | ${m['premiumSubscribers'] ?? 0} premium', AppTheme.accent),
              _statCard('Active Boosts', '${m['activeBoostedListings'] ?? 0}',
                'Pending fees INR ${m['pendingPlatformFees'] ?? 0}', AppTheme.danger),
            ],
          ),
          const SizedBox(height: 16),
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
                  'Monetization Snapshot',
                  style: TextStyle(
                    color: AppTheme.textSec,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                _metricRow(
                  'Released platform fees',
                  'INR ${m['releasedPlatformFees'] ?? 0}',
                ),
                _metricRow(
                  'Pending platform fees',
                  'INR ${m['pendingPlatformFees'] ?? 0}',
                ),
                _metricRow(
                  'Paid subscribers',
                  '${m['paidSubscribers'] ?? 0}',
                ),
                _metricRow(
                  'Active boosted listings',
                  '${m['activeBoostedListings'] ?? 0}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value,
      String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(color: color, width: 3),
          left: BorderSide(color: AppTheme.border),
          right: BorderSide(color: AppTheme.border),
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
            color: AppTheme.muted, fontSize: 11,
            fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(value, style: TextStyle(
            color: color, fontSize: 22,
            fontWeight: FontWeight.w900)),
          Text(sub, style: const TextStyle(
            color: AppTheme.muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsers(student) {
    if (_loadingUsers) return const Center(
      child: CircularProgressIndicator(color: AppTheme.accent));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 🔴 ADMIN MODE BANNER
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFEF4444).withOpacity(0.1),
                const Color(0xFFF59E0B).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppTheme.danger.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🔐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ADMIN MODE ACTIVE',
                      style: TextStyle(
                        color: Color(0xFFfca5a5),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      )),
                    const SizedBox(height: 2),
                    Text(
                      'Managing ${_users.length} registered users',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ..._users.map((u) {
          final isBanned = u['banned'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.accent.withOpacity(0.2),
                child: Text(
                  (u['name'] as String? ?? '?')
                    .substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u['name'] ?? '',
                    style: const TextStyle(
                      color: AppTheme.textPrim,
                      fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(u['email'] ?? '',
                    style: const TextStyle(
                      color: AppTheme.muted, fontSize: 11)),
                  Row(children: [
                    Container(
                      margin: const EdgeInsets.only(right: 6, top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                      child: Text(u['role'] ?? 'STUDENT',
                        style: const TextStyle(
                          color: AppTheme.accentH,
                          fontSize: 9, fontWeight: FontWeight.w700))),
                    if (isBanned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4)),
                        child: const Text('BANNED',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontSize: 9, fontWeight: FontWeight.w700))),
                  ]),
                ],
              )),
              if (u['id'] != student?.id)
                PopupMenuButton<String>(
                  color: AppTheme.surface2,
                  icon: const Icon(Icons.more_vert,
                    color: AppTheme.muted, size: 18),
                  onSelected: (action) async {
                    if (action == 'ban') {
                      final reason = await _showTextDialog(
                        'Ban Reason', 'Why are you banning ${u['name']}?');
                      if (reason == null) return;
                      try {
                        await _api.banUser(u['id'], reason);
                        _showMsg('${u['name']} banned');
                        _loadUsers();
                      } catch (e) {
                        _showMsg(e.toString(), error: true);
                      }
                    } else if (action == 'unban') {
                      try {
                        await _api.unbanUser(u['id']);
                        _showMsg('${u['name']} unbanned');
                        _loadUsers();
                      } catch (e) {
                        _showMsg(e.toString(), error: true);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isBanned)
                      const PopupMenuItem(value: 'ban',
                        child: Text('🚫 Ban User',
                          style: TextStyle(color: AppTheme.danger))),
                    if (isBanned)
                      const PopupMenuItem(value: 'unban',
                        child: Text('✅ Unban',
                          style: TextStyle(color: AppTheme.success))),
                  ],
                ),
            ]),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildItems(student) {
    if (_loadingItems) return const Center(
      child: CircularProgressIndicator(color: AppTheme.accent));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 🔴 ADMIN MODE BANNER
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFEF4444).withOpacity(0.1),
                const Color(0xFFF59E0B).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppTheme.danger.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🔐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ADMIN MODE ACTIVE',
                      style: TextStyle(
                        color: Color(0xFFfca5a5),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      )),
                    const SizedBox(height: 2),
                    Text(
                      'Moderating ${_items.length} items in the platform',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ..._items.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.surface2,
                  borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('📦',
                  style: TextStyle(fontSize: 22)))),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'] ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrim,
                      fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(
                    '₹${item['price']} · ${item['status']} · '
                    '${item['seller']?['name'] ?? '?'}',
                    style: const TextStyle(
                      color: AppTheme.muted, fontSize: 11)),
                ],
              )),
              PopupMenuButton<String>(
                color: AppTheme.surface2,
                icon: const Icon(Icons.more_vert,
                  color: AppTheme.muted, size: 18),
                onSelected: (action) async {
                  if (action == 'hide') {
                    try {
                      await _api.hideItem(item['id'], 'Admin action');
                      _showMsg('Item hidden');
                      _loadItems();
                    } catch (e) {
                      _showMsg(e.toString(), error: true);
                    }
                  }
                },
                itemBuilder: (_) => [
                  if (item['status'] != 'HIDDEN')
                    const PopupMenuItem(value: 'hide',
                      child: Text('🙈 Hide Item',
                        style: TextStyle(color: AppTheme.warning))),
                ],
              ),
            ]),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildReports(student) {
    if (_loadingReports) return const Center(
      child: CircularProgressIndicator(color: AppTheme.accent));

    if (_reports.isEmpty) return ListView(
      children: [
        // 🔴 ADMIN MODE BANNER
        Container(
          margin: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFEF4444).withOpacity(0.1),
                const Color(0xFFF59E0B).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppTheme.danger.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🔐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ADMIN MODE ACTIVE',
                      style: TextStyle(
                        color: Color(0xFFfca5a5),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      )),
                    const SizedBox(height: 2),
                    const Text(
                      'Reviewing user-submitted reports',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🚨', style: TextStyle(fontSize: 40)),
            SizedBox(height: 10),
            Text('No pending reports',
              style: TextStyle(color: AppTheme.textSec)),
          ]),
        ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 🔴 ADMIN MODE BANNER
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFEF4444).withOpacity(0.1),
                const Color(0xFFF59E0B).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppTheme.danger.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🔐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ADMIN MODE ACTIVE',
                      style: TextStyle(
                        color: Color(0xFFfca5a5),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      )),
                    const SizedBox(height: 2),
                    Text(
                      'Reviewing ${_reports.length} user-submitted reports',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ..._reports.map((r) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warning.withOpacity(0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text(r['reason'] ?? '',
                        style: const TextStyle(
                          color: AppTheme.danger,
                          fontSize: 10, fontWeight: FontWeight.w700))),
                    const Text('PENDING', style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(r['item']?['title'] ?? 'Unknown item',
                  style: const TextStyle(
                    color: AppTheme.textPrim,
                    fontWeight: FontWeight.w700)),
                Text('By: ${r['reporter']?['name'] ?? '?'}',
                  style: const TextStyle(
                    color: AppTheme.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  'Item reports: ${r['itemReportCount'] ?? 0} · Pending: ${r['pendingReportCount'] ?? 0}',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 11,
                  ),
                ),
                if (r['reviewedBy'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reviewed by: ${r['reviewedBy']?['name'] ?? 'Moderator'}',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: () async {
                      try {
                        await _api.reviewReport(r['id'], 'approve');
                        _showMsg('Item hidden');
                        _loadReports();
                      } catch (e) {
                        _showMsg(e.toString(), error: true);
                      }
                    },
                    child: const Text('Approve & Hide',
                      style: TextStyle(fontSize: 12)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.muted,
                      side: const BorderSide(color: AppTheme.border2),
                      padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: () async {
                      try {
                        await _api.reviewReport(r['id'], 'dismiss');
                        _showMsg('Report dismissed');
                        _loadReports();
                      } catch (e) {
                        _showMsg(e.toString(), error: true);
                      }
                    },
                    child: const Text('Dismiss',
                      style: TextStyle(fontSize: 12)),
                  )),
                ]),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLogs() {
    if (_loadingLogs) return const Center(
      child: CircularProgressIndicator(color: AppTheme.accent));

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // 🔴 ADMIN MODE BANNER
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFEF4444).withOpacity(0.1),
                const Color(0xFFF59E0B).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppTheme.danger.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🔐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ADMIN MODE ACTIVE',
                      style: TextStyle(
                        color: Color(0xFFfca5a5),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      )),
                    const SizedBox(height: 2),
                    Text(
                      'Viewing audit trail of ${_logs.length} admin actions',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ..._logs.map((log) {
          final actionColor = _getActionColor(log['action']);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: actionColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        log['action'] ?? '',
                        style: TextStyle(
                          color: actionColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(log['createdAt']),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  log['description'] ?? '',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'BAN_USER':
      case 'DELETE_USER':
      case 'FORCE_DELETE_ITEM':
        return AppTheme.danger;
      case 'UNBAN_USER':
      case 'RESTORE_ITEM':
        return AppTheme.success;
      case 'CHANGE_ROLE':
      case 'HIDE_ITEM':
        return AppTheme.warning;
      case 'REVIEW_REPORT':
        return AppTheme.accent;
      default:
        return AppTheme.muted;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp.toString());
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Future<String?> _showTextDialog(String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title,
          style: const TextStyle(color: AppTheme.textPrim)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.textPrim),
          decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Confirm')),
        ],
      ),
    );
  }
}
