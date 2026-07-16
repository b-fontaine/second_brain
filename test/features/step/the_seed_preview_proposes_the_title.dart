import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the seed preview proposes the title {'Note copiée sur les jardins partagés'}
///
/// The editable « Titre proposé » field of the sowing preview is pre-filled
/// with the enrichment proposal (local AI JSON, or first-line fallback).
Future<void> theSeedPreviewProposesTheTitle(
  WidgetTester tester,
  String param1,
) async {
  final fieldFinder = find.byKey(const Key('seed-preview-title'));
  expect(
    fieldFinder,
    findsOneWidget,
    reason: 'The sowing preview should display its proposed-title field',
  );
  final field = tester.widget<TextField>(fieldFinder);
  expect(
    field.controller?.text,
    param1,
    reason: 'The proposed title should be « $param1 »',
  );
}
