import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/core/theme/app_theme.dart';
import 'package:second_brain/core/theme/serre_tokens.dart';

void main() {
  group('AppTheme', () {
    test('light theme exposes the light SerreTokens extension', () {
      final tokens = AppTheme.light.extension<SerreTokens>();
      expect(tokens, isNotNull);
      expect(tokens, SerreTokens.light);
    });

    test('dark theme exposes the dark SerreTokens extension', () {
      final tokens = AppTheme.dark.extension<SerreTokens>();
      expect(tokens, isNotNull);
      expect(tokens, SerreTokens.dark);
    });

    test('color scheme is built from the tokens', () {
      final light = AppTheme.light;
      expect(light.colorScheme.primary, SerreTokens.light.accent);
      expect(light.colorScheme.surface, SerreTokens.light.surface);
      expect(light.colorScheme.onSurface, SerreTokens.light.ink);
      expect(light.scaffoldBackgroundColor, SerreTokens.light.paper);

      final dark = AppTheme.dark;
      expect(dark.colorScheme.primary, SerreTokens.dark.accent);
      expect(dark.colorScheme.surface, SerreTokens.dark.surface);
      expect(dark.colorScheme.onSurface, SerreTokens.dark.ink);
      expect(dark.scaffoldBackgroundColor, SerreTokens.dark.paper);
    });

    test('surface and onSurface keep a non-zero contrast', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final scheme = theme.colorScheme;
        expect(scheme.surface, isNot(scheme.onSurface));
        expect(scheme.primary, isNot(scheme.onPrimary));
      }
    });

    test('display, headline and title styles use Literata', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final text = theme.textTheme;
        for (final style in [
          text.displayLarge,
          text.displayMedium,
          text.displaySmall,
          text.headlineLarge,
          text.headlineMedium,
          text.headlineSmall,
          text.titleLarge,
          text.titleMedium,
          text.titleSmall,
        ]) {
          expect(style?.fontFamily, 'Literata');
        }
      }
    });

    test('labelSmall uses JetBrains Mono', () {
      expect(AppTheme.light.textTheme.labelSmall?.fontFamily, 'JetBrainsMono');
      expect(AppTheme.dark.textTheme.labelSmall?.fontFamily, 'JetBrainsMono');
    });

    test('body styles keep the default system font', () {
      expect(AppTheme.light.textTheme.bodyMedium?.fontFamily,
          isNot('Literata'));
    });
  });
}
