import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class SiteSettingsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  Map<String, dynamic> _settings = const {};
  bool _loading = true;

  Map<String, dynamic> get settings => _settings;
  bool get loading => _loading;
  String get cartLogoUrl => (_settings['cartLogoUrl'] ?? '').toString();

  Future<void> loadSettings() async {
    try {
      _settings = await _api.getPublicSiteSettings();
    } catch (_) {
      _settings = const {};
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSettings() => loadSettings();
}
