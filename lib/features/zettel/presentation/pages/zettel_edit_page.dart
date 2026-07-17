import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/serre_tokens.dart';
// Cross-feature imports — documented exception: the graph feature owns the
// RAG-backed suggestion use cases; the editor reuses them for its « fleur »
// banner so every Pollinisation surface shares the same engine.
import '../../../graph/domain/entities/related_note_suggestion.dart';
import '../../../graph/domain/usecases/suggest_draft_links.dart';
import '../../domain/entities/inbox_item.dart';
import '../../domain/entities/zettel.dart';
import '../../domain/entities/zettel_id.dart';
import '../bloc/zettel_edit/zettel_edit_bloc.dart';
import '../utils/markdown_highlighting_controller.dart';
import '../utils/zettel_text_formats.dart';
import '../widgets/wikilink_picker_dialog.dart';

/// Note editor (routes `/new`, `/note/:id/edit` and `/pepiniere/edit`):
/// title, markdown body with light syntax coloring, tag chips (parcelles),
/// wikilink insertion and a « fleur » banner suggesting a close note to
/// weave while typing.
///
/// With [draftItem] set (nursery « Modifier »), the form is prefilled from
/// the pending capture and saving transplants it into a zettel (« Repiquer »
/// with the edited values) instead of creating a bare note.
class ZettelEditPage extends StatelessWidget {
  const ZettelEditPage({super.key, this.zettelId, this.draftItem})
    : assert(
        zettelId == null || draftItem == null,
        'A note edition and a nursery draft are exclusive',
      );

  /// Raw `:id` route parameter; null when creating (route `/new`).
  final String? zettelId;

  /// Pending capture to edit then transplant (route `/pepiniere/edit`).
  final InboxItem? draftItem;

  /// Delay between the last keystroke in the body and the RAG lookup
  /// feeding the « fleur » banner. Public so tests pump it explicitly.
  static const Duration pollinationDebounce = Duration(milliseconds: 800);

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
          ZettelEditStarted(
            id: raw == null ? null : ZettelId.fromString(raw),
            draftItem: draftItem,
          ),
        ),
      child: _ZettelEditView(isNew: raw == null, isDraft: draftItem != null),
    );
  }
}

class _ZettelEditView extends StatefulWidget {
  const _ZettelEditView({required this.isNew, this.isDraft = false});

  final bool isNew;

  /// True in nursery transplant mode (adapted title and confirmation).
  final bool isDraft;

  @override
  State<_ZettelEditView> createState() => _ZettelEditViewState();
}

class _ZettelEditViewState extends State<_ZettelEditView> {
  final TextEditingController _titleController = TextEditingController();
  final MarkdownHighlightingController _bodyController =
      MarkdownHighlightingController();
  final TextEditingController _tagController = TextEditingController();
  final List<String> _tags = [];
  bool _initialized = false;

  /// Id of the note being edited (excluded from suggestions); null when
  /// creating or transplanting.
  String? _editedId;

  // « Fleur » banner state: suggestion fetching is debounced, silent on
  // failure and disabled for the session with the banner's close button.
  Timer? _pollinationTimer;
  int _pollinationRequest = 0;
  RelatedNoteSuggestion? _pollinationSuggestion;
  bool _pollinationEnabled = true;
  SuggestDraftLinks? _suggestDraftLinks;

  static const TextStyle _monospaceStyle = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Consolas', 'Courier New'],
  );

  @override
  void dispose() {
    _pollinationTimer?.cancel();
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
        final suggestion = _pollinationSuggestion;
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
                      if (suggestion != null && _pollinationEnabled) ...[
                        const SizedBox(height: 12),
                        _PollinationBanner(
                          title: suggestion.title,
                          onWeave: _weaveSuggestion,
                          onDismiss: _disablePollination,
                        ),
                      ],
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
                          onChanged: _onBodyChanged,
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

  String get _pageTitle {
    if (widget.isDraft) return 'Repiquer le brouillon';
    return widget.isNew ? 'Nouvelle note' : 'Modifier la note';
  }

  void _onStateChanged(BuildContext context, ZettelEditState state) {
    if (state is ZettelEditReady && !_initialized) {
      final initial = state.initial;
      final draft = state.draft;
      if (initial != null) {
        _editedId = initial.id.value;
        _titleController.text = initial.title;
        _bodyController.text = initial.body;
        _tags
          ..clear()
          ..addAll(initial.tags);
      } else if (draft != null) {
        // Nursery draft: prefill with the enriched proposal (same title as
        // the Pépinière card), raw text and parcelles.
        _titleController.text = draft.proposedTitle;
        _bodyController.text = draft.rawText;
        _tags
          ..clear()
          ..addAll(draft.tags);
      }
      setState(() => _initialized = true);
    } else if (state is ZettelEditSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isDraft
                ? 'Brouillon repiqué — la note a rejoint le jardin.'
                : 'Note enregistrée',
          ),
        ),
      );
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
    _insertIntoBody('[[${selected.id.value}|${selected.title}]]');
  }

  /// Inserts [link] at the cursor (replacing any selection), like the
  /// wikilink picker does.
  void _insertIntoBody(String link) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    _bodyController.value = TextEditingValue(
      text: text.replaceRange(start, end, link),
      selection: TextSelection.collapsed(offset: start + link.length),
    );
  }

  // --- « Fleur » banner (pollination while typing) --------------------------

  void _onBodyChanged(String text) {
    if (!_pollinationEnabled) return;
    _pollinationTimer?.cancel();
    _pollinationTimer = Timer(
      ZettelEditPage.pollinationDebounce,
      _fetchPollination,
    );
  }

  Future<void> _fetchPollination() async {
    final requestId = ++_pollinationRequest;
    final body = _bodyController.text;
    final query = '${_titleController.text}\n$body';
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _pollinationSuggestion = null);
      return;
    }
    final excluded = <String>{
      ?_editedId,
      for (final linked in Zettel.parseWikiLinks(body)) linked.value,
    };
    RelatedNoteSuggestion? suggestion;
    try {
      final suggest = _suggestDraftLinks ??= getIt<SuggestDraftLinks>();
      final result = await suggest(
        SuggestDraftLinksParams(text: query, excludedIds: excluded, count: 1),
      );
      suggestion = result.fold(
        // Silent on failure: the banner is a hint, never an obstacle.
        (_) => null,
        (suggestions) => suggestions.isEmpty ? null : suggestions.first,
      );
    } catch (_) {
      suggestion = null;
    }
    // Drop stale answers: another lookup was scheduled since.
    if (!mounted || requestId != _pollinationRequest) return;
    setState(() => _pollinationSuggestion = suggestion);
  }

  void _weaveSuggestion() {
    final suggestion = _pollinationSuggestion;
    if (suggestion == null) return;
    _insertIntoBody('[[${suggestion.id}|${suggestion.title}]]');
    setState(() => _pollinationSuggestion = null);
  }

  void _disablePollination() {
    _pollinationTimer?.cancel();
    setState(() {
      _pollinationEnabled = false;
      _pollinationSuggestion = null;
    });
  }
}

/// « Fleur » banner: a close note was found while typing — weave it?
class _PollinationBanner extends StatelessWidget {
  const _PollinationBanner({
    required this.title,
    required this.onWeave,
    required this.onDismiss,
  });

  final String title;
  final VoidCallback onWeave;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fleur =
        theme.extension<SerreTokens>()?.fleur ?? theme.colorScheme.tertiary;
    return Material(
      key: const Key('pollination-banner'),
      color: fleur.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.local_florist_outlined, size: 18, color: fleur),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '« $title » semble proche — tisser ?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton(
              key: const Key('pollination-weave-button'),
              onPressed: onWeave,
              child: const Text('Tisser'),
            ),
            IconButton(
              key: const Key('pollination-dismiss-button'),
              tooltip: 'Masquer les suggestions pour cette édition',
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
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
