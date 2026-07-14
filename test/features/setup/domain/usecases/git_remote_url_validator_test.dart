import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/setup/domain/usecases/git_remote_url_validator.dart';

void main() {
  group('GitRemoteUrlValidator', () {
    const validUrls = [
      // Generic https host with explicit .git suffix.
      'https://git.company.io/team/notes.git',
      'https://codeberg.org/user/repo.git',
      'https://gitlab.example.com/team/notes.git',
      'https://git.example.com:8443/team/repo.git',
      // GitHub, with and without .git.
      'https://github.com/user/zettelkasten.git',
      'https://github.com/user/zettelkasten',
      'https://github.com/user/my.repo-name_2',
      'https://www.github.com/user/repo',
      'https://github.com/user/repo/',
      // GitLab, including subgroups.
      'https://gitlab.com/group/project.git',
      'https://gitlab.com/group/subgroup/project',
      'https://gitlab.com/group/subgroup/deep/project.git',
      // Surrounding whitespace is tolerated (trimmed).
      '  https://github.com/user/repo.git  ',
    ];

    const invalidUrls = [
      // Not URLs at all.
      'not-a-url',
      '',
      '   ',
      'github.com/user/repo.git',
      // Wrong scheme.
      'http://github.com/user/repo.git',
      'ftp://github.com/user/repo.git',
      'ssh://git@github.com/user/repo.git',
      // scp-like ssh remote.
      'git@github.com:user/repo.git',
      // Missing repository path.
      'https://github.com',
      'https://github.com/user',
      'https://github.com/',
      // GitHub never has more than owner/repo.
      'https://github.com/user/repo/extra',
      // Generic host requires the .git suffix.
      'https://codeberg.org/user/repo',
      // Empty repository name.
      'https://github.com/user/.git',
      // Embedded credentials, query strings, fragments.
      'https://user:pass@github.com/user/repo.git',
      'https://github.com/user/repo.git?ref=main',
      'https://github.com/user/repo.git#readme',
      // Invalid characters in path segments.
      'https://github.com/us er/repo.git',
      // Host without a dot / empty host.
      'https://localhost/user/repo.git',
      'https:///user/repo.git',
    ];

    for (final url in validUrls) {
      test('accepts $url', () {
        expect(GitRemoteUrlValidator.isValid(url), isTrue, reason: url);
      });
    }

    for (final url in invalidUrls) {
      test('rejects "$url"', () {
        expect(GitRemoteUrlValidator.isValid(url), isFalse, reason: url);
      });
    }

    test('exposes the exact user-facing error message', () {
      expect(GitRemoteUrlValidator.invalidUrlMessage, 'URL de dépôt invalide');
    });
  });
}
