import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';

void main() {
  group('Zettel.parseWikiLinks', () {
    test('extracts plain [[id]] links', () {
      final links = Zettel.parseWikiLinks(
        'See [[20260714103005]] and [[20260714103006]].',
      );

      expect(links, [
        ZettelId.fromString('20260714103005'),
        ZettelId.fromString('20260714103006'),
      ]);
    });

    test('extracts [[id|label]] links', () {
      final links = Zettel.parseWikiLinks(
        'See [[20260714103005|la mémoire de travail]].',
      );

      expect(links, [ZettelId.fromString('20260714103005')]);
    });

    test('deduplicates repeated targets', () {
      final links = Zettel.parseWikiLinks(
        '[[20260714103005]] again [[20260714103005]]',
      );

      expect(links, hasLength(1));
    });

    test('ignores non-id wikilinks and malformed brackets', () {
      final links = Zettel.parseWikiLinks(
        '[[not-an-id]] [single] [[2026]] plain text',
      );

      expect(links, isEmpty);
    });

    test('returns empty list for a body without links', () {
      expect(Zettel.parseWikiLinks('Aucun lien ici.'), isEmpty);
    });
  });

  group('Zettel', () {
    final zettel = Zettel(
      id: ZettelId.fromString('20260714103005'),
      title: 'Concept A',
      body: 'Lié à [[20260714103006]].',
      createdAt: DateTime(2026, 7, 14, 10, 30, 5),
      tags: const ['cognition'],
    );

    test('outgoingLinks parses links from the body', () {
      expect(zettel.outgoingLinks, [ZettelId.fromString('20260714103006')]);
    });

    test('copyWith preserves id and createdAt', () {
      final updated = zettel.copyWith(title: 'Concept A2');

      expect(updated.id, zettel.id);
      expect(updated.createdAt, zettel.createdAt);
      expect(updated.title, 'Concept A2');
      expect(updated.body, zettel.body);
    });
  });
}
