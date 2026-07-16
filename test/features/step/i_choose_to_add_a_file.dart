import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I choose to add a file
///
/// Asserts the « Ajouter un fichier » chip is offered by the seed dial. The
/// chip is NOT tapped: its handler hard-calls the native file picker
/// (`file_selector.openFile` via `seedByFile`, no injectable wrapper),
/// which cannot run in a widget test. The file selection itself is injected
/// by "I import the audio file" / "I import the image file", which perform
/// the navigation the picker callback would (see `worldOpenSeedPreview`).
Future<void> iChooseToAddAFile(WidgetTester tester) async {
  expect(
    find.byKey(const Key('seed-dial-file')),
    findsOneWidget,
    reason: 'The seed dial should offer the « Ajouter un fichier » entry',
  );
}
