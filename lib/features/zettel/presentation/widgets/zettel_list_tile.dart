import 'package:flutter/material.dart';

import '../../domain/entities/zettel.dart';
import '../utils/zettel_text_formats.dart';

/// List row for a zettel: title, two-line excerpt, tag chips and a
/// relative date in French.
class ZettelListTile extends StatelessWidget {
  const ZettelListTile({
    super.key,
    required this.zettel,
    this.selected = false,
    this.onTap,
  });

  final Zettel zettel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final excerpt = zettelExcerpt(
      stripLeadingTitleHeading(zettel.body, zettel.title),
    );
    return ListTile(
      onTap: onTap,
      selected: selected,
      title: Text(
        zettel.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (excerpt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                excerpt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          if (zettel.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final tag in zettel.tags)
                    Chip(
                      label: Text(tag, style: theme.textTheme.labelSmall),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                ],
              ),
            ),
        ],
      ),
      trailing: Text(
        formatRelativeDateFr(zettel.createdAt),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
