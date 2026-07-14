import 'package:flutter/material.dart';

import '../../../../core/theme/serre_tokens.dart';

/// Growth stage of a zettel, derived from its link count (outgoing links
/// plus backlinks). Drives node and badge colors everywhere (graph, lists).
enum ZettelMaturity {
  /// 0-1 links: freshly planted.
  pousse,

  /// 2-3 links: growing.
  feuillage,

  /// 4+ links: well rooted.
  arbre;

  /// Maps a link count to its maturity stage. Counts below zero are
  /// treated as zero.
  static ZettelMaturity of(int linkCount) {
    if (linkCount >= 4) return arbre;
    if (linkCount >= 2) return feuillage;
    return pousse;
  }

  /// Theme-aware color of this stage, read from [SerreTokens].
  Color color(BuildContext context) {
    final tokens = Theme.of(context).extension<SerreTokens>()!;
    return switch (this) {
      pousse => tokens.pousse,
      feuillage => tokens.feuillage,
      arbre => tokens.arbre,
    };
  }
}
