import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the seed preview shows the detected type {'Texte'}
///
/// The « aperçu avant semis » screen displays the detected content family
/// (Texte / Image / Audio) as its type chip.
Future<void> theSeedPreviewShowsTheDetectedType(
  WidgetTester tester,
  String param1,
) async {
  final chip = find.byKey(const Key('seed-preview-kind'));
  expect(
    chip,
    findsOneWidget,
    reason: 'The sowing preview should display its detected-type chip',
  );
  expect(
    find.descendant(of: chip, matching: find.text('Type détecté : $param1')),
    findsOneWidget,
    reason: 'The detected type should be « $param1 »',
  );
}
