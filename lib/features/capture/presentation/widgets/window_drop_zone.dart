import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/serre_tokens.dart';
import '../utils/capture_file_pickers.dart';

/// Extensions the seeding intake accepts from a window drop (lowercase,
/// no dot) — the same families as the « Ajouter un fichier » picker.
final Set<String> _acceptedDropExtensions = {
  ...captureTextExtensions,
  ...captureImageExtensions,
  ...captureAudioExtensions,
};

/// First dropped file the seeding intake can ingest, or null when the drop
/// only carried folders or unsupported formats.
///
/// Folders ([DropItemDirectory]) are skipped: a directory path must never
/// reach the OCR/transcription pipelines.
@visibleForTesting
String? firstSeedableDroppedPath(List<DropItem> files) {
  for (final file in files) {
    if (file is DropItemDirectory) continue;
    final extension = p
        .extension(file.path)
        .replaceFirst('.', '')
        .toLowerCase();
    if (_acceptedDropExtensions.contains(extension)) return file.path;
  }
  return null;
}

/// Window-wide file drop target for desktop layouts: wraps the shell body
/// so dropping a note (.md/.txt), image or audio file anywhere on the
/// window seeds it through the same preview flow as « Ajouter un fichier ».
///
/// A green scrim (« Déposer pour semer ») covers the content while a drag
/// hovers the window; it lives under an [IgnorePointer] and is only built
/// during the hover, so it can never absorb taps (test-harness trap #4).
///
/// Strictly desktop: on non-desktop platforms (including large Android
/// tablets hitting the expanded breakpoint) the child is returned untouched —
/// desktop_drop's Android support is a preview delivering content URIs.
class WindowDropZone extends StatefulWidget {
  const WindowDropZone({
    super.key,
    required this.child,
    required this.onFileDropped,
    this.onUnsupportedDrop,
    @visibleForTesting this.enabledOverride,
  });

  final Widget child;

  /// Called with the path of the first ingestible dropped file.
  final void Function(String path) onFileDropped;

  /// Called when the drop carried no ingestible file (folder, unsupported
  /// extension); typically shows an explanatory SnackBar.
  final VoidCallback? onUnsupportedDrop;

  /// Test seam: forces the drop target on/off regardless of the platform.
  final bool? enabledOverride;

  @override
  State<WindowDropZone> createState() => _WindowDropZoneState();
}

class _WindowDropZoneState extends State<WindowDropZone> {
  bool _dragging = false;

  bool get _enabled => widget.enabledOverride ?? isDesktopPlatform;

  void _onDragDone(DropDoneDetails details) {
    setState(() => _dragging = false);
    final path = firstSeedableDroppedPath(details.files);
    if (path != null) {
      widget.onFileDropped(path);
    } else {
      widget.onUnsupportedDrop?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onDragDone,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_dragging)
            const Positioned.fill(child: IgnorePointer(child: _DropOverlay())),
        ],
      ),
    );
  }
}

/// Hover feedback: greenhouse scrim plus an explicit call to action.
class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return ColoredBox(
      key: const Key('window-drop-overlay'),
      // Scrim over the arbre green of the mockups.
      color: const Color(0x662F6B4F),
      child: Center(
        child: Material(
          color: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.accent, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.spa_outlined, size: 40, color: tokens.accent),
                const SizedBox(height: 8),
                Text('Déposer pour semer', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '.md · .txt · image · audio',
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.sub),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
