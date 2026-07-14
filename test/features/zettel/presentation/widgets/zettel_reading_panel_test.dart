import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';
import 'package:second_brain/features/zettel/presentation/bloc/zettel_detail/zettel_detail_cubit.dart';
import 'package:second_brain/features/zettel/presentation/widgets/zettel_reading_panel.dart';

class MockZettelDetailCubit extends MockCubit<ZettelDetailState>
    implements ZettelDetailCubit {}

void main() {
  final noteId = ZettelId.fromString('20260101120000');
  final note = Zettel(
    id: noteId,
    title: 'Concept A',
    body: 'Voir [[20260202120000|Concept B]] pour approfondir.',
    createdAt: DateTime(2026, 1, 1, 12),
    tags: const ['cognition'],
  );
  final backlink = Zettel(
    id: ZettelId.fromString('20260303120000'),
    title: 'Concept C',
    body: 'Référence [[20260101120000]].',
    createdAt: DateTime(2026, 3, 3, 12),
  );

  late MockZettelDetailCubit cubit;

  setUpAll(() {
    registerFallbackValue(ZettelId.fromString('20260101120000'));
  });

  setUp(() {
    cubit = MockZettelDetailCubit();
    when(() => cubit.load(any())).thenAnswer((_) async {});
    getIt.registerFactory<ZettelDetailCubit>(() => cubit);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<GoRouter> pumpPanel(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/panel',
      routes: [
        GoRoute(
          path: '/panel',
          builder: (_, _) =>
              Scaffold(body: ZettelReadingPanel(zettelId: noteId)),
        ),
        GoRoute(
          path: '/note/:id',
          builder: (_, state) =>
              Scaffold(body: Text('detail:${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  /// Finds the tap recognizer attached to the rendered link [linkText].
  GestureRecognizer? findLinkRecognizer(WidgetTester tester, String linkText) {
    GestureRecognizer? recognizer;
    for (final element in find.byType(RichText).evaluate()) {
      (element.widget as RichText).text.visitChildren((span) {
        if (span is TextSpan &&
            span.text == linkText &&
            span.recognizer != null) {
          recognizer = span.recognizer;
          return false;
        }
        return true;
      });
      if (recognizer != null) break;
    }
    return recognizer;
  }

  group('ZettelReadingPanel', () {
    testWidgets('loads its zettel through its own cubit', (tester) async {
      whenListen(
        cubit,
        const Stream<ZettelDetailState>.empty(),
        initialState: ZettelDetailLoaded(zettel: note),
      );
      await pumpPanel(tester);

      verify(() => cubit.load(noteId)).called(1);
      expect(find.text('Concept A'), findsOneWidget);
      expect(find.text('cognition'), findsOneWidget);
      expect(find.text('Liens entrants'), findsOneWidget);
    });

    testWidgets('renders a wikilink as a tappable link that navigates', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<ZettelDetailState>.empty(),
        initialState: ZettelDetailLoaded(zettel: note),
      );
      await pumpPanel(tester);

      final recognizer = findLinkRecognizer(tester, 'Concept B');
      expect(
        recognizer,
        isNotNull,
        reason: 'the wikilink should be rendered as a tappable link',
      );
      (recognizer! as TapGestureRecognizer).onTap!();
      await tester.pumpAndSettle();

      expect(find.text('detail:20260202120000'), findsOneWidget);
    });

    testWidgets('labels a bare [[id]] wikilink with the target title', (
      tester,
    ) async {
      final bareLinkNote = Zettel(
        id: noteId,
        title: 'Concept A',
        body: 'Voir [[20260202120000]].',
        createdAt: DateTime(2026, 1, 1, 12),
      );
      whenListen(
        cubit,
        const Stream<ZettelDetailState>.empty(),
        initialState: ZettelDetailLoaded(
          zettel: bareLinkNote,
          linkTitles: const {'20260202120000': 'Concept B'},
        ),
      );
      await pumpPanel(tester);

      expect(findLinkRecognizer(tester, 'Concept B'), isNotNull);
    });

    testWidgets('navigates to a backlink when tapped', (tester) async {
      whenListen(
        cubit,
        const Stream<ZettelDetailState>.empty(),
        initialState: ZettelDetailLoaded(zettel: note, backlinks: [backlink]),
      );
      await pumpPanel(tester);

      await tester.tap(find.text('Concept C'));
      await tester.pumpAndSettle();

      expect(find.text('detail:20260303120000'), findsOneWidget);
    });

    testWidgets('shows an empty-backlinks message', (tester) async {
      whenListen(
        cubit,
        const Stream<ZettelDetailState>.empty(),
        initialState: ZettelDetailLoaded(zettel: note),
      );
      await pumpPanel(tester);

      expect(find.text('Aucun lien entrant.'), findsOneWidget);
    });

    testWidgets('blocks remote images in the markdown body', (tester) async {
      // A note synced from a compromised remote must not trigger any
      // network fetch (tracking beacon) when rendered.
      final beaconNote = Zettel(
        id: noteId,
        title: 'Concept A',
        body: 'Avant\n\n![beacon](https://attacker.example/x.png?u=victim)\n',
        createdAt: DateTime(2026, 1, 1, 12),
      );
      whenListen(
        cubit,
        const Stream<ZettelDetailState>.empty(),
        initialState: ZettelDetailLoaded(zettel: beaconNote),
      );
      await pumpPanel(tester);

      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('Image externe non chargée'), findsOneWidget);
    });

    testWidgets('shows the error message on failure', (tester) async {
      whenListen(
        cubit,
        const Stream<ZettelDetailState>.empty(),
        initialState: const ZettelDetailError('Note introuvable : x'),
      );
      await pumpPanel(tester);

      expect(find.text('Note introuvable : x'), findsOneWidget);
    });
  });
}
