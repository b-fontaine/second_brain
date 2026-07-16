import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/data/models/inbox_item_model.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';

void main() {
  final item = InboxItem(
    id: '20260714103000',
    type: CaptureType.audio,
    rawText: 'Transcription de la réunion : idées à trier.\nDeuxième ligne.',
    capturedAt: DateTime(2026, 7, 14, 10, 30),
    assetPath: 'assets/meeting.m4a',
    status: InboxStatus.pending,
  );

  group('round-trip', () {
    test('preserves every field including accents and multiline text', () {
      final decoded = InboxItemModel.fromJsonString(
        InboxItemModel.toJsonString(item),
      );
      expect(decoded, item);
    });

    test('preserves a null assetPath', () {
      final withoutAsset = InboxItem(
        id: '20260714103001',
        type: CaptureType.clipboard,
        rawText: 'Texte collé',
        capturedAt: DateTime(2026, 7, 14, 10, 31),
      );
      final decoded = InboxItemModel.fromJsonString(
        InboxItemModel.toJsonString(withoutAsset),
      );
      expect(decoded, withoutAsset);
      expect(decoded.assetPath, isNull);
    });

    test('preserves a non-default status', () {
      final processed = item.copyWith(status: InboxStatus.processed);
      final decoded = InboxItemModel.fromJsonString(
        InboxItemModel.toJsonString(processed),
      );
      expect(decoded.status, InboxStatus.processed);
    });

    test('preserves the enriched title and parcelles', () {
      final enriched = InboxItem(
        id: '20260716120000',
        type: CaptureType.file,
        rawText: 'Contenu du fichier markdown.',
        capturedAt: DateTime(2026, 7, 16, 12),
        title: 'Titre proposé par l’assistant',
        tags: const ['jardin', 'semis'],
      );
      final decoded = InboxItemModel.fromJsonString(
        InboxItemModel.toJsonString(enriched),
      );
      expect(decoded, enriched);
      expect(decoded.title, 'Titre proposé par l’assistant');
      expect(decoded.tags, ['jardin', 'semis']);
    });
  });

  group('serialization format', () {
    test('writes pretty-printed JSON ending with a newline', () {
      final raw = InboxItemModel.toJsonString(item);
      expect(raw, startsWith('{\n'));
      expect(raw, endsWith('\n'));
      expect(raw, contains('"type": "audio"'));
      expect(raw, contains('"status": "pending"'));
    });
  });

  group('backward compatibility', () {
    test('reads pre-enrichment files without title or tags', () {
      final decoded = InboxItemModel.fromJson({
        'id': '20260714103000',
        'type': 'clipboard',
        'rawText': 'Capture historique',
        'capturedAt': '2026-07-14T10:30:00.000',
        'status': 'pending',
      });
      expect(decoded.title, isNull);
      expect(decoded.tags, isEmpty);
    });

    test('ignores malformed enrichment fields instead of throwing', () {
      final decoded = InboxItemModel.fromJson({
        'id': '20260714103000',
        'type': 'clipboard',
        'rawText': 'Capture historique',
        'capturedAt': '2026-07-14T10:30:00.000',
        'title': 42,
        'tags': ['ok', 7, '  '],
        'status': 'pending',
      });
      expect(decoded.title, isNull);
      expect(decoded.tags, ['ok']);
    });
  });

  group('corrupt input', () {
    test('throws on invalid JSON', () {
      expect(
        () => InboxItemModel.fromJsonString('{pas du json'),
        throwsFormatException,
      );
    });

    test('throws when payload is not an object', () {
      expect(
        () => InboxItemModel.fromJsonString('[1, 2, 3]'),
        throwsFormatException,
      );
    });

    test('throws on an unknown capture type', () {
      expect(
        () => InboxItemModel.fromJson({
          'id': '20260714103000',
          'type': 'telepathy',
          'rawText': 'x',
          'capturedAt': '2026-07-14T10:30:00',
          'status': 'pending',
        }),
        throwsFormatException,
      );
    });

    test('throws on an unknown status', () {
      expect(
        () => InboxItemModel.fromJson({
          'id': '20260714103000',
          'type': 'clipboard',
          'rawText': 'x',
          'capturedAt': '2026-07-14T10:30:00',
          'status': 'lost',
        }),
        throwsFormatException,
      );
    });

    test('throws on a missing id or malformed date', () {
      expect(
        () => InboxItemModel.fromJson({
          'type': 'clipboard',
          'rawText': 'x',
          'capturedAt': '2026-07-14T10:30:00',
          'status': 'pending',
        }),
        throwsFormatException,
      );
      expect(
        () => InboxItemModel.fromJson({
          'id': '20260714103000',
          'type': 'clipboard',
          'rawText': 'x',
          'capturedAt': 'hier matin',
          'status': 'pending',
        }),
        throwsFormatException,
      );
    });
  });
}
