import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I enter {'ghp_token123'} into the access token field
Future<void> iEnterIntoTheAccessTokenField(
  WidgetTester tester,
  String param1,
) async {
  await tester.enterText(find.byKey(const Key('token_field')), param1);
  await tester.pump();
}
