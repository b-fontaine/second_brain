import 'package:flutter_test/flutter_test.dart';

/// Usage: the sync status shows up to date
///
/// The AppBar `SyncStatusIndicator` renders the online upToDate state as
/// the cloud_done IconButton with the 'Synchronisé' tooltip.
Future<void> theSyncStatusShowsUpToDate(WidgetTester tester) async {
  expect(
    find.byTooltip('Synchronisé'),
    findsOneWidget,
    reason: "The sync indicator should show 'Synchronisé'",
  );
}
