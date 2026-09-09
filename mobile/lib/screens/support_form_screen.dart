import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/support_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

enum SupportFormMode { feedback, problem, contact }

class SupportFormScreen extends StatefulWidget {
  const SupportFormScreen({
    super.key,
    required this.mode,
  });

  final SupportFormMode mode;

  @override
  State<SupportFormScreen> createState() => _SupportFormScreenState();
}

class _SupportFormScreenState extends State<SupportFormScreen> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  bool _saving = false;
  String _status = '';
  String _category = '';
  Map<String, dynamic> _siteSettings = {};

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text = user?.name ?? '';
    _emailCtrl.text = user?.email ?? '';
    _category = _categories.first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSiteSettings());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
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

  List<String> get _categories {
    switch (widget.mode) {
      case SupportFormMode.feedback:
        return const [
          'UX',
          'Performance',
          'Feature Request',
          'Trust & Safety',
          'Admin Experience',
        ];
      case SupportFormMode.problem:
        return const ['Bug', 'Login', 'Payment', 'Listing', 'Chat', 'Admin'];
      case SupportFormMode.contact:
        return const ['General', 'Support', 'Business', 'Campus Rollout'];
    }
  }

  String get _title {
    switch (widget.mode) {
      case SupportFormMode.feedback:
        return 'Tell us what should become better next';
      case SupportFormMode.problem:
        return 'Something broken, confusing, or risky?';
      case SupportFormMode.contact:
        return 'Talk to the team behind Campus Mart';
    }
  }

  String get _eyebrow {
    switch (widget.mode) {
      case SupportFormMode.feedback:
        return 'Feedback';
      case SupportFormMode.problem:
        return 'Report a Problem';
      case SupportFormMode.contact:
        return 'Contact & Support';
    }
  }

  String get _description {
    switch (widget.mode) {
      case SupportFormMode.feedback:
        return 'Aap product quality, speed, trust, UI, admin flow, and feature ideas par direct feedback bhej sakte ho.';
      case SupportFormMode.problem:
        return 'Bug, payment issue, login problem, listing glitch, ya trust concern ho to yahan se directly escalate karo.';
      case SupportFormMode.contact:
        return 'Product issue, business query, campus rollout, ya support escalation ke liye direct message bhejo.';
    }
  }

  String get _submitLabel {
    switch (widget.mode) {
      case SupportFormMode.feedback:
        return 'Submit Feedback';
      case SupportFormMode.problem:
        return 'Submit Problem Report';
      case SupportFormMode.contact:
        return 'Send Message';
    }
  }

  String get _successMessage {
    switch (widget.mode) {
      case SupportFormMode.feedback:
        return 'Feedback save ho gaya. Team product improvements me consider karegi.';
      case SupportFormMode.problem:
        return 'Problem report receive ho gaya. Isse support panel me track kiya jayega.';
      case SupportFormMode.contact:
        return 'Support team ko message bhej diya gaya hai.';
    }
  }

  String get _pagePath {
    switch (widget.mode) {
      case SupportFormMode.feedback:
        return '/feedback';
      case SupportFormMode.problem:
        return '/report-problem';
      case SupportFormMode.contact:
        return '/contact';
    }
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _status = '';
    });

    final authUser = context.read<AuthProvider>().user;
    final payload = {
      'studentId': authUser?.id,
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'subject': _subjectCtrl.text.trim(),
      'category': _category,
      'message': _messageCtrl.text.trim(),
      'appPlatform': 'flutter',
      'pagePath': _pagePath,
    };

    try {
      switch (widget.mode) {
        case SupportFormMode.feedback:
          await _api.submitFeedback(payload);
          break;
        case SupportFormMode.problem:
          await _api.submitProblemReport(payload);
          break;
        case SupportFormMode.contact:
          await _api.submitContactMessage(payload);
          break;
      }

      setState(() {
        _status = _successMessage;
        _subjectCtrl.clear();
        _messageCtrl.clear();
      });
    } catch (e) {
      setState(() => _status = e.toString().replaceFirst('Exception: ', ''));
    }

    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final supportEmail = _settingOr('supportEmail', SupportConfig.supportEmail);
    final businessEmail =
        _settingOr('businessEmail', SupportConfig.businessEmail);
    final supportHours =
        _settingOr('supportHours', SupportConfig.responseWindow);
    final officeAddress = _settingOr(
      'officeAddress',
      'Add your startup office or campus support address here.',
    );
    final whatsappNumber =
        _settingOr('supportWhatsappNumber', SupportConfig.whatsappNumber);

    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(title: Text(_eyebrow)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(),
          const SizedBox(height: 16),
          if (widget.mode == SupportFormMode.contact) ...[
            _infoCard('Email Support', supportEmail),
            _infoCard(
              'WhatsApp',
              whatsappNumber.isEmpty
                  ? 'Configured on deploy'
                  : '+$whatsappNumber',
            ),
            _infoCard('Business', businessEmail),
            _infoCard('Response Window', supportHours),
            _infoCard('Office Address', officeAddress),
            const SizedBox(height: 16),
          ],
          _textField(_nameCtrl, 'Your name'),
          const SizedBox(height: 12),
          _textField(_emailCtrl, 'Your email'),
          const SizedBox(height: 12),
          _textField(
            _subjectCtrl,
            widget.mode == SupportFormMode.problem ? 'Issue title' : 'Subject',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: _inputDecoration('Category'),
            dropdownColor: const Color(0xFF111728),
            items: _categories
                .map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _category = value ?? _category);
            },
          ),
          const SizedBox(height: 12),
          _textField(
            _messageCtrl,
            widget.mode == SupportFormMode.problem
                ? 'What happened, where it happened, and how we can reproduce it?'
                : widget.mode == SupportFormMode.feedback
                    ? 'What did you like, what felt weak, and what would make this feel startup-grade?'
                    : 'How can we help?',
            maxLines: 7,
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _status,
              style: TextStyle(
                color: _status == _successMessage
                    ? const Color(0xFF00D4AA)
                    : const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4BFF),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _saving ? 'Submitting...' : _submitLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2440), Color(0xFF0F1320)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF2A3558)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _eyebrow,
            style: const TextStyle(
              color: Color(0xFF8EA0D8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _description,
            style: const TextStyle(color: Color(0xFFB6BFD8), height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value) {
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
          Text(
            label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 6),
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

  Widget _textField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
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
}
