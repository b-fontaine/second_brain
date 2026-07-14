import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/core/theme/serre_tokens.dart';
import 'package:second_brain/features/zettel/presentation/utils/zettel_maturity.dart';

void main() {
  group('ZettelMaturity.of', () {
    test('returns pousse for 0 and 1 links', () {
      expect(ZettelMaturity.of(0), ZettelMaturity.pousse);
      expect(ZettelMaturity.of(1), ZettelMaturity.pousse);
    });

    test('returns feuillage for 2 and 3 links', () {
      expect(ZettelMaturity.of(2), ZettelMaturity.feuillage);
      expect(ZettelMaturity.of(3), ZettelMaturity.feuillage);
    });

    test('returns arbre for 4 links and above', () {
      expect(ZettelMaturity.of(4), ZettelMaturity.arbre);
      expect(ZettelMaturity.of(42), ZettelMaturity.arbre);
    });

    test('treats negative counts as pousse', () {
      expect(ZettelMaturity.of(-1), ZettelMaturity.pousse);
    });
  });

  group('ZettelMaturity.color', () {
    testWidgets('resolves each stage from the theme tokens', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      const tokens = SerreTokens.light;
      expect(ZettelMaturity.pousse.color(context), tokens.pousse);
      expect(ZettelMaturity.feuillage.color(context), tokens.feuillage);
      expect(ZettelMaturity.arbre.color(context), tokens.arbre);
    });
  });
}
