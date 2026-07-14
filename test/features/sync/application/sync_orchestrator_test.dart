import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/clock.dart';
import 'package:second_brain/core/services/network_info.dart';
import 'package:second_brain/core/services/vault_write_notifier.dart';
import 'package:second_brain/features/sync/application/sync_orchestrator.dart';
import 'package:second_brain/features/sync/data/services/pull_change_notifier.dart';
import 'package:second_brain/features/sync/domain/entities/sync_status.dart';
import 'package:second_brain/features/sync/domain/repositories/git_sync_repository.dart';
import 'package:second_brain/features/zettel/domain/repositories/zettel_repository.dart';

class MockGitSyncRepository extends Mock implements GitSyncRepository {}

class MockZettelRepository extends Mock implements ZettelRepository {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockClock extends Mock implements Clock {}

void main() {
  const debounce = Duration(milliseconds: 40);
  const backoff = Duration(seconds: 30);
  final t0 = DateTime(2026, 7, 14, 10);

  late MockGitSyncRepository syncRepository;
  late MockZettelRepository zettelRepository;
  late MockNetworkInfo networkInfo;
  late MockClock clock;
  late PullChangeNotifier pullChangeNotifier;
  late VaultWriteNotifier vaultWriteNotifier;
  late StreamController<VaultChanged> vaultController;
  late StreamController<bool> networkController;
  late SyncOrchestrator orchestrator;

  /// Lets debounce timers fire and pending microtasks drain.
  Future<void> settle() =>
      Future<void>.delayed(debounce + const Duration(milliseconds: 40));

  setUp(() {
    syncRepository = MockGitSyncRepository();
    zettelRepository = MockZettelRepository();
    networkInfo = MockNetworkInfo();
    clock = MockClock();
    pullChangeNotifier = PullChangeNotifier();
    vaultWriteNotifier = VaultWriteNotifier();
    vaultController = StreamController<VaultChanged>.broadcast();
    networkController = StreamController<bool>.broadcast();

    when(
      () => zettelRepository.watchVault(),
    ).thenAnswer((_) => vaultController.stream);
    when(
      () => networkInfo.onStatusChange,
    ).thenAnswer((_) => networkController.stream);
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(() => clock.now()).thenReturn(t0);
    when(
      () => syncRepository.commitAll(any()),
    ).thenAnswer((_) async => const Right(unit));
    when(
      () => syncRepository.synchronize(),
    ).thenAnswer((_) async => const Right(unit));
    when(() => syncRepository.getStatus()).thenAnswer(
      (_) async => const Right(SyncStatus(state: SyncState.upToDate)),
    );

    orchestrator = SyncOrchestrator.withTimings(
      syncRepository,
      zettelRepository,
      networkInfo,
      pullChangeNotifier,
      vaultWriteNotifier,
      clock,
      debounceDelay: debounce,
      errorBackoff: backoff,
    );
  });

  tearDown(() async {
    await orchestrator.dispose();
    await vaultController.close();
    await networkController.close();
    await pullChangeNotifier.dispose();
    await vaultWriteNotifier.dispose();
  });

  group('vault changes', () {
    test(
      'commits once with the auto-save message after the debounce delay',
      () async {
        orchestrator.start();

        vaultController.add(const VaultChanged());
        vaultController.add(const VaultChanged());
        vaultController.add(const VaultChanged());
        await settle();

        verify(
          () => syncRepository.commitAll('note: sauvegarde automatique'),
        ).called(1);
      },
    );

    test('does not commit before the debounce delay elapses', () async {
      orchestrator.start();

      vaultController.add(const VaultChanged());
      await Future<void>.delayed(const Duration(milliseconds: 5));

      verifyNever(() => syncRepository.commitAll(any()));
    });

    test(
      'synchronizes after the commit when the network is available',
      () async {
        orchestrator.start();

        vaultController.add(const VaultChanged());
        await settle();

        verify(() => syncRepository.synchronize()).called(1);
      },
    );

    test('does not synchronize when offline, but still commits', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      orchestrator.start();

      vaultController.add(const VaultChanged());
      await settle();

      verify(() => syncRepository.commitAll(any())).called(1);
      verifyNever(() => syncRepository.synchronize());
    });

    test('commits after a raw vault write (inbox capture)', () async {
      orchestrator.start();

      vaultWriteNotifier.notifyWrite();
      await settle();

      verify(
        () => syncRepository.commitAll('note: sauvegarde automatique'),
      ).called(1);
      verify(() => syncRepository.synchronize()).called(1);
    });
  });

  group('discarded requests', () {
    test('replays a sync requested while another sync was running', () async {
      final firstSync = Completer<Either<Failure, Unit>>();
      var calls = 0;
      when(() => syncRepository.synchronize()).thenAnswer((_) {
        calls++;
        return calls == 1 ? firstSync.future : Future.value(const Right(unit));
      });
      orchestrator.start();

      vaultController.add(const VaultChanged());
      await settle();
      expect(calls, 1);

      // A note is saved while the first (slow) sync is still pushing:
      // the commit exists but the sync request is bounced.
      vaultController.add(const VaultChanged());
      await settle();
      expect(calls, 1);

      firstSync.complete(const Right(unit));
      await settle();

      // The bounced request must be replayed, not dropped.
      expect(calls, 2);
    });

    test('reschedules a request discarded by the error backoff', () async {
      const shortBackoff = Duration(milliseconds: 60);
      final local = SyncOrchestrator.withTimings(
        syncRepository,
        zettelRepository,
        networkInfo,
        pullChangeNotifier,
        vaultWriteNotifier,
        clock,
        debounceDelay: debounce,
        errorBackoff: shortBackoff,
      );
      when(
        () => syncRepository.synchronize(),
      ).thenAnswer((_) async => const Left(SyncFailure('réseau instable')));
      local.start();

      vaultController.add(const VaultChanged());
      await settle();
      verify(() => syncRepository.synchronize()).called(1);

      // Second request inside the backoff window: discarded but a retry
      // is scheduled for when the window closes.
      vaultController.add(const VaultChanged());
      await settle();
      verifyNever(() => syncRepository.synchronize());

      when(
        () => clock.now(),
      ).thenReturn(t0.add(const Duration(milliseconds: 500)));
      when(
        () => syncRepository.synchronize(),
      ).thenAnswer((_) async => const Right(unit));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      verify(() => syncRepository.synchronize()).called(1);
      await local.dispose();
    });
  });

  group('connectivity returns', () {
    test('synchronizes when commits are pending', () async {
      when(() => syncRepository.getStatus()).thenAnswer(
        (_) async => const Right(
          SyncStatus(state: SyncState.pendingPush, pendingCommits: 2),
        ),
      );
      orchestrator.start();

      networkController.add(true);
      await settle();

      verify(() => syncRepository.synchronize()).called(1);
    });

    test('does nothing when no commit is pending', () async {
      when(() => syncRepository.getStatus()).thenAnswer(
        (_) async => const Right(SyncStatus(state: SyncState.upToDate)),
      );
      orchestrator.start();

      networkController.add(true);
      await settle();

      verifyNever(() => syncRepository.synchronize());
    });

    test('does nothing when connectivity is lost', () async {
      orchestrator.start();

      networkController.add(false);
      await settle();

      verifyNever(() => syncRepository.getStatus());
      verifyNever(() => syncRepository.synchronize());
    });
  });

  group('error backoff', () {
    test('skips synchronization retries within the backoff window', () async {
      when(
        () => syncRepository.synchronize(),
      ).thenAnswer((_) async => const Left(SyncFailure('réseau instable')));
      orchestrator.start();

      vaultController.add(const VaultChanged());
      await settle();
      verify(() => syncRepository.synchronize()).called(1);

      // Still inside the backoff window.
      when(() => clock.now()).thenReturn(t0.add(const Duration(seconds: 10)));
      vaultController.add(const VaultChanged());
      await settle();

      verifyNever(() => syncRepository.synchronize());
    });

    test('retries once the backoff window has elapsed', () async {
      when(
        () => syncRepository.synchronize(),
      ).thenAnswer((_) async => const Left(SyncFailure('réseau instable')));
      orchestrator.start();

      vaultController.add(const VaultChanged());
      await settle();
      verify(() => syncRepository.synchronize()).called(1);

      when(() => clock.now()).thenReturn(t0.add(const Duration(seconds: 31)));
      vaultController.add(const VaultChanged());
      await settle();

      verify(() => syncRepository.synchronize()).called(1);
    });

    test('an OfflineFailure does not trigger the backoff', () async {
      when(
        () => syncRepository.synchronize(),
      ).thenAnswer((_) async => const Left(OfflineFailure()));
      orchestrator.start();

      vaultController.add(const VaultChanged());
      await settle();
      verify(() => syncRepository.synchronize()).called(1);

      // Same instant: a backoff would block this retry.
      vaultController.add(const VaultChanged());
      await settle();

      verify(() => syncRepository.synchronize()).called(1);
    });
  });

  group('remote changes relay', () {
    test('re-emits pull notifications on remoteChangesApplied', () async {
      orchestrator.start();

      final received = expectLater(
        orchestrator.remoteChangesApplied,
        emits(anything),
      );
      pullChangeNotifier.notifyPulledChanges();
      await received;
    });
  });

  group('lifecycle', () {
    test('start is idempotent', () async {
      orchestrator.start();
      orchestrator.start();

      vaultController.add(const VaultChanged());
      await settle();

      verify(() => syncRepository.commitAll(any())).called(1);
    });

    test('stop cancels the pending debounce and the subscriptions', () async {
      orchestrator.start();
      vaultController.add(const VaultChanged());
      orchestrator.stop();
      await settle();

      verifyNever(() => syncRepository.commitAll(any()));
    });
  });
}
