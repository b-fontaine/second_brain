import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/data/models/zettel_model.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';

void main() {
  final id = ZettelId.fromString('20260714103000');
  final createdAt = DateTime(2026, 7, 14, 10, 30);

  Zettel buildZettel({
    String title = 'Mémoire de travail',
    String body = 'Corps de la note.',
    List<String> tags = const ['cognition', 'memoire'],
    String? source,
  }) {
    return Zettel(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      tags: tags,
      source: source,
    );
  }

  group('toMarkdown', () {
    test('writes frontmatter with stable key order and quoted id', () {
      final markdown = ZettelModel.toMarkdown(
        buildZettel(source: 'capture:audio:meeting.m4a'),
      );
      final lines = markdown.split('\n');

      expect(lines[0], '---');
      expect(lines[1], 'id: "20260714103000"');
      expect(lines[2], 'title: "Mémoire de travail"');
      expect(lines[3], startsWith('date: 2026-07-14T10:30:00'));
      expect(
        lines[3],
        matches(r'^date: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$'),
      );
      expect(lines[4], 'tags: [cognition, memoire]');
      expect(lines[5], 'source: "capture:audio:meeting.m4a"');
      expect(lines[6], '---');
      expect(lines[7], '');
      expect(lines[8], 'Corps de la note.');
      expect(markdown, endsWith('\n'));
    });

    test('is deterministic', () {
      final zettel = buildZettel(source: 'capture:clipboard');
      expect(ZettelModel.toMarkdown(zettel), ZettelModel.toMarkdown(zettel));
    });

    test('omits the source line when source is null', () {
      final markdown = ZettelModel.toMarkdown(buildZettel());
      expect(markdown, isNot(contains('source:')));
      final lines = markdown.split('\n');
      expect(lines[5], '---');
    });

    test('writes empty tags as an empty flow list', () {
      final markdown = ZettelModel.toMarkdown(buildZettel(tags: const []));
      expect(markdown, contains('tags: []'));
    });

    test('quotes tags containing special characters', () {
      final markdown = ZettelModel.toMarkdown(
        buildZettel(tags: const ['mémoire', 'sciences-cognitives']),
      );
      expect(markdown, contains('tags: ["mémoire", sciences-cognitives]'));
    });

    test('quotes number-like tags so YAML re-parses them as strings', () {
      final markdown = ZettelModel.toMarkdown(
        buildZettel(tags: const ['007', '0x1A', 'v2']),
      );

      // Unquoted, the YAML core schema would resolve 007 -> 7 and
      // 0x1A -> 26, silently rewriting the tags on the next read.
      expect(markdown, contains('tags: ["007", "0x1A", v2]'));
      final decoded = ZettelModel.fromMarkdown(markdown);
      expect(decoded.tags, ['007', '0x1A', 'v2']);
    });
  });

  group('round-trip', () {
    test('preserves accents, tags, multiline body and wikilinks', () {
      final zettel = buildZettel(
        title: 'Mémoire de travail : capacité limitée',
        body:
            'La boucle phonologique s\'appuie sur '
            '[[20260101120000|la note socle]].\n'
            '\n'
            'Deuxième paragraphe avec accents : déjà, être, çà et là.\n'
            '\n'
            '- liste à puces\n'
            '- avec [[20260202130000]]',
        tags: const ['cognition', 'mémoire-de-travail'],
        source: 'capture:audio:réunion.m4a',
      );

      final decoded = ZettelModel.fromMarkdown(ZettelModel.toMarkdown(zettel));

      expect(decoded, zettel);
      expect(decoded.outgoingLinks.map((l) => l.value), [
        '20260101120000',
        '20260202130000',
      ]);
    });

    test('preserves the ## Références section verbatim', () {
      const referencesSection =
          '## Références\n'
          '- Baddeley, *Working Memory* (1992)\n'
          '- https://zettelkasten.de/introduction/';
      final zettel = buildZettel(
        body: 'Corps de la note.\n\n$referencesSection',
      );

      final markdown = ZettelModel.toMarkdown(zettel);
      final decoded = ZettelModel.fromMarkdown(markdown);

      expect(markdown, contains(referencesSection));
      expect(decoded.body, endsWith(referencesSection));
    });

    test('preserves titles containing quotes and backslashes', () {
      final zettel = buildZettel(title: r'Il a dit "non" et C:\chemin');
      final decoded = ZettelModel.fromMarkdown(ZettelModel.toMarkdown(zettel));
      expect(decoded.title, r'Il a dit "non" et C:\chemin');
    });

    test('preserves the creation date at second precision', () {
      final zettel = buildZettel();
      final decoded = ZettelModel.fromMarkdown(ZettelModel.toMarkdown(zettel));
      expect(decoded.createdAt, DateTime(2026, 7, 14, 10, 30));
      expect(decoded.createdAt.isUtc, isFalse);
    });
  });

  group('fromMarkdown tolerance', () {
    test('accepts an unquoted numeric id', () {
      const raw =
          '---\n'
          'id: 20260714103000\n'
          'title: Note importée\n'
          'date: 2026-07-14T10:30:00+02:00\n'
          'tags: [import]\n'
          '---\n'
          '\n'
          'Corps.\n';
      final decoded = ZettelModel.fromMarkdown(raw);
      expect(decoded.id.value, '20260714103000');
    });

    test('falls back to the id timestamp when date is missing', () {
      const raw =
          '---\n'
          'id: "20260714103000"\n'
          'title: Sans date\n'
          '---\n'
          'Corps.\n';
      final decoded = ZettelModel.fromMarkdown(raw);
      expect(decoded.createdAt, DateTime(2026, 7, 14, 10, 30));
      expect(decoded.tags, isEmpty);
    });

    test('accepts a scalar tag value', () {
      const raw =
          '---\n'
          'id: "20260714103000"\n'
          'title: Un seul tag\n'
          'tags: cognition\n'
          '---\n'
          'Corps.\n';
      expect(ZettelModel.fromMarkdown(raw).tags, ['cognition']);
    });

    test('strips leading blank lines and trailing newline from the body', () {
      const raw =
          '---\n'
          'id: "20260714103000"\n'
          'title: Corps décalé\n'
          '---\n'
          '\n'
          '\n'
          'Première ligne.\n'
          '\n';
      expect(ZettelModel.fromMarkdown(raw).body, 'Première ligne.');
    });
  });

  group('fromMarkdown corrupt input', () {
    test('throws on a file without frontmatter', () {
      expect(
        () => ZettelModel.fromMarkdown('# Juste du markdown\n'),
        throwsFormatException,
      );
    });

    test('throws on unclosed frontmatter', () {
      expect(
        () => ZettelModel.fromMarkdown('---\nid: "20260714103000"\nCorps'),
        throwsFormatException,
      );
    });

    test('throws on invalid YAML', () {
      expect(
        () => ZettelModel.fromMarkdown('---\nid: [unclosed\n---\nCorps\n'),
        throwsFormatException,
      );
    });

    test('throws when frontmatter is not a map', () {
      expect(
        () => ZettelModel.fromMarkdown('---\njuste une chaîne\n---\nCorps\n'),
        throwsFormatException,
      );
    });

    test('throws on a missing id', () {
      expect(
        () => ZettelModel.fromMarkdown('---\ntitle: Sans id\n---\nCorps\n'),
        throwsFormatException,
      );
    });

    test('throws on a malformed id', () {
      expect(
        () => ZettelModel.fromMarkdown(
          '---\nid: "202607141030"\ntitle: Id court\n---\nCorps\n',
        ),
        throwsFormatException,
      );
    });

    test('throws on a missing title', () {
      expect(
        () =>
            ZettelModel.fromMarkdown('---\nid: "20260714103000"\n---\nCorps\n'),
        throwsFormatException,
      );
    });
  });

  group('normalize', () {
    test('trims title/tags/source and canonicalizes the body', () {
      final zettel = Zettel(
        id: id,
        title: '  Titre  ',
        body: '\n\nCorps.\n\n',
        createdAt: DateTime(2026, 7, 14, 10, 30, 0, 123, 456),
        tags: const [' cognition ', '', '  '],
        source: '  ',
      );

      final normalized = ZettelModel.normalize(zettel);

      expect(normalized.title, 'Titre');
      expect(normalized.body, 'Corps.');
      expect(normalized.tags, ['cognition']);
      expect(normalized.source, isNull);
      expect(normalized.createdAt, DateTime(2026, 7, 14, 10, 30));
    });
  });
}
