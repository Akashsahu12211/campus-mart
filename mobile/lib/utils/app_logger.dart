import 'package:flutter/foundation.dart';

class AppLogger {
  static const bool _forceLogs = bool.fromEnvironment(
    'CAMPUS_MART_ENABLE_DEBUG_LOGS',
    defaultValue: false,
  );

  static bool get _enabled => !kReleaseMode || _forceLogs;

  static void debug(String message) {
    if (_enabled) {
      debugPrint(message);
    }
  }

  static void info(String message) {
    if (_enabled) {
      debugPrint(message);
    }
  }

  static void warn(String message) {
    if (_enabled) {
      debugPrint(message);
    }
  }

  static void error(String message, [Object? error]) {
    if (_enabled) {
      if (error == null) {
        debugPrint(message);
      } else {
        debugPrint('$message $error');
      }
    }
  }
}
