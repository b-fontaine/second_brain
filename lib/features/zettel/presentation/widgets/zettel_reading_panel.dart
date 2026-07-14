import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/vault_markdown_image.dart';
import '../../domain/entities/zettel_id.dart';
import '../bloc/zettel_detail/zettel_detail_cubit.dart';
import '../utils/wikilink_markdown.dart';
import '../utils/zettel_text_formats.dart';

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

/// Reading content (markdown body with tappable wikilinks, metadata,
/// backlinks). Requires a [ZettelDetailCubit] above it; used by both
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
    return ListView(
      key: const Key('zettel-reading-panel'),
      padding: const EdgeInsets.all(16),
      children: [
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
          styleSheet: MarkdownStyleSheet.fromTheme(theme),
          onTapLink: (text, href, title) => _handleLinkTap(context, href),
          // Never fetch remote images: notes come from the git remote and
          // a remote image URL would leak the note-opening to its server.
          imageBuilder: vaultMarkdownImageBuilder,
        ),
        const SizedBox(height: 32),
        Text('Liens entrants', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (state.backlinks.isEmpty)
          Text(
            'Aucun lien entrant.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final backlink in state.backlinks)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.call_received),
                title: Text(
                  backlink.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => context.push('/note/${backlink.id.value}'),
              ),
            ),
      ],
    );
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
