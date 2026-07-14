import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/zettel.dart';
import '../../domain/entities/zettel_id.dart';
import '../bloc/notes_list/notes_list_bloc.dart';
import '../widgets/zettel_list_tile.dart';
import '../widgets/zettel_reading_panel.dart';

/// Home screen (route `/`): searchable list of zettels. In expanded
/// layouts the selected note is read in a side panel; in compact
/// layouts a tap navigates to `/note/:id`.
class NotesHomePage extends StatelessWidget {
  const NotesHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<NotesListBloc>()..add(const NotesListStarted()),
      child: const _NotesHomeView(),
    );
  }
}

class _NotesHomeView extends StatefulWidget {
  const _NotesHomeView();

  @override
  State<_NotesHomeView> createState() => _NotesHomeViewState();
}

class _NotesHomeViewState extends State<_NotesHomeView> {
  ZettelId? _selectedId;

  @override
  Widget build(BuildContext context) {
    final expanded = Breakpoints.isExpanded(context);
    return Scaffold(
      body: SafeArea(
        child: expanded ? _buildExpandedLayout() : _buildListPane(),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('new-note-fab'),
        tooltip: 'Nouvelle note',
        onPressed: () => context.push('/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExpandedLayout() {
    final selectedId = _selectedId;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 360, child: _buildListPane()),
        const VerticalDivider(width: 1),
        Expanded(
          child: selectedId == null
              ? const _ReadingPlaceholder()
              : ZettelReadingPanel(
                  key: ValueKey(selectedId),
                  zettelId: selectedId,
                ),
        ),
      ],
    );
  }

  Widget _buildListPane() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SearchBar(
            key: const Key('notes-search-bar'),
            hintText: 'Rechercher dans les notes',
            leading: const Icon(Icons.search),
            onChanged: (query) =>
                context.read<NotesListBloc>().add(NotesListQueryChanged(query)),
          ),
        ),
        Expanded(
          child: BlocBuilder<NotesListBloc, NotesListState>(
            builder: (context, state) => switch (state) {
              NotesListInitial() || NotesListLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              NotesListError(:final message) => _ErrorView(message: message),
              NotesListLoaded(:final zettels, :final query) =>
                zettels.isEmpty
                    ? _EmptyView(hasQuery: query.trim().isNotEmpty)
                    : _buildList(zettels),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Zettel> zettels) {
    return ListView.separated(
      itemCount: zettels.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final zettel = zettels[index];
        return ZettelListTile(
          zettel: zettel,
          selected: Breakpoints.isExpanded(context) && _selectedId == zettel.id,
          onTap: () => _openZettel(zettel),
        );
      },
    );
  }

  void _openZettel(Zettel zettel) {
    if (Breakpoints.isExpanded(context)) {
      setState(() => _selectedId = zettel.id);
    } else {
      context.push('/note/${zettel.id.value}');
    }
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.lightbulb_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery
                  ? 'Aucune note ne correspond à votre recherche.'
                  : "Aucune note pour l'instant…",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 8),
              Text(
                'Appuyez sur + pour capturer votre première idée.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

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
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () =>
                  context.read<NotesListBloc>().add(const NotesListStarted()),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingPlaceholder extends StatelessWidget {
  const _ReadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Sélectionnez une note pour la lire.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
