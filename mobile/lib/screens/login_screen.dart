import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/site_settings_provider.dart';
import '../services/api_service.dart';
import '../services/social_auth_service.dart';
import '../utils/validators.dart';
import '../widgets/brand_mark.dart';
import '../widgets/custom_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _api = ApiService();
  final _socialAuth = SocialAuthService();
  bool _loading = false;
  bool _showPass = false;
  String _socialLoading = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SiteSettingsProvider>().refreshSettings();
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final student = await _api.login(_emailCtrl.text, _passCtrl.text);
      if (!mounted) return;
      await authProvider.login(student);
      navigator.pushReplacementNamed('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _socialLogin(String provider) async {
    final authProvider = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    setState(() {
      _socialLoading = provider;
      _error = null;
    });
    try {
      final payload = provider == 'GOOGLE'
          ? await _socialAuth.signInWithGoogle()
          : await _socialAuth.signInWithFacebook();
      final student = await _api.socialLogin(
        idToken: payload['idToken']!,
        provider: payload['provider']!,
      );
      if (!mounted) return;
      await authProvider.login(student);
      navigator.pushReplacementNamed('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) {
      setState(() => _socialLoading = '');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 780;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!compact)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 28),
                            child: _heroPanel(),
                          ),
                        ),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: _loginCard(),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.24)),
          ),
          child: const Text(
            'CAMPUS MARKETPLACE',
            style: TextStyle(
              color: Color(0xFFC7BFFF),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Secure sign-in for students, sellers, and admins',
          style: TextStyle(
            color: AppTheme.textPrim,
            fontSize: 42,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Access listings, orders, support tickets, and safer campus marketplace tools from one professional account flow.',
          style: TextStyle(
            color: AppTheme.textSec,
            height: 1.7,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 22),
        ...[
          'Password login, social login, OTP verification, and support tracking stay connected.',
          'Google and Facebook login are only for students who already registered with the same email.',
          'The same account works across web, app, support, and admin-safe workflows.',
        ].map(
          (point) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              point,
              style: const TextStyle(
                color: Color(0xFFC9D2EC),
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loginCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 44,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accent, AppTheme.accent2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: BrandMark(size: 38),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Welcome Back',
            style: TextStyle(
              color: AppTheme.textPrim,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in with your password or a trusted provider',
            style: TextStyle(color: AppTheme.textSec, fontSize: 14),
          ),
          const SizedBox(height: 26),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF9B9B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  label: 'Email Address',
                  hint: 'you@example.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                AppTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passCtrl,
                  obscure: !_showPass,
                  validator: Validators.password,
                  suffix: TextButton(
                    onPressed: () => setState(() => _showPass = !_showPass),
                    child: Text(
                      _showPass ? 'Hide' : 'Show',
                      style: const TextStyle(
                        color: AppTheme.accentH,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Sign In',
                  icon: Icons.lock_open_rounded,
                  loading: _loading,
                  onPressed: _login,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: AppTheme.border)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR CONTINUE WITH',
                  style: TextStyle(
                    color: AppTheme.textSec,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Expanded(child: Container(height: 1, color: AppTheme.border)),
            ],
          ),
          const SizedBox(height: 14),
          _socialButton(
            label: _socialLoading == 'GOOGLE'
                ? 'Connecting Google...'
                : 'Continue with Google',
            hint: 'Registered users only',
            foreground: const Color(0xFF0F172A),
            background: const Color(0xFFF8FAFC),
            iconBackground: Colors.white,
            iconForeground: const Color(0xFFEA4335),
            iconText: 'G',
            onPressed:
                _socialLoading.isNotEmpty ? null : () => _socialLogin('GOOGLE'),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.24),
              ),
            ),
            child: const Text(
              'Google sign-in only works for already registered students. Facebook sign-in in the Flutter app will be enabled after full Android setup is completed.',
              style: TextStyle(
                color: Color(0xFFFDE68A),
                fontSize: 12.5,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/forgot-password'),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: AppTheme.accentH,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(color: AppTheme.muted),
              ),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(
                  context,
                  '/register',
                ),
                child: const Text(
                  'Register',
                  style: TextStyle(
                    color: AppTheme.accentH,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required String hint,
    required Color foreground,
    required Color background,
    required Color iconBackground,
    required Color iconForeground,
    required String iconText,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          return ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              elevation: 0,
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: iconBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              iconText,
                              style: TextStyle(
                                color: iconForeground,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: foreground.withValues(alpha: 0.74),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: iconBackground,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                iconText,
                                style: TextStyle(
                                  color: iconForeground,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          hint,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: foreground.withValues(alpha: 0.74),
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
