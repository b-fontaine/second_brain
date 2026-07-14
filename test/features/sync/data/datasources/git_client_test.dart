import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/sync/data/datasources/git_client.dart';
import 'package:second_brain/features/zettel/data/datasources/zettel_file_naming.dart';

void main() {
  group('formatConflictTimestamp', () {
    test('formats as yyyyMMddHHmmss with zero padding', () {
      expect(
        formatConflictTimestamp(DateTime(2026, 7, 4, 9, 5, 3)),
        '20260704090503',
      );
    });
  });

  group('conflictBackupPath', () {
    test('moves the backup into conflicts/ at the vault root', () {
      expect(
        conflictBackupPath(
          'zettel/20260714103000-memoire.md',
          '20260714110000',
        ),
        'conflicts/conflict-20260714110000-20260714103000-memoire.md',
      );
    });

    test('handles files without an extension and at the vault root', () {
      expect(
        conflictBackupPath('notes/sans-extension', '20260714110000'),
        'conflicts/conflict-20260714110000-sans-extension',
      );
      expect(
        conflictBackupPath('README.md', '20260714110000'),
        'conflicts/conflict-20260714110000-README.md',
      );
    });

    test('is never inside zettel/ nor parseable as a zettel file, so a '
        'backup can neither shadow its original note in the index nor be '
        'deleted by the next write of that note', () {
      final backup = conflictBackupPath(
        'zettel/20260714103000-memoire.md',
        '20260714110000',
      );

      expect(backup, startsWith('conflicts/'));
      // The name must not start with the original 14-digit zettel id:
      // zettelIdFromFileName would otherwise map the backup to the SAME
      // id as the conflicted note.
      expect(zettelIdFromFileName(backup.split('/').last), isNull);
    });
  });

  group('PullResult', () {
    test('supports value equality', () {
      expect(const PullResult(), const PullResult());
      expect(const PullResult(updated: true), isNot(const PullResult()));
    });
  });

  group('ConflictResolution', () {
    test('supports value equality', () {
      expect(
        const ConflictResolution(path: 'a.md', backupPath: 'b.md'),
        const ConflictResolution(path: 'a.md', backupPath: 'b.md'),
      );
    });
  });
}
