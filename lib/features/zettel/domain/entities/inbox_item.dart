import 'package:equatable/equatable.dart';

/// Origin of a captured piece of content.
enum CaptureType { clipboard, audio, screenshot, dictation }

/// Lifecycle of an inbox item: captured, then processed into zettels
/// (or discarded).
enum InboxStatus { pending, processed, discarded }

/// A raw capture waiting to be processed into atomic zettels.
///
/// Persisted in the vault's `inbox/` folder so no capture is ever lost,
/// even if the AI assistant is unavailable.
class InboxItem extends Equatable {
  const InboxItem({
    required this.id,
    required this.type,
    required this.rawText,
    required this.capturedAt,
    this.assetPath,
    this.status = InboxStatus.pending,
  });

  /// Unique id (timestamp-based, same convention as zettel ids but
  /// belonging to the inbox namespace).
  final String id;

  final CaptureType type;

  /// Extracted text: clipboard content, transcript, or OCR output.
  final String rawText;

  final DateTime capturedAt;

  /// Relative vault path of the original asset (audio file, image),
  /// when the capture had one.
  final String? assetPath;

  final InboxStatus status;

  InboxItem copyWith({InboxStatus? status, String? rawText}) {
    return InboxItem(
      id: id,
      type: type,
      rawText: rawText ?? this.rawText,
      capturedAt: capturedAt,
      assetPath: assetPath,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [id, type, rawText, capturedAt, assetPath, status];
}
