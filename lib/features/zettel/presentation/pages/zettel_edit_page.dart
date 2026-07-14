import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/zettel.dart';
import '../../domain/entities/zettel_id.dart';
import '../bloc/zettel_edit/zettel_edit_bloc.dart';
import '../utils/zettel_text_formats.dart';
import '../widgets/wikilink_picker_dialog.dart';

/// Note editor (routes `/new` and `/note/:id/edit`): title, markdown
/// body, tag chips and wikilink insertion.
class ZettelEditPage extends StatelessWidget {
  const ZettelEditPage({super.key, this.zettelId});

  /// Raw `:id` route parameter; null when creating (route `/new`).
  final String? zettelId;

  @override
  Widget build(BuildContext context) {
    final raw = zettelId;
    if (raw != null && !ZettelId.isValid(raw)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Note introuvable')),
      );
    }
    return BlocProvider(
      create: (_) => getIt<ZettelEditBloc>()
        ..add(
          ZettelEditStarted(id: raw == null ? null : ZettelId.fromString(raw)),
        ),
      child: _ZettelEditView(isNew: raw == null),
    );
  }
}

class _ZettelEditView extends StatefulWidget {
  const _ZettelEditView({required this.isNew});

  final bool isNew;

  @override
  State<_ZettelEditView> createState() => _ZettelEditViewState();
}

class _ZettelEditViewState extends State<_ZettelEditView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final List<String> _tags = [];
  bool _initialized = false;

  static const TextStyle _monospaceStyle = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Consolas', 'Courier New'],
  );

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ZettelEditBloc, ZettelEditState>(
      listener: _onStateChanged,
      builder: (context, state) {
        if (state is ZettelEditError && state.blocking) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(state.message)),
          );
        }
        if (!_initialized) {
          return Scaffold(
            appBar: AppBar(title: Text(_pageTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final saving = state is ZettelEditSaving;
        return Scaffold(
          appBar: AppBar(
            title: Text(_pageTitle),
            actions: [
              IconButton(
                key: const Key('insert-wikilink-button'),
                tooltip: 'Insérer un lien vers une note',
                icon: const Icon(Icons.add_link),
                onPressed: saving ? null : _insertWikilink,
              ),
              IconButton(
                key: const Key('save-note-button'),
                tooltip: 'Enregistrer',
                icon: const Icon(Icons.check),
                onPressed: saving ? null : _submit,
              ),
            ],
          ),
          body: Column(
            children: [
              if (saving) const LinearProgressIndicator(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('note-title-field'),
                        controller: _titleController,
                        enabled: !saving,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Titre'),
                      ),
                      const SizedBox(height: 12),
                      _TagsEditor(
                        tags: _tags,
                        controller: _tagController,
                        enabled: !saving,
                        onAdded: _addTag,
                        onRemoved: _removeTag,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('note-body-field'),
                          controller: _bodyController,
                          enabled: !saving,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          style: _monospaceStyle,
                          decoration: const InputDecoration(
                            labelText: 'Contenu',
                            alignLabelWithHint: true,
                            hintText:
                                'Rédigez votre note en markdown. '
                                'Liez d’autres notes avec [[id]].',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String get _pageTitle => widget.isNew ? 'Nouvelle note' : 'Modifier la note';

  void _onStateChanged(BuildContext context, ZettelEditState state) {
    if (state is ZettelEditReady && !_initialized) {
      final initial = state.initial;
      if (initial != null) {
        _titleController.text = initial.title;
        _bodyController.text = initial.body;
        _tags
          ..clear()
          ..addAll(initial.tags);
      }
      setState(() => _initialized = true);
    } else if (state is ZettelEditSaved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note enregistrée')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    } else if (state is ZettelEditError && !state.blocking) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message)));
    }
  }

  void _submit() {
    context.read<ZettelEditBloc>().add(
      ZettelEditSubmitted(
        title: _titleController.text,
        body: _bodyController.text,
        tags: List.of(_tags),
      ),
    );
  }

  void _addTag(String raw) {
    final tag = normalizeTag(raw);
    _tagController.clear();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() => _tags.add(tag));
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _insertWikilink() async {
    final selected = await showDialog<Zettel>(
      context: context,
      builder: (_) => const WikilinkPickerDialog(),
    );
    if (selected == null || !mounted) return;
    final link = '[[${selected.id.value}|${selected.title}]]';
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    _bodyController.value = TextEditingValue(
      text: text.replaceRange(start, end, link),
      selection: TextSelection.collapsed(offset: start + link.length),
    );
  }
}

class _TagsEditor extends StatelessWidget {
  const _TagsEditor({
    required this.tags,
    required this.controller,
    required this.onAdded,
    required this.onRemoved,
    this.enabled = true,
  });

  final List<String> tags;
  final TextEditingController controller;
  final ValueChanged<String> onAdded;
  final ValueChanged<String> onRemoved;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Tags'),
      // Bounded height: with many tags the chip rows scroll instead of
      // overflowing the column and crushing the content field.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 108),
        child: SingleChildScrollView(
          key: const Key('tags-editor-scroll'),
          // Keep the last row — where the input field lives — visible.
          reverse: true,
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in tags)
                InputChip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  onDeleted: enabled ? () => onRemoved(tag) : null,
                ),
              SizedBox(
                width: 160,
                child: TextField(
                  key: const Key('tag-input-field'),
                  controller: controller,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Ajouter un tag',
                  ),
                  onSubmitted: onAdded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
