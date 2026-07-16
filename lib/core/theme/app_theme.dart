import 'package:flutter/material.dart';

import 'serre_tokens.dart';

/// Material 3 theme of the app, light and dark, built from [SerreTokens]
/// (« La Serre » design language).
///
/// Typography: Literata (serif) for display/headline/title, JetBrains Mono
/// for metadata ([TextTheme.labelSmall]), system font everywhere else.
/// Both families are bundled in assets/fonts (offline-first, no runtime
/// font download).
abstract final class AppTheme {
  // Memoized: rebuilding ThemeData yields unequal instances (the WidgetState
  // resolver closures differ), which makes every MaterialApp re-pump run a
  // spurious 200 ms AnimatedTheme transition.
  static final ThemeData light = _base(SerreTokens.light, Brightness.light);

  static final ThemeData dark = _base(SerreTokens.dark, Brightness.dark);

  static ThemeData _base(SerreTokens tokens, Brightness brightness) {
    final scheme = _schemeFrom(tokens, brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [tokens],
      scaffoldBackgroundColor: tokens.paper,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: _textTheme,
      dividerTheme: DividerThemeData(color: tokens.line, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.paper,
        foregroundColor: tokens.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tokens.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: tokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.accent, width: 2),
        ),
      ),
      // Dark toast on both brightnesses (light ink over light paper),
      // as in the mockups.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF27331F),
        contentTextStyle: TextStyle(color: Color(0xFFEFF4EA)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.accentSoft,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? tokens.accent
                : tokens.sub,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? tokens.accent
                : tokens.sub,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.accentSoft,
        selectedIconTheme: IconThemeData(color: tokens.accent),
        unselectedIconTheme: IconThemeData(color: tokens.sub),
        selectedLabelTextStyle: TextStyle(color: tokens.accent),
        unselectedLabelTextStyle: TextStyle(color: tokens.sub),
      ),
    );
  }

  /// Full M3 scheme derived from the tokens so every stock component keeps
  /// a coherent contrast without per-widget overrides.
  static ColorScheme _schemeFrom(SerreTokens tokens, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    // onPrimary must contrast with the accent: light paper over the deep
    // green in light mode, deep ink over the lightened green in dark mode.
    final onAccent = isLight ? const Color(0xFFFBFCF7) : const Color(0xFF17231A);
    return ColorScheme(
      brightness: brightness,
      primary: tokens.accent,
      onPrimary: onAccent,
      primaryContainer: isLight ? tokens.accentSoft : const Color(0xFF2F6B4F),
      onPrimaryContainer: isLight ? tokens.ink : const Color(0xFFE1EEDD),
      secondary: tokens.sub,
      onSecondary: onAccent,
      secondaryContainer: isLight ? tokens.pousse : tokens.accentSoft,
      onSecondaryContainer: tokens.ink,
      tertiary: tokens.fleur,
      onTertiary: onAccent,
      tertiaryContainer:
          isLight ? const Color(0xFFF6DED9) : const Color(0xFF5C2B23),
      onTertiaryContainer:
          isLight ? const Color(0xFF3E1A14) : const Color(0xFFF6DED9),
      error: isLight ? const Color(0xFFB3261E) : const Color(0xFFF2B8B5),
      onError: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF601410),
      errorContainer:
          isLight ? const Color(0xFFF9DEDC) : const Color(0xFF8C1D18),
      onErrorContainer:
          isLight ? const Color(0xFF410E0B) : const Color(0xFFF9DEDC),
      surface: tokens.surface,
      onSurface: tokens.ink,
      onSurfaceVariant: tokens.sub,
      surfaceDim: isLight ? const Color(0xFFDAE2D0) : const Color(0xFF121C14),
      surfaceBright: isLight ? tokens.surface : const Color(0xFF2A3B2C),
      surfaceContainerLowest:
          isLight ? const Color(0xFFFFFFFF) : const Color(0xFF101911),
      surfaceContainerLow:
          isLight ? const Color(0xFFF5F8F0) : const Color(0xFF1A271B),
      surfaceContainer: tokens.paper,
      surfaceContainerHigh:
          isLight ? const Color(0xFFE8EFE1) : const Color(0xFF243424),
      surfaceContainerHighest:
          isLight ? const Color(0xFFE1E9D8) : const Color(0xFF2A3B2C),
      outline: tokens.sub,
      outlineVariant: tokens.line,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF1E2C18),
      inverseSurface: isLight ? tokens.ink : tokens.paper,
      onInverseSurface: isLight ? tokens.paper : tokens.ink,
      inversePrimary:
          isLight ? const Color(0xFF8CBA9C) : const Color(0xFF2F6B4F),
      surfaceTint: tokens.accent,
    );
  }

  /// Family overrides only: sizes, weights and colors keep the Material
  /// typography defaults so component text keeps its expected metrics.
  static const _serif = TextStyle(fontFamily: 'Literata');

  static const _textTheme = TextTheme(
    displayLarge: _serif,
    displayMedium: _serif,
    displaySmall: _serif,
    headlineLarge: _serif,
    headlineMedium: _serif,
    headlineSmall: _serif,
    titleLarge: _serif,
    titleMedium: _serif,
    titleSmall: _serif,
    labelSmall: TextStyle(fontFamily: 'JetBrainsMono'),
  );
}

/// Material 3 window size breakpoints used by adaptive layouts.
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < medium;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}
