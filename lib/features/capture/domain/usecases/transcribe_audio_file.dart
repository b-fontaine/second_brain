import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../services/transcription_service.dart';

/// Transcribes a recorded audio file with the offline STT engine.
@injectable
class TranscribeAudioFile
    implements UseCase<String, TranscribeAudioFileParams> {
  const TranscribeAudioFile(this._transcription);

  final TranscriptionService _transcription;

  @override
  Future<Either<Failure, String>> call(TranscribeAudioFileParams params) async {
    try {
      final text = await _transcription.transcribeFile(params.path);
      return Right(text);
    } on TranscriptionException catch (e) {
      return Left(TranscriptionFailure(e.message));
    }
  }
}

class TranscribeAudioFileParams extends Equatable {
  const TranscribeAudioFileParams(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}
