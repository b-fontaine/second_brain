import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/data/datasources/zettel_file_naming.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';

void main() {
  final id = ZettelId.fromString('20260714103000');

  group('zettelFileName', () {
    test('slugifies the title: lowercase, hyphens, no accents', () {
      expect(
        zettelFileName(id, 'Mémoire de travail'),
        '20260714103000-memoire-de-travail.md',
      );
    });

    test('folds punctuation and apostrophes', () {
      expect(
        zettelFileName(id, "L'attention, ça se travaille !"),
        '20260714103000-lattention-ca-se-travaille.md',
      );
    });

    test('falls back to the bare id when the slug is empty', () {
      expect(zettelFileName(id, '???'), '20260714103000.md');
    });

    test('truncates long titles and never ends with a hyphen', () {
      final name = zettelFileName(id, 'mot ' * 40);
      // '<id>-' + slug (max 60) + '.md'
      expect(name.length, lessThanOrEqualTo(14 + 1 + 60 + 3));
      expect(name, endsWith('.md'));
      expect(name.substring(0, name.length - 3), isNot(endsWith('-')));
    });
  });

  group('zettelIdFromFileName', () {
    test('parses our convention <id>-<slug>.md', () {
      expect(
        zettelIdFromFileName('20260714103000-memoire-de-travail.md')?.value,
        '20260714103000',
      );
    });

    test('parses a bare <id>.md', () {
      expect(
        zettelIdFromFileName('20260714103000.md')?.value,
        '20260714103000',
      );
    });

    test('parses The Archive style "<id> Title.md"', () {
      expect(
        zettelIdFromFileName('20260714103000 Mémoire de travail.md')?.value,
        '20260714103000',
      );
    });

    test('rejects non-zettel files', () {
      expect(zettelIdFromFileName('README.md'), isNull);
      expect(zettelIdFromFileName('notes.txt'), isNull);
      expect(zettelIdFromFileName('202607141030-id-trop-court.md'), isNull);
      expect(
        zettelIdFromFileName('202607141030001-quinze-chiffres.md'),
        isNull,
      );
      expect(zettelIdFromFileName('20260714103000-note'), isNull);
    });
  });
}
