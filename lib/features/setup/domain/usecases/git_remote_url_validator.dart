/// Pure validation of a git remote URL entered during onboarding.
///
/// Accepted forms:
/// - any `https://host/…/repo.git` URL (at least owner + repo segments);
/// - GitHub (`https://github.com/owner/repo`) with or without `.git`;
/// - GitLab (`https://gitlab.com/group/…/project`) with or without `.git`.
///
/// Everything else (ssh, http, scp-like `git@host:…`, missing path, query
/// strings, embedded credentials…) is rejected.
abstract final class GitRemoteUrlValidator {
  /// Exact user-facing message carried by the [ValidationFailure]
  /// returned when the URL is rejected (asserted by the BDD specs).
  static const invalidUrlMessage = 'URL de dépôt invalide';

  static final _segmentPattern = RegExp(
    r'^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$',
  );

  static bool isValid(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    if (uri.host.isEmpty || !uri.host.contains('.')) return false;
    // No embedded credentials, query strings or fragments in a remote URL.
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.fragment.isNotEmpty) {
      return false;
    }

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    // At least owner/group + repository name.
    if (segments.length < 2) return false;

    var repoName = segments.last;
    final endsWithGit = repoName.endsWith('.git');
    if (endsWithGit) {
      repoName = repoName.substring(0, repoName.length - 4);
    }
    if (repoName.isEmpty) return false;

    final host = uri.host.toLowerCase();
    final isGitHub = host == 'github.com' || host == 'www.github.com';
    final isGitLab = host == 'gitlab.com' || host == 'www.gitlab.com';

    // Generic hosts must use the explicit `.git` form.
    if (!endsWithGit && !isGitHub && !isGitLab) return false;
    // GitHub repositories are always exactly owner/repo.
    if (isGitHub && segments.length != 2) return false;

    final checkedSegments = [
      ...segments.sublist(0, segments.length - 1),
      repoName,
    ];
    return checkedSegments.every(_segmentPattern.hasMatch);
  }
}
