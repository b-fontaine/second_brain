import 'dart:io';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;

import '../../domain/services/clipboard_service.dart';
import 'app_directories.dart';
import 'host_platform.dart';

/// [ClipboardService] reading text via Flutter's [Clipboard] and, on
/// desktop, images via `pasteboard` (written to a temporary PNG file so
/// downstream OCR backends get the file path they all support).
@LazySingleton(as: ClipboardService)
class SystemClipboardService implements ClipboardService {
  const SystemClipboardService(this._platform, this._directories);

  final HostPlatform _platform;
  final AppDirectories _directories;

  @override
  Future<ClipboardContent> read() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      return ClipboardContent(text: text);
    }

    if (_platform.isDesktop) {
      try {
        final bytes = await Pasteboard.image;
        if (bytes != null && bytes.isNotEmpty) {
          final dir = await _directories.temporary();
          _sweepStaleCaptures(dir);
          final file = File(
            p.join(
              dir.path,
              'clipboard-${DateTime.now().millisecondsSinceEpoch}.png',
            ),
          );
          await file.writeAsBytes(bytes);
          return ClipboardContent(imagePath: file.path);
        }
      } on Exception {
        // Clipboard image access can fail on some Linux setups (X11 vs
        // Wayland): fall through to an empty result.
      }
    }
    return const ClipboardContent();
  }

  /// A saved capture's temporary PNG is imported into the vault (and
  /// deleted) by the inbox repository; this sweep collects the ones left
  /// behind by abandoned captures so they do not accumulate. The one-hour
  /// grace period protects any capture still being edited.
  void _sweepStaleCaptures(Directory dir) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    try {
      for (final entry in dir.listSync(followLinks: false)) {
        if (entry is! File) continue;
        final name = p.basename(entry.path);
        if (!name.startsWith('clipboard-') || !name.endsWith('.png')) {
          continue;
        }
        try {
          if (entry.lastModifiedSync().isBefore(cutoff)) entry.deleteSync();
        } on FileSystemException {
          // Best effort only.
        }
      }
    } on FileSystemException {
      // Best effort only.
    }
  }
}
