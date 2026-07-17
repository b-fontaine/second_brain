import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/usecases/usecase.dart';
// Cross-feature dependency — documented exception: the graph feature owns the
// suggestion use cases backed by the local RAG index; the reading view reuses
// them for its « Pollinisation » section so every surface shares the same
// suggestion engine.
import '../../../../graph/domain/entities/related_note_suggestion.dart';
import '../../../../graph/domain/usecases/suggest_related_notes.dart';
import '../../../domain/entities/zettel.dart';
import '../../../domain/entities/zettel_id.dart';
import '../../../domain/usecases/delete_zettel.dart';
import '../../../domain/usecases/get_all_zettels.dart';
import '../../../domain/usecases/get_backlinks.dart';
import '../../../domain/usecases/get_zettel_by_id.dart';
import '../../../domain/usecases/update_zettel.dart';

part 'zettel_detail_state.dart';

/// Loads a zettel with its backlinks, the titles of the notes it links to
/// (used to label bare `[[id]]` wikilinks and the « Racines » rows), the
/// degree of its 1-hop neighborhood (maturity pastilles and the
/// mini-constellation) and the « Pollinisation » suggestions of the local
/// RAG index. Also weaves (« Tisser ») a suggestion into the note body.
@injectable
class ZettelDetailCubit extends Cubit<ZettelDetailState> {
  ZettelDetailCubit(
    this._getZettelById,
    this._getBacklinks,
    this._deleteZettel,
    this._getAllZettels,
    this._updateZettel,
    this._suggestRelatedNotes,
  ) : super(const ZettelDetailInitial());

  final GetZettelById _getZettelById;
  final GetBacklinks _getBacklinks;
  final DeleteZettel _deleteZettel;
  final GetAllZettels _getAllZettels;
  final UpdateZettel _updateZettel;
  final SuggestRelatedNotes _suggestRelatedNotes;

  /// How many « Pollinisation » suggestions are surfaced under a note.
  static const int suggestionCount = 5;

  Future<void> load(ZettelId id) async {
    emit(const ZettelDetailLoading());
    final zettelResult = await _getZettelById(id);
    await zettelResult.fold(
      (failure) async {
        if (!isClosed) emit(ZettelDetailError(failure.message));
      },
      (zettel) async {
        // A backlink failure must not prevent reading the note.
        final backlinks = (await _getBacklinks(
          id,
        )).getOrElse((_) => const <Zettel>[]);
        // One vault read resolves the outgoing link titles AND the degree of
        // every neighbor — much cheaper than one backlink query per neighbor.
        // On failure the note stays readable, only unlabeled and without
        // maturity pastilles.
        final all = (await _getAllZettels(
          const NoParams(),
        )).getOrElse((_) => const <Zettel>[]);
        final titlesById = {
          for (final other in all) other.id.value: other.title,
        };
        final linkTitles = <String, String>{};
        for (final linkedId in zettel.outgoingLinks) {
          final title = titlesById[linkedId.value];
          if (title != null) linkTitles[linkedId.value] = title;
        }
        final degrees = _degreesFor(all, {
          id.value,
          ...linkTitles.keys,
          for (final backlink in backlinks) backlink.id.value,
        });
        if (isClosed) return;
        emit(
          ZettelDetailLoaded(
            zettel: zettel,
            backlinks: backlinks,
            linkTitles: linkTitles,
            degrees: degrees,
          ),
        );
        await _loadSuggestions(zettel, backlinks);
      },
    );
  }

  /// « Tisser » : appends a `[[id|titre]]` wikilink to the end of the body
  /// (the vault format has no dedicated references section), saves through
  /// the regular update pipeline, then reloads so the Racines and the
  /// mini-constellation pick the new link up. On failure keeps the loaded
  /// state with a transient [ZettelDetailLoaded.errorMessage].
  Future<void> weave(RelatedNoteSuggestion suggestion) async {
    final current = state;
    if (current is! ZettelDetailLoaded) return;
    final zettel = current.zettel;
    final link = '[[${suggestion.id}|${suggestion.title}]]';
    final separator = zettel.body.trim().isEmpty ? '' : '\n\n';
    final updated = zettel.copyWith(
      body: '${zettel.body.trimRight()}$separator$link\n',
    );
    final result = await _updateZettel(updated);
    if (isClosed) return;
    await result.fold(
      (failure) async => emit(current.copyWith(errorMessage: failure.message)),
      (_) => load(zettel.id),
    );
  }

  /// Deletes the currently loaded zettel. Emits [ZettelDetailDeleted] on
  /// success; on failure keeps the loaded state with a transient
  /// [ZettelDetailLoaded.errorMessage].
  Future<void> delete() async {
    final current = state;
    if (current is! ZettelDetailLoaded) return;
    final result = await _deleteZettel(current.zettel.id);
    if (isClosed) return;
    result.fold(
      (failure) => emit(current.copyWith(errorMessage: failure.message)),
      (_) => emit(const ZettelDetailDeleted()),
    );
  }

  /// Fetches the « Pollinisation » suggestions (already-linked neighbors and
  /// the note itself excluded) and merges them into the loaded state. Errors
  /// are silent (the section simply stays empty) and stale answers — the
  /// user moved to another note while the index was thinking — are dropped.
  Future<void> _loadSuggestions(Zettel zettel, List<Zettel> backlinks) async {
    final result = await _suggestRelatedNotes(
      SuggestRelatedNotesParams(
        zettelId: zettel.id.value,
        excludedIds: {
          zettel.id.value,
          for (final linked in zettel.outgoingLinks) linked.value,
          for (final backlink in backlinks) backlink.id.value,
        },
        count: suggestionCount,
      ),
    );
    if (isClosed) return;
    final current = state;
    if (current is! ZettelDetailLoaded || current.zettel.id != zettel.id) {
      return;
    }
    result.fold(
      (_) {},
      (suggestions) => emit(current.copyWith(suggestions: suggestions)),
    );
  }

  /// Degree of each id in [ids]: number of unique undirected links over the
  /// whole vault (reciprocal links merged, self-links and links to missing
  /// notes ignored — same rules as the Explorer graph).
  static Map<String, int> _degreesFor(List<Zettel> all, Set<String> ids) {
    final live = {for (final zettel in all) zettel.id.value};
    final adjacency = <String, Set<String>>{};
    for (final zettel in all) {
      final source = zettel.id.value;
      for (final target in zettel.outgoingLinks) {
        final targetId = target.value;
        if (targetId == source || !live.contains(targetId)) continue;
        (adjacency[source] ??= <String>{}).add(targetId);
        (adjacency[targetId] ??= <String>{}).add(source);
      }
    }
    return {for (final id in ids) id: adjacency[id]?.length ?? 0};
  }
}
