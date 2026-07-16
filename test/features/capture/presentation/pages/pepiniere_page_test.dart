import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/vault_write_notifier.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/features/capture/presentation/bloc/pepiniere_cubit.dart';
import 'package:second_brain/features/capture/presentation/pages/pepiniere_page.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/domain/repositories/inbox_repository.dart';
import 'package:second_brain/features/zettel/domain/usecases/transplant_seedling.dart';

class MockInboxRepository extends Mock implements InboxRepository {}

class MockTransplantSeedling extends Mock implements TransplantSeedling {}

void main() {
  late MockInboxRepository inboxRepository;
  late MockTransplantSeedling transplantSeedling;
  late VaultWriteNotifier vaultWriteNotifier;

  final clipboardItem = InboxItem(
    id: '20260716094100',
    type: CaptureType.clipboard,
    rawText: 'Les notes atomiques rendent la connaissance réutilisable.',
    capturedAt: DateTime(2026, 7, 16, 9, 41),
    title: 'Notes atomiques',
    tags: const ['jardin', 'methode'],
  );
  // Legacy capture: no enriched title, the first line stands in.
  final dictationItem = InboxItem(
    id: '20260716101500',
    type: CaptureType.dictation,
    rawText: '# Note dictée\nCorps du second semis en attente.',
    capturedAt: DateTime(2026, 7, 16, 10, 15),
  );
  final tZettel = Zettel(
    id: ZettelId.fromString('20260716110000'),
    title: 'Notes atomiques',
    body: 'Les notes atomiques rendent la connaissance réutilisable.',
    createdAt: DateTime(2026, 7, 16, 11),
  );

  setUpAll(() {
    registerFallbackValue(TransplantSeedlingParams(item: clipboardItem));
  });

  setUp(() async {
    await getIt.reset();
    inboxRepository = MockInboxRepository();
    transplantSeedling = MockTransplantSeedling();
    vaultWriteNotifier = VaultWriteNotifier();
    getIt.registerFactory<PepiniereCubit>(
      () => PepiniereCubit(
        inboxRepository,
        transplantSeedling,
        vaultWriteNotifier,
      ),
    );

    when(
      () => inboxRepository.getPendingItems(),
    ).thenAnswer((_) async => Right([clipboardItem, dictationItem]));
    when(
      () => transplantSeedling(any()),
    ).thenAnswer((_) async => Right(tZettel));
    when(
      () => inboxRepository.removeItem(any()),
    ).thenAnswer((_) async => const Right(unit));
  });

  tearDown(() async {
    vaultWriteNotifier.dispose();
    await getIt.reset();
  });

  Future<void> pumpNursery(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/pepiniere',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('page:explorer')),
        ),
        GoRoute(
          path: '/pepiniere',
          builder: (_, _) => const PepinierePage(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, state) => Scaffold(
                body: Text('edit:${(state.extra! as InboxItem).id}'),
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  group('cards', () {
    testWidgets('shows source, timestamp, proposed title, excerpt and '
        'parcelles for every pending capture', (tester) async {
      await pumpNursery(tester);

      // Functional heading next to the gardener metaphor.
      expect(
        find.text(
          '2 brouillons à valider — repiquez-les en notes '
          'ou compostez-les.',
        ),
        findsOneWidget,
      );

      // Enriched clipboard capture.
      expect(find.text('Presse-papiers · 16/07/2026 · 09:41'), findsOneWidget);
      expect(find.text('Notes atomiques'), findsOneWidget);
      expect(
        find.text('Les notes atomiques rendent la connaissance réutilisable.'),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('pepiniere-tag-${clipboardItem.id}-jardin')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('pepiniere-tag-${clipboardItem.id}-methode')),
        findsOneWidget,
      );

      // Legacy dictation capture: first line stands in for the title.
      expect(find.text('Dictée · 16/07/2026 · 10:15'), findsOneWidget);
      expect(find.text('Note dictée'), findsOneWidget);
    });

    testWidgets('the list scrolls to reach the actions of the last card', (
      tester,
    ) async {
      final many = [
        for (var i = 0; i < 8; i++)
          InboxItem(
            id: '2026071609410$i',
            type: CaptureType.clipboard,
            rawText: 'Semis numéro $i',
            capturedAt: DateTime(2026, 7, 16, 9, i),
          ),
      ];
      when(
        () => inboxRepository.getPendingItems(),
      ).thenAnswer((_) async => Right(many));
      await pumpNursery(tester);

      final lastAction = find.byKey(
        Key('pepiniere-transplant-${many.last.id}'),
      );
      await tester.scrollUntilVisible(lastAction, 200);
      // scrollUntilVisible stops when the widget is partially visible; the
      // button center may still be below the 800×600 viewport boundary.
      // ensureVisible scrolls just enough to fully expose the widget, then
      // one pump settles the scroll before the tap.
      await tester.ensureVisible(lastAction);
      await tester.pump();
      await tester.tap(lastAction);
      await tester.pumpAndSettle();

      verify(() => transplantSeedling(any())).called(1);
    });
  });

  group('repiquer', () {
    testWidgets('transplants the capture, removes its card and confirms '
        'with a SnackBar', (tester) async {
      await pumpNursery(tester);

      await tester.tap(
        find.byKey(Key('pepiniere-transplant-${clipboardItem.id}')),
      );
      await tester.pumpAndSettle();

      final params =
          verify(() => transplantSeedling(captureAny())).captured.single
              as TransplantSeedlingParams;
      expect(params.item, clipboardItem);
      expect(
        find.byKey(Key('pepiniere-card-${clipboardItem.id}')),
        findsNothing,
      );
      expect(
        find.text('Repiqué au jardin — note « Notes atomiques » créée.'),
        findsOneWidget,
      );
      // The other card stays.
      expect(
        find.byKey(Key('pepiniere-card-${dictationItem.id}')),
        findsOneWidget,
      );
    });

    testWidgets('a failed transplant keeps the card and explains', (
      tester,
    ) async {
      when(
        () => transplantSeedling(any()),
      ).thenAnswer((_) async => const Left(VaultFailure('disque plein')));
      await pumpNursery(tester);

      await tester.tap(
        find.byKey(Key('pepiniere-transplant-${clipboardItem.id}')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('pepiniere-card-${clipboardItem.id}')),
        findsOneWidget,
      );
      expect(find.text('Le repiquage a échoué : disque plein'), findsOneWidget);
    });
  });

  group('composter', () {
    testWidgets('asks for confirmation then removes the capture', (
      tester,
    ) async {
      await pumpNursery(tester);

      final compostButton = find.byKey(
        Key('pepiniere-compost-${dictationItem.id}'),
      );
      await tester.ensureVisible(compostButton);
      await tester.tap(compostButton);
      await tester.pumpAndSettle();

      expect(find.text('Composter ce semis ?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pepiniere-compost-confirm')));
      await tester.pumpAndSettle();

      verify(() => inboxRepository.removeItem(dictationItem.id)).called(1);
      expect(
        find.byKey(Key('pepiniere-card-${dictationItem.id}')),
        findsNothing,
      );
      expect(find.text('Semis composté — brouillon supprimé.'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation keeps the capture', (
      tester,
    ) async {
      await pumpNursery(tester);

      final compostButton = find.byKey(
        Key('pepiniere-compost-${dictationItem.id}'),
      );
      await tester.ensureVisible(compostButton);
      await tester.tap(compostButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(() => inboxRepository.removeItem(any()));
      expect(
        find.byKey(Key('pepiniere-card-${dictationItem.id}')),
        findsOneWidget,
      );
    });
  });

  group('modifier', () {
    testWidgets('opens the prefilled edition with the capture as extra', (
      tester,
    ) async {
      await pumpNursery(tester);

      await tester.tap(find.byKey(Key('pepiniere-edit-${clipboardItem.id}')));
      await tester.pumpAndSettle();

      expect(find.text('edit:${clipboardItem.id}'), findsOneWidget);
    });
  });

  group('état vide', () {
    testWidgets('guides towards the seed dial', (tester) async {
      when(
        () => inboxRepository.getPendingItems(),
      ).thenAnswer((_) async => const Right([]));
      await pumpNursery(tester);

      expect(find.text('La pépinière est vide'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pepiniere-empty-sow')));
      await tester.pumpAndSettle();

      expect(find.text('page:explorer'), findsOneWidget);
    });
  });
}
