import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../services/transcription_service.dart';

/// Thrown by [TranscriptionService] implementations when the user denies
/// microphone access. Mapped to a [PermissionFailure] by [StartDictation].
///
/// Note: lives here (not in core/error/exceptions.dart) because the core
/// contracts are frozen; consider moving it there at integration time.
class MicrophonePermissionDeniedException extends TranscriptionException {
  const MicrophonePermissionDeniedException()
    : super("L'accès au microphone a été refusé");
}

/// Starts live dictation, streaming partial then final transcript segments.
@injectable
class StartDictation implements StreamUseCase<DictationSegment, NoParams> {
  const StartDictation(this._transcription);

  final TranscriptionService _transcription;

  @override
  Stream<Either<Failure, DictationSegment>> call(NoParams params) async* {
    try {
      await for (final segment in _transcription.startDictation()) {
        yield Right(segment);
      }
    } on MicrophonePermissionDeniedException catch (e) {
      yield Left(PermissionFailure(e.message));
    } on TranscriptionException catch (e) {
      yield Left(TranscriptionFailure(e.message));
    }
  }
}
