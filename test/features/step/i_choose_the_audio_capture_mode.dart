import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose the audio capture mode
///
/// Asserts the « Fichier audio » source card is offered. The card is NOT
/// tapped: its handler hard-calls the native file picker
/// (`file_selector.openFile` in `CaptureSourcesView`, no injectable
/// wrapper), which cannot run in a widget test. The file selection itself
/// is injected by "I import the audio file" through the bloc event the
/// picker callback would dispatch.
Future<void> iChooseTheAudioCaptureMode(WidgetTester tester) async {
  expect(
    find.text('Fichier audio'),
    findsOneWidget,
    reason: 'The audio capture mode should be offered',
  );
}
