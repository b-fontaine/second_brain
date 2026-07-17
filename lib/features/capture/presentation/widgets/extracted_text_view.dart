import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../zettel/domain/entities/inbox_item.dart';
import '../bloc/capture_bloc.dart';

/// Extracted text, editable before handing it to the assistant.
class ExtractedTextView extends StatefulWidget {
  const ExtractedTextView({super.key, required this.state});

  final CaptureTextEditing state;

  @override
  State<ExtractedTextView> createState() => _ExtractedTextViewState();
}

class _ExtractedTextViewState extends State<ExtractedTextView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.text);
  }

  @override
  void didUpdateWidget(ExtractedTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only resync when the bloc pushed a text we did not type ourselves.
    if (widget.state.text != oldWidget.state.text &&
        widget.state.text != _controller.text) {
      _controller.text = widget.state.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _typeLabel => switch (widget.state.type) {
    CaptureType.clipboard => 'Presse-papiers',
    CaptureType.audio => 'Fichier audio',
    CaptureType.screenshot => 'Capture d’écran',
    CaptureType.dictation => 'Dictée',
    CaptureType.file => 'Fichier',
    CaptureType.assistant => 'Synthèse de l’assistant',
  };

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CaptureBloc>();
    final theme = Theme.of(context);
    final assetPath = widget.state.assetPath;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Chip(label: Text(_typeLabel)),
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
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Texte extrait (modifiable)',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (value) => bloc.add(CaptureTextChanged(value)),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => bloc.add(const CaptureOrganizeRequested()),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Organiser avec l’assistant'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        bloc.add(const CaptureSaveToInboxRequested()),
                    icon: const Icon(Icons.inbox_outlined),
                    label: const Text('Enregistrer dans l’inbox'),
                  ),
                  TextButton(
                    onPressed: () => bloc.add(const CaptureReset()),
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
