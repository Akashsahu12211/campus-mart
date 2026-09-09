import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/social_links.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiService();
  final _locationCtrl = TextEditingController();
  bool _loading = false;
  String _status = '';
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _showPhone = true;
  bool _directChat = true;
  String _privacyMode = 'CAMPUS_ONLY';
  String _language = 'EN';
  String _locationLabel = '';
  List<dynamic> _blockedUsers = [];
  Map<String, dynamic>? _monetization;
  bool _monetizationLoading = false;
  String _activatingPlan = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() {
      _pushEnabled = user.pushNotificationsEnabled;
      _emailEnabled = user.emailNotificationsEnabled;
      _showPhone = user.showPhoneOnListings;
      _directChat = user.allowDirectChat;
      _privacyMode = user.privacyMode;
      _language = user.preferredLanguage;
      _locationLabel = user.locationLabel ?? '';
      _locationCtrl.text = _locationLabel;
    });
    try {
      final blocked = await _api.getBlockedUsers(user.id);
      setState(() => _blockedUsers = blocked);
    } catch (_) {}
    await _loadMonetization();
  }

  Future<void> _loadMonetization() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _monetizationLoading = true);
    try {
      final summary = await _api.getMonetizationSummary(user.id);
      if (mounted) {
        setState(() => _monetization = summary);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _monetization = null);
      }
    }
    if (mounted) {
      setState(() => _monetizationLoading = false);
    }
  }

  Future<void> _save({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? showPhone,
    bool? directChat,
    String? privacyMode,
    String? preferredLanguage,
    String? locationLabel,
    double? latitude,
    double? longitude,
  }) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final nextPush = pushEnabled ?? _pushEnabled;
    final nextEmail = emailEnabled ?? _emailEnabled;
    final nextShowPhone = showPhone ?? _showPhone;
    final nextDirectChat = directChat ?? _directChat;
    final nextPrivacyMode = privacyMode ?? _privacyMode;
    final nextLanguage = preferredLanguage ?? _language;
    final nextLocationLabel = locationLabel ?? _locationLabel;

    setState(() {
      _loading = true;
      _status = '';
      _pushEnabled = nextPush;
      _emailEnabled = nextEmail;
      _showPhone = nextShowPhone;
      _directChat = nextDirectChat;
      _privacyMode = nextPrivacyMode;
      _language = nextLanguage;
      _locationLabel = nextLocationLabel;
    });

    try {
      final updated = await _api.updateProfile(user.id, {
        'pushNotificationsEnabled': nextPush,
        'emailNotificationsEnabled': nextEmail,
        'showPhoneOnListings': nextShowPhone,
        'allowDirectChat': nextDirectChat,
        'privacyMode': nextPrivacyMode,
        'preferredLanguage': nextLanguage,
        'locationLabel': nextLocationLabel,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });

      await auth.refreshUser(updated);
      setState(() => _status = 'Settings updated');
    } catch (e) {
      setState(() => _status = e.toString().replaceFirst('Exception: ', ''));
    }

    setState(() => _loading = false);
  }

  Future<void> _unblock(int blockedId) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      await _api.unblockUser(blockedId, user.id);
      setState(() {
        _blockedUsers
            .removeWhere((entry) => entry['blocked']?['id'] == blockedId);
      });
    } catch (e) {
      setState(() => _status = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _captureLocation() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _status = 'Enable location services first');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _status = 'Location permission denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      await _save(
        latitude: position.latitude,
        longitude: position.longitude,
        locationLabel: _locationLabel,
      );
    } catch (e) {
      setState(() => _status = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _activatePlan(String planCode) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;
    setState(() {
      _activatingPlan = planCode;
      _status = '';
    });
    try {
      final result = await _api.activateMonetizationPlan(planCode);
      if (result['student'] is Map<String, dynamic>) {
        await auth.refreshUser(
          context.read<AuthProvider>().user!.copyWith(
                activeSubscriptionCode: result['student']['activeSubscriptionCode']?.toString(),
                subscriptionActivatedAt: result['student']['subscriptionActivatedAt']?.toString(),
                contactAccessTier: result['student']['contactAccessTier']?.toString(),
                contactAccessExpiresAt: result['student']['contactAccessExpiresAt']?.toString(),
                availableBoostCredits:
                    (result['student']['availableBoostCredits'] as num?)?.toInt(),
                usedBoostCredits:
                    (result['student']['usedBoostCredits'] as num?)?.toInt(),
                currentCommissionPercent:
                    (result['student']['currentCommissionPercent'] as num?)?.toDouble(),
              ),
        );
      }
      if (result['summary'] is Map) {
        setState(() => _monetization = Map<String, dynamic>.from(result['summary'] as Map));
      }
      setState(() => _status = result['message']?.toString() ?? 'Plan updated');
    } catch (e) {
      setState(() => _status = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) {
      setState(() => _activatingPlan = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final user = context.watch<AuthProvider>().user;
    final identityVerified = user?.identityVerified == true ||
        ((user?.emailVerified ?? false) &&
            (user?.phoneVerified ?? false) &&
            (user?.isActive ?? false) &&
            !(user?.isBanned ?? false));
    final contactAccessExpiry =
        user?.contactAccessExpiresAt?.split('T').first ?? '';
    final activePlanCode =
        _monetization?['activeSubscriptionCode']?.toString() ??
            user?.activeSubscriptionCode ??
            'FREE';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_status.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _status == 'Settings updated'
                    ? const Color(0xFF00D4AA).withValues(alpha: 0.1)
                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _status == 'Settings updated'
                      ? const Color(0xFF00D4AA)
                      : const Color(0xFFEF4444),
                ),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: _status == 'Settings updated'
                      ? const Color(0xFF00D4AA)
                      : const Color(0xFFEF4444),
                ),
              ),
            ),
          _card('Notification Preferences', [
            _switchTile(
              title: 'Push notifications',
              subtitle: 'Real-time chat, offer and marketplace updates',
              value: _pushEnabled,
              onChanged: (value) => _save(pushEnabled: value),
            ),
            _switchTile(
              title: 'Email notifications',
              subtitle: 'Important account and support emails',
              value: _emailEnabled,
              onChanged: (value) => _save(emailEnabled: value),
            ),
            _navTile('Open notification center',
                () => Navigator.pushNamed(context, '/notifications')),
          ]),
          const SizedBox(height: 16),
          _card('Display & Personalization', [
            DropdownButtonFormField<ThemeMode>(
              initialValue: themeProvider.themeMode,
              decoration: _inputDecoration('Theme mode'),
              items: const [
                DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: ThemeMode.light,
                    child:
                        Text('Light', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: ThemeMode.system,
                    child:
                        Text('System', style: TextStyle(color: Colors.white))),
              ],
              dropdownColor: const Color(0xFF111728),
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                }
              },
            ),
            const SizedBox(height: 12),
            _navTile('My support tickets',
                () => Navigator.pushNamed(context, '/support-tickets')),
            _navTile('Activity history',
                () => Navigator.pushNamed(context, '/activity')),
          ]),
          const SizedBox(height: 16),
          _card('Privacy Controls', [
            _switchTile(
              title: 'Show phone on listings',
              subtitle: 'Allow buyers to contact you directly',
              value: _showPhone,
              onChanged: (value) => _save(showPhone: value),
            ),
            _switchTile(
              title: 'Allow direct chat',
              subtitle: 'Turn off if you want controlled contact only',
              value: _directChat,
              onChanged: (value) => _save(directChat: value),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF5B4BFF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF5B4BFF).withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                'Verification: ${identityVerified ? 'Fully verified' : 'Partial verification'}\n'
                'Contact plan: ${user?.contactAccessTier ?? 'FREE'}'
                '${contactAccessExpiry.isNotEmpty ? ' until $contactAccessExpiry' : ''}\n'
                'Seller phone visibility now follows both seller preference and launch safety policy. In-app chat remains the default safe path for free users.',
                style: const TextStyle(
                  color: Color(0xFFD9D5FF),
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _privacyMode,
              decoration: _inputDecoration('Privacy mode'),
              dropdownColor: const Color(0xFF111728),
              items: const [
                DropdownMenuItem(
                    value: 'CAMPUS_ONLY',
                    child: Text('Campus Only',
                        style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 'LIMITED',
                    child: Text('Limited Visibility',
                        style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 'PUBLIC',
                    child: Text('Public Profile',
                        style: TextStyle(color: Colors.white))),
              ],
              onChanged: (value) {
                if (value != null) {
                  _save(privacyMode: value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: _inputDecoration('Language'),
              dropdownColor: const Color(0xFF111728),
              items: const [
                DropdownMenuItem(
                    value: 'EN',
                    child:
                        Text('English', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 'HI',
                    child:
                        Text('Hindi', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(
                    value: 'HINGLISH',
                    child: Text('Hinglish',
                        style: TextStyle(color: Colors.white))),
              ],
              onChanged: (value) {
                if (value != null) {
                  _save(preferredLanguage: value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationCtrl,
              onChanged: (value) => _locationLabel = value,
              onSubmitted: (value) => _save(locationLabel: value),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Saved location label'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loading ? null : _captureLocation,
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Use current location for nearby filters'),
            ),
          ]),
          const SizedBox(height: 16),
          _card('Monetization & Plans', [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF00D4AA).withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                'Current plan: $activePlanCode'
                '${_monetization?['contactAccessExpiresAt'] != null ? ' until ${_monetization!['contactAccessExpiresAt'].toString().split('T').first}' : ''}\n'
                'Seller fee: ${((_monetization?['commissionPercent'] as num?)?.toDouble() ?? user?.currentCommissionPercent ?? 7).toStringAsFixed(2)}% · '
                'Boost credits: ${_monetization?['availableBoostCredits'] ?? user?.availableBoostCredits ?? 0}\n'
                'Released seller net: ${_formatCurrency(_monetization?['releasedSellerNet'])} · '
                'Pending platform fees: ${_formatCurrency(_monetization?['pendingPlatformFees'])}',
                style: const TextStyle(
                  color: Color(0xFFC8F5EA),
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            ),
            if (_monetizationLoading)
              const Text(
                'Loading monetization summary...',
                style: TextStyle(color: Color(0xFF94A3B8)),
              )
            else ...[
              ...(((_monetization?['plans'] as List?) ?? const []).map((plan) {
                final entry = Map<String, dynamic>.from(plan as Map);
                final isActive = activePlanCode == entry['code']?.toString();
                final features = (entry['features'] as List?)
                        ?.map((feature) => feature.toString())
                        .join(' · ') ??
                    '';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF5B4BFF).withValues(alpha: 0.10)
                        : const Color(0xFF111728),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF5B4BFF).withValues(alpha: 0.45)
                          : const Color(0xFF1E2438),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      entry['name']?.toString() ?? 'Plan',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if ((entry['highlight']?.toString() ?? '').isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          entry['highlight'].toString(),
                                          style: const TextStyle(
                                            color: Color(0xFFF59E0B),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  entry['description']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_formatCurrency(entry['price'])} · ${entry['durationDays'] ?? 0} days · ${entry['commissionPercent']}% fee · ${entry['boostCredits'] ?? 0} boosts',
                                  style: const TextStyle(
                                    color: Color(0xFFA0A8C8),
                                    fontSize: 12,
                                  ),
                                ),
                                if (features.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    features,
                                    style: const TextStyle(
                                      color: Color(0xFF8FA0C4),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: (_activatingPlan.isNotEmpty || isActive)
                                ? null
                                : () => _activatePlan(entry['code'].toString()),
                            child: Text(
                              isActive
                                  ? 'Active'
                                  : _activatingPlan == entry['code'].toString()
                                      ? 'Activating...'
                                      : 'Test Activate',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList()),
              if (((_monetization?['recentLedger'] as List?) ?? const []).isNotEmpty) ...[
                const Text(
                  'Recent Commission Ledger',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ...(((_monetization?['recentLedger'] as List?) ?? const [])
                    .take(4)
                    .map((entry) {
                  final row = Map<String, dynamic>.from(entry as Map);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111728),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E2438)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row['entryType']?.toString() ?? 'ENTRY',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              row['createdAt'] != null
                                  ? row['createdAt'].toString().split('T').first
                                  : '',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fee ${_formatCurrency(row['platformFeeAmount'])} · Seller net ${_formatCurrency(row['sellerNetAmount'])}',
                          style: const TextStyle(
                            color: Color(0xFFA0A8C8),
                            fontSize: 12,
                          ),
                        ),
                        if ((row['itemTitle']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            row['itemTitle'].toString(),
                            style: const TextStyle(
                              color: Color(0xFF8FA0C4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList()),
              ],
            ],
          ]),
          const SizedBox(height: 16),
          _card('Safety Controls', [
            if (_blockedUsers.isEmpty)
              const Text('No blocked users yet',
                  style: TextStyle(color: Color(0xFF94A3B8)))
            else
              ..._blockedUsers.map((entry) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111728),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E2438)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry['blocked']?['name'] ?? 'User',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(entry['blocked']?['email'] ?? '',
                                  style: const TextStyle(
                                      color: Color(0xFF94A3B8), fontSize: 12)),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () => _unblock(entry['blocked']['id'] as int),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                          child: const Text('Unblock'),
                        ),
                      ],
                    ),
                  )),
            _navTile('Support & legal hub',
                () => Navigator.pushNamed(context, '/support')),
            _navTile('Support tickets',
                () => Navigator.pushNamed(context, '/support-tickets')),
          ]),
          const SizedBox(height: 16),
          _card('Social & Community', [
            if (SocialLinksConfig.enabledLinks.isEmpty)
              const Text(
                'Social handles can be enabled at build time when your startup brand accounts are ready.',
                style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
              )
            else
              ...SocialLinksConfig.enabledLinks.map(
                (link) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(link.label,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(link.shortLabel,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12)),
                  trailing:
                      const Icon(Icons.open_in_new, color: Color(0xFF94A3B8)),
                  onTap: () => launchUrl(Uri.parse(link.url),
                      mode: LaunchMode.externalApplication),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return 'INR ${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1320),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2438)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: _loading ? null : onChanged,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: const Color(0xFF5B4BFF),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
    );
  }

  Widget _navTile(String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
      onTap: onTap,
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF4A5568)),
      filled: true,
      fillColor: const Color(0xFF111728),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E2438)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E2438)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF5B4BFF)),
      ),
    );
  }
}
