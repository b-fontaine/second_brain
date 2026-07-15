/// Semantic zoom levels of the constellation, derived from the viewport
/// scale. Thresholds are named constants so they can be tuned in one place.
enum GraphLod {
  /// Below [canopyMaxScale] (s1): the constellation collapses into tag
  /// canopies (one blob per dominant tag, sized by member count).
  canopy,

  /// Between [canopyMaxScale] and [fullLabelsMinScale] (s1..s2): individual
  /// nodes are drawn but only the most connected ones keep their label.
  hubs,

  /// Above [fullLabelsMinScale] (s2): every node shows its label.
  detail;

  /// s1 — below this scale the view switches to tag canopies.
  static const double canopyMaxScale = 0.35;

  /// s2 — above this scale all labels are drawn. Matches the pre-existing
  /// label zoom threshold of the painter.
  static const double fullLabelsMinScale = 0.7;

  /// Minimum degree for a node to keep its label in [hubs] mode, aligned
  /// with the « arbre » maturity threshold (4+ links).
  static const int hubLabelMinDegree = 4;

  /// Maps a viewport scale to its level of detail.
  static GraphLod forScale(double scale) {
    if (scale < canopyMaxScale) return canopy;
    if (scale <= fullLabelsMinScale) return hubs;
    return detail;
  }
}
