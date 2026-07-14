import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../services/ocr_service.dart';

/// Extracts the text of a screenshot/image via the platform OCR engine.
@injectable
class RecognizeScreenshot
    implements UseCase<String, RecognizeScreenshotParams> {
  const RecognizeScreenshot(this._ocr);

  final OcrService _ocr;

  @override
  Future<Either<Failure, String>> call(RecognizeScreenshotParams params) async {
    try {
      final text = await _ocr.recognizeText(params.path);
      if (text.trim().isEmpty) {
        return const Left(
          OcrFailure("Aucun texte n'a été détecté dans l'image"),
        );
      }
      return Right(text);
    } on OcrException catch (e) {
      return Left(OcrFailure(e.message));
    }
  }
}

class RecognizeScreenshotParams extends Equatable {
  const RecognizeScreenshotParams(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}
