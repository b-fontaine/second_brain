import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/zettel/domain/entities/inbox_item.dart';

void main() {
  InboxItem item({
    String rawText = 'corps',
    String? title,
    String? assetPath,
    CaptureType type = CaptureType.clipboard,
  }) {
    return InboxItem(
      id: '20260716094100',
      type: type,
      rawText: rawText,
      capturedAt: DateTime(2026, 7, 16, 9, 41),
      assetPath: assetPath,
      title: title,
    );
  }

  group('proposedTitle', () {
    test('prefers the enriched title', () {
      expect(
        item(title: '  Semis enrichi  ', rawText: 'autre chose').proposedTitle,
        'Semis enrichi',
      );
    });

    test('falls back to the first non-empty line, heading marks '
        'stripped', () {
      expect(
        item(rawText: '\n  \n## Un titre markdown\ncorps').proposedTitle,
        'Un titre markdown',
      );
    });

    test('skips lines left empty by the heading stripping', () {
      expect(item(rawText: '###\nVraie ligne').proposedTitle, 'Vraie ligne');
    });

    test('truncates very long lines with an ellipsis', () {
      final title = item(rawText: 'mot ' * 60).proposedTitle;
      expect(title.length, lessThanOrEqualTo(81));
      expect(title, endsWith('…'));
    });

    test('labels blank captures explicitly', () {
      expect(
        item(rawText: '   \n  ', title: '  ').proposedTitle,
        InboxItem.untitledSeedling,
      );
    });
  });

  group('captureSource', () {
    test('uses the item id when the capture has no asset', () {
      expect(
        item(type: CaptureType.dictation).captureSource,
        'capture:dictation:20260716094100',
      );
    });

    test('uses the asset base name when the capture has one', () {
      expect(
        item(
          type: CaptureType.audio,
          assetPath: 'assets/meeting.m4a',
        ).captureSource,
        'capture:audio:meeting.m4a',
      );
    });
  });
}
