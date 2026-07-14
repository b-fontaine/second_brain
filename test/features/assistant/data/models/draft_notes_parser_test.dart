import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/assistant/data/models/draft_notes_parser.dart';

void main() {
  group('DraftNotesParser.tryParse', () {
    test('parses a clean JSON object', () {
      const raw =
          '{"notes":[{"title":"Mémoire de travail",'
          '"body":"La mémoire de travail est limitée.",'
          '"tags":["cognition","memoire"]}]}';

      final notes = DraftNotesParser.tryParse(raw);

      expect(notes, isNotNull);
      expect(notes, hasLength(1));
      expect(notes!.first.title, 'Mémoire de travail');
      expect(notes.first.body, 'La mémoire de travail est limitée.');
      expect(notes.first.tags, ['cognition', 'memoire']);
    });

    test('parses several notes', () {
      const raw =
          '{"notes":['
          '{"title":"A","body":"Corps A","tags":["a"]},'
          '{"title":"B","body":"Corps B","tags":[]},'
          '{"title":"C","body":"Corps C"}'
          ']}';

      final notes = DraftNotesParser.tryParse(raw);

      expect(notes, hasLength(3));
      expect(notes![2].tags, isEmpty);
    });

    test('extracts JSON wrapped in a markdown fence and prose', () {
      const raw =
          'Voici les notes demandées :\n'
          '```json\n'
          '{"notes":[{"title":"Titre","body":"Corps","tags":["tag"]}]}\n'
          '```\n'
          "J'espère que cela convient.";

      final notes = DraftNotesParser.tryParse(raw);

      expect(notes, hasLength(1));
      expect(notes!.first.title, 'Titre');
      expect(notes.first.body, 'Corps');
    });

    test('repairs trailing commas', () {
      const raw = '{"notes":[{"title":"T","body":"B","tags":["x",],},],}';

      final notes = DraftNotesParser.tryParse(raw);

      expect(notes, hasLength(1));
      expect(notes!.first.tags, ['x']);
    });

    test('ignores braces inside JSON strings', () {
      const raw =
          '{"notes":[{"title":"Accolades {}",'
          '"body":"Un corps avec { et } dedans","tags":[]}]}';

      final notes = DraftNotesParser.tryParse(raw);

      expect(notes, hasLength(1));
      expect(notes!.first.body, 'Un corps avec { et } dedans');
    });

    test('returns null on unrecoverable JSON', () {
      expect(DraftNotesParser.tryParse('pas de json ici'), isNull);
      expect(DraftNotesParser.tryParse('{"notes": pas valide'), isNull);
      expect(DraftNotesParser.tryParse(''), isNull);
    });

    test('returns null when the notes list is missing or empty', () {
      expect(DraftNotesParser.tryParse('{"autre":"chose"}'), isNull);
      expect(DraftNotesParser.tryParse('{"notes":[]}'), isNull);
    });

    test('skips malformed entries but keeps the valid ones', () {
      const raw =
          '{"notes":['
          '{"title":"","body":"corps sans titre"},'
          '{"title":"Valide","body":"Corps valide","tags":["ok"]},'
          '{"title":"Sans corps"}'
          ']}';

      final notes = DraftNotesParser.tryParse(raw);

      expect(notes, hasLength(1));
      expect(notes!.first.title, 'Valide');
    });
  });

  group('DraftNotesParser.extractFirstJsonObject', () {
    test('returns the first balanced object', () {
      expect(
        DraftNotesParser.extractFirstJsonObject('avant {"a":1} après {"b":2}'),
        '{"a":1}',
      );
    });

    test('best-effort slice when the object is truncated', () {
      const raw = '{"notes":[{"title":"T","body":"B"}]';
      expect(
        DraftNotesParser.extractFirstJsonObject(raw),
        '{"notes":[{"title":"T","body":"B"}',
      );
    });

    test('returns null without any opening brace', () {
      expect(DraftNotesParser.extractFirstJsonObject('rien'), isNull);
    });
  });

  group('DraftNotesParser.repairTrailingCommas', () {
    test('removes commas before closing brackets', () {
      expect(
        DraftNotesParser.repairTrailingCommas('{"a":[1,2,],"b":{"c":1,},}'),
        '{"a":[1,2],"b":{"c":1}}',
      );
    });

    test('keeps valid separators untouched', () {
      const valid = '{"a":[1,2],"b":"x, y"}';
      expect(DraftNotesParser.repairTrailingCommas(valid), valid);
    });

    test('never touches commas inside string values', () {
      // The body itself contains what looks like a trailing comma: only
      // the structural one (after the note object) may be removed.
      const raw =
          '{"notes":[{"title":"T","body":"points : [1, 2, ]","tags":[]},]}';
      expect(
        DraftNotesParser.repairTrailingCommas(raw),
        '{"notes":[{"title":"T","body":"points : [1, 2, ]","tags":[]}]}',
      );

      final notes = DraftNotesParser.tryParse(raw);
      expect(notes, hasLength(1));
      expect(notes!.first.body, 'points : [1, 2, ]');
    });

    test('ignores escaped quotes when tracking strings', () {
      const raw = r'{"a":"guillemet \" et , virgule","b":[1,]}';
      expect(
        DraftNotesParser.repairTrailingCommas(raw),
        r'{"a":"guillemet \" et , virgule","b":[1]}',
      );
    });
  });
}
