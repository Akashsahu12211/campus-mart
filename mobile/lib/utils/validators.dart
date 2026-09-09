// lib/utils/validators.dart

class Validators {
  static final _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');

  static String? name(String? val) {
    if (val == null || val.trim().isEmpty) return 'Name is required.';
    if (val.trim().length < 2) return 'Name must be at least 2 characters.';
    return null;
  }

  static String? email(String? val) {
    if (val == null || val.trim().isEmpty) return 'Email is required.';
    if (!_emailRegex.hasMatch(val.trim())) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? val) {
    if (val == null || val.isEmpty) return 'Password is required.';
    if (val.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  static String? confirmPassword(String? val, String original) {
    if (val == null || val.isEmpty) return 'Please confirm your password.';
    if (val != original) return 'Passwords do not match.';
    return null;
  }

  static String? price(String? val) {
    if (val == null || val.isEmpty) return 'Price is required.';
    final n = double.tryParse(val);
    if (n == null || n <= 0) return 'Enter a valid price.';
    return null;
  }

  static String? required(String? val, [String field = 'This field']) {
    if (val == null || val.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String passwordStrength(String password) {
    if (password.length < 4) return 'Too weak';
    if (password.length < 6) return 'Weak';
    if (password.length < 10) return 'Good';
    return 'Strong';
  }
}
