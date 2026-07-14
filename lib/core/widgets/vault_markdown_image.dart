import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../features/setup/domain/repositories/setup_repository.dart';
import '../di/injection.dart';

/// Markdown `imageBuilder` restricted to the local vault `assets/` folder.
///
/// Vault markdown is external content pulled from the git remote, so the
/// default builder (which fetches `http(s)` images) would let any note act
/// as a tracking beacon the moment it is rendered. Only vault-relative
/// `assets/...` paths are resolved; everything else shows a placeholder.
Widget vaultMarkdownImageBuilder(Uri uri, String? title, String? alt) =>
    VaultMarkdownImage(uri: uri, alt: alt);

/// Vault-relative path of [uri] when it points inside the vault `assets/`
/// folder, or null when it must not be loaded (remote, `data:`, absolute
/// or escaping the folder with `..`).
String? vaultAssetRelativePath(Uri uri) {
  if (uri.hasScheme || uri.hasAuthority) return null;
  if (uri.path.startsWith('/')) return null;
  if (uri.pathSegments.isEmpty) return null;
  // pathSegments are percent-decoded; normalize to collapse `.` and `..`.
  final path = p.posix.normalize(uri.pathSegments.join('/'));
  if (!p.posix.isWithin('assets', path)) return null;
  return path;
}

/// Renders a markdown image only when it lives in the vault `assets/`
/// folder; shows an explicit French placeholder otherwise.
class VaultMarkdownImage extends StatefulWidget {
  const VaultMarkdownImage({super.key, required this.uri, this.alt});

  final Uri uri;
  final String? alt;

  @override
  State<VaultMarkdownImage> createState() => _VaultMarkdownImageState();
}

class _VaultMarkdownImageState extends State<VaultMarkdownImage> {
  String? _relativePath;
  Future<String?>? _vaultPath;

  @override
  void initState() {
    super.initState();
    _relativePath = vaultAssetRelativePath(widget.uri);
    if (_relativePath != null) _vaultPath = _resolveVaultPath();
  }

  static Future<String?> _resolveVaultPath() async {
    final result = await getIt<SetupRepository>().getConfig();
    return result.fold((_) => null, (config) => config?.vaultPath);
  }

  @override
  Widget build(BuildContext context) {
    final relativePath = _relativePath;
    if (relativePath == null) {
      return _ImagePlaceholder(
        icon: Icons.image_not_supported_outlined,
        message: 'Image externe non chargée',
        alt: widget.alt,
      );
    }
    return FutureBuilder<String?>(
      future: _vaultPath,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final vaultPath = snapshot.data;
        if (vaultPath == null) {
          return _ImagePlaceholder(
            icon: Icons.broken_image_outlined,
            message: 'Image introuvable',
            alt: widget.alt,
          );
        }
        return Image.file(
          File(p.join(vaultPath, relativePath)),
          errorBuilder: (context, error, stackTrace) => _ImagePlaceholder(
            icon: Icons.broken_image_outlined,
            message: 'Image introuvable',
            alt: widget.alt,
          ),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({
    required this.icon,
    required this.message,
    this.alt,
  });

  final IconData icon;
  final String message;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final label = alt == null || alt!.isEmpty ? message : '$message : $alt';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
