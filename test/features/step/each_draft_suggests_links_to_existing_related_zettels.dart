import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/capture/presentation/bloc/capture_bloc.dart';
import 'package:second_brain/features/capture/presentation/widgets/drafts_review_view.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';

import 'bdd_world.dart';

/// Usage: each draft suggests links to existing related zettels
///
/// Every proposed draft must carry suggested links, and each link must
/// target a zettel that really exists in the vault.
Future<void> eachDraftSuggestsLinksToExistingRelatedZettels(
  WidgetTester tester,
) async {
  final review = find.byType(DraftsReviewView);
  expect(review, findsOneWidget);
  final state =
      BlocProvider.of<CaptureBloc>(tester.element(review)).state
          as CaptureDraftsReview;
  expect(state.drafts, isNotEmpty);

  final result = await getIt<ZettelRepository>().getAllZettels();
  final zettels = result.fold<List<Zettel>>(
    (failure) => throw StateError('getAllZettels: ${failure.message}'),
    (list) => list,
  );
  final existingIds = {for (final zettel in zettels) zettel.id.value};

  for (final draft in state.drafts) {
    expect(
      draft.suggestedLinks,
      isNotEmpty,
      reason: "Draft '${draft.title}' should suggest at least one link",
    );
    for (final link in draft.suggestedLinks) {
      expect(
        existingIds,
        contains(link.value),
        reason:
            "Suggested link [[${link.value}]] of draft "
            "'${draft.title}' must target an existing zettel",
      );
    }
  }
}
