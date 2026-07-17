import 'package:flutter_test/flutter_test.dart';

import 'bdd_world.dart';

/// Usage: the last synchronization resolved {2} conflicts
///
/// Scripts the fake git backend so the next pull "resolves" [param1]
/// conflicts local-wins (remote copies under `conflicts/`, like the real
/// GitClient), then runs it. The emitted status carries the conflict count:
/// the shell toast fires on its rising edge and the settings screen will
/// show the amber card.
Future<void> theLastSynchronizationResolvedConflicts(
  WidgetTester tester,
  num param1,
) async {
  fakeGitSyncRepository.conflictsOnNextSynchronize = param1.toInt();
  final result = await fakeGitSyncRepository.synchronize();
  expect(
    result.isRight(),
    isTrue,
    reason: 'The scripted synchronization should succeed',
  );
  // Render the new status (conflict toast included).
  await tester.pumpAndSettle();
}
