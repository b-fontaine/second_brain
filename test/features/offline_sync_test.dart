// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_running_with_a_configured_vault.dart';
import './step/a_remote_repository_is_configured.dart';
import './step/the_device_is_offline.dart';
import './step/i_create_a_zettel_titled.dart';
import './step/the_zettel_is_committed_to_the_local_repository.dart';
import './step/the_sync_status_shows_pending_changes.dart';
import './step/the_device_comes_back_online.dart';
import './step/the_pending_commits_are_pushed_to_the_remote.dart';
import './step/the_sync_status_shows_up_to_date.dart';
import './step/the_device_is_online.dart';

void main() {
  group('''Offline-first with automatic git synchronization''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsRunningWithAConfiguredVault(tester);
      await aRemoteRepositoryIsConfigured(tester);
    }

    testWidgets('''Saving a note offline commits locally''', (tester) async {
      await bddSetUp(tester);
      await theDeviceIsOffline(tester);
      await iCreateAZettelTitled(tester, 'Note hors ligne');
      await theZettelIsCommittedToTheLocalRepository(tester);
      await theSyncStatusShowsPendingChanges(tester);
    });
    testWidgets('''Regaining connectivity triggers an automatic push''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await theDeviceIsOffline(tester);
      await iCreateAZettelTitled(tester, 'Note hors ligne');
      await theDeviceComesBackOnline(tester);
      await thePendingCommitsArePushedToTheRemote(tester);
      await theSyncStatusShowsUpToDate(tester);
    });
    testWidgets('''Saving while online syncs immediately''', (tester) async {
      await bddSetUp(tester);
      await theDeviceIsOnline(tester);
      await iCreateAZettelTitled(tester, 'Note en ligne');
      await theZettelIsCommittedToTheLocalRepository(tester);
      await thePendingCommitsArePushedToTheRemote(tester);
    });
  });
}
