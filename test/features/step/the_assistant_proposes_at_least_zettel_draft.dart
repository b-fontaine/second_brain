import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/widgets/draft_card.dart';
import 'package:second_brain/features/capture/presentation/widgets/drafts_review_view.dart';

/// Usage: the assistant proposes at least {1} zettel draft
Future<void> theAssistantProposesAtLeastZettelDraft(
  WidgetTester tester,
  num param1,
) async {
  final review = find.byType(DraftsReviewView);
  expect(
    review,
    findsOneWidget,
    reason: 'The drafts review screen should be displayed',
  );

  final state = BlocProvider.of<CaptureBloc>(tester.element(review)).state;
  expect(state, isA<CaptureDraftsReview>());
  final drafts = (state as CaptureDraftsReview).drafts;
  expect(
    drafts.length,
    greaterThanOrEqualTo(param1.toInt()),
    reason: 'The assistant should propose at least $param1 draft(s)',
  );

  // At least one draft card is rendered on screen.
  expect(find.byType(DraftCard), findsWidgets);
}
