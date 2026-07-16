import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/di/injection.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/bloc/dictation_transcript.dart';
import 'package:second_brain/features/capture/presentation/pages/capture_page.dart';
import 'package:second_brain/features/capture/presentation/widgets/dictation_view.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';

class MockCaptureBloc extends MockBloc<CaptureEvent, CaptureState>
    implements CaptureBloc {}

void main() {
  late MockCaptureBloc bloc;

  final tSownItem = InboxItem(
    id: '20260716120000',
    type: CaptureType.dictation,
    rawText: 'bonjour à tous',
    capturedAt: DateTime(2026, 7, 16, 12),
    title: 'Bonjour',
    tags: const ['parcelle'],
  );

  setUp(() async {
    await getIt.reset();
    bloc = MockCaptureBloc();
    getIt.registerFactory<CaptureBloc>(() => bloc);
  });

  tearDown(() => getIt.reset());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const CapturePage()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a running dictation fills the whole screen with the immersive view',
    (tester) async {
      whenListen(
        bloc,
        const Stream<CaptureState>.empty(),
        initialState: const CaptureDictationRunning(
          DictationTranscript(committed: 'bonjour'),
        ),
      );

      await pumpPage(tester);

      expect(find.byType(DictationView), findsOneWidget);
      // No standard « Semer » app bar: the night surface owns the screen.
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Arrêter la dictée'), findsOneWidget);
    },
  );

  testWidgets('the sowing state reports the nursery write in progress', (
    tester,
  ) async {
    whenListen(
      bloc,
      const Stream<CaptureState>.empty(),
      initialState: const CaptureSowing(),
    );

    // CaptureSowing shows a CircularProgressIndicator (infinite animation):
    // pumpAndSettle would time out. Two bounded pumps are sufficient to
    // settle the first frame and let the BlocConsumer resolve.
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const CapturePage()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Semis du brouillon en pépinière…'), findsOneWidget);
  });

  testWidgets(
    'a sown dictation returns to Explorer with the nursery SnackBar',
    (tester) async {
      whenListen(
        bloc,
        Stream<CaptureState>.fromIterable([
          const CaptureSowing(),
          CaptureSown(tSownItem),
        ]),
        initialState: const CaptureDictationRunning(
          DictationTranscript(committed: 'bonjour à tous'),
        ),
      );

      await pumpPage(tester);

      // Pumped as home (nothing to pop, no router): the listener still
      // confirms the seeding on the root messenger.
      expect(
        find.text('Semé en pépinière — brouillon à valider.'),
        findsOneWidget,
      );
    },
  );
}
