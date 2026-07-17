import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/serre_tokens.dart';
// Cross-feature domain import — documented exception: the nursery displays
// the pending captures (inbox items) owned by the zettel feature.
import '../../../zettel/domain/entities/inbox_item.dart';
import '../bloc/pepiniere_cubit.dart';

/// « Pépinière — brouillons à valider » (route `/pepiniere`): every pending
/// capture of the inbox as an amber-bordered card (waiting state), with the
/// three nursery actions — **Repiquer** (inbox → zettel), **Modifier**
/// (prefilled edition, transplanted with the edits on save) and
/// **Composter** (delete, with a light confirmation).
///
/// Pushed above the shell (like `/settings`), so the page carries its own
/// AppBar; the whole content scrolls (the 800×600 test viewport must reach
/// every card action).
class PepinierePage extends StatelessWidget {
  const PepinierePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<PepiniereCubit>()..start(),
      child: const _PepiniereView(),
    );
  }
}

class _PepiniereView extends StatelessWidget {
  const _PepiniereView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pépinière')),
      body: SafeArea(
        child: BlocConsumer<PepiniereCubit, PepiniereState>(
          listenWhen: (previous, current) =>
              current is PepiniereLoaded &&
              current.notice != null &&
              (previous is! PepiniereLoaded ||
                  previous.notice != current.notice),
          listener: (context, state) {
            final notice = (state as PepiniereLoaded).notice!;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(notice.message)));
          },
          builder: (context, state) => switch (state) {
            PepiniereLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
            PepiniereLoadFailure(:final message) => _LoadFailureView(
              message: message,
            ),
            PepiniereLoaded(:final items) =>
              items.isEmpty
                  ? const _EmptyNurseryView()
                  : _SeedlingList(state: state),
          },
        ),
      ),
    );
  }
}

class _SeedlingList extends StatelessWidget {
  const _SeedlingList({required this.state});

  final PepiniereLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    final items = state.items;
    final count = items.length;
    return ListView.separated(
      key: const Key('pepiniere-list'),
      padding: const EdgeInsets.all(16),
      itemCount: count + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          // The gardener label never stands alone: the functional meaning
          // (drafts to validate) heads the list.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(
                count == 1
                    ? '1 brouillon à valider — repiquez-le en note '
                          'ou compostez-le.'
                    : '$count brouillons à valider — repiquez-les en notes '
                          'ou compostez-les.',
                style: theme.textTheme.bodyMedium?.copyWith(color: tokens.sub),
              ),
            ),
          );
        }
        final item = items[index - 1];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: _SeedlingCard(item: item, busy: state.busyItemId != null),
          ),
        );
      },
    );
  }
}

/// One pending capture: source and timestamp (mono metadata), proposed
/// title, text excerpt, parcelle chips and the three nursery actions.
/// Amber border: the waiting state color of the Serre scale.
class _SeedlingCard extends StatelessWidget {
  const _SeedlingCard({required this.item, required this.busy});

  final InboxItem item;

  /// True while any card action is in flight: every action is disabled
  /// (one transplant/compost at a time).
  final bool busy;

  String get _sourceLabel => switch (item.type) {
    CaptureType.clipboard => 'Presse-papiers',
    CaptureType.audio => 'Audio',
    CaptureType.screenshot => 'Image',
    CaptureType.dictation => 'Dictée',
    CaptureType.file => 'Fichier',
    CaptureType.assistant => 'Assistant',
  };

  IconData get _sourceIcon => switch (item.type) {
    CaptureType.clipboard => Icons.content_paste,
    CaptureType.audio => Icons.graphic_eq,
    CaptureType.screenshot => Icons.image_outlined,
    CaptureType.dictation => Icons.mic_none,
    CaptureType.file => Icons.description_outlined,
    CaptureType.assistant => Icons.psychology_alt_outlined,
  };

  /// Deterministic French timestamp (no locale data needed in tests).
  static String _formatTimestamp(DateTime date) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(date.day)}/${pad(date.month)}/${date.year} '
        '· ${pad(date.hour)}:${pad(date.minute)}';
  }

  Future<void> _confirmCompost(BuildContext context) async {
    final cubit = context.read<PepiniereCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Composter ce semis ?'),
        content: Text(
          'Le brouillon « ${item.proposedTitle} » sera supprimé '
          'de la pépinière.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('pepiniere-compost-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Composter'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.compost(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    final cubit = context.read<PepiniereCubit>();
    return Material(
      key: Key('pepiniere-card-${item.id}'),
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // Amber: the « waiting » state of the maturity/state scale.
        side: BorderSide(color: tokens.ambre, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_sourceIcon, size: 16, color: tokens.sub),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$_sourceLabel · ${_formatTimestamp(item.capturedAt)}',
                    // labelSmall carries JetBrains Mono (metadata font).
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.sub,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.proposedTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              item.rawText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
            ),
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in item.tags)
                    Chip(
                      key: Key('pepiniere-tag-${item.id}-$tag'),
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: Key('pepiniere-transplant-${item.id}'),
                  onPressed: busy ? null : () => cubit.transplant(item),
                  icon: const Icon(Icons.park_outlined),
                  label: const Text('Repiquer'),
                ),
                OutlinedButton.icon(
                  key: Key('pepiniere-edit-${item.id}'),
                  onPressed: busy
                      ? null
                      : () =>
                            context.push(AppRoutes.pepiniereEdit, extra: item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                TextButton.icon(
                  key: Key('pepiniere-compost-${item.id}'),
                  onPressed: busy ? null : () => _confirmCompost(context),
                  icon: const Icon(Icons.compost_outlined),
                  label: const Text('Composter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// « La pépinière est vide » : guidance towards the seed dial.
class _EmptyNurseryView extends StatelessWidget {
  const _EmptyNurseryView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<SerreTokens>()!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.spa_outlined, size: 56, color: tokens.pousse),
              const SizedBox(height: 16),
              Text(
                'La pépinière est vide',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Semez une capture — dictée, collage ou fichier — '
                'et retrouvez son brouillon ici avant de le repiquer '
                'en note.',
                style: theme.textTheme.bodyMedium?.copyWith(color: tokens.sub),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('pepiniere-empty-sow'),
                // Back to Explorer with the seed dial open (same deep link
                // as `/capture`).
                onPressed: () => context.go('${AppRoutes.explorer}?semer=1'),
                icon: const Icon(Icons.spa_outlined),
                label: const Text('Semer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadFailureView extends StatelessWidget {
  const _LoadFailureView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.read<PepiniereCubit>().start(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
