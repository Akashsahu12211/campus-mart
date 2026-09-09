# Flutter Mobile Fixes - Action Items

**Status**: Pending (requires Flutter workspace)

## Fix #1: Remove Debug LAN Host

**File**: `lib/config/api_config.dart`

**Current Issue**:
```dart
const String debugLanCandidate = '192.168.x.x';  // ❌ SECURITY RISK
```

**Problem**: Hardcoded LAN IP exposes internal network configuration in production APK

**Fix**:
```dart
// Remove hardcoded IP completely
// Use only environment configuration via dart-define

class ApiConfig {
  static String getBaseUrl() {
    const String? envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    
    // Fallback to production API
    return 'https://api.campusmart.com';
  }
}
```

**Build Commands**:
```bash
# Development build with local API
flutter build apk --dart-define=API_BASE_URL=http://10.0.2.2:8081

# Production release (no debug URL)
flutter build apk --release
```

---

## Fix #2: Remove CoD UI from Payment Screen

**File**: `lib/pages/payment_screen.dart`

**Current Issue**:
```dart
// Around line 387
PaymentMethodTile(
  label: 'Cash on Delivery (CoD)',
  value: 'COD',
  // ❌ Backend doesn't support this
)
```

**Problem**: UI shows CoD option but backend payment service only supports Razorpay, causing user confusion

**Fix**:
```dart
// Keep only Razorpay as payment method
Column(
  children: [
    PaymentMethodTile(
      label: 'Razorpay Payment',
      value: 'RAZORPAY',
      groupValue: selectedPaymentMethod,
      onChanged: (value) {
        setState(() => selectedPaymentMethod = value);
      },
    ),
    SizedBox(height: 16),
    Text(
      'Secure payment via Razorpay',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    ),
  ],
)
```

**Alternative** (if you want to support CoD in future):
```dart
// Make CoD option conditional based on backend capability
if (PaymentService.isPaymentMethodSupported('COD')) {
  PaymentMethodTile(
    label: 'Cash on Delivery (CoD)',
    value: 'COD',
  );
}

PaymentMethodTile(
  label: 'Razorpay Payment',
  value: 'RAZORPAY',
)
```

---

## Deployment Instructions for Flutter

### Before Release
1. ✅ Remove debug LAN host
2. ✅ Remove CoD UI
3. Update version in `pubspec.yaml`
4. Run `flutter pub get`
5. Run tests: `flutter test`

### Build for Release
```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build APK with dart-define
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.campusmart.com

# Build App Bundle for Play Store
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.campusmart.com
```

### Upload to Firebase App Distribution
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Authenticate
firebase login

# Build and distribute
flutter build apk --release --dart-define=API_BASE_URL=https://api.campusmart.com
firebase app:distribute lib/build/app/outputs/flutter-app.apk \
  --app-id=<APP_ID> \
  --release-notes='Production release' \
  --testers='qa@campusmart.com'
```

---

## Security Checklist for Mobile

Before going to production, verify:
- ✅ No hardcoded IPs or URLs (except production API)
- ✅ No debug logging with sensitive data
- ✅ ProGuard/R8 obfuscation enabled
- ✅ Certificate pinning for API calls
- ✅ No API keys exposed in app
- ✅ Permissions follow least-privilege principle
- ✅ Sensitive data encrypted with flutter_secure_storage
- ✅ All warnings resolved

---

**Expected Completion**: Same release cycle as backend/frontend
**Estimated Time**: 30 minutes (search & replace + testing)
**Priority**: P0 - Security risk if shipped with hardcoded debug host
