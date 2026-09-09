import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _productionApiBaseUrl = 'https://api.mycampusmart.in/api';
  static const String _apiUrlOverride =
      String.fromEnvironment('CAMPUS_MART_API_URL', defaultValue: '');
  static const String _webApiUrlOverride =
      String.fromEnvironment('CAMPUS_MART_WEB_API_URL', defaultValue: '');
  static const String _androidApiUrlOverride =
      String.fromEnvironment('CAMPUS_MART_ANDROID_API_URL', defaultValue: '');
  static const String _iosApiUrlOverride =
      String.fromEnvironment('CAMPUS_MART_IOS_API_URL', defaultValue: '');

  static List<String> get baseUrlCandidates {
    if (_apiUrlOverride.isNotEmpty) {
      return [_normalizeBaseUrl(_apiUrlOverride)];
    }

    if (kIsWeb) {
      if (_webApiUrlOverride.isNotEmpty) {
        return [_normalizeBaseUrl(_webApiUrlOverride)];
      }
      return [
        kReleaseMode ? _productionApiBaseUrl : 'http://localhost:8081/api',
      ];
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (_androidApiUrlOverride.isNotEmpty) {
          return [_normalizeBaseUrl(_androidApiUrlOverride)];
        }
        if (kReleaseMode) {
          return const [_productionApiBaseUrl];
        }
        return const [
          'http://127.0.0.1:8081/api',
          'http://localhost:8081/api',
          'http://10.0.2.2:8081/api',
        ];
      case TargetPlatform.iOS:
        if (_iosApiUrlOverride.isNotEmpty) {
          return [_normalizeBaseUrl(_iosApiUrlOverride)];
        }
        return [
          kReleaseMode ? _productionApiBaseUrl : 'http://localhost:8081/api',
        ];
      default:
        return [
          kReleaseMode ? _productionApiBaseUrl : 'http://localhost:8081/api',
        ];
    }
  }

  static String get baseUrl => baseUrlCandidates.first;

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    if (!normalized.endsWith('/api')) {
      normalized = '$normalized/api';
    }

    return normalized;
  }

  static const int connectTimeoutSeconds = 6;
  static const int receiveTimeoutSeconds = 15;
  static const int maxImageSizeMB = 3;
  static const int maxImages = 5;
  static const bool enableNetworkLogs = bool.fromEnvironment(
    'CAMPUS_MART_ENABLE_NETWORK_LOGS',
    defaultValue: !kReleaseMode,
  );
}
