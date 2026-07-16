import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/core/usecases/usecase.dart';
import 'package:second_brain/features/capture/domain/services/capture_intake.dart';
import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';
import 'package:second_brain/features/capture/domain/usecases/capture_from_clipboard.dart';
import 'package:second_brain/features/capture/domain/usecases/ensure_stt_model.dart';
import 'package:second_brain/features/capture/presentation/bloc/seed_intake_cubit.dart';
import 'package:second_brain/features/capture/presentation/pages/seed_preview_page.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';

class MockCaptureIntake extends Mock implements CaptureIntake {}

class MockCaptureFromClipboard extends Mock implements CaptureFromClipboard {}

class MockEnsureSttModel extends Mock implements EnsureSttModel {}

void main() {
  late MockCaptureIntake intake;
  late MockCaptureFromClipboard captureFromClipboard;
  late MockEnsureSttModel ensureSttModel;

  const tDraft = SeedDraft(
    type: CaptureType.clipboard,
    kind: SeedKind.text,
    text: 'Les notes atomiques rendent la connaissance réutilisable.',
    title: 'Notes atomiques',
    tags: ['jardin', 'semis'],
  );
  final tItem = InboxItem(
    id: '20260716120000',
    type: CaptureType.clipboard,
    rawText: tDraft.text,
    capturedAt: DateTime(2026, 7, 16, 12),
    title: tDraft.title,
    tags: tDraft.tags,
  );

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const TextPayload('x'));
    registerFallbackValue(tDraft);
  });

  setUp(() async {
    await getIt.reset();
    intake = MockCaptureIntake();
    captureFromClipboard = MockCaptureFromClipboard();
    ensureSttModel = MockEnsureSttModel();
    getIt.registerFactory<SeedIntakeCubit>(
      () => SeedIntakeCubit(intake, captureFromClipboard, ensureSttModel),
    );

    when(() => captureFromClipboard(any())).thenAnswer(
      (_) async => Right(ClipboardContent(text: tDraft.text)),
    );
    when(() => intake.analyze(any())).thenAnswer(
      (_) async => const Right(tDraft),
    );
    when(() => intake.sow(any())).thenAnswer((_) async => Right(tItem));
  });

  tearDown(() => getIt.reset());

  Future<void> pumpPreview(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const SeedPreviewPage(source: ClipboardSeedSource()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the detected type, editable fields and parcelles', (
    tester,
  ) async {
    await pumpPreview(tester);

    expect(find.text('Type détecté : Texte'), findsOneWidget);
    expect(find.text('Notes atomiques'), findsOneWidget);
    expect(
      find.text('Les notes atomiques rendent la connaissance réutilisable.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('seed-preview-tag-jardin')), findsOneWidget);
    expect(find.byKey(const Key('seed-preview-tag-semis')), findsOneWidget);
    expect(find.text('Semer en pépinière'), findsOneWidget);
  });

  testWidgets('sows the edited draft and confirms with a SnackBar', (
    tester,
  ) async {
    await pumpPreview(tester);

    await tester.enterText(
      find.byKey(const Key('seed-preview-title')),
      'Titre édité',
    );
    await tester.enterText(
      find.byKey(const Key('seed-preview-text')),
      'Texte édité avant semis.',
    );
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('seed-preview-sow')));
    await tester.tap(find.byKey(const Key('seed-preview-sow')));
    await tester.pumpAndSettle();

    final sown = verify(() => intake.sow(captureAny())).captured.single
        as SeedDraft;
    expect(sown.title, 'Titre édité');
    expect(sown.text, 'Texte édité avant semis.');
    expect(
      find.text('Semis déposé en pépinière — brouillon à valider.'),
      findsOneWidget,
    );
  });

  testWidgets('a removed parcelle disappears and is not sown', (tester) async {
    await pumpPreview(tester);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('seed-preview-tag-jardin')),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('seed-preview-tag-jardin')), findsNothing);
    expect(find.byKey(const Key('seed-preview-tag-semis')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('seed-preview-sow')));
    await tester.tap(find.byKey(const Key('seed-preview-sow')));
    await tester.pumpAndSettle();

    final sown = verify(() => intake.sow(captureAny())).captured.single
        as SeedDraft;
    expect(sown.tags, ['semis']);
  });

  testWidgets('a failed sow keeps the form with an inline error', (
    tester,
  ) async {
    when(
      () => intake.sow(any()),
    ).thenAnswer((_) async => const Left(VaultFailure('disque plein')));

    await pumpPreview(tester);

    await tester.ensureVisible(find.byKey(const Key('seed-preview-sow')));
    await tester.tap(find.byKey(const Key('seed-preview-sow')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Le semis a échoué'), findsOneWidget);
    expect(find.byKey(const Key('seed-preview-text')), findsOneWidget);
    expect(find.text('Semer en pépinière'), findsOneWidget);
  });

  testWidgets('an unreadable capture shows the terminal error view', (
    tester,
  ) async {
    when(() => captureFromClipboard(any())).thenAnswer(
      (_) async => const Left(ValidationFailure('Le presse-papiers est vide')),
    );

    await pumpPreview(tester);

    expect(find.text('Le presse-papiers est vide'), findsOneWidget);
    expect(find.text('Fermer'), findsOneWidget);
  });
}
