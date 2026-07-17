import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../capture/domain/services/capture_intake.dart';
import '../../../zettel/domain/entities/inbox_item.dart';
import 'sow_synthesis_state.dart';

/// « Semer cette synthèse » : turns an assistant answer into a draft of
/// the nursery inbox (« Pépinière — brouillons à valider ») through the
/// regular seeding intake — analyze (best-effort title/parcelles
/// enrichment) then a single sow write, exactly like a dictation capture.
@injectable
class SowSynthesisCubit extends Cubit<SowSynthesisState> {
  SowSynthesisCubit(this._captureIntake) : super(const SowSynthesisIdle());

  final CaptureIntake _captureIntake;

  /// Sows [synthesis] (the markdown answer, `[[id]]` citations included)
  /// as a pending inbox item. Concurrent taps are ignored while a seeding
  /// is in flight.
  Future<void> sow(String synthesis) async {
    if (state is SowSynthesisSowing) return;
    emit(const SowSynthesisSowing());

    final analyzed = await _captureIntake.analyze(
      TextPayload(synthesis, source: CaptureType.assistant),
    );
    await analyzed.fold(
      (failure) async {
        if (!isClosed) emit(SowSynthesisFailure(failure.message));
      },
      (draft) async {
        final sown = await _captureIntake.sow(draft);
        if (isClosed) return;
        sown.fold(
          (failure) => emit(SowSynthesisFailure(failure.message)),
          (_) => emit(const SowSynthesisSown()),
        );
      },
    );
  }

  /// Returns to idle once the outcome has been surfaced to the user.
  void reset() {
    if (!isClosed) emit(const SowSynthesisIdle());
  }
}
