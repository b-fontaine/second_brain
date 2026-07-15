import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/serre_tokens.dart';
// Cross-feature imports — documented exception: the Explorer search results
// reuse the zettel feature's list bloc, tiles and maturity scale.
import '../../../zettel/presentation/bloc/notes_list/notes_list_bloc.dart';
import '../../../zettel/presentation/utils/zettel_maturity.dart';
import '../../../zettel/presentation/widgets/zettel_list_tile.dart';

/// Floating search results shown under the Explorer search bar while a
/// query is active (search mode). Hidden when the query is empty; shows a
/// French empty message when nothing matches.
class ExplorerSearchResults extends StatelessWidget {
  const ExplorerSearchResults({
    super.key,
    required this.degreeById,
    required this.onOpen,
  });

  /// Undirected link count per note id, for the maturity dots.
  final Map<String, int> degreeById;

  /// Called with the tapped result id.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SerreTokens>()!;
    return BlocBuilder<NotesListBloc, NotesListState>(
      builder: (context, state) {
        if (state is! NotesListLoaded || state.query.trim().isEmpty) {
          return const SizedBox.shrink();
        }
        return Material(
          key: const Key('explorer-search-results'),
          color: tokens.surface,
          elevation: 3,
          shadowColor: tokens.scrim,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: state.zettels.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Aucune note ne correspond à votre recherche.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: tokens.sub),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: state.zettels.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final zettel = state.zettels[index];
                      return ZettelListTile(
                        zettel: zettel,
                        maturity: ZettelMaturity.of(
                          degreeById[zettel.id.value] ?? 0,
                        ),
                        onTap: () => onOpen(zettel.id.value),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
