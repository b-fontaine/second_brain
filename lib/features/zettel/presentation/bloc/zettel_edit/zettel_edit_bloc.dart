import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/error/failures.dart';
import '../../../domain/entities/inbox_item.dart';
import '../../../domain/entities/zettel.dart';
import '../../../domain/entities/zettel_id.dart';
import '../../../domain/usecases/create_zettel.dart';
import '../../../domain/usecases/get_zettel_by_id.dart';
import '../../../domain/usecases/transplant_seedling.dart';
import '../../../domain/usecases/update_zettel.dart';

part 'zettel_edit_event.dart';
part 'zettel_edit_state.dart';

/// Drives note creation ([CreateZettel]), edition ([UpdateZettel]) and the
/// « Modifier » flow of the nursery: editing a pending capture prefilled in
/// the form, whose submission transplants it into a zettel
/// ([TransplantSeedling]).
@injectable
class ZettelEditBloc extends Bloc<ZettelEditEvent, ZettelEditState> {
  ZettelEditBloc(
    this._createZettel,
    this._updateZettel,
    this._getZettelById,
    this._transplantSeedling,
  ) : super(const ZettelEditInitial()) {
    on<ZettelEditStarted>(_onStarted);
    on<ZettelEditSubmitted>(_onSubmitted);
  }

  static const String emptyTitleMessage = 'Le titre ne peut pas être vide';

  final CreateZettel _createZettel;
  final UpdateZettel _updateZettel;
  final GetZettelById _getZettelById;
  final TransplantSeedling _transplantSeedling;

  /// Loaded note when editing; null when creating.
  Zettel? _original;

  /// Pending capture being edited before transplant; null otherwise.
  InboxItem? _draftItem;

  Future<void> _onStarted(
    ZettelEditStarted event,
    Emitter<ZettelEditState> emit,
  ) async {
    final draftItem = event.draftItem;
    if (draftItem != null) {
      // Nursery « Modifier » mode: the form is prefilled from the pending
      // capture and the save transplants it (create + mark processed).
      _original = null;
      _draftItem = draftItem;
      emit(ZettelEditReady(draft: draftItem));
      return;
    }
    final id = event.id;
    if (id == null) {
      _original = null;
      emit(const ZettelEditReady());
      return;
    }
    emit(const ZettelEditLoading());
    final result = await _getZettelById(id);
    result.fold(
      (failure) => emit(ZettelEditError(failure.message, blocking: true)),
      (zettel) {
        _original = zettel;
        emit(ZettelEditReady(initial: zettel));
      },
    );
  }

  Future<void> _onSubmitted(
    ZettelEditSubmitted event,
    Emitter<ZettelEditState> emit,
  ) async {
    final title = event.title.trim();
    if (title.isEmpty) {
      emit(const ZettelEditError(emptyTitleMessage));
      return;
    }
    emit(const ZettelEditSaving());
    final original = _original;
    final draftItem = _draftItem;
    final Either<Failure, Zettel> result;
    if (draftItem != null) {
      result = await _transplantSeedling(
        TransplantSeedlingParams(
          item: draftItem,
          title: title,
          body: event.body,
          tags: event.tags,
        ),
      );
    } else if (original == null) {
      result = await _createZettel(
        CreateZettelParams(title: title, body: event.body, tags: event.tags),
      );
    } else {
      result = await _updateZettel(
        original.copyWith(title: title, body: event.body, tags: event.tags),
      );
    }
    emit(
      result.fold(
        (failure) => ZettelEditError(failure.message),
        (zettel) => ZettelEditSaved(zettel),
      ),
    );
  }
}
