import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/features/graph/domain/entities/related_note_suggestion.dart';
import 'package:second_brain/features/graph/domain/usecases/suggest_draft_links.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/presentation/bloc/zettel_edit/zettel_edit_bloc.dart';
import 'package:second_brain/features/zettel/presentation/pages/zettel_edit_page.dart';

class MockZettelEditBloc extends MockBloc<ZettelEditEvent, ZettelEditState>
    implements ZettelEditBloc {}

class MockSuggestDraftLinks extends Mock implements SuggestDraftLinks {}

void main() {
  late MockZettelEditBloc bloc;
  late MockSuggestDraftLinks suggestDraftLinks;

  setUpAll(() {
    registerFallbackValue(const SuggestDraftLinksParams(text: ''));
  });

  setUp(() {
    bloc = MockZettelEditBloc();
    suggestDraftLinks = MockSuggestDraftLinks();
    getIt
      ..registerFactory<ZettelEditBloc>(() => bloc)
      ..registerFactory<SuggestDraftLinks>(() => suggestDraftLinks);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpEditor(WidgetTester tester, Zettel note) async {
    whenListen(
      bloc,
      Stream<ZettelEditState>.fromIterable([ZettelEditReady(initial: note)]),
      initialState: const ZettelEditLoading(),
    );
    await tester.pumpWidget(
      MaterialApp(home: ZettelEditPage(zettelId: note.id.value)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('keeps the tags area bounded and the content field usable '
      'with many tags on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final note = Zettel(
      id: ZettelId.fromString('20260101120000'),
      title: 'Concept A',
      body: 'Corps de la note.',
      createdAt: DateTime(2026, 1, 1, 12),
      tags: List.generate(24, (i) => 'etiquette-numero-$i'),
    );

    await pumpEditor(tester, note);

    // Regression: the unbounded tag Wrap overflowed the column and crushed
    // the content field to zero height.
    expect(tester.takeException(), isNull);

    final tagsArea = tester.getSize(
      find.byKey(const Key('tags-editor-scroll')),
    );
    expect(tagsArea.height, lessThanOrEqualTo(108));

    final bodyField = tester.getSize(find.byKey(const Key('note-body-field')));
    expect(bodyField.height, greaterThan(40));
  });

  testWidgets('prefills the form from a nursery draft and submits a '
      'transplant', (tester) async {
    final draft = InboxItem(
      id: '20260716094100',
      type: CaptureType.dictation,
      rawText: 'Texte dicté du brouillon.',
      capturedAt: DateTime(2026, 7, 16, 9, 41),
      title: 'Brouillon dicté',
      tags: const ['jardin', 'semis'],
    );
    whenListen(
      bloc,
      Stream<ZettelEditState>.fromIterable([ZettelEditReady(draft: draft)]),
      initialState: const ZettelEditInitial(),
    );
    await tester.pumpWidget(
      MaterialApp(home: ZettelEditPage(draftItem: draft)),
    );
    await tester.pumpAndSettle();

    // Transplant mode is explicit and the proposal prefills every field.
    expect(find.text('Repiquer le brouillon'), findsOneWidget);
    expect(find.text('Brouillon dicté'), findsOneWidget);
    expect(find.text('Texte dicté du brouillon.'), findsOneWidget);
    expect(find.text('jardin'), findsOneWidget);
    expect(find.text('semis'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-note-button')));
    await tester.pump();

    verify(
      () => bloc.add(
        const ZettelEditSubmitted(
          title: 'Brouillon dicté',
          body: 'Texte dicté du brouillon.',
          tags: ['jardin', 'semis'],
        ),
      ),
    ).called(1);
  });

  group('fleur banner (pollination while typing)', () {
    const suggestion = RelatedNoteSuggestion(
      id: '20260202120000',
      title: 'Concept B',
    );
    final bodyField = find.byKey(const Key('note-body-field'));
    final banner = find.byKey(const Key('pollination-banner'));

    Future<void> pumpNewNoteEditor(WidgetTester tester) async {
      whenListen(
        bloc,
        Stream<ZettelEditState>.fromIterable([const ZettelEditReady()]),
        initialState: const ZettelEditInitial(),
      );
      await tester.pumpWidget(const MaterialApp(home: ZettelEditPage()));
      await tester.pumpAndSettle();
    }

    testWidgets('appears after the debounce and weaves the wikilink at the '
        'cursor', (tester) async {
      when(() => suggestDraftLinks(any())).thenAnswer(
        (_) async => const Right([suggestion]),
      );
      await pumpNewNoteEditor(tester);

      await tester.enterText(bodyField, 'Les jardins partagés en ville');

      // Nothing happens before the full debounce elapses.
      await tester.pump(
        ZettelEditPage.pollinationDebounce - const Duration(milliseconds: 1),
      );
      verifyNever(() => suggestDraftLinks(any()));
      expect(banner, findsNothing);

      // The debounce fires, the index answers, the banner shows up.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      verify(() => suggestDraftLinks(any())).called(1);
      expect(banner, findsOneWidget);
      expect(find.textContaining('Concept B'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pollination-weave-button')));
      await tester.pump();

      final body = tester.widget<TextField>(bodyField).controller!.text;
      expect(body, contains('[[20260202120000|Concept B]]'));
      expect(banner, findsNothing);
    });

    testWidgets('every keystroke restarts the debounce', (tester) async {
      when(() => suggestDraftLinks(any())).thenAnswer(
        (_) async => const Right([suggestion]),
      );
      await pumpNewNoteEditor(tester);

      await tester.enterText(bodyField, 'Premier jet');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(bodyField, 'Premier jet complété');
      await tester.pump(const Duration(milliseconds: 500));

      // 1 s after the first keystroke but only 500 ms after the second:
      // the lookup has not fired yet.
      verifyNever(() => suggestDraftLinks(any()));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      verify(() => suggestDraftLinks(any())).called(1);
    });

    testWidgets('the close button disables the suggestions for the session',
        (tester) async {
      when(() => suggestDraftLinks(any())).thenAnswer(
        (_) async => const Right([suggestion]),
      );
      await pumpNewNoteEditor(tester);

      await tester.enterText(bodyField, 'Les jardins partagés');
      await tester.pump(ZettelEditPage.pollinationDebounce);
      await tester.pump();
      expect(banner, findsOneWidget);

      await tester.tap(find.byKey(const Key('pollination-dismiss-button')));
      await tester.pump();
      expect(banner, findsNothing);

      // Typing again never re-triggers a lookup in this session.
      await tester.enterText(bodyField, 'Les jardins partagés, suite');
      await tester.pump(ZettelEditPage.pollinationDebounce);
      await tester.pump();
      expect(banner, findsNothing);
      verify(() => suggestDraftLinks(any())).called(1);
    });

    testWidgets('stays silent when the index fails', (tester) async {
      when(() => suggestDraftLinks(any())).thenAnswer(
        (_) async => const Left(VaultFailure('index indisponible')),
      );
      await pumpNewNoteEditor(tester);

      await tester.enterText(bodyField, 'Les jardins partagés');
      await tester.pump(ZettelEditPage.pollinationDebounce);
      await tester.pump();

      expect(banner, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
