import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/sync/presentation/widgets/sync_shell_scope.dart';

/// Usage: the offline banner counts {1} note waiting for the rain
///
/// While local commits wait for connectivity, the static shell banner
/// (key `sync-offline-banner`) announces « n note(s) attendent la pluie —
/// synchronisation à la reconnexion ».
Future<void> theOfflineBannerCountsNoteWaitingForTheRain(
  WidgetTester tester,
  num param1,
) async {
  final banner = find.byKey(const Key('sync-offline-banner'));
  expect(
    banner,
    findsOneWidget,
    reason: 'The offline banner should be visible (offline + pending push)',
  );
  expect(
    find.descendant(
      of: banner,
      matching: find.text(SyncOfflineBanner.messageFor(param1.toInt())),
    ),
    findsOneWidget,
    reason: 'The banner should count the notes waiting for the rain',
  );
}
