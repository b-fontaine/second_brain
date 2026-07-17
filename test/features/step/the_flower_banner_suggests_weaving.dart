import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the flower banner suggests weaving {'Mémoire de travail'}
///
/// The editor's « fleur » banner surfaces the close note found while
/// typing: « X » semble proche — tisser ?
Future<void> theFlowerBannerSuggestsWeaving(
  WidgetTester tester,
  String param1,
) async {
  final banner = find.byKey(const Key('pollination-banner'));
  expect(
    banner,
    findsOneWidget,
    reason: 'The « fleur » banner should be visible after the debounce',
  );
  expect(
    find.descendant(
      of: banner,
      matching: find.text('« $param1 » semble proche — tisser ?'),
    ),
    findsOneWidget,
    reason: "The banner should suggest weaving '$param1'",
  );
}
