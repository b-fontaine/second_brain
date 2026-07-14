import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/domain/entities/zettel_id.dart';

void main() {
  group('ZettelId', () {
    test('fromDateTime formats as yyyyMMddHHmmss', () {
      final id = ZettelId.fromDateTime(DateTime(2026, 7, 14, 10, 30, 5));

      expect(id.value, '20260714103005');
    });

    test('fromDateTime pads single-digit components', () {
      final id = ZettelId.fromDateTime(DateTime(2026, 1, 2, 3, 4, 5));

      expect(id.value, '20260102030405');
    });

    test('fromString accepts a valid 14-digit id', () {
      expect(ZettelId.fromString('20260714103005').value, '20260714103005');
    });

    test('fromString rejects malformed ids', () {
      expect(() => ZettelId.fromString('nope'), throwsFormatException);
      expect(() => ZettelId.fromString('2026071410300'), throwsFormatException);
      expect(
        () => ZettelId.fromString('202607141030055'),
        throwsFormatException,
      );
    });

    test('ids with the same value are equal', () {
      expect(
        ZettelId.fromString('20260714103005'),
        ZettelId.fromString('20260714103005'),
      );
    });

    test('isValid matches only 14-digit strings', () {
      expect(ZettelId.isValid('20260714103005'), isTrue);
      expect(ZettelId.isValid('abc'), isFalse);
      expect(ZettelId.isValid(''), isFalse);
    });
  });
}
