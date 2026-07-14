import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose the screenshot capture mode
///
/// Asserts the « Capture d’écran » source card is offered. The card is NOT
/// tapped: its handler hard-calls the native pickers (`ImagePicker` on
/// mobile, `file_selector.openFile` on desktop, in `CaptureSourcesView`,
/// no injectable wrapper), which cannot run in a widget test. The image
/// selection itself is injected by "I import the image file" through the
/// bloc event the picker callback would dispatch.
Future<void> iChooseTheScreenshotCaptureMode(WidgetTester tester) async {
  expect(
    find.text('Capture d’écran'),
    findsOneWidget,
    reason: 'The screenshot capture mode should be offered',
  );
}
