import 'dart:io';
import 'dart:isolate';

import 'package:git2dart/git2dart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/services/clock.dart';
import 'git_client.dart';

/// [GitClient] backed by git2dart (libgit2 FFI).
///
/// Every libgit2 call is synchronous and blocks its thread, so each whole
/// operation runs inside [Isolate.run]. FFI handles never cross the isolate
/// boundary: repositories are opened, used and freed entirely inside the
/// closure; only paths, tokens and plain result objects go in and out.
///
/// Requires `PlatformSpecific.initialize()` to have run in `main()` before
/// any method is called (mandatory on Android/iOS for CA roots).
@LazySingleton(as: GitClient)
class Git2dartClient implements GitClient {
  Git2dartClient(this._clock);

  final Clock _clock;

  @override
  Future<void> clone({
    required String url,
    required String path,
    required String token,
  }) => _runGit(() {
    final repo = Repository.clone(
      url: url,
      localPath: path,
      callbacks: _remoteCallbacks(token),
    );
    repo.free();
  });

  @override
  Future<void> init(String path) => _runGit(() {
    Repository.init(path: path, initialHead: 'main').free();
  });

  @override
  Future<bool> isRepository(String path) => _runGit(() {
    try {
      Repository.open(path).free();
      return true;
    } catch (_) {
      return false;
    }
  });

  @override
  Future<bool> hasRemote(String path) => _runGit(() {
    final repo = Repository.open(path);
    try {
      return Remote.list(repo).isNotEmpty;
    } finally {
      repo.free();
    }
  });

  @override
  Future<void> stageAll(String path) => _runGit(() {
    final repo = Repository.open(path);
    try {
      _stageAllChanges(repo);
    } finally {
      repo.free();
    }
  });

  @override
  Future<bool> commit({required String path, required String message}) =>
      _runGit(() {
        final repo = Repository.open(path);
        try {
          if (repo.status.isEmpty) return false;
          // Idempotent safety net: make sure everything is staged even if
          // stageAll was not called first.
          _stageAllChanges(repo);
          final index = repo.index;
          final Oid treeOid;
          try {
            treeOid = index.writeTree();
          } finally {
            index.free();
          }
          _createCommit(repo: repo, treeOid: treeOid, message: message);
          return true;
        } finally {
          repo.free();
        }
      });

  @override
  Future<int> aheadCount(String path) => _runGit(() {
    final repo = Repository.open(path);
    try {
      if (repo.isEmpty) return 0;
      final localOid = repo.head.target;
      final upstreamOid = _remoteBranchTarget(repo, _currentBranchName(repo));
      if (upstreamOid == null) {
        // No upstream yet: every local commit is pending.
        return _countFirstParentCommits(repo, localOid);
      }
      return repo.aheadBehind(local: localOid, upstream: upstreamOid).first;
    } finally {
      repo.free();
    }
  });

  @override
  Future<void> fetch({required String path, required String token}) =>
      _runGit(() {
        final repo = Repository.open(path);
        try {
          _fetchOrigin(repo, token);
        } finally {
          repo.free();
        }
      });

  @override
  Future<PullResult> pull({required String path, required String token}) {
    final timestamp = formatConflictTimestamp(_clock.now());
    return _runGit(() {
      final repo = Repository.open(path);
      try {
        _fetchOrigin(repo, token);
        return _integrateUpstream(repo, timestamp);
      } finally {
        repo.free();
      }
    });
  }

  @override
  Future<void> push({required String path, required String token}) =>
      _runGit(() {
        final repo = Repository.open(path);
        try {
          final branch = _currentBranchName(repo);
          final remote = Remote.lookup(repo: repo, name: 'origin');
          try {
            var rejection = '';
            remote.push(
              refspecs: ['refs/heads/$branch'],
              callbacks: Callbacks(
                credentials: _credentials(token),
                pushUpdateReference: (refname, message) {
                  // Empty message means the server accepted the update.
                  if (message.isNotEmpty) rejection = message;
                },
              ),
            );
            if (rejection.isNotEmpty) {
              throw GitException('Poussée refusée par le serveur : $rejection');
            }
          } finally {
            remote.free();
          }
        } finally {
          repo.free();
        }
      });

  @override
  Future<List<String>> listConflicts(String path) => _runGit(() {
    final repo = Repository.open(path);
    try {
      final index = repo.index;
      try {
        if (!index.hasConflicts) return const <String>[];
        return index.conflicts.keys.toList();
      } finally {
        index.free();
      }
    } finally {
      repo.free();
    }
  });

  @override
  Future<List<ConflictResolution>> resolveConflictsLocalWins(String path) {
    final timestamp = formatConflictTimestamp(_clock.now());
    return _runGit(() {
      final repo = Repository.open(path);
      try {
        final index = repo.index;
        try {
          if (!index.hasConflicts) return const <ConflictResolution>[];
          final resolutions = _resolveConflictsKeepingLocal(
            repo,
            index,
            timestamp,
          );
          if (repo.state == GitRepositoryState.merge) {
            final theirOid = _lookupTarget(repo, 'MERGE_HEAD');
            if (theirOid != null) {
              _createMergeCommit(
                repo: repo,
                index: index,
                theirOid: theirOid,
                branch: _currentBranchName(repo),
              );
            } else {
              // MERGE_HEAD unavailable: record the resolution on top of HEAD.
              _createCommit(
                repo: repo,
                treeOid: index.writeTree(),
                message: 'merge: résolution de conflits (priorité locale)',
              );
            }
            repo.stateCleanup();
          }
          return resolutions;
        } finally {
          index.free();
        }
      } finally {
        repo.free();
      }
    });
  }
}

/// Runs [body] on a background isolate, converting every git2dart error
/// (Git2DartError, LibGit2Error) into a typed [GitException].
Future<T> _runGit<T>(T Function() body) async {
  try {
    return await Isolate.run(() {
      try {
        return body();
      } on GitException {
        rethrow;
      } catch (error) {
        throw GitException(error.toString());
      }
    });
  } on GitException {
    rethrow;
  } catch (error) {
    // RemoteError fallback when the original error could not be sent
    // across the isolate boundary.
    throw GitException(error.toString());
  }
}

Credentials _credentials(String token) =>
    UserPass(username: 'x-access-token', password: token);

Callbacks _remoteCallbacks(String token) =>
    Callbacks(credentials: _credentials(token));

Signature _signature() =>
    Signature.create(name: 'Second Brain', email: 'second-brain@local');

/// Stages every working-tree change: new/modified files are added,
/// deletions are removed from the index. Ignored files are skipped.
void _stageAllChanges(Repository repo) {
  const addFlags = {
    GitStatus.wtNew,
    GitStatus.wtModified,
    GitStatus.wtTypeChange,
    GitStatus.wtRenamed,
    GitStatus.conflicted,
  };
  final index = repo.index;
  try {
    for (final entry in repo.status.entries) {
      final flags = entry.value;
      if (flags.contains(GitStatus.ignored)) continue;
      if (flags.any(addFlags.contains)) {
        index.add(entry.key);
      } else if (flags.contains(GitStatus.wtDeleted)) {
        index.remove(entry.key);
      }
      // Remaining flags are index-only: the change is already staged.
    }
    index.write();
  } finally {
    index.free();
  }
}

String _currentBranchName(Repository repo) {
  try {
    final head = repo.head;
    final name = head.shorthand;
    head.free();
    return name;
  } catch (_) {
    // Unborn HEAD (fresh repository): default branch name.
    return 'main';
  }
}

Oid? _remoteBranchTarget(Repository repo, String branch) =>
    _lookupTarget(repo, 'refs/remotes/origin/$branch');

Oid? _lookupTarget(Repository repo, String refName) {
  try {
    final ref = Reference.lookup(repo: repo, name: refName);
    final target = ref.target;
    ref.free();
    return target;
  } catch (_) {
    return null;
  }
}

int _countFirstParentCommits(Repository repo, Oid from) {
  const cap = 1000;
  var count = 0;
  var oid = from;
  while (count < cap) {
    final commit = Commit.lookup(repo: repo, oid: oid);
    final parents = commit.parents;
    commit.free();
    count++;
    if (parents.isEmpty) break;
    oid = parents.first;
  }
  return count;
}

void _fetchOrigin(Repository repo, String token) {
  final remote = Remote.lookup(repo: repo, name: 'origin');
  try {
    remote.fetch(callbacks: _remoteCallbacks(token));
  } finally {
    remote.free();
  }
}

/// Integrates `origin/<branch>` into the local branch after a fetch:
/// fast-forward when possible, merge (with local-wins conflict resolution)
/// otherwise.
PullResult _integrateUpstream(Repository repo, String timestamp) {
  final branch = _currentBranchName(repo);
  final theirOid = _remoteBranchTarget(repo, branch);
  if (theirOid == null) {
    // Remote branch does not exist yet (empty remote): nothing to merge.
    return const PullResult();
  }

  if (repo.isEmpty) {
    // Unborn local branch: adopt the remote history.
    _fastForward(repo, branch, theirOid);
    return const PullResult(updated: true);
  }

  final analysis = Merge.analysis(
    repo: repo,
    theirHead: theirOid,
    ourRef: 'refs/heads/$branch',
  );
  if (analysis.result.contains(GitMergeAnalysis.upToDate)) {
    return const PullResult();
  }
  if (analysis.result.contains(GitMergeAnalysis.fastForward) ||
      analysis.result.contains(GitMergeAnalysis.unborn)) {
    _fastForward(repo, branch, theirOid);
    return const PullResult(updated: true);
  }

  // Diverged histories: normal merge.
  final annotated = AnnotatedCommit.lookup(repo: repo, oid: theirOid);
  try {
    Merge.commit(repo: repo, commit: annotated);
  } finally {
    annotated.free();
  }
  final index = repo.index;
  try {
    var resolutions = const <ConflictResolution>[];
    if (index.hasConflicts) {
      resolutions = _resolveConflictsKeepingLocal(repo, index, timestamp);
    }
    _createMergeCommit(
      repo: repo,
      index: index,
      theirOid: theirOid,
      branch: branch,
    );
    return PullResult(updated: true, resolvedConflicts: resolutions);
  } finally {
    index.free();
    // Always clear the merge state, even if commit creation failed.
    repo.stateCleanup();
  }
}

void _fastForward(Repository repo, String branch, Oid theirOid) {
  Reference.create(
    repo: repo,
    name: 'refs/heads/$branch',
    target: theirOid,
    force: true,
    logMessage: 'pull: fast-forward',
  ).free();
  Checkout.head(repo: repo, strategy: const {GitCheckout.force});
}

/// Resolves every index conflict with the "local wins" strategy.
///
/// For each conflicted path the remote ("their") version is first written
/// to `conflicts/conflict-<timestamp>-<file name>` (outside the zettel
/// namespace, see [conflictBackupPath]) so no data is ever lost, then the
/// local ("our") version is restored (or the local deletion is kept).
List<ConflictResolution> _resolveConflictsKeepingLocal(
  Repository repo,
  Index index,
  String timestamp,
) {
  final workdir = repo.workdir;
  final resolutions = <ConflictResolution>[];
  // Snapshot: resolving entries mutates the conflicts map.
  final conflicts = index.conflicts.entries.toList();
  for (final entry in conflicts) {
    final path = entry.key;
    final ours = entry.value.our;
    final theirs = entry.value.their;

    String? backupPath;
    if (theirs != null) {
      // Save the remote version BEFORE resolving.
      backupPath = conflictBackupPath(path, timestamp);
      _writeBlobToFile(repo, theirs.oid, '$workdir$backupPath');
    }

    if (ours != null) {
      // Local wins: restore our content and clear the conflict.
      _writeBlobToFile(repo, ours.oid, '$workdir$path');
      index.add(path);
    } else {
      // Deleted locally: local wins, keep the deletion.
      final file = File('$workdir$path');
      if (file.existsSync()) file.deleteSync();
      entry.value.remove();
    }

    if (backupPath != null) index.add(backupPath);
    resolutions.add(ConflictResolution(path: path, backupPath: backupPath));
  }
  index.write();
  return resolutions;
}

void _writeBlobToFile(Repository repo, Oid blobOid, String filePath) {
  final blob = Blob.lookup(repo: repo, oid: blobOid);
  try {
    // contentBytes (raw size + bytes) is mandatory here: blob.content reads
    // a C string, which truncates binary blobs at the first NUL byte and may
    // read past the end of a buffer that is not NUL-terminated.
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(blob.contentBytes);
  } finally {
    blob.free();
  }
}

void _createCommit({
  required Repository repo,
  required Oid treeOid,
  required String message,
}) {
  final tree = Tree.lookup(repo: repo, oid: treeOid);
  final parents = repo.isEmpty
      ? <Commit>[]
      : [Commit.lookup(repo: repo, oid: repo.head.target)];
  try {
    final signature = _signature();
    Commit.create(
      repo: repo,
      updateRef: 'HEAD',
      author: signature,
      committer: signature,
      message: message,
      tree: tree,
      parents: parents,
    );
  } finally {
    tree.free();
    for (final parent in parents) {
      parent.free();
    }
  }
}

void _createMergeCommit({
  required Repository repo,
  required Index index,
  required Oid theirOid,
  required String branch,
}) {
  final treeOid = index.writeTree();
  final tree = Tree.lookup(repo: repo, oid: treeOid);
  final ourCommit = Commit.lookup(repo: repo, oid: repo.head.target);
  final theirCommit = Commit.lookup(repo: repo, oid: theirOid);
  try {
    final signature = _signature();
    Commit.create(
      repo: repo,
      updateRef: 'HEAD',
      author: signature,
      committer: signature,
      message: 'merge: origin/$branch',
      tree: tree,
      parents: [ourCommit, theirCommit],
    );
  } finally {
    tree.free();
    ourCommit.free();
    theirCommit.free();
  }
}
