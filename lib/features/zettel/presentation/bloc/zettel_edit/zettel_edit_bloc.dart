import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../../core/error/failures.dart';
import '../../../domain/entities/zettel.dart';
import '../../../domain/entities/zettel_id.dart';
import '../../../domain/usecases/create_zettel.dart';
import '../../../domain/usecases/get_zettel_by_id.dart';
import '../../../domain/usecases/update_zettel.dart';

part 'zettel_edit_event.dart';
part 'zettel_edit_state.dart';

/// Drives note creation ([CreateZettel]) and edition ([UpdateZettel]).
@injectable
class ZettelEditBloc extends Bloc<ZettelEditEvent, ZettelEditState> {
  ZettelEditBloc(this._createZettel, this._updateZettel, this._getZettelById)
    : super(const ZettelEditInitial()) {
    on<ZettelEditStarted>(_onStarted);
    on<ZettelEditSubmitted>(_onSubmitted);
  }

  static const String emptyTitleMessage = 'Le titre ne peut pas être vide';

  final CreateZettel _createZettel;
  final UpdateZettel _updateZettel;
  final GetZettelById _getZettelById;

  /// Loaded note when editing; null when creating.
  Zettel? _original;

  Future<void> _onStarted(
    ZettelEditStarted event,
    Emitter<ZettelEditState> emit,
  ) async {
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
    final Either<Failure, Zettel> result;
    if (original == null) {
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
