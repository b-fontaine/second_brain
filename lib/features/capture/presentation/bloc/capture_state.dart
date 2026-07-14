part of 'capture_bloc.dart';

sealed class CaptureState extends Equatable {
  const CaptureState();

  @override
  List<Object?> get props => const [];
}

/// Mode selection: the four capture source cards.
final class CaptureIdle extends CaptureState {
  const CaptureIdle();
}

/// The STT model is being downloaded (first use).
final class CaptureModelInstalling extends CaptureState {
  const CaptureModelInstalling({required this.type, required this.progress});

  final CaptureType type;

  /// 0.0 → 1.0
  final double progress;

  @override
  List<Object?> get props => [type, progress];
}

/// Extraction (clipboard read, transcription, OCR) in progress.
final class CaptureExtracting extends CaptureState {
  const CaptureExtracting(this.type);

  final CaptureType type;

  @override
  List<Object?> get props => [type];
}

/// Live dictation in progress.
final class CaptureDictationRunning extends CaptureState {
  const CaptureDictationRunning(this.transcript);

  final DictationTranscript transcript;

  @override
  List<Object?> get props => [transcript];
}

/// Extracted text shown to the user for editing before organizing.
final class CaptureTextEditing extends CaptureState {
  const CaptureTextEditing({
    required this.type,
    required this.text,
    this.assetPath,
  });

  final CaptureType type;
  final String text;
  final String? assetPath;

  @override
  List<Object?> get props => [type, text, assetPath];
}

/// The assistant is splitting the capture into drafts.
final class CaptureOrganizing extends CaptureState {
  const CaptureOrganizing({
    required this.type,
    required this.text,
    this.assetPath,
  });

  final CaptureType type;
  final String text;
  final String? assetPath;

  @override
  List<Object?> get props => [type, text, assetPath];
}

/// The local AI model is missing: offer to save the capture as-is.
final class CaptureAssistantUnavailable extends CaptureState {
  const CaptureAssistantUnavailable({
    required this.type,
    required this.text,
    required this.message,
    this.assetPath,
  });

  final CaptureType type;
  final String text;
  final String message;
  final String? assetPath;

  @override
  List<Object?> get props => [type, text, message, assetPath];
}

/// Drafts proposed by the assistant, under user review.
final class CaptureDraftsReview extends CaptureState {
  const CaptureDraftsReview({
    required this.item,
    required this.drafts,
    this.acceptedCount = 0,
    this.accepting = false,
    this.errorMessage,
  });

  final InboxItem item;
  final List<ZettelDraft> drafts;

  /// Number of drafts already turned into zettels in this session.
  final int acceptedCount;

  /// True while an acceptance is being written to the vault.
  final bool accepting;

  /// Transient inline error (e.g. a draft acceptance that failed); the
  /// remaining drafts stay reviewable.
  final String? errorMessage;

  /// Note: [errorMessage] is transient and intentionally NOT carried over —
  /// any copy clears it unless a new message is provided explicitly.
  CaptureDraftsReview copyWith({
    InboxItem? item,
    List<ZettelDraft>? drafts,
    int? acceptedCount,
    bool? accepting,
    String? errorMessage,
  }) {
    return CaptureDraftsReview(
      item: item ?? this.item,
      drafts: drafts ?? this.drafts,
      acceptedCount: acceptedCount ?? this.acceptedCount,
      accepting: accepting ?? this.accepting,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    item,
    drafts,
    acceptedCount,
    accepting,
    errorMessage,
  ];
}

/// Terminal success (notes created, capture saved to inbox, or rejection).
final class CaptureSuccess extends CaptureState {
  const CaptureSuccess({required this.message, this.createdCount = 0});

  final String message;
  final int createdCount;

  @override
  List<Object?> get props => [message, createdCount];
}

/// Terminal error with a user-presentable message.
final class CaptureFailed extends CaptureState {
  const CaptureFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
