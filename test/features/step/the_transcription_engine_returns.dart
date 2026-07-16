import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the transcription engine returns {'Relevé vocal sur les ruches urbaines'}
///
/// Scripts the fake STT engine: the next transcribed file yields a
/// transcript whose first line is the given text — with the default
/// (prose) fake AI answer, the intake falls back on that first line as
/// the proposed title.
Future<void> theTranscriptionEngineReturns(
  WidgetTester tester,
  String param1,
) async {
  fakeTranscriptionService.scriptedTranscript =
      '$param1\n'
      'La transcription complète détaille les observations enregistrées '
      'sur le terrain.';
}
