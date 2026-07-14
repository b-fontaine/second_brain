import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/widgets/drafts_review_view.dart';

/// Usage: each draft has a title, a body and suggested tags
Future<void> eachDraftHasATitleABodyAndSuggestedTags(
  WidgetTester tester,
) async {
  final review = find.byType(DraftsReviewView);
  expect(review, findsOneWidget);
  final state =
      BlocProvider.of<CaptureBloc>(tester.element(review)).state
          as CaptureDraftsReview;
  expect(state.drafts, isNotEmpty);

  for (final draft in state.drafts) {
    expect(
      draft.title.trim(),
      isNotEmpty,
      reason: 'Every proposed draft should have a title',
    );
    expect(
      draft.body.trim(),
      isNotEmpty,
      reason: "Draft '${draft.title}' should have a body",
    );
    expect(
      draft.tags,
      isNotEmpty,
      reason: "Draft '${draft.title}' should have suggested tags",
    );
  }
}
