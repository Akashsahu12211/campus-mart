# Flutter App - Registration Flow Update Guide

## Complete Backend Changes Summary

Your **Spring Boot backend** has been updated to properly handle user registration:

### New Flow (CORRECT):
1. **User fills form** → `/register` endpoint → Creates **RegistrationSession** (temp storage)
   - Returns: `sessionId` (NOT userId)
   - Sends: Email OTP

2. **User enters email OTP** → `/verify-email` endpoint
   - Takes: `sessionId`, `otp`
   - Returns: `sessionId`, `maskedPhone`, `devPhoneOtp`
   - Sends: Phone OTP

3. **User enters phone OTP** → `/verify-phone` endpoint
   - Takes: `sessionId`, `otp`
   - NOW creates **Student** record (isActive=true)
   - Returns: JWT token + student data
   - Deletes: RegistrationSession

### Key Points:
- ✅ User is ONLY saved to database after BOTH OTPs verified
- ✅ Before OTP verification, data is in temporary RegistrationSession table
- ✅ Resend endpoints now take `sessionId` instead of `userId`

## Flutter App Updates Required

### 1. Update `api_service.dart`

Replace userId with sessionId in these methods:

```dart
// REGISTER - Already returns sessionId from backend
Future<Map> registerUser(String name, String email, String password, String phone) async {
  try {
    final response = await dio.post(
      '$baseUrl/auth/register',
      data: {'name': name, 'email': email, 'password': password, 'phone': phone},
    );
    // Backend now returns: { sessionId, nextStep, email }
    return response.data;
  } on DioException catch (e) {
    throw _handleError(e);
  }
}

// VERIFY EMAIL OTP - Update parameter name
Future<Map> verifyEmailOtp(String sessionId, String otp) async {  // Changed from userId
  try {
    final response = await dio.post(
      '$baseUrl/auth/verify-email',
      data: {'sessionId': sessionId, 'otp': otp},  // Changed from userId
    );
    // Backend returns: { message, nextStep, phone, devPhoneOtp }
    return response.data;
  } on DioException catch (e) {
    throw _handleError(e);
  }
}

// VERIFY PHONE OTP - Update parameter name
Future<Map> verifyPhoneOtp(String sessionId, String otp) async {  // Changed from userId
  try {
    final response = await dio.post(
      '$baseUrl/auth/verify-phone',
      data: {'sessionId': sessionId, 'otp': otp},  // Changed from userId
    );
    // Backend returns: { token, student, message, nextStep }
    return response.data;
  } on DioException catch (e) {
    throw _handleError(e);
  }
}

// RESEND EMAIL OTP - Update parameter name
Future<Map> resendEmailOtp(String sessionId) async {  // Changed from userId
  try {
    final response = await dio.post(
      '$baseUrl/auth/resend-email-otp',
      data: {'sessionId': sessionId},  // Changed from userId
    );
    return response.data;
  } on DioException catch (e) {
    throw _handleError(e);
  }
}

// RESEND PHONE OTP - Update parameter name
Future<Map> resendPhoneOtp(String sessionId) async {  // Changed from userId
  try {
    final response = await dio.post(
      '$baseUrl/auth/resend-phone-otp',
      data: {'sessionId': sessionId},  // Changed from userId
    );
    // Backend returns: { message, devPhoneOtp }
    return response.data;
  } on DioException catch (e) {
    throw _handleError(e);
  }
}
```

### 2. Update Registration Screen (e.g., `registration_screen.dart`)

**State Variable:**
```dart
// OLD
String? userId;

// NEW
String? sessionId;
```

**Form Submission:**
```dart
// OLD
final response = await apiService.registerUser(...);
setState(() {
  userId = response['userId'];  // Got userId
  currentStep = 'email_otp';
});

// NEW
final response = await apiService.registerUser(...);
setState(() {
  sessionId = response['sessionId'];  // Get sessionId instead!
  currentStep = 'email_otp';
});
```

**Email OTP Verification:**
```dart
// OLD
await apiService.verifyEmailOtp(userId, emailOtpCode);

// NEW
await apiService.verifyEmailOtp(sessionId, emailOtpCode);
```

**Phone OTP Verification:**
```dart
// OLD
final response = await apiService.verifyPhoneOtp(userId, phoneOtpCode);

// NEW
final response = await apiService.verifyPhoneOtp(sessionId, phoneOtpCode);
// Backend returns JWT token here - save it!
final token = response['token'];
SharedPreferences prefs = await SharedPreferences.getInstance();
prefs.setString('auth_token', token);
```

**Resend OTP Calls:**
```dart
// OLD
await apiService.resendEmailOtp(userId);
await apiService.resendPhoneOtp(userId);

// NEW
await apiService.resendEmailOtp(sessionId);
await apiService.resendPhoneOtp(sessionId);
```

### 3. UI Changes (Optional but Recommended)

To match React UI:
- Form button: "Create Account →" → "Next →"
- Success button: "Start →" → "Done ✓"

### 4. Complete Flow

```
User fills details → sessionId received
      ↓
User enters email OTP → Email verified
      ↓
User enters phone OTP → ACCOUNT CREATED + JWT token
      ↓
User logged in successfully
```

## Testing Steps

1. Fill registration form (Details page)
2. Enter 6-digit email OTP (check terminal output for dev mode OTP)
3. Enter 6-digit phone OTP (check terminal output for dev mode OTP)
4. See success message "Account Created!"
5. App navigates to home page (user is now registered)

## Common Issues

**Issue**: "sessionId not found"
- **Fix**: Make sure response from `/register` has `sessionId` field
- **Check**: Backend logs for response format

**Issue**: "Wrong parameter format"
- **Fix**: Ensure you're sending `{ sessionId, otp }` not `{ userId, otp }`

**Issue**: "User already registered"
- **Fix**: Clean up MySQL `registration_sessions` table or use different email

## Files to Modify
1. ✅ `lib/services/api_service.dart` - Update 5 methods
2. ✅ `lib/screens/registration_screen.dart` (or equivalent) - Update state variable + API calls
3. Optional: UI button text changes

---

**Backend Status**: ✅ Ready (Running on port 8081)
**React Frontend**: ✅ Ready (Uses sessionId)
**Flutter App**: ⏳ Needs above changes

Need help with specific screen code? Let me know!
