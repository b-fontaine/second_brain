import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I sow the seed preview
///
/// Taps the « Semer en pépinière » CTA of the sowing preview: the reviewed
/// draft is written to the inbox nursery, the preview pops and the app
/// returns to the Explorer.
Future<void> iSowTheSeedPreview(WidgetTester tester) async {
  final sowButton = find.byKey(const Key('seed-preview-sow'));
  expect(
    sowButton,
    findsOneWidget,
    reason: 'The « Semer en pépinière » CTA should be on the preview',
  );
  // The preview scrolls (800x600 viewport): bring the CTA on-screen first.
  await tester.ensureVisible(sowButton);
  await tester.pumpAndSettle();
  await tester.tap(sowButton);
  await tester.pumpAndSettle();
}
