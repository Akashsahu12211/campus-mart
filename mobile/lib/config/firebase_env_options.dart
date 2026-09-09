import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseEnvOptions {
  static const String _apiKey =
      String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  static const String _projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
  static const String _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
  static const String _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
  static const String _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID', defaultValue: '');
  static const String _iosAppId =
      String.fromEnvironment('FIREBASE_IOS_APP_ID', defaultValue: '');
  static const String _iosBundleId =
      String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: '');

  static bool get isConfigured {
    if (_apiKey.isEmpty ||
        _projectId.isEmpty ||
        _messagingSenderId.isEmpty ||
        _storageBucket.isEmpty) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidAppId.isNotEmpty;
      case TargetPlatform.iOS:
        return _iosAppId.isNotEmpty && _iosBundleId.isNotEmpty;
      default:
        return false;
    }
  }

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb || !isConfigured) {
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: _apiKey,
          appId: _androidAppId,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          storageBucket: _storageBucket,
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: _apiKey,
          appId: _iosAppId,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          storageBucket: _storageBucket,
          iosBundleId: _iosBundleId,
        );
      default:
        return null;
    }
  }
}
