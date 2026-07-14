import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/widgets/capture_sources_view.dart';

import 'bdd_world.dart';

/// Usage: I import the image file {'slide.png'}
///
/// The native image picker (hard-called by `CaptureSourcesView` without an
/// injectable wrapper) cannot run in a widget test, so this step dispatches
/// [CaptureScreenshotPicked] — the exact event the picker callback
/// dispatches — with the chosen file. A default OCR text is seeded when no
/// Given scripted one.
Future<void> iImportTheImageFile(WidgetTester tester, String param1) async {
  if (fakeOcrService.scriptedText.isEmpty) {
    fakeOcrService.scriptedText =
        'Texte reconnu sur la diapositive : principes d’architecture et '
        'bonnes pratiques.';
  }
  final sources = find.byType(CaptureSourcesView);
  expect(
    sources,
    findsOneWidget,
    reason: 'The capture mode-selection screen should be displayed',
  );
  BlocProvider.of<CaptureBloc>(
    tester.element(sources),
  ).add(CaptureScreenshotPicked(param1));
  await tester.pumpAndSettle();
}
