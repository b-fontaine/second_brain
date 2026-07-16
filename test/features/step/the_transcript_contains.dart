import 'package:flutter_test/flutter_test.dart';

/// Usage: the transcript contains {'ceci est une note dictée'}
///
/// The immersive dictation screen (« serre de nuit ») is still running and
/// its live transcript shows the dictated words.
Future<void> theTranscriptContains(WidgetTester tester, String param1) async {
  expect(
    find.text('Dictée en cours…'),
    findsOneWidget,
    reason: 'The live dictation screen should still be displayed',
  );
  expect(
    find.textContaining(param1),
    findsWidgets,
    reason: 'The live transcript should contain the dictated words',
  );
}
