import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A provider for accessing platform-specific information.
final platformServiceProvider = Provider<PlatformService>((ref) => PlatformService());

/// A service to provide information about the current platform.
///
/// This service abstracts the platform detection logic, making it easy to check
/// whether the app is running on mobile, desktop, or web, and what features
/// are supported.
class PlatformService {
  /// Returns `true` if the platform is a desktop environment.
  ///
  /// Considers Windows, macOS, and Linux as desktop platforms.
  bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Returns `true` if the platform is a mobile environment.
  ///
  /// Considers Android and iOS as mobile platforms.
  bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Returns `true` if the platform is a web browser.
  bool get isWeb => kIsWeb;

  /// Returns `true` if the platform supports camera-related features.
  ///
  /// Typically, this is available on mobile devices.
  bool get supportsCameraFeatures => isMobile;

  /// Returns `true` if the platform supports voice recording features.
  ///
  /// Typically, this is available on mobile devices.
  bool get supportsVoiceRecording => isMobile;

  /// Returns the name of the current platform as a string.
  ///
  /// Examples: "Windows", "Android", "Web".
  String get platformName {
    if (kIsWeb) {
      return 'Web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
