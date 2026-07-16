import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/presentation/bloc/zettel_edit/zettel_edit_bloc.dart';
import 'package:second_brain/features/zettel/presentation/pages/zettel_edit_page.dart';

class MockZettelEditBloc extends MockBloc<ZettelEditEvent, ZettelEditState>
    implements ZettelEditBloc {}

void main() {
  late MockZettelEditBloc bloc;

  setUp(() {
    bloc = MockZettelEditBloc();
    getIt.registerFactory<ZettelEditBloc>(() => bloc);
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
}
