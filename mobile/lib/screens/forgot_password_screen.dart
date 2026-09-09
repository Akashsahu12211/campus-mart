import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = ApiService();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  bool _loading = false;
  bool _requested = false;
  String _message = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final response = await _api.requestForgotPassword(_emailCtrl.text.trim());
      setState(() {
        _requested = true;
        _message = response['message']?.toString() ?? 'OTP sent';
      });
    } catch (e) {
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    }
    setState(() => _loading = false);
  }

  Future<void> _resetPassword() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final response = await _api.resetForgotPassword(
        email: _emailCtrl.text.trim(),
        otp: _otpCtrl.text.trim(),
        newPassword: _newPasswordCtrl.text,
      );
      setState(() => _message = response['message']?.toString() ?? 'Password reset successful');
    } catch (e) {
      setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    }
    setState(() => _loading = false);
  }

  InputDecoration _decoration(String hint) => InputDecoration(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(title: const Text('Forgot Password')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Email OTP ke through password reset karo.',
            style: TextStyle(color: Color(0xFF94A3B8), height: 1.6),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _decoration('Registered email'),
          ),
          if (_requested) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otpCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Email OTP'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('New password'),
            ),
          ],
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _message,
              style: TextStyle(
                color: _message.toLowerCase().contains('successful') || _message.toLowerCase().contains('sent')
                    ? const Color(0xFF00D4AA)
                    : const Color(0xFFEF4444),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : (_requested ? _resetPassword : _requestOtp),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B4BFF),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _loading ? 'Please wait...' : (_requested ? 'Reset Password' : 'Send Reset OTP'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
