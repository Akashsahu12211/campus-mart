import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/site_settings_provider.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../widgets/brand_mark.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = ApiService();

  // Steps: form → email_otp → phone_otp → success
  String _step       = 'form';
  String? _sessionId;
  String _maskedEmail = '';
  String _maskedPhone = '';
  String _devOtp      = '';
  bool   _loading     = false;
  String _msg         = '';
  bool   _msgSuccess  = false;
  int    _resendTimer = 0;

  // Form controllers
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  bool  _showPw       = false;

  // OTP controllers
  final List<TextEditingController> _emailOtpCtrl = List.generate(6, (_) => TextEditingController());
  final List<TextEditingController> _phoneOtpCtrl = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _emailFocus = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _phoneFocus = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SiteSettingsProvider>().refreshSettings();
    });
  }

  @override
  void dispose() {
    for (final c in [..._emailOtpCtrl, ..._phoneOtpCtrl]) c.dispose();
    for (final f in [..._emailFocus,   ..._phoneFocus])   f.dispose();
    super.dispose();
  }

  String get _emailOtp => _emailOtpCtrl.map((c) => c.text).join();
  String get _phoneOtp => _phoneOtpCtrl.map((c) => c.text).join();

  int _pwStrength(String pw) {
    int s = 0;
    if (pw.length >= 6)                              s++;
    if (pw.length >= 10)                             s++;
    if (RegExp(r'[A-Z]').hasMatch(pw))              s++;
    if (RegExp(r'[0-9]').hasMatch(pw))              s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw))       s++;
    return s;
  }

  void _startTimer() {
    setState(() => _resendTimer = 30);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendTimer--);
      return _resendTimer > 0;
    });
  }

  void _showMsg(String text, {bool success = false}) =>
      setState(() { _msg = text; _msgSuccess = success; });

  // ── Register ──
  Future<void> _register() async {
    if (_passwordCtrl.text != _confirmCtrl.text) { _showMsg('Passwords do not match'); return; }
    setState(() { _loading = true; _msg = ''; });
    try {
      final res = await _api.registerUser(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      setState(() {
        _sessionId   = res['sessionId']?.toString();
        _maskedEmail = (res['email'] ?? '').toString();
        _step        = 'email_otp';
      });
      _showMsg('OTP sent to $_maskedEmail', success: true);
      _startTimer();
    } catch (e) {
      _showMsg(e.toString());
    } finally { setState(() => _loading = false); }
  }

  // ── Verify Email OTP ──
  Future<void> _verifyEmail() async {
    if (_emailOtp.length != 6) { _showMsg('Enter 6-digit OTP'); return; }
    setState(() { _loading = true; _msg = ''; });
    try {
      final res = await _api.verifyEmailOtp(
        sessionId: _sessionId ?? '',
        otp: _emailOtp,
      );
      setState(() {
        _maskedPhone = (res['maskedPhone'] ?? res['phone'] ?? '').toString();
        _devOtp      = (res['devPhoneOtp'] ?? '').toString();
        _step        = 'phone_otp';
      });
      _showMsg('Email verified! OTP sent to your phone.', success: true);
      _startTimer();
    } catch (e) {
      _showMsg(e.toString());
    } finally { setState(() => _loading = false); }
  }

  // ── Verify Phone OTP ──
  Future<void> _verifyPhone() async {
    if (_phoneOtp.length != 6) { _showMsg('Enter 6-digit OTP'); return; }
    setState(() { _loading = true; _msg = ''; });
    try {
      final res = await _api.verifyPhoneOtp(
        sessionId: _sessionId ?? '',
        otp: _phoneOtp,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('campusmart_user',  jsonEncode(res['student']));
      await prefs.setInt('campusmart_user_id', res['student']['id'] as int);
      await PushNotificationService.instance.syncTokenForUser(res['student']['id'] as int);
      setState(() => _step = 'success');
    } catch (e) {
      _showMsg(e.toString());
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B14),
        elevation: 0,
        leading: _step != 'form' && _step != 'success'
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => setState(() { _step = _step == 'phone_otp' ? 'email_otp' : 'form'; _msg = ''; }),
        )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            _buildLogo(),
            const SizedBox(height: 16),
            _buildProgressBar(),
            const SizedBox(height: 28),

            if (_step == 'form')       _buildFormStep(),
            if (_step == 'email_otp')  _buildEmailOtpStep(),
            if (_step == 'phone_otp')  _buildPhoneOtpStep(),
            if (_step == 'success')    _buildSuccessStep(),
          ]),
        ),
      ),
    );
  }

  Widget _buildLogo() => Column(children: [
    Container(
      width: 64, height: 64, decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(colors: [Color(0xFF5B4BFF), Color(0xFF00D4AA)]),
    ),
      child: const Center(child: BrandMark(size: 38)),
    ),
    const SizedBox(height: 10),
    const Text('Campus Mart', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
    const Text('College Student Marketplace', style: TextStyle(fontSize: 12, color: Color(0xFF718096))),
  ]);

  Widget _buildProgressBar() {
    final steps = [
      {'key': 'form',      'icon': '📝', 'label': 'Details'},
      {'key': 'email_otp', 'icon': '📧', 'label': 'Email'},
      {'key': 'phone_otp', 'icon': '📱', 'label': 'Phone'},
      {'key': 'success',   'icon': '✅', 'label': 'Done'},
    ];
    final cur = steps.indexWhere((s) => s['key'] == _step);
    return Row(children: steps.asMap().entries.expand((entry) {
      final i = entry.key; final s = entry.value;
      final active = i <= cur;
      return [
        Expanded(child: Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? const Color(0xFF5B4BFF) : const Color(0xFF1E2438),
              border: Border.all(color: active ? const Color(0xFF5B4BFF) : const Color(0xFF2A3550), width: 2),
            ),
            child: Center(child: Text(i < cur ? '✓' : s['icon']!, style: const TextStyle(fontSize: 14))),
          ),
          const SizedBox(height: 4),
          Text(s['label']!, style: TextStyle(fontSize: 10, color: active ? const Color(0xFFA0AEC0) : const Color(0xFF4A5568))),
        ])),
        if (i < steps.length - 1)
          Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 16), color: i < cur ? const Color(0xFF5B4BFF) : const Color(0xFF1E2438))),
      ];
    }).toList());
  }

  Widget _buildFormStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Create Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
    const SizedBox(height: 20),
    _field('Full Name', _nameCtrl, hint: 'Your full name', icon: Icons.person_outline),
    _field('Email', _emailCtrl, hint: 'your@email.com', icon: Icons.email_outlined, type: TextInputType.emailAddress),
    _buildPasswordField(),
    _field('Confirm Password', _confirmCtrl, hint: 'Re-enter password', icon: Icons.lock_outlined, obscure: true),
    _field('Phone Number', _phoneCtrl, hint: '10-digit mobile number', icon: Icons.phone_outlined, type: TextInputType.phone),
    if (_msg.isNotEmpty) _msgBox(),
    const SizedBox(height: 8),
    _button(_loading ? 'Creating Account...' : 'Create Account', _loading ? null : _register),
    const SizedBox(height: 16),
    Center(child: TextButton(
      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
      child: const Text('Already have an account? Login', style: TextStyle(color: Color(0xFF5B4BFF))),
    )),
  ]);

  Widget _buildPasswordField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Password', style: TextStyle(fontSize: 12, color: Color(0xFFA0AEC0), fontWeight: FontWeight.w600)),
    const SizedBox(height: 5),
    TextField(
      controller: _passwordCtrl, obscureText: !_showPw,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Min 6 chars + number', hintStyle: const TextStyle(color: Color(0xFF4A5568)),
        prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF718096), size: 20),
        suffixIcon: IconButton(icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF718096), size: 20), onPressed: () => setState(() => _showPw = !_showPw)),
        filled: true, fillColor: const Color(0xFF080B14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E2438))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E2438))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF5B4BFF))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    if (_passwordCtrl.text.isNotEmpty) ...[
      const SizedBox(height: 8),
      Row(children: List.generate(5, (i) {
        final s = _pwStrength(_passwordCtrl.text);
        Color c = i < s ? (s <= 2 ? const Color(0xFFEF4444) : s <= 3 ? const Color(0xFFF6AD55) : const Color(0xFF00D4AA)) : const Color(0xFF1E2438);
        return Expanded(child: Container(height: 4, margin:  EdgeInsets.only(right: i < 4 ? 4 : 0), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))));
      })),
      const SizedBox(height: 4),
      Text(['', 'Weak', 'Weak', 'Fair', 'Strong', 'Very Strong'][_pwStrength(_passwordCtrl.text)], style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
    ],
    const SizedBox(height: 14),
  ]);

  Widget _buildEmailOtpStep() => Column(children: [
    const Text('📧', style: TextStyle(fontSize: 52)),
    const SizedBox(height: 12),
    const Text('Verify Email', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
    const SizedBox(height: 8),
    Text('OTP sent to $_maskedEmail', style: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 14), textAlign: TextAlign.center),
    const Text('Valid for 10 minutes', style: TextStyle(color: Color(0xFF718096), fontSize: 12)),
    const SizedBox(height: 24),
    _otpBoxes(_emailOtpCtrl, _emailFocus),
    if (_msg.isNotEmpty) _msgBox(),
    const SizedBox(height: 16),
    _button(_loading ? 'Verifying...' : 'Verify Email', _loading ? null : _verifyEmail),
    const SizedBox(height: 14),
    _resendButton(() async {
      try {
        await _api.resendEmailOtp(sessionId: _sessionId ?? '');
        _startTimer(); _showMsg('New OTP sent!', success: true);
      } catch (e) { _showMsg(e.toString()); }
    }),
  ]);

  Widget _buildPhoneOtpStep() => Column(children: [
    const Text('📱', style: TextStyle(fontSize: 52)),
    const SizedBox(height: 12),
    const Text('Verify Phone', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
    const SizedBox(height: 8),
    Text('OTP sent to $_maskedPhone', style: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 14), textAlign: TextAlign.center),
    if (_devOtp.isNotEmpty) ...[
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF00D4AA).withOpacity(0.1), border: Border.all(color: const Color(0xFF00D4AA)), borderRadius: BorderRadius.circular(8)),
        child: Text('🔧 Dev OTP: $_devOtp', style: const TextStyle(color: Color(0xFF00D4AA), fontWeight: FontWeight.w700)),
      ),
    ],
    const SizedBox(height: 24),
    _otpBoxes(_phoneOtpCtrl, _phoneFocus),
    if (_msg.isNotEmpty) _msgBox(),
    const SizedBox(height: 16),
    _button(_loading ? 'Verifying...' : 'Verify Phone', _loading ? null : _verifyPhone),
    const SizedBox(height: 14),
    _resendButton(() async {
      try {
        final r = await _api.resendPhoneOtp(sessionId: _sessionId ?? '');
        if (r['devPhoneOtp'] != null) setState(() => _devOtp = r['devPhoneOtp'].toString());
        _startTimer(); _showMsg('New OTP sent!', success: true);
      } catch (e) { _showMsg(e.toString()); }
    }),
  ]);

  Widget _buildSuccessStep() => Column(children: [
    const SizedBox(height: 20),
    const Text('🎉', style: TextStyle(fontSize: 72)),
    const SizedBox(height: 16),
    const Text('Account Verified!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF00D4AA))),
    const SizedBox(height: 8),
    const Text('Welcome to Campus Mart!\nYour account is now active.', style: TextStyle(color: Color(0xFFA0AEC0), fontSize: 14), textAlign: TextAlign.center),
    const SizedBox(height: 32),
    _button('Start Exploring →', () => Navigator.pushReplacementNamed(context, '/')),
  ]);

  Widget _otpBoxes(List<TextEditingController> ctrls, List<FocusNode> foci) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = ((constraints.maxWidth - 40) / 6).clamp(42.0, 46.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            6,
            (i) => Container(
              width: boxWidth,
              height: 54,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: TextField(
                controller: ctrls[i], focusNode: foci[i],
                textAlign: TextAlign.center, keyboardType: TextInputType.number,
                maxLength: 1, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) FocusScope.of(context).requestFocus(foci[i + 1]);
                  if (v.isEmpty && i > 0)   FocusScope.of(context).requestFocus(foci[i - 1]);
                  setState(() {});
                },
                decoration: InputDecoration(
                  counterText: '', contentPadding: EdgeInsets.zero,
                  filled: true, fillColor: const Color(0xFF0F1320),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ctrls[i].text.isNotEmpty ? const Color(0xFF5B4BFF) : const Color(0xFF1E2438), width: 2)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ctrls[i].text.isNotEmpty ? const Color(0xFF5B4BFF) : const Color(0xFF1E2438), width: 2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF5B4BFF), width: 2)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _resendButton(VoidCallback onTap) => _resendTimer > 0
      ? Text('Resend OTP in ${_resendTimer}s', style: const TextStyle(color: Color(0xFF718096), fontSize: 13))
      : TextButton(onPressed: onTap, child: const Text('Resend OTP', style: TextStyle(color: Color(0xFF5B4BFF), fontWeight: FontWeight.w700)));

  Widget _field(String label, TextEditingController ctrl, {String hint = '', IconData? icon, TextInputType? type, bool obscure = false}) =>
      Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFFA0AEC0), fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl, keyboardType: type, obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(color: Color(0xFF4A5568)),
            prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF718096), size: 20) : null,
            filled: true, fillColor: const Color(0xFF080B14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E2438))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E2438))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF5B4BFF))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]));

  Widget _button(String text, VoidCallback? onPressed) => SizedBox(width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5B4BFF), foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          disabledBackgroundColor: const Color(0xFF3730A3),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ));

  Widget _msgBox() => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: (_msgSuccess ? const Color(0xFF00D4AA) : const Color(0xFFEF4444)).withOpacity(0.1),
      border: Border.all(color: _msgSuccess ? const Color(0xFF00D4AA) : const Color(0xFFEF4444)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(_msg, style: TextStyle(fontSize: 12, color: _msgSuccess ? const Color(0xFF00D4AA) : const Color(0xFFEF4444))),
  );
}
