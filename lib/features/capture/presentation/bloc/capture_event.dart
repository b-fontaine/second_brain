part of 'capture_bloc.dart';

sealed class CaptureEvent extends Equatable {
  const CaptureEvent();

  @override
  List<Object?> get props => const [];
}

/// User picked the clipboard card: import copied text or image.
final class CaptureClipboardRequested extends CaptureEvent {
  const CaptureClipboardRequested();
}

/// User picked an audio file to transcribe.
final class CaptureAudioFilePicked extends CaptureEvent {
  const CaptureAudioFilePicked(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// User picked a screenshot/image to run OCR on.
final class CaptureScreenshotPicked extends CaptureEvent {
  const CaptureScreenshotPicked(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// Desktop: paste an image from the clipboard and run OCR on it.
final class CapturePasteImageRequested extends CaptureEvent {
  const CapturePasteImageRequested();
}

final class CaptureDictationStarted extends CaptureEvent {
  const CaptureDictationStarted();
}

final class CaptureDictationStopped extends CaptureEvent {
  const CaptureDictationStopped();
}

/// User edited the extracted text before organizing it.
final class CaptureTextChanged extends CaptureEvent {
  const CaptureTextChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// Run the assistant on the (possibly edited) extracted text.
final class CaptureOrganizeRequested extends CaptureEvent {
  const CaptureOrganizeRequested();
}

/// Save the capture to the inbox without assistant drafts.
final class CaptureSaveToInboxRequested extends CaptureEvent {
  const CaptureSaveToInboxRequested();
}

/// User edited a proposed draft (title/body/tags).
final class CaptureDraftChanged extends CaptureEvent {
  const CaptureDraftChanged(this.index, this.draft);

  final int index;
  final ZettelDraft draft;

  @override
  List<Object?> get props => [index, draft];
}

final class CaptureDraftAccepted extends CaptureEvent {
  const CaptureDraftAccepted(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

final class CaptureAcceptAllRequested extends CaptureEvent {
  const CaptureAcceptAllRequested();
}

/// Reject the proposed drafts; the inbox item stays pending.
final class CaptureDraftsRejected extends CaptureEvent {
  const CaptureDraftsRejected();
}

/// Back to the capture mode selection.
final class CaptureReset extends CaptureEvent {
  const CaptureReset();
}

/// Internal: a dictation segment (or failure) arrived from the STT stream.
final class _CaptureDictationSegmentReceived extends CaptureEvent {
  const _CaptureDictationSegmentReceived(this.result);

  final Either<Failure, DictationSegment> result;

  @override
  List<Object?> get props => [result];
}
