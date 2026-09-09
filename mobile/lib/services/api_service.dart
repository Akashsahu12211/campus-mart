// lib/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/item_model.dart';
import '../models/student_model.dart';
import '../models/category_model.dart';
import '../utils/app_logger.dart';
import 'secure_session_storage.dart';

class ApiService {
  late final Dio _dio;
  static const String _skipBaseUrlFailoverKey = '_skipBaseUrlFailover';
  static const String _triedBaseUrlsKey = '_triedBaseUrls';
  static const Duration _categoryCacheTtl = Duration(minutes: 5);
  static const Duration _publicSettingsCacheTtl = Duration(minutes: 5);
  String _activeBaseUrl = ApiConfig.baseUrl;
  List<Category>? _cachedCategories;
  DateTime? _cachedCategoriesAt;
  Map<String, dynamic>? _cachedPublicSiteSettings;
  DateTime? _cachedPublicSiteSettingsAt;

  // ✅ Singleton pattern
  static final ApiService _instance = ApiService._internal();

  // ✅ Callback for 401 redirect
  Function? onUnauthorized;
  
  // ✅ Token refresh state
  bool _isRefreshing = false;
  final List<Function> _refreshQueue = [];

  factory ApiService() {
    return _instance;
  }

  String get activeBaseUrl => _activeBaseUrl;
  String get activeWebSocketUrl => '${_activeBaseUrl.replaceAll('/api', '')}/ws';

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _activeBaseUrl,
      connectTimeout: Duration(seconds: ApiConfig.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: ApiConfig.receiveTimeoutSeconds),
      headers: {'Content-Type': 'application/json'},
    ));

    // 🔥 Token attach call
    _attachToken();

    // ✅ ADD RESPONSE INTERCEPTOR FOR AUTHORIZATION WITH AUTO-REFRESH
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (DioException error, handler) async {
        if (_shouldRetryWithAlternateBaseUrl(error)) {
          final fallbackResponse =
              await _retryWithAlternateBaseUrl(error.requestOptions);
          if (fallbackResponse != null) {
            return handler.resolve(fallbackResponse);
          }
        }
        // ✅ HANDLE 401 - TRY TO REFRESH TOKEN
        if (error.response?.statusCode == 401) {
          final isRefreshRequest =
              error.requestOptions.path.contains('/auth/refresh');
          final token = await _getToken();
          final refreshToken = await _getRefreshToken();
          final hasStoredSession =
              (token != null && token.isNotEmpty) ||
              (refreshToken != null && refreshToken.isNotEmpty);

          if (isRefreshRequest) {
            AppLogger.warn('[API] Refresh token request failed. Redirecting to login.');
            _isRefreshing = false;
            _processQueue(error);
            await _clearTokenAndRedirect();
            return handler.reject(error);
          }

          if (!hasStoredSession) {
            AppLogger.warn(
              '[API] 401 received for request without a stored session. Skipping refresh.',
            );
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: error.type,
                error: error.response?.data?['error'] ?? 'Authentication required',
              ),
            );
          }

          AppLogger.warn('[API] 401 Unauthorized. Attempting token refresh.');
          
          if (_isRefreshing) {
            // Another request is already refreshing, queue this one
            return _queueRequest(error, handler);
          }

          _isRefreshing = true;

          try {
            if (refreshToken == null || refreshToken.isEmpty) {
              throw Exception('No token available');
            }

            // Try to refresh
            final refreshResponse = await _dio.post(
              '/auth/refresh',
              data: {'refreshToken': refreshToken},
              options: Options(headers: {'Authorization': 'Bearer $token'}),
            );

            final newToken = refreshResponse.data['token'];
            final newRefreshToken = refreshResponse.data['refreshToken'];
            await _saveAuthTokens(newToken, refreshToken: newRefreshToken);

            _isRefreshing = false;
            _processQueue(null);

            // Retry original request with new token
            error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            return handler.resolve(await _dio.fetch(error.requestOptions));
          } catch (e) {
            AppLogger.error('[API] Token refresh failed.', e);
            _isRefreshing = false;
            _processQueue(e);
            _clearTokenAndRedirect();
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: error.type,
                error: 'Session expired. Please login again.',
              ),
            );
          }
        }

        // ✅ HANDLE 403 - FORBIDDEN (User doesn't own resource)
        if (error.response?.statusCode == 403) {
          AppLogger.warn('[API] 403 Forbidden.');
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: error.response?.data?['error'] ??
                  'Forbidden: You do not have permission',
            ),
          );
        }

        return handler.next(error);
      },
    ));

    if (ApiConfig.enableNetworkLogs) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: false,
        error: true,
      ));
    }
  }

  // ✅ Queue request during token refresh
  bool _shouldRetryWithAlternateBaseUrl(DioException error) {
    if (ApiConfig.baseUrlCandidates.length <= 1) {
      return false;
    }

    if (error.requestOptions.extra[_skipBaseUrlFailoverKey] == true) {
      return false;
    }

    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  Future<Response<dynamic>?> _retryWithAlternateBaseUrl(
    RequestOptions requestOptions,
  ) async {
    final triedBaseUrls = <String>{
      _activeBaseUrl,
      ...((requestOptions.extra[_triedBaseUrlsKey] as List<dynamic>? ?? const [])
          .map((value) => value.toString())),
    };

    for (final candidate in ApiConfig.baseUrlCandidates) {
      if (triedBaseUrls.contains(candidate)) {
        continue;
      }

      try {
        AppLogger.debug('[API] Retrying ${requestOptions.path} via $candidate');
        final retryRequest = requestOptions.copyWith(
          baseUrl: candidate,
          path: _normalizeRetryPath(requestOptions.path),
          extra: {
            ...requestOptions.extra,
            _skipBaseUrlFailoverKey: true,
            _triedBaseUrlsKey: [...triedBaseUrls, candidate],
          },
        );
        final response = await _dio.fetch(retryRequest);
        _setActiveBaseUrl(candidate);
        AppLogger.info('[API] Connected using fallback base URL: $candidate');
        return response;
      } on DioException catch (retryError) {
        if (!_isRetryableNetworkError(retryError)) {
          rethrow;
        }
      }
    }

    return null;
  }

  bool _isRetryableNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout;
  }

  String _normalizeRetryPath(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final uri = Uri.parse(path);
      final query = uri.hasQuery ? '?${uri.query}' : '';
      return '${uri.path}$query';
    }

    return path;
  }

  void _setActiveBaseUrl(String value) {
    _activeBaseUrl = value;
    _dio.options.baseUrl = value;
  }

  Future<dynamic> _queueRequest(DioException error, ErrorInterceptorHandler handler) {
    return Future.delayed(Duration(milliseconds: 100), () async {
      final token = await _getToken();
      if (token != null) {
        error.requestOptions.headers['Authorization'] = 'Bearer $token';
        return handler.resolve(await _dio.fetch(error.requestOptions));
      } else {
        _clearTokenAndRedirect();
        return handler.reject(error);
      }
    });
  }

  // ✅ Process queued requests after token refresh
  void _processQueue(dynamic error) {
    for (var callback in _refreshQueue) {
      callback(error);
    }
    _refreshQueue.clear();
  }

  // 🔥 Token attach method
  Future<void> _attachToken() async {
    final token = await SecureSessionStorage.readAccessToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<void> _ensureAuthHeader() async {
    final token = await SecureSessionStorage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // ✅ GET TOKEN FROM STORAGE
  Future<String?> _getToken() async {
    return SecureSessionStorage.readAccessToken();
  }

  Future<String?> _getRefreshToken() async {
    return SecureSessionStorage.readRefreshToken();
  }

  // ✅ SAVE TOKEN TO STORAGE
  Future<void> _saveAuthTokens(String token, {String? refreshToken}) async {
    await SecureSessionStorage.saveTokens(
      accessToken: token,
      refreshToken: refreshToken,
    );
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // ✅ CLEAR TOKEN AND REDIRECT TO LOGIN ON 401
  Future<void> _clearTokenAndRedirect({bool triggerCallback = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await SecureSessionStorage.clearTokens();
    await prefs.remove('campusmart_user');

    // Call callback if set
    if (triggerCallback && onUnauthorized != null) {
      onUnauthorized!();
    }
  }

  // ── Auth ─────────────────────────────────────────────────

  // 🔥 UPDATED LOGIN
  Future<Student> login(String email, String password) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'email': email.trim().toLowerCase(),
        'password': password,
      });

      await _saveAuthTokens(
        res.data['token'],
        refreshToken: res.data['refreshToken'],
      );

      return Student.fromJson(res.data['student']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Student> socialLogin({
    required String idToken,
    required String provider,
  }) async {
    try {
      final res = await _dio.post('/auth/social-login', data: {
        'idToken': idToken,
        'provider': provider,
      });

      await _saveAuthTokens(
        res.data['token'],
        refreshToken: res.data['refreshToken'],
      );

      return Student.fromJson(res.data['student']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Student> register(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/auth/register', data: data);
      return Student.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Student> updateProfile(int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('/students/$id', data: data);
      return Student.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ✅ GET STUDENT BY ID (NEW)
  Future<Student> getStudentById(int id) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.get('/students/$id');
      return Student.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getInstitutions({
    String? query,
    String? type,
    String? city,
    String? state,
  }) async {
    try {
      final endpoint = query != null || type != null || city != null || state != null
          ? '/institutions/search'
          : '/institutions';
      final res = await _dio.get(
        endpoint,
        queryParameters: {
          if (query != null && query.isNotEmpty) 'q': query,
          if (type != null && type.isNotEmpty) 'type': type,
          if (city != null && city.isNotEmpty) 'city': city,
          if (state != null && state.isNotEmpty) 'state': state,
        },
      );
      return List<Map<String, dynamic>>.from(
        (res.data as List).map((item) => Map<String, dynamic>.from(item as Map)),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ✅ CHANGE PASSWORD METHOD (NEW)
  Future<void> changePassword(
    int id, {
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.put(
        '/students/$id/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> saveNotificationToken({
    required int userId,
    required String fcmToken,
    required String platform,
  }) async {
    try {
      await _ensureAuthHeader();
      await _dio.post('/notifications/token', data: {
        'userId': userId,
        'fcmToken': fcmToken,
        'platform': platform,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> clearNotificationToken({
    required int userId,
    String? fcmToken,
    required String platform,
  }) async {
    try {
      await _ensureAuthHeader();
      await _dio.delete('/notifications/token', data: {
        'userId': userId,
        'fcmToken': fcmToken,
        'platform': platform,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Items ─────────────────────────────────────────────────
  Future<List<Item>> getAllItems() async {
    try {
      final res = await _dio.get('/items');
      return (res.data as List).map((j) => Item.fromJson(j)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Item>> getRecentItems() async {
    try {
      final res = await _dio.get('/items/recent');
      return (res.data as List).map((j) => Item.fromJson(j)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Item> getItemById(int id) async {
    try {
      final res = await _dio.get('/items/$id');
      return Item.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Item>> getSimilarItems(int id) async {
    try {
      final res = await _dio.get('/items/$id/similar');
      return (res.data as List).map((j) => Item.fromJson(j)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Item>> getItemsByCategory(int categoryId) async {
    try {
      final res = await _dio.get('/items/category/$categoryId');
      return (res.data as List).map((j) => Item.fromJson(j)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Item>> getItemsBySeller(int sellerId) async {
    try {
      final res = await _dio.get('/items/seller/$sellerId');
      return (res.data as List).map((j) => Item.fromJson(j)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Item>> searchItems(String query) async {
    try {
      final res =
          await _dio.get('/items/search?q=${Uri.encodeComponent(query)}');
      return (res.data as List).map((j) => Item.fromJson(j)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadItemImage(String filePath, {String? fileName}) async {
    try {
      await _ensureAuthHeader();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName ?? filePath.split(RegExp(r'[\\\\/]')).last,
        ),
      });
      final res = await _dio.post(
        '/items/images',
        data: formData,
        options: Options(headers: {
          'Content-Type': 'multipart/form-data',
        }),
      );
      return res.data['url'] as String;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Item> addItem(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/items', data: data);
      return Item.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Item> updateItem(int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('/items/$id', data: data);
      return Item.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Item> markAsSold(int id) async {
    try {
      final res = await _dio.patch('/items/$id/sold');
      return Item.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Item> markAsReserved(int id) async {
    try {
      final res = await _dio.patch('/items/$id/reserved');
      return Item.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      await _dio.delete('/items/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Item> renewItem(int id) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.patch('/items/$id/renew');
      return Item.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Item>> getReservedItems(int buyerId) async {
    try {
      final res = await _dio.get('/items/reserved/buyer/$buyerId');
      return (res.data as List).map((j) => Item.fromJson(j)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Item>> getReservedItemsBySeller(int sellerId) async {
    try {
      final res = await _dio.get('/items/reserved/seller/$sellerId');
      return (res.data as List).map((j) => Item.fromJson(j)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unreserveItem(int itemId) async {
    try {
      await _dio.patch('/items/$itemId/unreserve');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Categories ────────────────────────────────────────────
  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    try {
      final categoriesCacheIsFresh =
          !forceRefresh &&
          _cachedCategories != null &&
          _cachedCategoriesAt != null &&
          DateTime.now().difference(_cachedCategoriesAt!) < _categoryCacheTtl;

      if (categoriesCacheIsFresh) {
        return List<Category>.from(_cachedCategories!);
      }

      final res = await _dio.get('/categories');
      final categories =
          (res.data as List).map((j) => Category.fromJson(j)).toList();
      _cachedCategories = List<Category>.from(categories);
      _cachedCategoriesAt = DateTime.now();
      return categories;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Reviews ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getItemReviews(int itemId) async {
    try {
      final res = await _dio.get('/reviews/item/$itemId');
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getSellerReviews(int sellerId) async {
    try {
      final res = await _dio.get('/reviews/seller/$sellerId');
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> addReview(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/reviews', data: data);
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateReview(
      int id, Map<String, dynamic> data) async {
    try {
      final res = await _dio.put('/reviews/$id', data: data);
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteReview(int id) async {
    try {
      await _dio.delete('/reviews/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> checkReview(int reviewerId, int itemId) async {
    try {
      final res = await _dio.get('/reviews/check', queryParameters: {
        'reviewerId': reviewerId,
        'itemId': itemId,
      });
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── 💰 OFFERS (PHASE 2) ────────────────────────────────────
  Future<Map<String, dynamic>> makeOffer(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/offers', data: data);
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getOffersForItem(int itemId) async {
    try {
      final res = await _dio.get('/offers/item/$itemId');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getOffersForSeller(int sellerId) async {
    try {
      final res = await _dio.get('/offers/seller/$sellerId');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getOffersForBuyer(int buyerId) async {
    try {
      final res = await _dio.get('/offers/buyer/$buyerId');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> acceptOffer(int offerId) async {
    try {
      final res = await _dio.patch('/offers/$offerId/accept');
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> rejectOffer(int offerId) async {
    try {
      final res = await _dio.patch('/offers/$offerId/reject');
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── PAGINATION (PHASE 2) ──────────────────────────────────
  Future<Map<String, dynamic>> getPaginatedItems({
    int page = 0,
    int pageSize = 20,
    String sort = 'newest',
    String? q,
    int? categoryId,
    double? minPrice,
    double? maxPrice,
    String? condition,
    String? hostel,
    String? branch,
    double? userLat,
    double? userLng,
    double? radiusKm,
  }) async {
    try {
      final res = await _dio.get(
        '/items/paginated',
        queryParameters: {
          'page': page,
          'pageSize': pageSize,
          'sort': sort,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (categoryId != null) 'categoryId': categoryId,
          if (minPrice != null) 'minPrice': minPrice,
          if (maxPrice != null) 'maxPrice': maxPrice,
          if (condition != null && condition.isNotEmpty) 'condition': condition,
          if (hostel != null && hostel.trim().isNotEmpty)
            'hostel': hostel.trim(),
          if (branch != null && branch.trim().isNotEmpty)
            'branch': branch.trim(),
          if (userLat != null) 'userLat': userLat,
          if (userLng != null) 'userLng': userLng,
          if (radiusKm != null) 'radiusKm': radiusKm,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── OTP (PHASE 2) ─────────────────────────────────────────
  Future<Map<String, dynamic>> requestEmailOtp(String email) async {
    try {
      final res = await _dio.post('/auth/otp/request-email', data: {
        'email': email,
      });
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> requestPhoneOtp(String phone) async {
    try {
      final res = await _dio.post('/auth/otp/request-phone', data: {
        'phone': phone,
      });
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String otp,
    required String type, // 'EMAIL' or 'PHONE'
  }) async {
    try {
      final res = await _dio.post('/auth/otp/verify', data: {
        'otp': otp,
        'type': type,
      });
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resendOtp(String type) async {
    try {
      final res = await _dio.post('/auth/otp/resend', data: {
        'type': type,
      });
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── PHASE 2 REGISTRATION (4-STEP WITH SESSION ID) ──────────
  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    try {
      final res = await _dio.post('/auth/register', data: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'phone': phone.trim(),
      });
      // Returns: { sessionId, nextStep, email }
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyEmailOtp({
    required String sessionId,
    required String otp,
  }) async {
    try {
      final res = await _dio.post('/auth/verify-email', data: {
        'sessionId': sessionId,
        'otp': otp,
      });
      // Returns: { phone, maskedPhone, devPhoneOtp, nextStep }
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyPhoneOtp({
    required String sessionId,
    required String otp,
  }) async {
    try {
      final res = await _dio.post('/auth/verify-phone', data: {
        'sessionId': sessionId,
        'otp': otp,
      });
      if (res.data['token'] != null) {
        await _saveAuthTokens(
          res.data['token'],
          refreshToken: res.data['refreshToken'],
        );
      }
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout({bool allDevices = false}) async {
    try {
      await _ensureAuthHeader();
      final refreshToken = await _getRefreshToken();
      if (allDevices) {
        await _dio.post('/auth/logout-all');
      } else {
        await _dio.post('/auth/logout', data: {
          if (refreshToken != null && refreshToken.isNotEmpty) 'refreshToken': refreshToken,
        });
      }
    } catch (_) {
      // Local cleanup still happens below.
    } finally {
      await _clearTokenAndRedirect(triggerCallback: false);
    }
  }

  Future<Map<String, dynamic>> resendEmailOtp({
    required String sessionId,
  }) async {
    try {
      final res = await _dio.post('/auth/resend-email-otp', data: {
        'sessionId': sessionId,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resendPhoneOtp({
    required String sessionId,
  }) async {
    try {
      final res = await _dio.post('/auth/resend-phone-otp', data: {
        'sessionId': sessionId,
      });
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Chat APIs ──────────────────────────────────────────────

  Future<List<dynamic>> getConversation({
    required int user1Id,
    required int user2Id,
    int? itemId,
  }) async {
    try {
      final params = <String, dynamic>{
        'user1Id': user1Id,
        'user2Id': user2Id,
        if (itemId != null) 'itemId': itemId,
      };
      AppLogger.debug(
          '[API] Fetching conversation: user1=$user1Id, user2=$user2Id, item=$itemId');
      final res = await _dio.get('/chat/conversation', queryParameters: params);
      AppLogger.debug('[API] Got ${(res.data as List).length} messages');
      return res.data as List;
    } on DioException catch (e) {
      AppLogger.error('[API] Error getting conversation.', e.message);
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getInbox(int userId) async {
    try {
      if (userId == 0) {
        AppLogger.warn('[API] Invalid userId: 0, skipping inbox fetch.');
        return [];
      }
      AppLogger.debug('[API] Fetching inbox for user $userId');
      final res = await _dio.get('/chat/inbox/$userId');
      AppLogger.debug('[API] Got ${(res.data as List).length} conversations');
      return res.data as List;
    } catch (e) {
      AppLogger.error('[API] Error getting inbox.', e);
      return [];
    }
  }

  Future<void> markAsRead({
    required int receiverId,
    required int senderId,
  }) async {
    try {
      AppLogger.debug(
          '[API] Marking message as read (receiver=$receiverId, sender=$senderId)');
      await _dio.post('/chat/mark-read', data: {
        'receiverId': receiverId,
        'senderId': senderId,
      });
    } catch (e) {
      AppLogger.error('[API] Error marking as read.', e);
    }
  }

  Future<int> getUnreadCount(int userId) async {
    try {
      if (userId == 0) {
        AppLogger.warn('[API] Invalid userId: 0, returning 0 unread.');
        return 0;
      }
      final res = await _dio.get('/chat/unread/$userId');
      final count = res.data['count'] as int? ?? 0;
      if (count > 0) AppLogger.debug('[API] Unread messages: $count');
      return count;
    } catch (e) {
      AppLogger.error('[API] Error getting unread count.', e);
      return 0;
    }
  }

  // HTTP fallback for sending
  Future<Map<String, dynamic>> sendMessageHttp({
    required int senderId,
    required int receiverId,
    int? itemId,
    required String content,
  }) async {
    try {
      AppLogger.debug(
          '[API] Sending message via HTTP (sender=$senderId, receiver=$receiverId)');
      final res = await _dio.post('/chat/send', data: {
        'senderId': senderId,
        'receiverId': receiverId,
        if (itemId != null) 'itemId': itemId,
        'content': content,
      });
      AppLogger.debug(
          '[API] Message saved to database with ID: ${res.data['id']}');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      AppLogger.error('[API] HTTP send failed.', e.message);
      throw _handleError(e);
    }
  }

  // ── 💳 RAZORPAY PAYMENT GATEWAY ────────────────────────────

  Future<Map<String, dynamic>> createPaymentOrder({
    required int itemId,
    required double amount,
    String? notes,
  }) async {
    try {
      final res = await _dio.post('/payments/create-order', data: {
        'itemId': itemId,
        'amount': amount,
        if (notes != null) 'notes': notes,
      });
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final res = await _dio.post('/payments/verify', data: {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      });
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> confirmDelivery(int orderId) async {
    try {
      final res = await _dio.post('/payments/$orderId/confirm-delivery',
          data: <String, dynamic>{});
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> raiseDispute(int orderId, String reason) async {
    try {
      final res = await _dio.post('/payments/$orderId/dispute',
          data: {'reason': reason});
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getBuyerOrders(int buyerId) async {
    try {
      final res = await _dio.get('/payments/buyer/$buyerId');
      return (res.data as List).map((j) => j).toList();
    } on DioException catch (e) {
      AppLogger.error('[API] Error getting buyer orders.', e.message);
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getSellerOrders(int sellerId) async {
    try {
      final res = await _dio.get('/payments/seller/$sellerId');
      return (res.data as List).map((j) => j).toList();
    } on DioException catch (e) {
      AppLogger.error('[API] Error getting seller orders.', e.message);
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getOrderTimeline(int orderId) async {
    try {
      final res = await _dio.get('/payments/$orderId/timeline');
      return (res.data as List).map((j) => j).toList();
    } on DioException catch (e) {
      AppLogger.error('[API] Error getting order timeline.', e.message);
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    try {
      final res =
          await _dio.post('/payments/$orderId/cancel', data: <String, dynamic>{});
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> getRazorpayKeyId() async {
    try {
      final res = await _dio.get('/payments/config');
      return res.data['keyId'] as String;
    } catch (_) {
      return '';
    }
  }

  Future<Map<String, dynamic>> getPaymentConfig() async {
    try {
      final res = await _dio.get('/payments/config');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getMonetizationPlans() async {
    try {
      final res = await _dio.get('/monetization/plans');
      return List<Map<String, dynamic>>.from(
        (res.data as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getMonetizationSummary(int studentId) async {
    try {
      final res = await _dio.get('/monetization/summary/$studentId');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getMonetizationLedger(int studentId) async {
    try {
      final res = await _dio.get('/monetization/ledger/$studentId');
      return List<dynamic>.from(res.data as List);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> activateMonetizationPlan(String planCode) async {
    try {
      final res = await _dio.post('/monetization/subscribe', data: {
        'planCode': planCode,
      });
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> boostMonetizedListing(int itemId) async {
    try {
      final res = await _dio.post('/monetization/items/$itemId/boost');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── Error Handling ─────────────────────────────────────────
  String _handleError(DioException e) {
    // ✅ HANDLE 401 - UNAUTHORIZED
    if (e.response?.statusCode == 401) {
      AppLogger.warn('[AUTH] 401 Unauthorized. Token invalid or expired.');
      _clearTokenAndRedirect();
      return 'Unauthorized: Please login again';
    }

    // ✅ HANDLE 403 - FORBIDDEN
    if (e.response?.statusCode == 403) {
      AppLogger.warn('[AUTH] 403 Forbidden.');
      final errorMsg = e.response?.data?['error'] ??
          'You do not have permission to perform this action';
      return errorMsg;
    }

    // Get error from response
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data['error'] != null) return data['error'];
    }

    // Handle timeout errors
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Check your internet.';
      case DioExceptionType.connectionError:
        return 'Cannot connect to server. Make sure backend is running.';
      case DioExceptionType.badResponse:
        return 'Server error: ${e.response?.statusCode}';
      default:
        return 'Something went wrong. Try again.';
    }
  }

  // ── 🔒 ADMIN PANEL ─────────────────────────────────────────

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final res = await _dio.get('/admin/stats');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getAdminUsers({String? search}) async {
    try {
      final res = await _dio.get('/admin/users', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      });
      return res.data as List;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> banUser(int targetId, String reason) async {
    try {
      final res =
          await _dio.patch('/admin/users/$targetId/ban', data: {'reason': reason});
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> unbanUser(int targetId) async {
    try {
      final res =
          await _dio.patch('/admin/users/$targetId/unban', data: <String, dynamic>{});
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getAdminItems({String? status}) async {
    try {
      final res = await _dio.get('/admin/items', queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      });
      return res.data as List;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> hideItem(int itemId, String reason) async {
    try {
      final res =
          await _dio.patch('/admin/items/$itemId/hide', data: {'reason': reason});
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getAdminReports({bool pendingOnly = false}) async {
    try {
      final res = await _dio.get('/admin/reports', queryParameters: {
        'pendingOnly': pendingOnly,
      });
      return res.data as List;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> reviewReport(int reportId, String action) async {
    try {
      final res =
          await _dio.patch('/admin/reports/$reportId', data: {'action': action});
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getAdminLogs() async {
    try {
      final res = await _dio.get('/admin/logs');
      return res.data as List;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getDisputedOrders() async {
    try {
      final res = await _dio.get('/admin/disputes');
      return res.data as List;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> resolveDispute(
      int orderId, String action, String reason) async {
    try {
      final res = await _dio.patch('/admin/disputes/$orderId/resolve',
          data: {'action': action, 'reason': reason});
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> refundPayment(int orderId, String reason) async {
    try {
      final res =
          await _dio.post('/payments/$orderId/refund', data: {'reason': reason});
      return res.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── ❤️ WISHLIST ────────────────────────────────────────────
  Future<List<dynamic>> getWishlist(int studentId) async {
    try {
      final res = await _dio.get('/wishlist/$studentId');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> addToWishlist(int studentId, int itemId) async {
    try {
      await _dio.post('/wishlist', data: {
        'studentId': studentId,
        'itemId': itemId,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> removeFromWishlist(int studentId, int itemId) async {
    try {
      await _dio.delete('/wishlist/$studentId/$itemId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> checkWishlist(int studentId, int itemId) async {
    try {
      final res = await _dio.get('/wishlist/$studentId/check/$itemId');
      return res.data['wishlisted'] as bool? ?? false;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> reserveByBuyer({
    required int itemId,
  }) async {
    try {
      await _ensureAuthHeader();
      await _dio.patch('/items/$itemId/reserve-by-buyer',
          data: <String, dynamic>{});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentStats(int id) async {
    try {
      final res = await _dio.get('/students/$id/stats');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getBoughtHistory(int id) async {
    try {
      final res = await _dio.get('/transactions/bought/$id');
      return List<dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getSoldHistory(int id) async {
    try {
      final res = await _dio.get('/transactions/sold/$id');
      return List<dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitFeedback(Map<String, dynamic> data) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.post('/support/feedback', data: data);
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitProblemReport(
      Map<String, dynamic> data) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.post('/support/report-problem', data: data);
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitContactMessage(
      Map<String, dynamic> data) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.post('/support/contact', data: data);
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getSupportTickets(int studentId) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.get('/support/student/$studentId');
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPublicSiteSettings() async {
    try {
      final settingsCacheIsFresh =
          _cachedPublicSiteSettings != null &&
          _cachedPublicSiteSettingsAt != null &&
          DateTime.now().difference(_cachedPublicSiteSettingsAt!) <
              _publicSettingsCacheTtl;

      if (settingsCacheIsFresh) {
        return Map<String, dynamic>.from(_cachedPublicSiteSettings!);
      }

      final res = await _dio.get('/public/site-settings');
      final settings = Map<String, dynamic>.from(res.data);
      _cachedPublicSiteSettings = Map<String, dynamic>.from(settings);
      _cachedPublicSiteSettingsAt = DateTime.now();
      return settings;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> requestForgotPassword(String email) async {
    try {
      final res = await _dio.post('/auth/forgot-password/request', data: {
        'email': email,
      });
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> resetForgotPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post('/auth/forgot-password/reset', data: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      });
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteAccount(int id, String password) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.post('/students/$id/delete-account', data: {
        'password': password,
      });
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getNotifications(int userId) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.get('/notifications/$userId');
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getActivityHistory(int userId) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.get('/activity/$userId');
      return List<dynamic>.from(res.data['activities'] ?? const []);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markNotificationRead(int userId, int notificationId) async {
    try {
      await _ensureAuthHeader();
      await _dio.patch('/notifications/$userId/$notificationId/read');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markAllNotificationsRead(int userId) async {
    try {
      await _ensureAuthHeader();
      await _dio.patch('/notifications/$userId/read-all');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<dynamic>> getBlockedUsers(int blockerId) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.get('/blocks/$blockerId');
      return List<dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> unblockUser(int blockedId, int blockerId) async {
    try {
      await _ensureAuthHeader();
      await _dio.delete('/blocks/$blockedId', queryParameters: {
        'blockerId': blockerId,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> checkBlockStatus(
      int viewerId, int targetUserId) async {
    try {
      await _ensureAuthHeader();
      final res = await _dio.get('/blocks/check', queryParameters: {
        'viewerId': viewerId,
        'targetUserId': targetUserId,
      });
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> blockUser(int blockerId, int blockedId) async {
    try {
      await _ensureAuthHeader();
      await _dio.post('/blocks', data: {
        'blockerId': blockerId,
        'blockedId': blockedId,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> submitItemReport({
    required int itemId,
    required String reason,
    String? description,
  }) async {
    try {
      await _ensureAuthHeader();
      await _dio.post('/reports', data: {
        'itemId': itemId,
        'reason': reason,
        'description': description,
      });
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
}
