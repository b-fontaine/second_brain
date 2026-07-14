import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/domain/services/clipboard_service.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/widgets/drafts_review_view.dart';

import 'bdd_world.dart';
import 'i_choose_to_paste.dart';
import 'i_tap_the_seed_button.dart';

/// Usage: the capture assistant proposed a draft titled {'Mémoire de travail'}
///
/// Drives the full clipboard-capture journey (seed dial, « Coller » chip)
/// with a single-paragraph text whose first line is the wanted title (the
/// fake LLM proposes one draft per paragraph, first line as title), landing
/// on the drafts review.
Future<void> theCaptureAssistantProposedADraftTitled(
  WidgetTester tester,
  String param1,
) async {
  fakeClipboardService.content = ClipboardContent(
    text:
        '$param1\n'
        'Corps de la note proposée par l’assistant à partir du contenu '
        'copié dans le presse-papiers.',
  );

  await iTapTheSeedButton(tester);
  await iChooseToPaste(tester);

  await tester.tap(find.text('Organiser avec l’assistant'));
  await tester.pumpAndSettle();

  // The review screen shows a draft carrying exactly the wanted title.
  final review = find.byType(DraftsReviewView);
  expect(
    review,
    findsOneWidget,
    reason: 'The drafts review screen should be displayed',
  );
  final state =
      BlocProvider.of<CaptureBloc>(tester.element(review)).state
          as CaptureDraftsReview;
  expect(state.drafts.map((draft) => draft.title), contains(param1));
}
