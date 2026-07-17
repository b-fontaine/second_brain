import 'package:flutter/material.dart';

import '../theme/serre_tokens.dart';

/// Small stadium-shaped status badge — an optional colored dot plus a
/// label — in the « La Serre » visual language (see [SerreTokens]).
///
/// Used for lightweight state/selection indicators (recommended option,
/// active choice, pending counts) across features.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.dotColor, this.onTap});

  final String label;

  /// Status dot color; no dot when null.
  final Color? dotColor;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Material(
      color: tokens.surface,
      shape: StadiumBorder(side: BorderSide(color: tokens.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: tokens.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
