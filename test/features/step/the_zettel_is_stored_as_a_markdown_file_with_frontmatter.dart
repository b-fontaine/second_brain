import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'bdd_world.dart';

/// Usage: the zettel is stored as a markdown file with frontmatter
///
/// Asserts against the REAL temp vault on disk: a `zettel/<id>-<slug>.md`
/// file whose YAML frontmatter carries the zettel's id and title.
Future<void> theZettelIsStoredAsAMarkdownFileWithFrontmatter(
  WidgetTester tester,
) async {
  final zettel = worldLastZettel;
  if (zettel == null) {
    fail('No zettel in scope: run "a zettel exists with title ..." first');
  }

  final zettelDir = Directory(p.join(bddVaultDir.path, 'zettel'));
  final files = zettelDir.listSync().whereType<File>().where((file) {
    final name = p.basename(file.path);
    return name.startsWith(zettel.id.value) && name.endsWith('.md');
  }).toList();
  expect(
    files,
    hasLength(1),
    reason: 'Exactly one zettel/<id>-<slug>.md file for id ${zettel.id.value}',
  );

  // Sync read: async file IO never completes under the FakeAsync test zone.
  final content = files.single.readAsStringSync();
  expect(
    content,
    startsWith('---\n'),
    reason: 'Frontmatter must open the file',
  );
  expect(content, contains('id: "${zettel.id.value}"'));
  expect(content, contains('title:'));
  expect(content, contains('date:'));
  expect(
    RegExp('^---', multiLine: true).allMatches(content).length,
    greaterThanOrEqualTo(2),
    reason: 'Frontmatter must be closed by a second --- delimiter',
  );
}
