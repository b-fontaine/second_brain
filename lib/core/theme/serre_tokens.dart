import 'package:flutter/material.dart';

/// Design tokens of the « La Serre » theme, exposed as a [ThemeExtension]
/// so widgets can read semantic colors (maturity, states) that have no
/// direct [ColorScheme] slot.
///
/// Access with `Theme.of(context).extension<SerreTokens>()!`.
@immutable
class SerreTokens extends ThemeExtension<SerreTokens> {
  const SerreTokens({
    required this.paper,
    required this.surface,
    required this.line,
    required this.ink,
    required this.sub,
    required this.accent,
    required this.accentSoft,
    required this.pousse,
    required this.feuillage,
    required this.arbre,
    required this.fleur,
    required this.ambre,
    required this.scrim,
  });

  /// App background (scaffold).
  final Color paper;

  /// Elevated surfaces: cards, sheets, inputs.
  final Color surface;

  /// Hairline borders and dividers.
  final Color line;

  /// Primary text.
  final Color ink;

  /// Secondary text and muted icons.
  final Color sub;

  /// Primary action color.
  final Color accent;

  /// Soft accent fill (selection indicators, chips).
  final Color accentSoft;

  /// Zettel maturity: 0-1 links.
  final Color pousse;

  /// Zettel maturity: 2-3 links.
  final Color feuillage;

  /// Zettel maturity: 4+ links.
  final Color arbre;

  /// AI suggestion highlight.
  final Color fleur;

  /// Pending / conflict state.
  final Color ambre;

  /// Overlay behind dialogs and the seed dial.
  final Color scrim;

  /// Light variant, matching the « La Serre » mockups.
  static const light = SerreTokens(
    paper: Color(0xFFEFF4EA),
    surface: Color(0xFFFBFCF7),
    line: Color(0xFFD6E0CB),
    ink: Color(0xFF27331F),
    sub: Color(0xFF71855F),
    accent: Color(0xFF2F6B4F),
    accentSoft: Color(0xFFE1EEDD),
    pousse: Color(0xFFB7CFA6),
    feuillage: Color(0xFF7FA86B),
    arbre: Color(0xFF2F6B4F),
    fleur: Color(0xFFE8705F),
    ambre: Color(0xFFC9A44A),
    scrim: Color(0x611E2C18), // rgba(30, 44, 24, .38)
  );

  /// Dark variant « serre de nuit ». Provisional: these tokens were not
  /// part of the mockups and will be refined in a later design iteration.
  static const dark = SerreTokens(
    paper: Color(0xFF17231A),
    surface: Color(0xFF1E2C1F),
    line: Color(0xFF33452F),
    ink: Color(0xFFEFF4EA),
    sub: Color(0xFFA9BF9C),
    accent: Color(0xFF8CBA9C),
    accentSoft: Color(0xFF2A3D2C),
    // Maturity and state hues kept from light, slightly desaturated so they
    // do not glow against the dark backgrounds.
    pousse: Color(0xFFA9BC9B),
    feuillage: Color(0xFF7C9E6E),
    arbre: Color(0xFF8CBA9C),
    fleur: Color(0xFFD97A6C),
    ambre: Color(0xFFC0A25E),
    scrim: Color(0x80060B07), // rgba(6, 11, 7, .5)
  );

  @override
  SerreTokens copyWith({
    Color? paper,
    Color? surface,
    Color? line,
    Color? ink,
    Color? sub,
    Color? accent,
    Color? accentSoft,
    Color? pousse,
    Color? feuillage,
    Color? arbre,
    Color? fleur,
    Color? ambre,
    Color? scrim,
  }) {
    return SerreTokens(
      paper: paper ?? this.paper,
      surface: surface ?? this.surface,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      sub: sub ?? this.sub,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      pousse: pousse ?? this.pousse,
      feuillage: feuillage ?? this.feuillage,
      arbre: arbre ?? this.arbre,
      fleur: fleur ?? this.fleur,
      ambre: ambre ?? this.ambre,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  SerreTokens lerp(ThemeExtension<SerreTokens>? other, double t) {
    if (other is! SerreTokens) return this;
    return SerreTokens(
      paper: Color.lerp(paper, other.paper, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      sub: Color.lerp(sub, other.sub, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      pousse: Color.lerp(pousse, other.pousse, t)!,
      feuillage: Color.lerp(feuillage, other.feuillage, t)!,
      arbre: Color.lerp(arbre, other.arbre, t)!,
      fleur: Color.lerp(fleur, other.fleur, t)!,
      ambre: Color.lerp(ambre, other.ambre, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
