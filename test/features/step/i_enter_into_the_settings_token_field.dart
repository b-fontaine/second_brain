import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I enter {'new-token'} into the settings token field
Future<void> iEnterIntoTheSettingsTokenField(
  WidgetTester tester,
  String param1,
) async {
  await tester.enterText(
    find.byKey(const Key('settings_token_field')),
    param1,
  );
  await tester.pump();
}
