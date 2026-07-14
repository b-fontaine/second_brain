import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: I enter {'https://github.com/user/zettelkasten.git'} into the repository url field
Future<void> iEnterIntoTheRepositoryUrlField(
  WidgetTester tester,
  String param1,
) async {
  await tester.enterText(find.byKey(const Key('repo_url_field')), param1);
  await tester.pump();
}
