import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../domain/entities/zettel.dart';
import '../../../domain/entities/zettel_id.dart';
import '../../../domain/usecases/delete_zettel.dart';
import '../../../domain/usecases/get_backlinks.dart';
import '../../../domain/usecases/get_zettel_by_id.dart';

part 'zettel_detail_state.dart';

/// Loads a zettel with its backlinks and the titles of the notes it
/// links to (used to label bare `[[id]]` wikilinks).
@injectable
class ZettelDetailCubit extends Cubit<ZettelDetailState> {
  ZettelDetailCubit(this._getZettelById, this._getBacklinks, this._deleteZettel)
    : super(const ZettelDetailInitial());

  final GetZettelById _getZettelById;
  final GetBacklinks _getBacklinks;
  final DeleteZettel _deleteZettel;

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
        final linkTitles = <String, String>{};
        for (final linkedId in zettel.outgoingLinks) {
          (await _getZettelById(linkedId)).fold(
            (_) {},
            (linked) => linkTitles[linkedId.value] = linked.title,
          );
        }
        if (isClosed) return;
        emit(
          ZettelDetailLoaded(
            zettel: zettel,
            backlinks: backlinks,
            linkTitles: linkTitles,
          ),
        );
      },
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
}
