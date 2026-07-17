import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/core/theme/serre_tokens.dart';
import 'package:second_brain/features/zettel/presentation/utils/markdown_highlighting_controller.dart';

void main() {
  group('MarkdownHighlightingController.segment', () {
    test('returns nothing for an empty text', () {
      expect(MarkdownHighlightingController.segment(''), isEmpty);
    });

    test('keeps unmarked text as a single plain segment', () {
      expect(MarkdownHighlightingController.segment('Une note simple.'), [
        const MarkdownSegment(MarkdownSegmentKind.plain, 'Une note simple.'),
      ]);
    });

    test('isolates a heading line', () {
      expect(
        MarkdownHighlightingController.segment('# Titre\ncorps'),
        const [
          MarkdownSegment(MarkdownSegmentKind.heading, '# Titre'),
          MarkdownSegment(MarkdownSegmentKind.plain, '\ncorps'),
        ],
      );
    });

    test('only recognizes headings at the start of a line', () {
      expect(
        MarkdownHighlightingController.segment('a # faux titre'),
        const [
          MarkdownSegment(MarkdownSegmentKind.plain, 'a # faux titre'),
        ],
      );
    });

    test('isolates bold runs and wikilinks in the middle of a line', () {
      expect(
        MarkdownHighlightingController.segment(
          'Un **mot fort** relié à [[20260101120000|Concept A]] ici.',
        ),
        const [
          MarkdownSegment(MarkdownSegmentKind.plain, 'Un '),
          MarkdownSegment(MarkdownSegmentKind.bold, '**mot fort**'),
          MarkdownSegment(MarkdownSegmentKind.plain, ' relié à '),
          MarkdownSegment(
            MarkdownSegmentKind.wikilink,
            '[[20260101120000|Concept A]]',
          ),
          MarkdownSegment(MarkdownSegmentKind.plain, ' ici.'),
        ],
      );
    });

    test('leaves an unclosed bold marker plain', () {
      expect(
        MarkdownHighlightingController.segment('du **texte sans fermeture'),
        const [
          MarkdownSegment(
            MarkdownSegmentKind.plain,
            'du **texte sans fermeture',
          ),
        ],
      );
    });

    test('scales linearly on long texts (no quadratic pass)', () {
      final longText = StringBuffer();
      for (var i = 0; i < 2000; i++) {
        longText.writeln('Ligne $i avec **du gras** et [[20260101120000]].');
      }
      final stopwatch = Stopwatch()..start();
      final segments = MarkdownHighlightingController.segment(
        longText.toString(),
      );
      stopwatch.stop();
      expect(segments.length, greaterThan(2000));
      // Generous bound: a quadratic scan of ~100k characters would blow it.
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('buildTextSpan', () {
    testWidgets('styles headings and wikilinks with the accent color and '
        'bold runs in bold', (tester) async {
      final controller = MarkdownHighlightingController(
        text: '# Titre\ndu **gras** et [[20260101120000|Concept A]]',
      );
      addTearDown(controller.dispose);
      late final TextSpan span;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontFamily: 'monospace'),
                withComposing: false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final accent = AppTheme.light.extension<SerreTokens>()!.accent;
      final children = span.children!.cast<TextSpan>();
      final byText = {for (final child in children) child.text!: child.style};

      expect(byText['# Titre']?.color, accent);
      expect(byText['# Titre']?.fontWeight, FontWeight.w700);
      expect(byText['**gras**']?.fontWeight, FontWeight.w700);
      expect(byText['[[20260101120000|Concept A]]']?.color, accent);
      expect(byText.keys, contains('\ndu '));
      expect(byText['\ndu '], isNull, reason: 'plain text keeps the base style');
      // The base style stays on the root span (field metrics untouched).
      expect(span.style?.fontFamily, 'monospace');
      // The concatenation reproduces the exact text (nothing lost).
      expect(span.toPlainText(), controller.text);
    });
  });
}
