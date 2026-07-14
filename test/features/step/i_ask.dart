import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/assistant/presentation/widgets/chat_input_bar.dart';

/// Usage: I ask {'Que sais-je sur la mémoire de travail ?'}
///
/// Types the question in the chat input bar and taps the send button, then
/// settles: the fake LLM completes in microtasks, so the generating
/// indicator disappears within a couple of frames.
Future<void> iAsk(WidgetTester tester, String param1) async {
  final field = find.descendant(
    of: find.byType(ChatInputBar),
    matching: find.byType(TextField),
  );
  expect(
    field,
    findsOneWidget,
    reason: 'The chat page should show its question input field',
  );
  await tester.enterText(field, param1);
  await tester.pump();
  await tester.tap(find.byTooltip('Envoyer'));
  await tester.pumpAndSettle();
}
