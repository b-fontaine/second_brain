import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../services/transcription_service.dart';

/// Stops the microphone and finalizes the pending dictation segments.
@injectable
class StopDictation implements UseCase<Unit, NoParams> {
  const StopDictation(this._transcription);

  final TranscriptionService _transcription;

  @override
  Future<Either<Failure, Unit>> call(NoParams params) async {
    try {
      await _transcription.stopDictation();
      return const Right(unit);
    } on TranscriptionException catch (e) {
      return Left(TranscriptionFailure(e.message));
    }
  }
}
