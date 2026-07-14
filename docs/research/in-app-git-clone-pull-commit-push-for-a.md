# In-app git (clone/pull/commit/push) for a Flutter markdown-notes app on iOS/Android/Windows/Linux/macOS, no shell git dependency, HTTPS+token auth, offline-first with opportunistic sync

## Recommandation

git2dart ^0.5.3 (pub.dev, verified publisher dartgit.dev, published ~2026-07-01, i.e. 13 days before 2026-07-14) — actively maintained libgit2 FFI bindings with prebuilt native binaries via transitive git2dart_binaries 1.11.4 (published 14 days ago). It is the ONLY evaluated option that is simultaneously: maintained (multiple releases in the last month), covers all five target platforms, has real smart-HTTP(S) network transport with token auth (plus SSH via bundled libssh2), and exposes full merge/conflict-resolution machinery (Merge.analysis, index.conflicts, favor strategies, rebase, revert, stash). Comparison that led here — (1) dart_git (GitJournal): pub.dev release is 0.0.2 from ~2021, effectively dead on pub.dev; the GitHub repo (GitJournal/dart-git, ~680 commits) is pure Dart but implements LOCAL operations only — its lib/ has no HTTP/SSH transport at all, so no clone/fetch/push; GitJournal itself pairs it with a separate native library for networking. Not viable alone. (2) libgit2dart 1.2.2: officially DISCONTINUED on pub.dev (3 years stale, desktop-only); git2dart is its maintained successor. (3) GitJournal's overall approach: dart_git (local ops) + go_git_dart (go-git compiled via cgo/gomobile, called over FFI, SSH auth via openssh_ed25519) — battle-tested in a shipped app, but go_git_dart is NOT on pub.dev, has 4 stars, requires a Go cross-compilation toolchain, and means maintaining two git engines; too much integration cost for a new app. (4) Shelling out to system git (package:git 2.3.2, kevmoo, 10 months old): impossible on iOS (cannot bundle/exec a git binary in the sandbox) and impractical on Android (no git binary; exec of extracted binaries blocked on modern API levels), and even on Windows/Linux/macOS it silently fails on machines without git installed — fails the 'no shell git' requirement outright on 2 of 5 platforms. (5) isomorphic-git style: isomorphic-git is JavaScript-only (irrelevant outside Flutter web); the closest Dart analogue is git_on_dart 0.1.4 (pure Dart, HTTPS token + SSH via dartssh2, clone/push/pull/merge-with-conflict-detection) but it is 6 months stale, unverified publisher, 1 like/63 downloads, and self-describes its push/pull as a 'simplified implementation' — too immature to bet the app's data integrity on, but it is the best pure-Dart escape hatch. Offline-first fit: libgit2 is fully embedded, so init/open/add/commit/log/status/branch/merge all work with zero network; only Remote.fetch/push touch the network, which matches the background/opportunistic sync requirement exactly.

## Support plateformes

{"android": true, "ios": true, "windows": true, "linux": true, "macos": true}

## Fallback

Layered fallback plan, enabled by wrapping all git access behind a GitSyncService interface from day one: (1) If git2dart's prebuilt binaries break on one platform (most likely candidates: Windows OpenSSL DLL issues or a future Android NDK change), pin git2dart_binaries to the last-good 1.11.x and file upstream — the binaries package is versioned independently precisely for this. (2) If git2dart becomes unmaintained (watch: DartGit-dev/git2dart release cadence), adopt the GitJournal production pattern: dart_git from github.com/GitJournal/dart-git (pure Dart local ops: commit/index/merge/checkout) + go_git_dart from github.com/GitJournal/go_git_dart (go-git compiled per-platform, FFI) for clone/fetch/push — proven in a shipped app on iOS/Android but requires a Go build toolchain in CI. (3) Pure-Dart escape hatch with zero native code: git_on_dart 0.1.4 (HTTPS token + SSH, clone/push/pull/merge with conflict detection) — acceptable for a beta, immature for production; consider vendoring/forking it since the publisher is unverified. (4) Desktop-only convenience fallback: shell out to system git via package:git 2.3.2 or Process.run — viable ONLY on Windows/Linux/macOS and only when git is installed (detect with `git --version` at startup and degrade to 'local-only mode' otherwise); never available on iOS/Android, so it can only ever be a per-platform backend, not the primary engine. (5) Worst case for 32-bit Android (armeabi-v7a, unsupported by git2dart binaries): ship those devices in local-only mode with export/import, or route them to backend (3).

## Entrées pubspec

- `git2dart: ^0.5.3`
- `# transitively pulls git2dart_binaries >=1.11.4 <1.12.0 (prebuilt libgit2 + libssh2 + OpenSSL per platform)`
- `flutter_secure_storage: ^9.2.4  # recommended for storing the HTTPS token (not part of git2dart)`
- `connectivity_plus: ^6.1.0  # recommended trigger for opportunistic sync (not part of git2dart)`

## Setup plateforme

SDK floors: Dart >=3.7.2 <4.0.0, Flutter >=3.29.3.
ALL PLATFORMS (mobile mandatory, harmless on desktop): before ANY repository/remote/credential/certificate API call run — WidgetsFlutterBinding.ensureInitialized(); await PlatformSpecific.initialize(); — put it in main(). Platform-scoped variants exist: PlatformSpecific.androidInitialize() / PlatformSpecific.iosInitialize().
ANDROID: minSdk 21 (API 21+). Only arm64-v8a and x86_64 ABIs ship in git2dart_binaries — 32-bit armeabi-v7a devices are NOT supported; add to android/app/build.gradle: android { defaultConfig { ndk { abiFilters 'arm64-v8a', 'x86_64' } } }. Add <uses-permission android:name="android.permission.INTERNET"/> to AndroidManifest.xml (needed for fetch/push; normal permission, no runtime prompt). Android does not expose system CA certs on disk, so PlatformSpecific.initialize() extracts bundled trusted roots to the app cache dir — skipping init makes every HTTPS fetch fail with a certificate error.
iOS: minimum iOS 12.0. No manual Podfile edits: git2dart_binaries contributes the native pod automatically (vendored static frameworks: libgit2, libssh2, OpenSSL). Just flutter pub get && flutter build ios (runs pod install). All ops are in-process — no App Store issues about spawning processes.
DESKTOP (64-bit only): Linux runtime/build needs libssl-dev and libpcre3; macOS needs OpenSSL (brew); Windows needs OpenSSL DLLs available (per git2dart README). Verify by running Repository.init in a smoke test on each CI platform.
TOKEN STORAGE: keep the PAT in flutter_secure_storage (Keychain/Keystore/DPAPI/libsecret), never in the repo's .git/config URL.

## Notes API

ALL version facts verified on pub.dev / GitHub 2026-07-14. Package: git2dart 0.5.3 (MIT, repo github.com/DartGit-dev/git2dart, docs in doc/types/*.md, exhaustive examples in test/*.dart — the tests are the best API reference).

=== 0. Architecture rules ===
(a) Every libgit2 FFI call is SYNCHRONOUS and blocks the calling thread. Never run clone/fetch/push/merge on the UI isolate — wrap each whole operation in Isolate.run(() { ... }). FFI handles (Repository, Remote, Index...) must NOT cross isolate boundaries: open the repo, do the work, and free it entirely INSIDE the isolate closure; pass only paths/strings/booleans in and out.
(b) Wrap everything behind your own GitSyncService interface (clone/commitAll/sync) so a fallback engine can be swapped per platform later.
(c) Errors: every failed call throws Git2DartError (single field: message). Offline/unreachable-host/auth failures surface here from fetch/push — catch it, mark sync as pending, retry later. Local ops (commit/status/merge) work fully offline by design.
(d) Native handles have .free() — call it in finally blocks (Repository, Remote, Index, Commit, Tree, AnnotatedCommit all expose free()); finalizers exist but be deterministic on mobile.

=== 1. Init (main.dart) ===
import 'package:git2dart/git2dart.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlatformSpecific.initialize(); // REQUIRED before any repo/remote/credential API on Android/iOS (extracts CA roots on Android)
  runApp(const App());
}

=== 2. Credentials (HTTPS token) ===
Classes (lib/src/credentials.dart, verified): UserPass(username:, password:), Keypair(username:, pubKey:, privateKey:, passPhrase:) [file paths], KeypairFromMemory(username:, pubKey:, privateKey:, passPhrase:), KeypairFromAgent(username:).
GitHub PAT: UserPass(username: 'x-access-token', password: '<PAT>') — username can be any non-empty string for PATs, 'x-access-token' also works for GitHub App installation tokens.
GitLab PAT: UserPass(username: '<any-nonempty, e.g. git>', password: '<PAT>'); GitLab OAuth token: username MUST be 'oauth2'.
Callbacks class (verified ctor): const Callbacks({credentials, certificateCheck, transferProgress, sidebandProgress, updateTips, pushUpdateReference});
final callbacks = Callbacks(
  credentials: UserPass(username: 'x-access-token', password: token),
  transferProgress: (TransferProgress s) { /* s has receivedObjects/totalObjects/receivedBytes */ },
);
GOTCHA: if the server rejects the credential, libgit2 re-invokes the credential callback; a permanently-wrong token ends in a Git2DartError — treat 'auth' substrings in e.message as 'reauth needed', don't blind-retry.
Optional pinning: certificateCheck: (cert, host, {required valid}) => valid || host == 'github.com'.

=== 3. Clone ===
final repo = await Isolate.run(() {
  final r = Repository.clone(
    url: 'https://github.com/user/notes.git',
    localPath: notesDir,               // app documents subdir
    callbacks: callbacks,
    // optional: bare: false, checkoutBranch: 'main'
  );
  final headSha = r.head.target.sha;
  r.free();
  return headSha;
});
Open later: Repository.open(notesDir). Fresh empty repo (offline first-run before user configures a remote): Repository.init(path: notesDir); then Remote.create(repo: repo, name: 'origin', url: httpsUrl) when the user adds one. repo.setIdentity(name: 'Note User', email: 'user@device') once; or pass explicit Signatures per commit.

=== 4. Stage + commit (fully offline) ===
final index = repo.index;
index.add('daily/2026-07-14.md');       // or index.addAll(['a.md','b.md']); use updateAll for deletions or add each path — deleted files: index.remove(path)
index.write();
final treeOid = index.writeTree();
final sig = Signature.create(name: 'Benoit', email: 'me@example.com'); // time defaults to now
final parents = repo.isEmpty ? <Commit>[] : [Commit.lookup(repo: repo, oid: repo.head.target)];
final commitOid = Commit.create(
  repo: repo, updateRef: 'HEAD',
  author: sig, committer: sig,
  message: 'notes: autosave',
  tree: Tree.lookup(repo: repo, oid: treeOid),
  parents: parents,
);
Detect dirty state before committing: repo.status (map of path -> status flags); skip commit when empty.

=== 5. Pull = fetch + merge (libgit2 has no 'pull') ===
final remote = Remote.lookup(repo: repo, name: 'origin');
remote.fetch(callbacks: callbacks);           // optional refspecs:, prune:
final theirOid = Reference.lookup(repo: repo, name: 'refs/remotes/origin/main').target;
final analysis = Merge.analysis(repo: repo, theirHead: theirOid, ourRef: 'refs/heads/main');
// analysis.result is a Set<GitMergeAnalysis>: upToDate | fastForward | normal
if (analysis.result.contains(GitMergeAnalysis.upToDate)) { /* nothing */ }
else if (analysis.result.contains(GitMergeAnalysis.fastForward)) {
  Reference.setTarget(repo: repo, name: 'refs/heads/main', target: theirOid, logMessage: 'ff');
  Checkout.head(repo: repo, strategy: {GitCheckout.force});
} else { // normal merge
  Merge.commit(repo: repo, commit: AnnotatedCommit.lookup(repo: repo, oid: theirOid));
  // repo.state is now GitRepositoryState.merge
  final idx = repo.index;
  if (!idx.hasConflicts) {
    _createMergeCommit(repo, idx, theirOid);
  } else {
    resolveConflicts(repo, idx, theirOid);   // section 6
  }
  repo.stateCleanup();                        // ALWAYS after merge/cherry-pick/rebase resolution or abort
}
_createMergeCommit: final treeOid = idx.writeTree(); Commit.create(repo:repo, updateRef:'HEAD', author:sig, committer:sig, message:'merge origin/main', tree: Tree.lookup(repo:repo, oid:treeOid), parents: [Commit.lookup(repo:repo, oid: repo.head.target), Commit.lookup(repo:repo, oid: theirOid)]);

=== 6. Conflict resolution ===
idx.conflicts is Map<String, ConflictEntry>; each entry has .ancestor / .our / .their (nullable IndexEntry with .path, .oid — null side means deleted there).
for (final e in idx.conflicts.entries) {
  final path = e.key;
  final ours = e.value.our; final theirs = e.value.their;
  // Strategy for a notes app — never lose text:
  //  option A (recommended): keep both — read blobs and concatenate with a divider
  final ourTxt  = ours   == null ? '' : Blob.lookup(repo: repo, oid: ours.oid).content;
  final theirTxt= theirs == null ? '' : Blob.lookup(repo: repo, oid: theirs.oid).content;
  File('${repo.workdir}$path').writeAsStringSync('$ourTxt\n\n<!-- merged from remote -->\n\n$theirTxt');
  idx.add(path);      // adding the path CLEARS its conflict entries
}
idx.write();
// now idx.hasConflicts == false -> create the merge commit as in section 5, then repo.stateCleanup();
Automatic alternatives: pass favor: GitMergeFileFavor.ours / .theirs / .union to Merge.commit to auto-resolve (union = keep both sides' lines — good default for markdown). Tuning: Merge.commits(..., mergeFlags: {GitMergeFlag.findRenames}, fileFlags: {GitMergeFileFlag.ignoreWhitespace}). Also available: Merge.base(repo, oursOid, theirsOid), Merge.trees(...), Merge.cherryPick(...).

=== 7. Push ===
remote.push(refspecs: ['refs/heads/main'], callbacks: Callbacks(
  credentials: UserPass(username: 'x-access-token', password: token),
  pushUpdateReference: (String refname, String message) {
    // message is EMPTY on success; non-empty = server rejected (e.g. non-fast-forward)
    if (message.isNotEmpty) rejected = true;
  },
));
Non-fast-forward rejection recovery: run the pull flow (section 5), then push again. NEVER force-push in this app.
Full sync loop (background/opportunistic): commit local changes -> fetch -> merge/resolve -> push, all inside one Isolate.run, triggered by connectivity_plus events + app lifecycle (paused/resumed) + a debounce after note saves. Every step before fetch works offline; if fetch/push throws Git2DartError, keep the local commits and retry on next trigger — git's model makes this naturally safe.

=== 8. Other verified APIs ===
Checkout.head/index/reference/commit (strategy: {GitCheckout.force|safe...}, paths: [...] for partial). Branch.lookup(repo:, name:), Branch.create. Reference.create(repo:, name:, target:, force:, logMessage:). Repository getters: workdir, isEmpty, isShallow, head, state, status, config, index. Remote.create/lookup/setUrl/ls/fetch/push/prune. Stash, rebase, reset, revert, blame all exist.

=== 9. Verified alternative-option facts (for the record) ===
- dart_git: pub.dev 0.0.2 (~5 yrs old); GitHub master active-ish (GitJournal consumes it as a git dependency); pure Dart local ops only, NO network transport in lib/ (plumbing/, storage/, merge.dart, remotes.dart = config only).
- GitJournal production stack (pubspec verified): dart_git (git dep) + go_git_dart (go-git via gomobile/FFI, not on pub.dev, 4 stars) + openssh_ed25519 + local git_setup package.
- libgit2dart 1.2.2: discontinued, 3 yrs stale, desktop-only. git_bindings 0.0.18 (GitJournal, 5 yrs, Dart-3 incompatible). 
- package:git 2.3.2 (kevmoo, verified, 10 mo old): thin wrapper that REQUIRES system git binary — desktop-only viability (Windows/Linux/macOS, and only if git installed); impossible on iOS, impractical on Android.
- git_on_dart 0.1.4 (6 mo old, unverified publisher, 1 like): pure Dart clone/fetch/push/pull/merge+conflict detection, HTTPS token + SSH (dartssh2); self-described 'simplified' push/pull, no LFS/stash/cherry-pick — fallback candidate only.
- isomorphic-git: JavaScript, not usable from Flutter mobile/desktop Dart; only relevant if a web target is added later (via JS interop or wasm-git/lg2.wasm).
