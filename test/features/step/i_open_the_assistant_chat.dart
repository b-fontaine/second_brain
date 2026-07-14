import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/assistant/data/datasources/vault_rag_index.dart';
import 'package:second_brain/features/assistant/presentation/pages/assistant_chat_page.dart';

import 'bdd_world.dart';

/// Usage: I open the assistant chat
///
/// Navigates like a user: taps the 'Assistant' destination of the adaptive
/// shell (left of the central seed button in the compact bottom bar — the
/// 800x600 test surface is below the 840 dp breakpoint), then settles so
/// the model status check completes and the input bar is enabled.
Future<void> iOpenTheAssistantChat(WidgetTester tester) async {
  // Opening the chat instantiates the VaultRagIndex singleton, which
  // subscribes to the vault-change stream inside THIS test's FakeAsync
  // zone. Cancel that subscription before the test's zone dies: the next
  // scenario's `getIt.reset()` awaits VaultRagIndex.dispose(), and a
  // broadcast-stream cancel scheduled in a dead FakeAsync zone would never
  // complete (observed as a 0%-CPU hang of the following scenario).
  // Double-dispose is safe: dispose() nulls the subscription.
  addTearDown(() => getIt<VaultRagIndex>().dispose());

  final destination = find.descendant(
    of: find.byKey(const Key('seed-navigation-bar')),
    matching: find.text('Assistant'),
  );
  expect(
    destination,
    findsOneWidget,
    reason: "The shell navigation should offer an 'Assistant' destination",
  );
  await tester.tap(destination);
  await tester.pumpAndSettle();
  expect(
    find.byType(AssistantChatPage),
    findsOneWidget,
    reason: 'Tapping the Assistant destination should open the chat page',
  );
}
