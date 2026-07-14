import 'package:flutter/material.dart';

/// Spinner (indeterminate) or progress bar (model download) with a label.
class ExtractionProgressView extends StatelessWidget {
  const ExtractionProgressView({super.key, required this.label, this.progress});

  final String label;

  /// 0.0 → 1.0 for determinate progress, null for a spinner.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(progress!.clamp(0.0, 1.0) * 100).round()} %',
                style: theme.textTheme.labelLarge,
              ),
            ] else
              const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
