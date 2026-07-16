import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../domain/services/capture_intake.dart';
import '../bloc/seed_intake_cubit.dart';

/// « Aperçu avant semis » form: detected type chip, editable extracted
/// text, editable proposed title, removable proposed parcelles, and the
/// « Semer en pépinière » CTA.
///
/// The whole form scrolls (the 800×600 test viewport must reach the CTA).
class SeedPreviewForm extends StatefulWidget {
  const SeedPreviewForm({super.key, required this.state});

  final SeedIntakeReady state;

  @override
  State<SeedPreviewForm> createState() => _SeedPreviewFormState();
}

class _SeedPreviewFormState extends State<SeedPreviewForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.state.draft.title);
    _textController = TextEditingController(text: widget.state.draft.text);
  }

  @override
  void didUpdateWidget(SeedPreviewForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only resync when the cubit pushed a value we did not type ourselves.
    final draft = widget.state.draft;
    if (draft.title != oldWidget.state.draft.title &&
        draft.title != _titleController.text) {
      _titleController.text = draft.title;
    }
    if (draft.text != oldWidget.state.draft.text &&
        draft.text != _textController.text) {
      _textController.text = draft.text;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String get _kindLabel => switch (widget.state.draft.kind) {
    SeedKind.text => 'Texte',
    SeedKind.image => 'Image',
    SeedKind.audio => 'Audio',
  };

  IconData get _kindIcon => switch (widget.state.draft.kind) {
    SeedKind.text => Icons.notes,
    SeedKind.image => Icons.image_outlined,
    SeedKind.audio => Icons.graphic_eq,
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SeedIntakeCubit>();
    final theme = Theme.of(context);
    final draft = widget.state.draft;
    final sowing = widget.state.sowing;
    final errorMessage = widget.state.errorMessage;
    final assetPath = draft.assetPath;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Chip(
                    key: const Key('seed-preview-kind'),
                    avatar: Icon(_kindIcon, size: 18),
                    label: Text('Type détecté : $_kindLabel'),
                  ),
                  const SizedBox(width: 8),
                  if (assetPath != null)
                    Expanded(
                      child: Text(
                        p.basename(assetPath),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('seed-preview-title'),
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre proposé (modifiable)',
                ),
                onChanged: cubit.titleChanged,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('seed-preview-text'),
                controller: _textController,
                minLines: 6,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Texte extrait (modifiable)',
                  alignLabelWithHint: true,
                ),
                onChanged: cubit.textChanged,
              ),
              if (draft.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Parcelles proposées',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in draft.tags)
                      InputChip(
                        key: Key('seed-preview-tag-$tag'),
                        label: Text(tag),
                        // Explicit icon: the M2/M3 defaults differ and the
                        // widget tests tap it by icon.
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: sowing
                            ? null
                            : () => cubit.tagRemoved(tag),
                        deleteButtonTooltipMessage: 'Retirer la parcelle',
                      ),
                  ],
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('seed-preview-sow'),
                    onPressed: sowing ? null : cubit.sow,
                    icon: const Icon(Icons.spa_outlined),
                    label: const Text('Semer en pépinière'),
                  ),
                  TextButton(
                    onPressed: sowing
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: const Text('Annuler'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
