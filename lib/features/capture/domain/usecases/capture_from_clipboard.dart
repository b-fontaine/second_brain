import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../services/clipboard_service.dart';

/// Reads the system clipboard (text, or image on desktop).
///
/// Fails with a [ValidationFailure] when the clipboard is empty.
@injectable
class CaptureFromClipboard implements UseCase<ClipboardContent, NoParams> {
  const CaptureFromClipboard(this._clipboard);

  final ClipboardService _clipboard;

  @override
  Future<Either<Failure, ClipboardContent>> call(NoParams params) async {
    try {
      final content = await _clipboard.read();
      if (content.isEmpty) {
        return const Left(ValidationFailure('Le presse-papiers est vide'));
      }
      return Right(content);
    } on Exception catch (e) {
      return Left(
        ValidationFailure('Lecture du presse-papiers impossible : $e'),
      );
    }
  }
}
