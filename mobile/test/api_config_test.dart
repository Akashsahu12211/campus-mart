import 'dart:io';

import 'package:campus_mart_app/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiConfig always exposes at least one normalized base URL', () {
    expect(ApiConfig.baseUrlCandidates, isNotEmpty);
    expect(ApiConfig.baseUrl, endsWith('/api'));
    expect(ApiConfig.baseUrlCandidates.every((value) => value.endsWith('/api')), isTrue);
  });

  test('ApiService source keeps refresh-token persistence and refresh endpoint wiring', () {
    final apiServiceFile = File('lib/services/api_service.dart');
    final source = apiServiceFile.readAsStringSync();

    expect(source, contains('SecureSessionStorage.readRefreshToken()'));
    expect(source, contains('SecureSessionStorage.saveTokens('));
    expect(source, contains("'/auth/refresh'"));
    expect(source, contains("refreshToken: res.data['refreshToken']"));
  });
}
