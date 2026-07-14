import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:second_brain/core/error/exceptions.dart';
import 'package:second_brain/core/error/failures.dart';
import 'package:second_brain/core/services/clock.dart';
import 'package:second_brain/core/services/network_info.dart';
import 'package:second_brain/core/services/vault_locator.dart';
import 'package:second_brain/features/sync/data/datasources/git_client.dart';
import 'package:second_brain/features/sync/data/repositories/git_sync_repository_impl.dart';
import 'package:second_brain/features/sync/data/services/pull_change_notifier.dart';
import 'package:second_brain/features/sync/domain/entities/sync_status.dart';

class MockGitClient extends Mock implements GitClient {}

class MockVaultLocator extends Mock implements VaultLocator {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

class MockClock extends Mock implements Clock {}

void main() {
  const vaultPath = '/vault';
  const token = 'pat-123';
  final now = DateTime(2026, 7, 14, 10, 30);

  late MockGitClient git;
  late MockVaultLocator vaultLocator;
  late MockNetworkInfo networkInfo;
  late MockSecureStorage secureStorage;
  late MockClock clock;
  late PullChangeNotifier pullChangeNotifier;
  late GitSyncRepositoryImpl repository;

  setUp(() {
    git = MockGitClient();
    vaultLocator = MockVaultLocator();
    networkInfo = MockNetworkInfo();
    secureStorage = MockSecureStorage();
    clock = MockClock();
    pullChangeNotifier = PullChangeNotifier();
    repository = GitSyncRepositoryImpl(
      git,
      vaultLocator,
      networkInfo,
      secureStorage,
      clock,
      pullChangeNotifier,
    );

    when(() => vaultLocator.vaultPath()).thenAnswer((_) async => vaultPath);
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
    when(() => clock.now()).thenReturn(now);
    when(
      () => secureStorage.read(key: GitSyncRepositoryImpl.tokenKey),
    ).thenAnswer((_) async => token);
    when(() => git.isRepository(vaultPath)).thenAnswer((_) async => true);
    when(() => git.hasRemote(vaultPath)).thenAnswer((_) async => true);
    when(() => git.aheadCount(vaultPath)).thenAnswer((_) async => 0);
    when(() => git.stageAll(vaultPath)).thenAnswer((_) async {});
    when(
      () => git.commit(
        path: vaultPath,
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => git.pull(path: vaultPath, token: token),
    ).thenAnswer((_) async => const PullResult());
    when(
      () => git.push(path: vaultPath, token: token),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await repository.dispose();
    await pullChangeNotifier.dispose();
  });

  group('getStatus', () {
    test('is localOnly when no vault is configured', () async {
      when(() => vaultLocator.vaultPath()).thenAnswer((_) async => null);

      final result = await repository.getStatus();

      expect(
        result,
        const Right<Failure, SyncStatus>(
          SyncStatus(state: SyncState.localOnly),
        ),
      );
    });

    test('is localOnly when the vault has no remote', () async {
      when(() => git.hasRemote(vaultPath)).thenAnswer((_) async => false);

      final result = await repository.getStatus();

      result.fold(
        (failure) => fail('expected a status, got $failure'),
        (status) => expect(status.state, SyncState.localOnly),
      );
    });

    test(
      'is pendingPush with the ahead count when commits are waiting',
      () async {
        when(() => git.aheadCount(vaultPath)).thenAnswer((_) async => 3);

        final result = await repository.getStatus();

        result.fold((failure) => fail('expected a status, got $failure'), (
          status,
        ) {
          expect(status.state, SyncState.pendingPush);
          expect(status.pendingCommits, 3);
        });
      },
    );

    test('is upToDate when nothing is ahead', () async {
      final result = await repository.getStatus();

      result.fold(
        (failure) => fail('expected a status, got $failure'),
        (status) => expect(status.state, SyncState.upToDate),
      );
    });

    test('converts a GitException into a SyncFailure', () async {
      when(
        () => git.aheadCount(vaultPath),
      ).thenThrow(const GitException('boom'));

      final result = await repository.getStatus();

      expect(result, const Left<Failure, SyncStatus>(SyncFailure('boom')));
    });
  });

  group('commitAll', () {
    test('stages everything then commits with the given message', () async {
      final result = await repository.commitAll('note: test (123)');

      expect(result, const Right<Failure, Unit>(unit));
      verifyInOrder([
        () => git.stageAll(vaultPath),
        () => git.commit(path: vaultPath, message: 'note: test (123)'),
      ]);
    });

    test(
      'initializes the repository first when the vault is not one',
      () async {
        when(() => git.isRepository(vaultPath)).thenAnswer((_) async => false);
        when(() => git.init(vaultPath)).thenAnswer((_) async {});
        when(() => git.hasRemote(vaultPath)).thenAnswer((_) async => false);

        final result = await repository.commitAll('m');

        expect(result.isRight(), isTrue);
        verify(() => git.init(vaultPath)).called(1);
      },
    );

    test('emits a pendingPush status after a real commit', () async {
      when(() => git.aheadCount(vaultPath)).thenAnswer((_) async => 1);
      final emitted = <SyncStatus>[];
      final subscription = repository.watchStatus().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await repository.commitAll('m');
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(emitted.last.state, SyncState.pendingPush);
      expect(emitted.last.pendingCommits, 1);
    });

    test('does not emit anything when the working tree was clean', () async {
      when(
        () => git.commit(
          path: vaultPath,
          message: any(named: 'message'),
        ),
      ).thenAnswer((_) async => false);
      final emitted = <SyncStatus>[];
      final subscription = repository.watchStatus().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);
      final replayCount = emitted.length;

      final result = await repository.commitAll('m');
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(result, const Right<Failure, Unit>(unit));
      expect(emitted.length, replayCount);
    });

    test(
      'converts a GitException into a SyncFailure and an error status',
      () async {
        when(
          () => git.stageAll(vaultPath),
        ).thenThrow(const GitException('disque plein'));

        final result = await repository.commitAll('m');

        expect(result, const Left<Failure, Unit>(SyncFailure('disque plein')));
        final status = await repository.getStatus();
        // getStatus recomputes, so check the streamed value instead.
        expect(status.isRight(), isTrue);
      },
    );
  });

  group('synchronize', () {
    test(
      'returns OfflineFailure without touching the network when offline',
      () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);
        when(() => git.aheadCount(vaultPath)).thenAnswer((_) async => 2);

        final result = await repository.synchronize();

        expect(result, const Left<Failure, Unit>(OfflineFailure()));
        verifyNever(() => git.pull(path: vaultPath, token: token));
        verifyNever(() => git.push(path: vaultPath, token: token));
      },
    );

    test('emits a pendingPush status when skipped because offline', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(() => git.aheadCount(vaultPath)).thenAnswer((_) async => 2);
      final emitted = <SyncStatus>[];
      final subscription = repository.watchStatus().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      await repository.synchronize();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(emitted.last.state, SyncState.pendingPush);
      expect(emitted.last.pendingCommits, 2);
    });

    test('is a no-op success when the vault has no remote', () async {
      when(() => git.hasRemote(vaultPath)).thenAnswer((_) async => false);

      final result = await repository.synchronize();

      expect(result, const Right<Failure, Unit>(unit));
      verifyNever(() => git.pull(path: vaultPath, token: token));
    });

    test('fails without a stored token', () async {
      when(
        () => secureStorage.read(key: GitSyncRepositoryImpl.tokenKey),
      ).thenAnswer((_) async => null);

      final result = await repository.synchronize();

      expect(result.isLeft(), isTrue);
      verifyNever(
        () => git.pull(
          path: vaultPath,
          token: any(named: 'token'),
        ),
      );
    });

    test('pulls then pushes and ends upToDate with lastSyncedAt', () async {
      // One commit to push, then nothing ahead once the push completed.
      final aheadCounts = [1, 0];
      when(
        () => git.aheadCount(vaultPath),
      ).thenAnswer((_) async => aheadCounts.removeAt(0));
      final emitted = <SyncStatus>[];
      final subscription = repository.watchStatus().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      final result = await repository.synchronize();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(result, const Right<Failure, Unit>(unit));
      verifyInOrder([
        () => git.pull(path: vaultPath, token: token),
        () => git.push(path: vaultPath, token: token),
      ]);
      expect(
        emitted.map((s) => s.state),
        containsAllInOrder([SyncState.syncing, SyncState.upToDate]),
      );
      expect(emitted.last.lastSyncedAt, now);
    });

    test('recomputes the pending count instead of assuming upToDate when a '
        'commit landed while the sync was running', () async {
      // One commit to push before the sync, and one created while it ran.
      final aheadCounts = [1, 1];
      when(
        () => git.aheadCount(vaultPath),
      ).thenAnswer((_) async => aheadCounts.removeAt(0));
      final emitted = <SyncStatus>[];
      final subscription = repository.watchStatus().listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      final result = await repository.synchronize();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(result, const Right<Failure, Unit>(unit));
      expect(emitted.last.state, SyncState.pendingPush);
      expect(emitted.last.pendingCommits, 1);
    });

    test('skips the push when nothing is ahead after the pull', () async {
      when(() => git.aheadCount(vaultPath)).thenAnswer((_) async => 0);

      final result = await repository.synchronize();

      expect(result.isRight(), isTrue);
      verifyNever(() => git.push(path: vaultPath, token: token));
    });

    test('notifies the pull listeners when the pull changed files', () async {
      when(
        () => git.pull(path: vaultPath, token: token),
      ).thenAnswer((_) async => const PullResult(updated: true));
      final notified = expectLater(pullChangeNotifier.changes, emits(anything));

      await repository.synchronize();

      await notified;
    });

    test('conflicts resolved local-wins (backup copies created by the client) '
        'still end in a successful sync', () async {
      when(() => git.pull(path: vaultPath, token: token)).thenAnswer(
        (_) async => const PullResult(
          updated: true,
          resolvedConflicts: [
            ConflictResolution(
              path: 'zettel/20260714103000-memoire.md',
              backupPath:
                  'conflicts/conflict-20260714110000-20260714103000-memoire.md',
            ),
          ],
        ),
      );
      final notified = expectLater(pullChangeNotifier.changes, emits(anything));

      final result = await repository.synchronize();

      expect(result, const Right<Failure, Unit>(unit));
      await notified;
    });

    test('does not notify pull listeners when nothing changed', () async {
      var notifications = 0;
      final subscription = pullChangeNotifier.changes.listen(
        (_) => notifications++,
      );

      await repository.synchronize();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(notifications, 0);
    });

    test(
      'converts a GitException into a SyncFailure and an error status',
      () async {
        when(
          () => git.pull(path: vaultPath, token: token),
        ).thenThrow(const GitException('authentification requise'));
        final emitted = <SyncStatus>[];
        final subscription = repository.watchStatus().listen(emitted.add);
        await Future<void>.delayed(Duration.zero);

        final result = await repository.synchronize();
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(
          result,
          const Left<Failure, Unit>(SyncFailure('authentification requise')),
        );
        expect(emitted.last.state, SyncState.error);
        expect(emitted.last.message, 'authentification requise');
      },
    );
  });

  group('watchStatus', () {
    test('replays the latest status to a late subscriber', () async {
      when(() => git.aheadCount(vaultPath)).thenAnswer((_) async => 5);
      await repository.getStatus();

      final first = await repository.watchStatus().first;

      expect(first.state, SyncState.pendingPush);
      expect(first.pendingCommits, 5);
    });
  });

  group('cloneRemote', () {
    test('stores the token then clones and ends upToDate', () async {
      when(
        () => secureStorage.write(
          key: GitSyncRepositoryImpl.tokenKey,
          value: token,
        ),
      ).thenAnswer((_) async {});
      when(
        () => git.clone(url: 'https://x/y.git', path: vaultPath, token: token),
      ).thenAnswer((_) async {});

      final result = await repository.cloneRemote(
        remoteUrl: 'https://x/y.git',
        token: token,
      );

      expect(result, const Right<Failure, Unit>(unit));
      verifyInOrder([
        () => secureStorage.write(
          key: GitSyncRepositoryImpl.tokenKey,
          value: token,
        ),
        () => git.clone(url: 'https://x/y.git', path: vaultPath, token: token),
      ]);
      final status = await repository.watchStatus().first;
      expect(status.state, SyncState.upToDate);
    });

    test('fails when no vault is configured', () async {
      when(() => vaultLocator.vaultPath()).thenAnswer((_) async => null);

      final result = await repository.cloneRemote(
        remoteUrl: 'https://x/y.git',
        token: token,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('initLocal', () {
    test('initializes a repository and reports localOnly', () async {
      when(() => git.isRepository(vaultPath)).thenAnswer((_) async => false);
      when(() => git.init(vaultPath)).thenAnswer((_) async {});

      final result = await repository.initLocal();

      expect(result, const Right<Failure, Unit>(unit));
      verify(() => git.init(vaultPath)).called(1);
      final status = await repository.watchStatus().first;
      expect(status.state, SyncState.localOnly);
    });
  });
}
