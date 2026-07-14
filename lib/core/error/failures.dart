import 'package:equatable/equatable.dart';

/// Base class for all domain-level failures returned by use cases
/// as the left side of an `Either<Failure, T>`.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Human-readable, user-presentable description.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Local vault (file system) read/write failed.
class VaultFailure extends Failure {
  const VaultFailure(super.message);
}

/// The requested zettel does not exist in the vault.
class ZettelNotFoundFailure extends Failure {
  const ZettelNotFoundFailure(this.id) : super('Note introuvable : $id');

  final String id;

  @override
  List<Object?> get props => [message, id];
}

/// Git operation failed (clone, commit, push, pull...).
class SyncFailure extends Failure {
  const SyncFailure(super.message);
}

/// No network available while a remote operation was required.
class OfflineFailure extends Failure {
  const OfflineFailure() : super('Aucune connexion réseau disponible');
}

/// Local AI model missing, still downloading, or inference error.
class AiFailure extends Failure {
  const AiFailure(super.message);
}

/// Speech-to-text engine failure (model missing, mic denied...).
class TranscriptionFailure extends Failure {
  const TranscriptionFailure(super.message);
}

/// OCR engine failure.
class OcrFailure extends Failure {
  const OcrFailure(super.message);
}

/// User input validation failed (e.g. malformed repository URL).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Required platform permission denied (microphone, photos...).
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}
