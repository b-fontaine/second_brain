/// Data-layer exceptions. Repositories catch these and convert them
/// into [Failure]s; they must never escape the data layer.
class VaultException implements Exception {
  const VaultException(this.message);
  final String message;

  @override
  String toString() => 'VaultException: $message';
}

class GitException implements Exception {
  const GitException(this.message);
  final String message;

  @override
  String toString() => 'GitException: $message';
}

class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => 'AiException: $message';
}

class TranscriptionException implements Exception {
  const TranscriptionException(this.message);
  final String message;

  @override
  String toString() => 'TranscriptionException: $message';
}

class OcrException implements Exception {
  const OcrException(this.message);
  final String message;

  @override
  String toString() => 'OcrException: $message';
}
