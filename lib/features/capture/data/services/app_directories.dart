import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

/// Injectable wrapper around path_provider so data services relying on
/// well-known directories stay testable.
@lazySingleton
class AppDirectories {
  const AppDirectories();

  Future<Directory> applicationSupport() => getApplicationSupportDirectory();

  Future<Directory> temporary() => getTemporaryDirectory();
}
