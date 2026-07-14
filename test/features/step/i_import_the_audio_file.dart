import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/widgets/capture_sources_view.dart';

import 'bdd_world.dart';

/// Usage: I import the audio file {'meeting.m4a'}
///
/// The native file picker (`file_selector.openFile`, hard-called by
/// `CaptureSourcesView` without an injectable wrapper) cannot run in a
/// widget test, so this step dispatches [CaptureAudioFilePicked] — the
/// exact event the picker callback dispatches — with the chosen file.
/// A default transcript is seeded when no Given scripted one.
Future<void> iImportTheAudioFile(WidgetTester tester, String param1) async {
  if (fakeTranscriptionService.scriptedTranscript.isEmpty) {
    fakeTranscriptionService.scriptedTranscript =
        'Compte rendu de la réunion : décisions prises et prochaines '
        'étapes à planifier.';
  }
  final sources = find.byType(CaptureSourcesView);
  expect(
    sources,
    findsOneWidget,
    reason: 'The capture mode-selection screen should be displayed',
  );
  BlocProvider.of<CaptureBloc>(
    tester.element(sources),
  ).add(CaptureAudioFilePicked(param1));
  await tester.pumpAndSettle();
}
