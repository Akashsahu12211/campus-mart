import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/social_links.dart';
import '../config/support_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class SupportHubScreen extends StatefulWidget {
  const SupportHubScreen({super.key});

  @override
  State<SupportHubScreen> createState() => _SupportHubScreenState();
}

class _SupportHubScreenState extends State<SupportHubScreen> {
  final _api = ApiService();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _mode = 'feedback';
  String _category = 'UX';
  bool _submitting = false;
  String _status = '';
  Map<String, dynamic> _siteSettings = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSiteSettings());
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSiteSettings() async {
    try {
      final data = await _api.getPublicSiteSettings();
      if (!mounted) return;
      setState(() => _siteSettings = data);
    } catch (_) {}
  }

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() {
      _submitting = true;
      _status = '';
    });

    try {
      final payload = {
        'studentId': user.id,
        'name': user.name,
        'email': user.email,
        'subject': _subjectCtrl.text.trim(),
        'category': _category,
        'message': _messageCtrl.text.trim(),
        'appPlatform': 'flutter',
        'pagePath': '/support-hub',
      };

      if (_mode == 'feedback') {
        await _api.submitFeedback(payload);
      } else if (_mode == 'problem') {
        await _api.submitProblemReport(payload);
      } else {
        await _api.submitContactMessage(payload);
      }

      setState(() {
        _status = 'Request submitted successfully';
        _subjectCtrl.clear();
        _messageCtrl.clear();
      });
    } catch (e) {
      setState(() {
        _status = e.toString().replaceFirst('Exception: ', '');
      });
    }

    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isProblem = _mode == 'problem';

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        title: const Text('Support & Legal'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(),
          const SizedBox(height: 16),
          _linkActionCard(
            title: 'My Support Tickets',
            text:
                'Track feedback, bug reports, and contact requests with ticket status.',
            onTap: () => Navigator.pushNamed(context, '/support-tickets'),
          ),
          _linkActionCard(
            title: 'About Campus Mart',
            text:
                'Student-first marketplace for trusted campus buying and selling.',
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),
          _linkActionCard(
            title: 'Help Center',
            text:
                'Quick answers for account, listings, payments, trust, and support topics.',
            onTap: () => Navigator.pushNamed(context, '/help'),
          ),
          _linkActionCard(
            title: 'FAQ',
            text:
                'Common product, support, and transaction questions with direct answers.',
            onTap: () => Navigator.pushNamed(context, '/faq'),
          ),
          _linkActionCard(
            title: 'Privacy Policy',
            text:
                'We store account, listing, support, and transaction data only for product operations and safety.',
            onTap: () => Navigator.pushNamed(context, '/legal', arguments: {
              'title': 'Privacy Policy',
              'intro': _settingOr(
                'privacyPolicyContent',
                'We store account, listing, support, and transaction data only for product operations and safety.',
              ),
              'sections': [
                {
                  'title': 'Information We Collect',
                  'body':
                      'Account details, listing content, transaction metadata, support requests, reports, and notification tokens where enabled.'
                },
                {
                  'title': 'Why We Use It',
                  'body':
                      'To run listings, secure access, enable communication, detect abuse, and improve product safety.'
                },
              ],
            }),
          ),
          _linkActionCard(
            title: 'Terms & Conditions',
            text:
                'Fake listings, abuse, impersonation, and unsafe marketplace behavior are not allowed.',
            onTap: () => Navigator.pushNamed(context, '/legal', arguments: {
              'title': 'Terms & Conditions',
              'intro': _settingOr(
                'termsContent',
                'Fake listings, abuse, impersonation, and unsafe marketplace behavior are not allowed.',
              ),
              'sections': [
                {
                  'title': 'Marketplace Conduct',
                  'body':
                      'Users must not post fake, stolen, or misleading listings and must avoid harassment, spam, and fraud.'
                },
                {
                  'title': 'Moderation Rights',
                  'body':
                      'Campus Mart may review, hide, or remove listings and suspend accounts to protect the community.'
                },
              ],
            }),
          ),
          _linkActionCard(
            title: 'Community Guidelines',
            text:
                'Respect users, post truthful listings, and use reporting tools whenever something feels unsafe.',
            onTap: () => Navigator.pushNamed(context, '/community-guidelines'),
          ),
          _linkActionCard(
            title: 'Refund Policy',
            text:
                'Understand disputes, escrow release, and when refunds may apply.',
            onTap: () => Navigator.pushNamed(context, '/legal', arguments: {
              'title': 'Refund Policy',
              'intro': _settingOr(
                'refundPolicyContent',
                'Refunds depend on payment state, dispute review, and delivery evidence.',
              ),
              'sections': [
                {
                  'title': 'When refunds may apply',
                  'body':
                      'Duplicate payments, failed delivery, fraud indicators, or approved disputes can qualify.'
                },
                {
                  'title': 'Review process',
                  'body':
                      'Support and admin teams review payment timeline, user actions, and issue evidence before deciding.'
                },
              ],
            }),
          ),
          _linkActionCard(
            title: 'Cookie Policy',
            text:
                'See how the app stores session, notification, and preference state.',
            onTap: () => Navigator.pushNamed(context, '/legal', arguments: {
              'title': 'Cookie Policy',
              'intro': _settingOr(
                'cookiePolicyContent',
                'Campus Mart stores lightweight session and preference data for smoother product behavior.',
              ),
              'sections': [
                {
                  'title': 'Stored data',
                  'body':
                      'Login session, language, notifications, and product preferences may be cached locally.'
                },
                {
                  'title': 'Your control',
                  'body':
                      'You can log out, clear storage, or change product settings anytime.'
                },
              ],
            }),
          ),
          _linkActionCard(
            title: 'Disclaimer',
            text:
                'Campus Mart enables listings and moderation, but users remain responsible for safe transactions.',
            onTap: () => Navigator.pushNamed(context, '/legal', arguments: {
              'title': 'Disclaimer',
              'intro': _settingOr(
                'disclaimerContent',
                'The marketplace helps students discover items and communicate, but does not guarantee every listing or meetup outcome.',
              ),
              'sections': [
                {
                  'title': 'Seller responsibility',
                  'body':
                      'Sellers must post truthful, lawful, and accurate listings.'
                },
                {
                  'title': 'Buyer responsibility',
                  'body':
                      'Buyers should verify condition, price, and safety before completing a transaction.'
                },
              ],
            }),
          ),
          _contactCard(),
          const SizedBox(height: 16),
          _socialCard(),
          const SizedBox(height: 16),
          _sectionTitle('Dedicated Support Pages'),
          _linkActionCard(
            title: 'Feedback',
            text:
                'Share product quality, UX, performance, trust, and feature suggestions in a dedicated form.',
            onTap: () => Navigator.pushNamed(context, '/feedback'),
          ),
          _linkActionCard(
            title: 'Report a Problem',
            text:
                'Escalate bugs, payment issues, login problems, listing glitches, or trust concerns.',
            onTap: () => Navigator.pushNamed(context, '/report-problem'),
          ),
          _linkActionCard(
            title: 'Contact Support',
            text:
                'Send a direct support or business message with contact details and response expectations.',
            onTap: () => Navigator.pushNamed(context, '/contact'),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Contact & Feedback'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _modeChip('feedback', 'Feedback'),
              _modeChip('problem', 'Report Problem'),
              _modeChip('contact', 'Contact'),
            ],
          ),
          const SizedBox(height: 14),
          _textField(_subjectCtrl, 'Subject'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: _inputDecoration('Category'),
            dropdownColor: const Color(0xFF111728),
            items: (isProblem
                    ? ['Bug', 'Login', 'Payment', 'Listing', 'Chat', 'Admin']
                    : [
                        'UX',
                        'Performance',
                        'Feature Request',
                        'Trust & Safety',
                        'General'
                      ])
                .map((value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value,
                          style: const TextStyle(color: Colors.white)),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => _category = value ?? _category);
            },
          ),
          const SizedBox(height: 12),
          _textField(_messageCtrl,
              isProblem ? 'Describe the issue clearly' : 'Share your message',
              maxLines: 6),
          const SizedBox(height: 12),
          if (user != null)
            Text(
              'Signed in as ${user.name} (${user.email})',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _status,
              style: TextStyle(
                color: _status == 'Request submitted successfully'
                    ? const Color(0xFF00D4AA)
                    : const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4BFF),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _submitting ? 'Submitting...' : 'Submit',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2440), Color(0xFF0F1320)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF2A3558)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campus Mart Support',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Feedback, product issues, and support communication ko ek clean place me collect karne ke liye ye hub add kiya gaya hai.',
            style: TextStyle(color: Color(0xFFB6BFD8), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _linkCard({required String title, required String text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(color: Color(0xFF94A3B8), height: 1.5)),
        ],
      ),
    );
  }

  Widget _linkActionCard({
    required String title,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: _linkCard(title: title, text: text),
    );
  }

  Widget _socialCard() {
    final links = _dynamicSocialLinks();
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
          const Text(
            'Social & Community',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Brand handles ready hone par users direct startup updates, product announcements, aur support channels tak pahunch sakte hain.',
            style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
          ),
          const SizedBox(height: 12),
          if (links.isEmpty)
            const Text(
              'Social links can be enabled by admin or at build time.',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          else
            ...links.map((link) => ListTile(
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
                )),
        ],
      ),
    );
  }

  Widget _contactCard() {
    final supportEmail = _settingOr('supportEmail', SupportConfig.supportEmail);
    final businessEmail =
        _settingOr('businessEmail', SupportConfig.businessEmail);
    final whatsappNumber =
        _settingOr('supportWhatsappNumber', SupportConfig.whatsappNumber);
    final whatsappLink = whatsappNumber.isNotEmpty
        ? 'https://wa.me/${whatsappNumber.replaceAll(RegExp(r'\\D'), '')}'
        : SupportConfig.whatsappLink;
    final supportHours =
        _settingOr('supportHours', SupportConfig.responseWindow);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1320),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2438)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Direct Support',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _actionRow('Email Support', supportEmail, 'mailto:$supportEmail'),
          _actionRow('Business', businessEmail, 'mailto:$businessEmail'),
          if (whatsappLink != null && whatsappNumber.isNotEmpty)
            _actionRow('WhatsApp', '+$whatsappNumber', whatsappLink),
          if (whatsappLink == null || whatsappNumber.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'WhatsApp support can be enabled by admin or at build time.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            supportHours,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(String label, String value, String link) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(link);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Color(0xFF5B4BFF), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }

  Widget _modeChip(String value, String label) {
    final active = _mode == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mode = value;
          _category = value == 'problem' ? 'Bug' : 'UX';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF5B4BFF) : const Color(0xFF0F1320),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color:
                  active ? const Color(0xFF5B4BFF) : const Color(0xFF1E2438)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(hint),
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

  String _settingOr(String key, String fallback) {
    final value = (_siteSettings[key] ?? '').toString().trim();
    return value.isEmpty ? fallback : value;
  }

  List<_SupportSocialLink> _dynamicSocialLinks() {
    final dynamicLinks = [
      _SupportSocialLink(
          'Instagram', '@campusmart', _settingOr('instagramUrl', '')),
      _SupportSocialLink(
          'LinkedIn', 'Campus Mart', _settingOr('linkedinUrl', '')),
      _SupportSocialLink(
          'YouTube', 'Campus Mart', _settingOr('youtubeUrl', '')),
      _SupportSocialLink('X / Twitter', '@campusmart', _settingOr('xUrl', '')),
      _SupportSocialLink('GitHub', 'campus-mart', _settingOr('githubUrl', '')),
    ].where((entry) => entry.url.trim().isNotEmpty).toList();

    if (dynamicLinks.isNotEmpty) {
      return dynamicLinks;
    }

    return SocialLinksConfig.enabledLinks
        .map((entry) =>
            _SupportSocialLink(entry.label, entry.shortLabel, entry.url))
        .toList();
  }
}

class _SupportSocialLink {
  const _SupportSocialLink(this.label, this.shortLabel, this.url);

  final String label;
  final String shortLabel;
  final String url;
}
