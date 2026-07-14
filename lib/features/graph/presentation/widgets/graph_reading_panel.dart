import 'package:flutter/material.dart';

import '../../../zettel/domain/entities/zettel_id.dart';
// Cross-feature widget import — documented exception: ZettelReadingPanel is
// the shared reading widget exposed by the zettel feature for reuse here.
import '../../../zettel/presentation/widgets/zettel_reading_panel.dart';

/// Hosts the shared [ZettelReadingPanel] with a close button. Used both as
/// the right side panel (expanded layout) and inside the draggable bottom
/// sheet (compact layout).
class GraphReadingPanel extends StatelessWidget {
  const GraphReadingPanel({
    super.key,
    required this.zettelId,
    required this.onClose,
  });

  final ZettelId zettelId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ),
            ),
            Expanded(child: ZettelReadingPanel(zettelId: zettelId)),
          ],
        ),
      ),
    );
  }
}
