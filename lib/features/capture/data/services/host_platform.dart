import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Testable indirection over the platform the app runs on.
///
/// Reads [defaultTargetPlatform], which honours
/// [debugDefaultTargetPlatformOverride] in tests.
@lazySingleton
class HostPlatform {
  const HostPlatform();

  TargetPlatform get target => defaultTargetPlatform;

  bool get isMobile =>
      target == TargetPlatform.android || target == TargetPlatform.iOS;

  bool get isDesktop =>
      target == TargetPlatform.macOS ||
      target == TargetPlatform.windows ||
      target == TargetPlatform.linux;
}
