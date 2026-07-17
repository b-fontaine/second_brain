import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/core/theme/serre_tokens.dart';
import 'package:second_brain/features/assistant/domain/entities/assistant_answer.dart';
import 'package:second_brain/features/assistant/presentation/bloc/chat_state.dart';
import 'package:second_brain/features/assistant/presentation/bloc/sow_synthesis_cubit.dart';
import 'package:second_brain/features/assistant/presentation/widgets/chat_message_bubble.dart';
import 'package:second_brain/features/assistant/presentation/widgets/sow_synthesis_listener.dart';
import 'package:second_brain/features/capture/domain/services/capture_intake.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';

class MockCaptureIntake extends Mock implements CaptureIntake {}

void main() {
  late MockCaptureIntake intake;

  const tDraft = SeedDraft(
    type: CaptureType.assistant,
    kind: SeedKind.text,
    text: 'Réponse de synthèse.',
    title: 'Synthèse',
  );
  final tItem = InboxItem(
    id: '20260716120000',
    type: CaptureType.assistant,
    rawText: 'Réponse de synthèse.',
    capturedAt: DateTime(2026, 7, 16, 12),
  );

  setUpAll(() {
    registerFallbackValue(const TextPayload('x'));
    registerFallbackValue(tDraft);
  });

  setUp(() {
    intake = MockCaptureIntake();
  });

  /// Real router (bubble taps push `/note/:id`), real light theme (Serre
  /// tokens), real cubit over the mocked intake, and the production
  /// SnackBar listener — the exact wiring of the chat page.
  Widget harness(ChatMessage message) {
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (context, state) => BlocProvider(
            create: (_) => SowSynthesisCubit(intake),
            child: Scaffold(
              body: SowSynthesisListener(
                child: ChatMessageBubble(message: message),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/note/:id',
          builder: (context, state) =>
              Scaffold(body: Text('détail ${state.pathParameters['id']}')),
        ),
      ],
    );
    return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
  }

  /// The bubble's outer card (first Container under the bubble widget).
  BoxDecoration bubbleDecoration(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ChatMessageBubble),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  group('bubble styles (Serre palette)', () {
    testWidgets('user bubble is an arbre-green card with light text', (
      tester,
    ) async {
      await tester.pumpWidget(harness(ChatMessage.user('Bonjour jardin')));

      const tokens = SerreTokens.light;
      final decoration = bubbleDecoration(tester);
      expect(decoration.color, tokens.arbre);
      expect(decoration.border, isNull);
      final text = tester.widget<Text>(find.text('Bonjour jardin'));
      expect(text.style?.color, tokens.paper);
      // No seeding action on the user's own question.
      expect(find.text('Semer cette synthèse'), findsNothing);
    });

    testWidgets('assistant bubble is an ivory card with a hairline border', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(ChatMessage.assistant(text: 'Réponse du jardin.')),
      );

      const tokens = SerreTokens.light;
      final decoration = bubbleDecoration(tester);
      expect(decoration.color, tokens.surface);
      expect(decoration.border, Border.all(color: tokens.line));
    });

    testWidgets('error bubble keeps the error container', (tester) async {
      await tester.pumpWidget(harness(ChatMessage.error('Modèle absent')));

      final decoration = bubbleDecoration(tester);
      expect(decoration.color, AppTheme.light.colorScheme.errorContainer);
      expect(find.text('Semer cette synthèse'), findsNothing);
    });
  });

  group('sources', () {
    final message = ChatMessage.assistant(
      text: 'Réponse sourcée.',
      sources: [
        AssistantSource(
          id: ZettelId.fromString('20260101120000'),
          title: 'Mémoire de travail',
          linkCount: 5,
        ),
      ],
    );

    testWidgets('shows one chip per source, titled with a maturity badge', (
      tester,
    ) async {
      await tester.pumpWidget(harness(message));

      expect(find.text('Sources'), findsOneWidget);
      final chip = find.widgetWithText(ActionChip, 'Mémoire de travail');
      expect(chip, findsOneWidget);
      // 5 links → « arbre » maturity dot.
      final badge = find.descendant(
        of: chip,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
              (widget.decoration! as BoxDecoration).color ==
                  SerreTokens.light.arbre,
        ),
      );
      expect(badge, findsOneWidget);
    });

    testWidgets('tapping a source chip opens the note detail', (tester) async {
      await tester.pumpWidget(harness(message));

      await tester.tap(find.text('Mémoire de travail'));
      await tester.pumpAndSettle();

      expect(find.text('détail 20260101120000'), findsOneWidget);
    });

    testWidgets('falls back to the raw id when the title is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          ChatMessage.assistant(
            text: 'Réponse.',
            sources: [
              AssistantSource(id: ZettelId.fromString('20260101120000')),
            ],
          ),
        ),
      );

      expect(find.widgetWithText(ActionChip, '20260101120000'), findsOneWidget);
    });
  });

  group('« Et peut-être » (retrieved but not cited)', () {
    final message = ChatMessage.assistant(
      text: 'Réponse.',
      sources: [
        AssistantSource(
          id: ZettelId.fromString('20260101120000'),
          title: 'Mémoire de travail',
        ),
      ],
      related: [
        AssistantSource(
          id: ZettelId.fromString('20260102120000'),
          title: 'Charge cognitive',
        ),
      ],
    );

    testWidgets('lists the related notes under a discreet header', (
      tester,
    ) async {
      await tester.pumpWidget(harness(message));

      expect(
        find.text('Et peut-être — notes proches non citées'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ActionChip, 'Charge cognitive'),
        findsOneWidget,
      );
    });

    testWidgets('hides the section when everything was cited', (tester) async {
      await tester.pumpWidget(harness(ChatMessage.assistant(text: 'Réponse.')));

      expect(
        find.text('Et peut-être — notes proches non citées'),
        findsNothing,
      );
    });

    testWidgets('tapping a related note opens its detail', (tester) async {
      await tester.pumpWidget(harness(message));

      await tester.tap(find.text('Charge cognitive'));
      await tester.pumpAndSettle();

      expect(find.text('détail 20260102120000'), findsOneWidget);
    });
  });

  group('« Semer cette synthèse »', () {
    testWidgets(
      'sows the answer through the intake and confirms with a SnackBar',
      (tester) async {
        when(
          () => intake.analyze(any()),
        ).thenAnswer((_) async => const Right(tDraft));
        when(() => intake.sow(any())).thenAnswer((_) async => Right(tItem));
        await tester.pumpWidget(
          harness(ChatMessage.assistant(text: 'Réponse de synthèse.')),
        );

        await tester.tap(find.text('Semer cette synthèse'));
        // One pump per hop: intake microtasks, listener reaction, then the
        // SnackBar's entrance frame.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        final payload =
            verify(() => intake.analyze(captureAny())).captured.single
                as TextPayload;
        expect(payload.text, 'Réponse de synthèse.');
        expect(payload.source, CaptureType.assistant);
        verify(() => intake.sow(tDraft)).called(1);
        expect(find.textContaining('Semé en pépinière'), findsOneWidget);
      },
    );

    testWidgets('surfaces a seeding failure as a SnackBar', (tester) async {
      when(() => intake.analyze(any())).thenAnswer(
        (_) async => const Left(ValidationFailure('Aucun texte à semer')),
      );
      await tester.pumpWidget(harness(ChatMessage.assistant(text: 'Réponse.')));

      await tester.tap(find.text('Semer cette synthèse'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Aucun texte à semer'), findsOneWidget);
      verifyNever(() => intake.sow(any()));
    });
  });
}
