// lib/screens/otp_verification_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String otpType; // 'EMAIL' or 'PHONE'
  final String contact; // Email or phone number
  final Function(bool) onVerificationSuccess;

  const OtpVerificationScreen({
    Key? key,
    required this.otpType,
    required this.contact,
    required this.onVerificationSuccess,
  }) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _apiService = ApiService();

  late int _timer;
  late int _maxTimer;
  bool _loading = false;
  String _error = '';
  String _success = '';

  @override
  void initState() {
    super.initState();
    _maxTimer = 300; // 5 minutes
    _timer = _maxTimer;
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(Duration(seconds: 1), () {
      if (_timer > 0 && mounted) {
        setState(() => _timer--);
        _startTimer();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() => _error = 'Please enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await _apiService.verifyOtp(
        otp: _otpController.text,
        type: widget.otpType,
      );

      setState(() => _success = 'OTP verified successfully!');
      widget.onVerificationSuccess(true);

      // Navigate after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _loading = true);
    try {
      await _apiService.resendOtp(widget.otpType);
      setState(() {
        _success = 'OTP resent successfully!';
        _timer = _maxTimer;
        _otpController.clear();
      });
      _startTimer();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Header Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B4BFF).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF5B4BFF),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Verify ${widget.otpType == 'EMAIL' ? 'Email' : 'Phone'}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  "We've sent a 6-digit code to ${widget.contact}",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFA0AEC0),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // OTP Input
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF2D3748)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _otpController,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5B4BFF),
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: const TextStyle(
                        color: Color(0xFF2D3748),
                        letterSpacing: 8,
                      ),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: const Color(0xFF1A1F2E),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length == 6) {
                        // Auto-focus out to show keyboard dismiss
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_error.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFFCA5A5)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error,
                            style: const TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Success Message
                if (_success.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Color(0xFF86EFAC)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _success,
                            style: const TextStyle(
                              color: Color(0xFF86EFAC),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Timer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2D3748)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Expires in ${_formatTime(_timer)}',
                        style: const TextStyle(
                          color: Color(0xFFA0AEC0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_timer == 0)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'OTP has expired. Click Resend below.',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_loading ||
                            _otpController.text.length != 6 ||
                            _timer == 0)
                        ? null
                        : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B4BFF),
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _loading ? 'Verifying...' : 'Verify OTP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Resend Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: (_loading || _timer > 240) ? null : _resendOtp,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF5B4BFF)),
                      disabledForegroundColor: Colors.grey.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: (_loading || _timer > 240)
                            ? Colors.grey
                            : const Color(0xFF5B4BFF),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Help Text
                Text(
                  "Didn't get the code? Check your spam folder or try resending.",
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}
