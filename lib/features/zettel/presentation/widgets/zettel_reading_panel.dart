import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/vault_markdown_image.dart';
// Cross-feature imports — documented exception: the suggestion entity and
// GraphPalette (maturity colors with a ColorScheme fallback) are owned by
// the graph feature; the reading view reuses them so the Racines pastilles
// and the Pollinisation cards stay consistent with the Explorer.
import '../../../graph/domain/entities/related_note_suggestion.dart';
import '../../../graph/presentation/painting/graph_painter.dart';
import '../../domain/entities/zettel_id.dart';
import '../bloc/zettel_detail/zettel_detail_cubit.dart';
import '../utils/wikilink_markdown.dart';
import '../utils/zettel_text_formats.dart';
import 'zettel_mini_constellation.dart';

/// Self-contained reading panel for a zettel: creates its own
/// [ZettelDetailCubit] via getIt. Reused by the detail page's sibling
/// features (e.g. the graph's side panel) — navigate between notes with
/// route pushes, never direct page imports.
class ZettelReadingPanel extends StatelessWidget {
  const ZettelReadingPanel({super.key, required this.zettelId});

  final ZettelId zettelId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ZettelDetailCubit>()..load(zettelId),
      child: const ZettelReadingView(),
    );
  }
}

/// Reading content: mini-constellation of the 1-hop neighborhood, markdown
/// body with tappable wikilinks, metadata, « Racines » (incoming and
/// outgoing links) and « Pollinisation » (RAG suggestions with a « Tisser »
/// action). Requires a [ZettelDetailCubit] above it; used by both
/// [ZettelReadingPanel] and the detail page.
class ZettelReadingView extends StatelessWidget {
  const ZettelReadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ZettelDetailCubit, ZettelDetailState>(
      builder: (context, state) => switch (state) {
        ZettelDetailInitial() || ZettelDetailLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        ZettelDetailError(:final message) => _MessageView(
          icon: Icons.error_outline,
          message: message,
        ),
        ZettelDetailDeleted() => const _MessageView(
          icon: Icons.delete_outline,
          message: 'Note supprimée',
        ),
        ZettelDetailLoaded() => _ZettelContent(state: state),
      },
    );
  }
}

class _ZettelContent extends StatelessWidget {
  const _ZettelContent({required this.state});

  final ZettelDetailLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zettel = state.zettel;
    final markdown = transformWikilinks(
      stripLeadingTitleHeading(zettel.body, zettel.title),
      titlesById: state.linkTitles,
    );
    final neighbors = _neighbors();
    return ListView(
      key: const Key('zettel-reading-panel'),
      padding: const EdgeInsets.all(16),
      children: [
        if (neighbors.isNotEmpty) ...[
          ZettelMiniConstellation(
            key: const Key('mini-constellation'),
            center: MiniConstellationNode(
              id: zettel.id.value,
              title: zettel.title,
              degree: state.degrees[zettel.id.value] ?? neighbors.length,
            ),
            neighbors: neighbors,
            onNeighborTap: (id) => context.push('/note/$id'),
          ),
          const SizedBox(height: 12),
        ],
        Text(zettel.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _MetaItem(
              icon: Icons.event_outlined,
              label: formatFullDateFr(zettel.createdAt),
            ),
            if (zettel.source != null)
              _MetaItem(
                icon: Icons.input_outlined,
                label: 'Source : ${zettel.source}',
              ),
          ],
        ),
        if (zettel.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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
        const Divider(height: 32),
        MarkdownBody(
          data: markdown,
          // Reading body in Literata (serif), as everywhere titles are.
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'Literata',
              fontSize: 16,
              height: 1.6,
            ),
          ),
          onTapLink: (text, href, title) => _handleLinkTap(context, href),
          // Never fetch remote images: notes come from the git remote and
          // a remote image URL would leak the note-opening to its server.
          imageBuilder: vaultMarkdownImageBuilder,
        ),
        const SizedBox(height: 32),
        Text(
          'Racines — liens de la note',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (state.backlinks.isEmpty && state.linkTitles.isEmpty)
          Text(
            'Aucun lien pour l’instant.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          for (final backlink in state.backlinks)
            _RootLinkTile(
              id: backlink.id.value,
              title: backlink.title,
              degree: state.degrees[backlink.id.value] ?? 0,
              incoming: true,
            ),
          for (final entry in state.linkTitles.entries)
            _RootLinkTile(
              id: entry.key,
              title: entry.value,
              degree: state.degrees[entry.key] ?? 0,
              incoming: false,
            ),
        ],
        if (state.suggestions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Pollinisation — notes proches',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final (index, suggestion) in state.suggestions.indexed)
            _PollinationTile(suggestion: suggestion, rank: index + 1),
        ],
      ],
    );
  }

  /// 1-hop neighborhood of the note: backlinks first, then the outgoing
  /// targets that are not already backlinks (a note can be both).
  List<MiniConstellationNode> _neighbors() {
    final seen = <String>{};
    final neighbors = <MiniConstellationNode>[];
    for (final backlink in state.backlinks) {
      if (seen.add(backlink.id.value)) {
        neighbors.add(
          MiniConstellationNode(
            id: backlink.id.value,
            title: backlink.title,
            degree: state.degrees[backlink.id.value] ?? 0,
          ),
        );
      }
    }
    for (final entry in state.linkTitles.entries) {
      if (seen.add(entry.key)) {
        neighbors.add(
          MiniConstellationNode(
            id: entry.key,
            title: entry.value,
            degree: state.degrees[entry.key] ?? 0,
          ),
        );
      }
    }
    return neighbors;
  }

  void _handleLinkTap(BuildContext context, String? href) {
    final id = zettelIdFromWikiHref(href);
    if (id != null) {
      context.push('/note/$id');
      return;
    }
    // External links: no url_launcher dependency, surface the URL instead.
    if (href != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('Lien externe : $href')));
    }
  }
}

/// A « Racines » row: direction of the link, maturity pastille of the
/// neighbor, title; tap opens the neighbor's detail.
class _RootLinkTile extends StatelessWidget {
  const _RootLinkTile({
    required this.id,
    required this.title,
    required this.degree,
    required this.incoming,
  });

  final String id;
  final String title;
  final int degree;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = GraphPalette.fromTheme(theme);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('root-link-$id'),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              incoming ? Icons.call_received : Icons.call_made,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            _MaturityDot(color: palette.maturityColor(degree)),
          ],
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(incoming ? 'Lien entrant' : 'Lien sortant'),
        onTap: () => context.push('/note/$id'),
      ),
    );
  }
}

/// A « Pollinisation » card: suggested note with its score (or rank when
/// the keyword fallback answered, which carries no comparable score) and
/// the « Tisser » action appending a wikilink to the note body.
class _PollinationTile extends StatelessWidget {
  const _PollinationTile({required this.suggestion, required this.rank});

  final RelatedNoteSuggestion suggestion;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = GraphPalette.fromTheme(theme);
    final score = suggestion.score;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: Key('pollination-${suggestion.id}'),
        leading: Icon(Icons.local_florist_outlined, color: palette.fleur),
        title: Text(
          suggestion.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          score != null
              ? 'Proximité ${(score * 100).round()} %'
              : 'Suggestion n° $rank',
        ),
        trailing: TextButton.icon(
          key: Key('weave-${suggestion.id}'),
          onPressed: () =>
              context.read<ZettelDetailCubit>().weave(suggestion),
          icon: const Icon(Icons.add_link, size: 18),
          label: const Text('Tisser'),
        ),
        onTap: () => context.push('/note/${suggestion.id}'),
      ),
    );
  }
}

class _MaturityDot extends StatelessWidget {
  const _MaturityDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
