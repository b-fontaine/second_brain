import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/domain/services/transcription_service.dart';
import 'package:second_brain/features/capture/presentation/bloc/dictation_transcript.dart';

void main() {
  test('a partial replaces the previous partial', () {
    const transcript = DictationTranscript();

    final withFirst = transcript.apply(
      const DictationSegment('bon', isFinal: false),
    );
    final withSecond = withFirst.apply(
      const DictationSegment('bonjour', isFinal: false),
    );

    expect(withSecond.committed, '');
    expect(withSecond.partial, 'bonjour');
    expect(withSecond.fullText, 'bonjour');
  });

  test('a final segment is committed and clears the partial', () {
    const transcript = DictationTranscript(partial: 'bonjour à');

    final committed = transcript.apply(
      const DictationSegment('bonjour à tous', isFinal: true),
    );

    expect(committed.committed, 'bonjour à tous');
    expect(committed.partial, '');
  });

  test('successive utterances are joined with a space', () {
    var transcript = const DictationTranscript();
    transcript = transcript.apply(
      const DictationSegment('première phrase', isFinal: true),
    );
    transcript = transcript.apply(
      const DictationSegment('deuxième', isFinal: false),
    );

    expect(transcript.fullText, 'première phrase deuxième');

    transcript = transcript.apply(
      const DictationSegment('deuxième phrase', isFinal: true),
    );

    expect(transcript.committed, 'première phrase deuxième phrase');
    expect(transcript.partial, '');
  });

  test('trims segment whitespace when joining', () {
    var transcript = const DictationTranscript();
    transcript = transcript.apply(
      const DictationSegment('  salut  ', isFinal: true),
    );
    transcript = transcript.apply(
      const DictationSegment(' toi ', isFinal: true),
    );

    expect(transcript.fullText, 'salut toi');
  });

  test('isEmpty reflects both committed and partial', () {
    expect(const DictationTranscript().isEmpty, isTrue);
    expect(const DictationTranscript(partial: 'a').isEmpty, isFalse);
    expect(const DictationTranscript(committed: 'a').isEmpty, isFalse);
  });
}
