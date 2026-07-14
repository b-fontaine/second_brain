import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/presentation/utils/zettel_text_formats.dart';

void main() {
  group('formatRelativeDateFr', () {
    final now = DateTime(2026, 7, 14, 15, 0);

    test('less than a minute ago', () {
      expect(
        formatRelativeDateFr(DateTime(2026, 7, 14, 14, 59, 40), now: now),
        "à l'instant",
      );
    });

    test('minutes ago', () {
      expect(
        formatRelativeDateFr(DateTime(2026, 7, 14, 14, 55), now: now),
        'il y a 5 min',
      );
    });

    test('hours ago the same day', () {
      expect(
        formatRelativeDateFr(DateTime(2026, 7, 14, 12, 0), now: now),
        'il y a 3 h',
      );
    });

    test('yesterday by calendar day', () {
      expect(
        formatRelativeDateFr(DateTime(2026, 7, 13, 23, 0), now: now),
        'hier',
      );
    });

    test('a few days ago', () {
      expect(
        formatRelativeDateFr(DateTime(2026, 7, 10, 9, 0), now: now),
        'il y a 4 j',
      );
    });

    test('older date in the same year omits the year', () {
      expect(formatRelativeDateFr(DateTime(2026, 1, 5), now: now), '5 janv.');
    });

    test('older date in another year includes the year', () {
      expect(
        formatRelativeDateFr(DateTime(2025, 3, 10), now: now),
        '10 mars 2025',
      );
    });
  });

  group('formatFullDateFr', () {
    test('formats a full French date with time', () {
      expect(
        formatFullDateFr(DateTime(2026, 7, 14, 10, 30)),
        '14 juillet 2026 à 10:30',
      );
    });

    test('uses 1er for the first day of the month', () {
      expect(
        formatFullDateFr(DateTime(2026, 2, 1, 9, 5)),
        '1er février 2026 à 9:05',
      );
    });
  });

  group('zettelExcerpt', () {
    test('strips markdown markers, links and code', () {
      const body = '''
## Une section

Du texte **important** avec un [[20260101120000|lien interne]] et
un [lien externe](https://example.com).

```dart
final code = 'ignoré';
```

- item de liste
''';
      expect(
        zettelExcerpt(body),
        'Une section Du texte important avec un lien interne et '
        'un lien externe. item de liste',
      );
    });

    test('keeps the alias of wikilinks and the id of bare wikilinks', () {
      expect(
        zettelExcerpt('Voir [[20260101120000]] et [[20260202120000|B]].'),
        'Voir 20260101120000 et B.',
      );
    });
  });

  group('stripLeadingTitleHeading', () {
    test('removes a leading H1 duplicating the title', () {
      expect(
        stripLeadingTitleHeading('# Mon titre\n\nCorps.', 'Mon titre'),
        '\nCorps.',
      );
    });

    test('keeps a heading that differs from the title', () {
      expect(
        stripLeadingTitleHeading('# Autre chose\n\nCorps.', 'Mon titre'),
        '# Autre chose\n\nCorps.',
      );
    });
  });

  group('normalizeTag', () {
    test('lowercases, trims, removes # and hyphenates spaces', () {
      expect(normalizeTag('  #Mémoire de Travail '), 'mémoire-de-travail');
    });

    test('returns empty for blank input', () {
      expect(normalizeTag('   '), '');
    });
  });
}
