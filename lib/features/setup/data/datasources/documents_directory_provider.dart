import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

/// Thin injectable wrapper around `path_provider` so the documents
/// directory can be faked in tests.
abstract interface class DocumentsDirectoryProvider {
  Future<Directory> documentsDirectory();
}

@LazySingleton(as: DocumentsDirectoryProvider)
class PathProviderDocumentsDirectoryProvider
    implements DocumentsDirectoryProvider {
  @override
  Future<Directory> documentsDirectory() => getApplicationDocumentsDirectory();
}
