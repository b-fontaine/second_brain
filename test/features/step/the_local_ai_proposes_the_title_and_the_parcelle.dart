import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the local AI proposes the title {'Semis sous serre froide'} and the parcelle {'serre'}
///
/// Scripts the fake local model to answer the strict-JSON enrichment
/// prompt of `CaptureIntake` with the given title and single parcelle.
Future<void> theLocalAiProposesTheTitleAndTheParcelle(
  WidgetTester tester,
  String param1,
  String param2,
) async {
  fakeLocalAiService.onGenerate = (prompt, systemPrompt) => jsonEncode({
    'title': param1,
    'tags': [param2],
  });
}
