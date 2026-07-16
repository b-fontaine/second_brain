import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/core/theme/serre_tokens.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/bloc/dictation_transcript.dart';
import 'package:second_brain/features/capture/presentation/widgets/dictation_view.dart';

class MockCaptureBloc extends MockBloc<CaptureEvent, CaptureState>
    implements CaptureBloc {}

void main() {
  late MockCaptureBloc bloc;

  setUp(() {
    bloc = MockCaptureBloc();
    whenListen(
      bloc,
      const Stream<CaptureState>.empty(),
      initialState: const CaptureDictationRunning(DictationTranscript()),
    );
  });

  Future<void> pumpView(
    WidgetTester tester,
    DictationTranscript transcript, {
    bool disableAnimations = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => MediaQuery(
            // copyWith keeps the test viewport metrics intact.
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: BlocProvider<CaptureBloc>.value(
              value: bloc,
              child: DictationView(transcript: transcript),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'commits to the night greenhouse backdrop with the live transcript',
    (tester) async {
      await pumpView(
        tester,
        const DictationTranscript(committed: 'bonjour', partial: 'à tous'),
      );
      await tester.pumpAndSettle();

      // Immersive surface: the dark token set is used even in light theme.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, SerreTokens.dark.paper);

      expect(find.text('Dictée en cours…'), findsOneWidget);
      final transcript = tester.widget<Text>(
        find.byKey(const Key('dictation-transcript')),
      );
      expect(transcript.textSpan?.toPlainText(), 'bonjour à tous');
      expect(find.byKey(const Key('dictation-wave')), findsOneWidget);
      expect(find.text('Arrêter la dictée'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    },
  );

  testWidgets('shows the placeholder while nothing was recognized yet', (
    tester,
  ) async {
    await pumpView(tester, const DictationTranscript());
    await tester.pumpAndSettle();

    expect(find.text('Parlez, le texte apparaît ici…'), findsOneWidget);
  });

  testWidgets(
    'a transcript update pulses the wave with a BOUNDED animation '
    '(pumpAndSettle terminates)',
    (tester) async {
      await pumpView(
        tester,
        const DictationTranscript(committed: 'bonjour'),
      );
      await tester.pumpAndSettle();

      await pumpView(
        tester,
        const DictationTranscript(committed: 'bonjour à tous'),
      );
      // The swell is a single forward() run: it MUST settle on its own.
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byKey(const Key('dictation-wave')), findsOneWidget);
    },
  );

  testWidgets('reduced motion renders a static wave (no scheduled frame)', (
    tester,
  ) async {
    await pumpView(
      tester,
      const DictationTranscript(committed: 'bonjour'),
      disableAnimations: true,
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    await pumpView(
      tester,
      const DictationTranscript(committed: 'bonjour à tous'),
      disableAnimations: true,
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byKey(const Key('dictation-wave')), findsOneWidget);
  });

  testWidgets('the stop button asks the bloc to stop (and sow)', (
    tester,
  ) async {
    await pumpView(
      tester,
      const DictationTranscript(committed: 'bonjour'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dictation-stop')));
    verify(() => bloc.add(const CaptureDictationStopped())).called(1);
  });

  testWidgets('« Annuler » resets the capture flow', (tester) async {
    await pumpView(tester, const DictationTranscript());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annuler'));
    verify(() => bloc.add(const CaptureReset())).called(1);
  });
}
