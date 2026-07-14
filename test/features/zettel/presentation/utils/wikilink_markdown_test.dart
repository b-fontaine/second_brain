import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/presentation/utils/wikilink_markdown.dart';

void main() {
  group('transformWikilinks', () {
    test('rewrites a bare [[id]] using the target title when known', () {
      expect(
        transformWikilinks(
          'Voir [[20260101120000]].',
          titlesById: const {'20260101120000': 'Concept A'},
        ),
        'Voir [Concept A](sb://note/20260101120000).',
      );
    });

    test('falls back to the id when the title is unknown', () {
      expect(
        transformWikilinks('Voir [[20260101120000]].'),
        'Voir [20260101120000](sb://note/20260101120000).',
      );
    });

    test('prefers the alias over the title', () {
      expect(
        transformWikilinks(
          'Voir [[20260101120000|mon libellé]].',
          titlesById: const {'20260101120000': 'Concept A'},
        ),
        'Voir [mon libellé](sb://note/20260101120000).',
      );
    });

    test('resolves Obsidian-style filename targets by id prefix', () {
      expect(
        transformWikilinks(
          'Voir [[20260101120000-concept-a]].',
          titlesById: const {'20260101120000': 'Concept A'},
        ),
        'Voir [Concept A](sb://note/20260101120000).',
      );
    });

    test('renders targets without a valid id as plain text', () {
      expect(transformWikilinks('Voir [[pas-un-id|Brisé]].'), 'Voir Brisé.');
      expect(transformWikilinks('Voir [[pas-un-id]].'), 'Voir pas-un-id.');
    });

    test('leaves fenced code blocks untouched', () {
      const markdown =
          'Avant\n```\n[[20260101120000]]\n```\nAprès '
          '[[20260101120000]].';
      expect(
        transformWikilinks(markdown),
        'Avant\n```\n[[20260101120000]]\n```\nAprès '
        '[20260101120000](sb://note/20260101120000).',
      );
    });

    test('leaves inline code untouched', () {
      expect(
        transformWikilinks('Avant `[[20260101120000]]` après.'),
        'Avant `[[20260101120000]]` après.',
      );
    });

    test('escapes square brackets in labels', () {
      expect(
        transformWikilinks(
          'Voir [[20260101120000]].',
          titlesById: const {'20260101120000': 'Titre [risqué]'},
        ),
        r'Voir [Titre \[risqué\]](sb://note/20260101120000).',
      );
    });
  });

  group('zettelIdFromWikiHref', () {
    test('extracts the id from a wikilink href', () {
      expect(
        zettelIdFromWikiHref('sb://note/20260101120000'),
        '20260101120000',
      );
    });

    test('returns null for external or malformed hrefs', () {
      expect(zettelIdFromWikiHref('https://example.com'), isNull);
      expect(zettelIdFromWikiHref('sb://note/pas-un-id'), isNull);
      expect(zettelIdFromWikiHref(null), isNull);
    });
  });
}
