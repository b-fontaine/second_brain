import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../services/transcription_service.dart';

/// Makes sure the on-device STT models are installed, downloading them on
/// first use. Emits progress 0.0 → 1.0; emits 1.0 immediately when the
/// models are already installed.
@injectable
class EnsureSttModel implements StreamUseCase<double, NoParams> {
  const EnsureSttModel(this._transcription);

  final TranscriptionService _transcription;

  @override
  Stream<Either<Failure, double>> call(NoParams params) async* {
    try {
      if (await _transcription.isReady()) {
        yield const Right(1.0);
        return;
      }
      await for (final progress in _transcription.installModel()) {
        yield Right(progress);
      }
      yield const Right(1.0);
    } on TranscriptionException catch (e) {
      yield Left(TranscriptionFailure(e.message));
    }
  }
}
