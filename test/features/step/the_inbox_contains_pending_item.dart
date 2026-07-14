import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/domain/repositories/inbox_repository.dart';

import 'bdd_world.dart';

/// Usage: the inbox contains {1} pending item
Future<void> theInboxContainsPendingItem(
  WidgetTester tester,
  num param1,
) async {
  final result = await getIt<InboxRepository>().getPendingItems();
  final pending = result.getOrElse(
    (failure) => throw StateError('getPendingItems: ${failure.message}'),
  );
  expect(pending, hasLength(param1.toInt()));
}
