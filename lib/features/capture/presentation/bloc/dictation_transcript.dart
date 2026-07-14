import 'package:equatable/equatable.dart';

import '../../domain/services/transcription_service.dart';

/// Immutable accumulator of live dictation segments.
///
/// The STT engine emits, for each utterance, revisable partials (each one
/// replacing the previous) followed by one final segment which is committed.
class DictationTranscript extends Equatable {
  const DictationTranscript({this.committed = '', this.partial = ''});

  /// Finalized text, no longer subject to revision.
  final String committed;

  /// Current utterance as recognized so far (may still change).
  final String partial;

  DictationTranscript apply(DictationSegment segment) {
    if (segment.isFinal) {
      return DictationTranscript(
        committed: _join(committed, segment.text),
        partial: '',
      );
    }
    return DictationTranscript(committed: committed, partial: segment.text);
  }

  /// Committed text followed by the pending partial, space-joined.
  String get fullText => _join(committed, partial);

  bool get isEmpty => fullText.isEmpty;

  static String _join(String a, String b) {
    final left = a.trim();
    final right = b.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    return '$left $right';
  }

  @override
  List<Object?> get props => [committed, partial];
}
