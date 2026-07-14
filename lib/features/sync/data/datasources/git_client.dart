import 'package:equatable/equatable.dart';

/// Outcome of a conflict resolved with the "local wins" strategy.
///
/// [backupPath] is the vault-relative path of the copy of the remote
/// version, written BEFORE resolving so no data is ever lost. Null when
/// the remote side deleted the file (nothing to back up).
class ConflictResolution extends Equatable {
  const ConflictResolution({required this.path, this.backupPath});

  /// Vault-relative path of the conflicted file.
  final String path;

  /// Vault-relative path of the saved remote copy, if any.
  final String? backupPath;

  @override
  List<Object?> get props => [path, backupPath];
}

/// Outcome of a pull (fetch + fast-forward-or-merge).
class PullResult extends Equatable {
  const PullResult({this.updated = false, this.resolvedConflicts = const []});

  /// True when the pull changed files in the working directory.
  final bool updated;

  /// Conflicts that were resolved local-wins during the merge.
  final List<ConflictResolution> resolvedConflicts;

  @override
  List<Object?> get props => [updated, resolvedConflicts];
}

/// Thin abstraction over git2dart so the data layer stays testable and a
/// fallback engine can be swapped per platform later.
///
/// All [path] arguments are the absolute vault directory. Implementations
/// throw [GitException] (core/error/exceptions.dart) on any git error and
/// must never block the UI isolate.
abstract interface class GitClient {
  /// Clones [url] into [path] using [token] for HTTPS auth.
  Future<void> clone({
    required String url,
    required String path,
    required String token,
  });

  /// Initializes a fresh local repository at [path] (branch `main`).
  Future<void> init(String path);

  /// Whether [path] is the working directory of a git repository.
  Future<bool> isRepository(String path);

  /// Whether the repository at [path] has at least one remote configured.
  Future<bool> hasRemote(String path);

  /// Stages every change of the working tree (additions, edits, deletions).
  Future<void> stageAll(String path);

  /// Commits the staged changes with [message].
  ///
  /// No-op when the working tree is clean; returns true when a commit was
  /// actually created.
  Future<bool> commit({required String path, required String message});

  /// Number of local commits not present on the remote-tracking branch.
  Future<int> aheadCount(String path);

  /// Updates the remote-tracking branches from `origin`.
  Future<void> fetch({required String path, required String token});

  /// Fetch then integrate `origin/<branch>`: fast-forward when possible,
  /// merge otherwise. Conflicts resolve local-wins; the remote version of
  /// each conflicted file is saved under `conflicts/` (see
  /// [conflictBackupPath]) BEFORE resolution so nothing is ever lost.
  Future<PullResult> pull({required String path, required String token});

  /// Pushes the current branch to `origin`. Never force-pushes.
  Future<void> push({required String path, required String token});

  /// Vault-relative paths currently in a conflicted state.
  Future<List<String>> listConflicts(String path);

  /// Resolves every pending index conflict with the local version, saving
  /// the remote copies first. Concludes the in-progress merge when needed.
  Future<List<ConflictResolution>> resolveConflictsLocalWins(String path);
}

/// Formats [time] as the compact `yyyyMMddHHmmss` timestamp used in
/// conflict backup file names.
String formatConflictTimestamp(DateTime time) {
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${time.year.toString().padLeft(4, '0')}${pad(time.month)}'
      '${pad(time.day)}${pad(time.hour)}${pad(time.minute)}${pad(time.second)}';
}

/// Builds the backup path for a conflicted [path]:
/// `zettel/<id>-foo.md` -> `conflicts/conflict-<timestamp>-<id>-foo.md`.
///
/// Backups deliberately live OUTSIDE the `zettel/` namespace and their
/// name does not start with a zettel id: a backup carrying the id of its
/// original note (in its name or its frontmatter) would be indexed as
/// that note and could shadow it — or be silently deleted by the next
/// write of the real note.
String conflictBackupPath(String path, String timestamp) {
  final slash = path.lastIndexOf('/');
  final baseName = slash >= 0 ? path.substring(slash + 1) : path;
  return 'conflicts/conflict-$timestamp-$baseName';
}
