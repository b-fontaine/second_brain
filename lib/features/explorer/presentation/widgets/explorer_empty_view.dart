import 'package:flutter/material.dart';

import '../../../../core/theme/serre_tokens.dart';

/// Empty-garden state of the Explorer surface: a painted sprout and a call
/// to action guiding towards the central « Semer » button of the shell.
class ExplorerEmptyView extends StatelessWidget {
  const ExplorerEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(96, 110),
              painter: _SproutPainter(
                stem: tokens.arbre,
                leftLeaf: tokens.feuillage,
                rightLeaf: tokens.pousse,
                ground: tokens.line,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Aucune note pour l'instant…",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Semez votre première idée avec le bouton « Semer ».',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.sub),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal sprout illustration (no binary asset): a curved stem, two leaves
/// and the ground line, painted with the maturity palette.
class _SproutPainter extends CustomPainter {
  const _SproutPainter({
    required this.stem,
    required this.leftLeaf,
    required this.rightLeaf,
    required this.ground,
  });

  final Color stem;
  final Color leftLeaf;
  final Color rightLeaf;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Ground line.
    canvas.drawLine(
      Offset(w * 0.15, h * 0.92),
      Offset(w * 0.85, h * 0.92),
      Paint()
        ..color = ground
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Stem: gentle S-curve from the ground to the bud.
    final stemPath = Path()
      ..moveTo(w * 0.50, h * 0.90)
      ..cubicTo(w * 0.54, h * 0.72, w * 0.46, h * 0.52, w * 0.50, h * 0.34);
    canvas.drawPath(
      stemPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = stem
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Two leaves: closed lens shapes on both sides of the stem.
    final left = Path()
      ..moveTo(w * 0.50, h * 0.62)
      ..quadraticBezierTo(w * 0.26, h * 0.66, w * 0.16, h * 0.46)
      ..quadraticBezierTo(w * 0.38, h * 0.42, w * 0.50, h * 0.62)
      ..close();
    canvas.drawPath(left, Paint()..color = leftLeaf);

    final right = Path()
      ..moveTo(w * 0.50, h * 0.48)
      ..quadraticBezierTo(w * 0.74, h * 0.52, w * 0.84, h * 0.32)
      ..quadraticBezierTo(w * 0.62, h * 0.28, w * 0.50, h * 0.48)
      ..close();
    canvas.drawPath(right, Paint()..color = rightLeaf);

    // Bud at the tip of the stem.
    canvas.drawCircle(Offset(w * 0.50, h * 0.30), 5, Paint()..color = stem);
  }

  @override
  bool shouldRepaint(covariant _SproutPainter oldDelegate) =>
      stem != oldDelegate.stem ||
      leftLeaf != oldDelegate.leftLeaf ||
      rightLeaf != oldDelegate.rightLeaf ||
      ground != oldDelegate.ground;
}
