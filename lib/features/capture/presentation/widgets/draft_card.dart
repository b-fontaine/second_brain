import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../assistant/domain/entities/zettel_draft.dart';
import '../bloc/capture_bloc.dart';

/// One editable assistant draft: title, body and tags are editable,
/// suggested links are displayed, and the draft can be accepted alone.
class DraftCard extends StatefulWidget {
  const DraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.enabled,
  });

  final int index;
  final ZettelDraft draft;
  final bool enabled;

  @override
  State<DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<DraftCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
    _bodyController = TextEditingController(text: widget.draft.body);
  }

  @override
  void didUpdateWidget(DraftCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.title != oldWidget.draft.title &&
        widget.draft.title != _titleController.text) {
      _titleController.text = widget.draft.title;
    }
    if (widget.draft.body != oldWidget.draft.body &&
        widget.draft.body != _bodyController.text) {
      _bodyController.text = widget.draft.body;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _emit(ZettelDraft draft) {
    context.read<CaptureBloc>().add(CaptureDraftChanged(widget.index, draft));
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty || widget.draft.tags.contains(tag)) return;
    _tagController.clear();
    _emit(widget.draft.copyWith(tags: [...widget.draft.tags, tag]));
  }

  void _removeTag(String tag) {
    _emit(
      widget.draft.copyWith(
        tags: widget.draft.tags.where((t) => t != tag).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<CaptureBloc>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              enabled: widget.enabled,
              decoration: const InputDecoration(labelText: 'Titre'),
              onChanged: (value) => _emit(widget.draft.copyWith(title: value)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              enabled: widget.enabled,
              minLines: 3,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Contenu',
                alignLabelWithHint: true,
              ),
              onChanged: (value) => _emit(widget.draft.copyWith(body: value)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in widget.draft.tags)
                  InputChip(
                    label: Text(tag),
                    onDeleted: widget.enabled ? () => _removeTag(tag) : null,
                  ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _tagController,
                    enabled: widget.enabled,
                    decoration: const InputDecoration(
                      hintText: 'Ajouter un tag…',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
              ],
            ),
            if (widget.draft.suggestedLinks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Liens suggérés :',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final id in widget.draft.suggestedLinks)
                    Chip(
                      avatar: const Icon(Icons.link, size: 16),
                      label: Text('[[${id.value}]]'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: widget.enabled
                    ? () => bloc.add(CaptureDraftAccepted(widget.index))
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Accepter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
