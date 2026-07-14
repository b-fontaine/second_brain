import 'package:flutter/material.dart';

import '../../../../core/theme/serre_tokens.dart';
import '../bloc/capture_bloc.dart';
import '../pages/capture_page.dart';
import '../utils/capture_file_pickers.dart';

/// Left-border accent of the « Ajouter un fichier » chip. Brown from the
/// mockups; not a theme token because nothing else uses it yet.
const Color _fileBrown = Color(0xFF8A6E4B);

/// Pushes the full-screen capture flow primed with [event]; the flow reuses
/// the existing [CaptureBloc] pipeline end to end.
void _openCaptureFlow(NavigatorState navigator, CaptureEvent event) {
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => CapturePage(initialEvent: event),
    ),
  );
}

/// « Dicter » : streaming STT dictation (⌘⇧D / Ctrl⇧D on desktop).
void seedByDictation(BuildContext context) =>
    _openCaptureFlow(Navigator.of(context), const CaptureDictationStarted());

/// « Coller » : import the copied text or image (⌘⇧V / Ctrl⇧V).
void seedByClipboard(BuildContext context) =>
    _openCaptureFlow(Navigator.of(context), const CaptureClipboardRequested());

/// « Ajouter un fichier » : pick an audio or image file (⌘⇧O / Ctrl⇧O).
/// No-op when the picker is cancelled.
Future<void> seedByFile(BuildContext context) async {
  // Resolved before the async gap so the flow can open even if the calling
  // widget (a dial chip being dismissed) is gone when the picker returns.
  final navigator = Navigator.of(context);
  final event = await pickCaptureFileEvent();
  if (event != null) _openCaptureFlow(navigator, event);
}

/// Speed-dial of the « Semer » button: a scrim that dismisses on tap and
/// three seeding chips. Single component for both form factors: chips stack
/// above the centered mobile button, or above the desktop FAB when
/// [alignEnd] is true.
class SeedDial extends StatefulWidget {
  const SeedDial({
    super.key,
    required this.onDismiss,
    this.alignEnd = false,
    this.bottomInset = 0,
    this.onDictate,
    this.onPaste,
    this.onAddFile,
  });

  /// Closes the dial; owned by the shell (the dial never removes itself).
  final VoidCallback onDismiss;

  /// True on expanded layouts: chips align to the right, above the FAB.
  final bool alignEnd;

  /// Space kept free under the chips for the seed button, in dp above the
  /// bottom SafeArea.
  final double bottomInset;

  /// Chip action overrides; default to the real capture flows
  /// ([seedByDictation], [seedByClipboard], [seedByFile]). Tests inject
  /// stubs here to avoid the DI container.
  final VoidCallback? onDictate;
  final VoidCallback? onPaste;
  final VoidCallback? onAddFile;

  @override
  State<SeedDial> createState() => _SeedDialState();
}

class _SeedDialState extends State<SeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  bool _entranceStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    // Accessibility: skip the entrance animation entirely when the
    // platform asks for reduced motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Dismisses the dial then runs the chip action. The action resolves its
  /// Navigator synchronously, before the dismissal rebuild lands.
  void _handle(VoidCallback? override, void Function(BuildContext) action) {
    widget.onDismiss();
    if (override != null) {
      override();
    } else {
      action(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SerreTokens>()!;
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(fade);

    return FadeTransition(
      opacity: fade,
      child: Stack(
        children: [
          ModalBarrier(
            key: const Key('seed-dial-scrim'),
            color: tokens.scrim,
            onDismiss: widget.onDismiss,
            semanticsLabel: 'Fermer le menu Semer',
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: widget.bottomInset),
                child: Align(
                  alignment: widget.alignEnd
                      ? Alignment.bottomRight
                      : Alignment.bottomCenter,
                  child: SlideTransition(
                    position: slide,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SeedChip(
                            key: const Key('seed-dial-dictate'),
                            icon: Icons.mic_none,
                            title: 'Dicter',
                            subtitle: 'voix → note, hors-ligne',
                            accent: tokens.feuillage,
                            onTap: () =>
                                _handle(widget.onDictate, seedByDictation),
                          ),
                          const SizedBox(height: 10),
                          _SeedChip(
                            key: const Key('seed-dial-paste'),
                            icon: Icons.content_paste,
                            title: 'Coller',
                            subtitle: 'texte · markdown · image · audio',
                            accent: tokens.ambre,
                            onTap: () =>
                                _handle(widget.onPaste, seedByClipboard),
                          ),
                          const SizedBox(height: 10),
                          _SeedChip(
                            key: const Key('seed-dial-file'),
                            icon: Icons.upload_file,
                            title: 'Ajouter un fichier',
                            subtitle: '.md · .txt · image · audio',
                            accent: _fileBrown,
                            onTap: () => _handle(widget.onAddFile, seedByFile),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One seeding entry: surface card, radius 16, 4 dp colored left border,
/// icon plus title/subtitle.
class _SeedChip extends StatelessWidget {
  const _SeedChip({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Material(
      color: tokens.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            child: Row(
              children: [
                Icon(icon, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.sub,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
