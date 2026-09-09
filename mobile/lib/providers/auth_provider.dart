import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_model.dart';
import '../services/api_service.dart';
import '../services/push_notification_service.dart';
import '../utils/app_logger.dart';

class AuthProvider extends ChangeNotifier {
  Student? _user;
  static const String _key = 'campusmart_user';

  Function(BuildContext)? onLogoutRequired;

  Student? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => (_user?.role.toUpperCase() ?? '') == 'ADMIN';

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('campusmart_user');
    if (userJson == null) return;

    try {
      final cached = jsonDecode(userJson);
      _user = Student.fromJson(cached);
      await prefs.setInt('campusmart_user_id', _user!.id);
      notifyListeners();
      unawaited(PushNotificationService.instance.syncTokenForUser(_user!.id));

      _setupUnauthorizedCallback();
      final fresh = await ApiService().getStudentById(_user!.id);
      final finalProfilePic = fresh.profilePic ?? _user?.profilePic;

      _user = fresh.copyWith(profilePic: finalProfilePic);

      await prefs.setString('campusmart_user', jsonEncode(_user!.toJson()));
      notifyListeners();

      AppLogger.debug(
        '[AUTH] User refreshed - profilePic: ${finalProfilePic != null ? "EXISTS" : "NULL"}',
      );
    } catch (e) {
      AppLogger.error('[AUTH] Error loading fresh user.', e);
    }
  }

  Future<void> login(Student student) async {
    _user = student;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(student.toJson()));
    await prefs.setInt('campusmart_user_id', student.id);

    _setupUnauthorizedCallback();
    unawaited(PushNotificationService.instance.syncTokenForUser(student.id));

    notifyListeners();
  }

  Future<void> logout() async {
    final currentUserId = _user?.id;
    if (currentUserId != null) {
      try {
        await PushNotificationService.instance.clearTokenForUser(currentUserId);
      } catch (_) {
        // Local logout must still continue if remote token cleanup fails.
      }
    }
    try {
      await ApiService().logout();
    } catch (_) {
      // Local logout must still continue if server logout fails.
    }
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove('campusmart_user_id');
    notifyListeners();
  }

  Future<void> refreshUser(Student updated) async {
    _user = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(updated.toJson()));
    notifyListeners();
  }

  void _setupUnauthorizedCallback() {
    ApiService().onUnauthorized = () {
      AppLogger.warn('[SECURITY] User unauthorized. Logging out.');
      logout();
      if (onLogoutRequired != null) {
        // Navigation hook kept for future use.
      }
    };
  }
}
