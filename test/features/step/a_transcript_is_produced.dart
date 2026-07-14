import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/widgets/extracted_text_view.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';

import 'bdd_world.dart';

/// Usage: a transcript is produced
///
/// The fake engine transcribed the imported file and the capture flow now
/// holds a non-empty audio transcript.
Future<void> aTranscriptIsProduced(WidgetTester tester) async {
  expect(
    fakeTranscriptionService.transcribedFiles,
    isNotEmpty,
    reason: 'The transcription engine should have received the file',
  );

  final view = find.byType(ExtractedTextView);
  expect(view, findsOneWidget);
  final state = BlocProvider.of<CaptureBloc>(tester.element(view)).state;
  expect(state, isA<CaptureTextEditing>());
  final editing = state as CaptureTextEditing;
  expect(editing.type, CaptureType.audio);
  expect(
    editing.text.trim(),
    isNotEmpty,
    reason: 'The produced transcript should not be empty',
  );
}
