import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/sync/presentation/widgets/sync_shell_scope.dart';

/// Usage: the conflict toast explains the conflicts folder
///
/// The shell shows the pedagogical SnackBar once per rising conflict edge:
/// the remote copy is safe under `conflicts/`, nothing was lost.
Future<void> theConflictToastExplainsTheConflictsFolder(
  WidgetTester tester,
) async {
  expect(
    find.text(SyncShellScope.conflictToastMessage),
    findsOneWidget,
    reason: 'The pedagogical conflict toast should be visible',
  );
}
