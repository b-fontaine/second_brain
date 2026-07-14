import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/zettel.dart';
import '../../domain/entities/zettel_id.dart';
import '../bloc/zettel_detail/zettel_detail_cubit.dart';
import '../widgets/zettel_reading_panel.dart';

/// Note reading screen (route `/note/:id`) with edit and delete actions.
class ZettelDetailPage extends StatelessWidget {
  const ZettelDetailPage({super.key, required this.zettelId});

  /// Raw `:id` route parameter.
  final String zettelId;

  @override
  Widget build(BuildContext context) {
    if (!ZettelId.isValid(zettelId)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Note introuvable')),
      );
    }
    return BlocProvider(
      create: (_) =>
          getIt<ZettelDetailCubit>()..load(ZettelId.fromString(zettelId)),
      child: _ZettelDetailView(zettelId: zettelId),
    );
  }
}

class _ZettelDetailView extends StatelessWidget {
  const _ZettelDetailView({required this.zettelId});

  final String zettelId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ZettelDetailCubit, ZettelDetailState>(
      listener: (context, state) {
        if (state is ZettelDetailDeleted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Note supprimée')));
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        } else if (state is ZettelDetailLoaded && state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      builder: (context, state) {
        final loaded = state is ZettelDetailLoaded ? state : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              loaded?.zettel.title ?? 'Note',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                key: const Key('edit-note-button'),
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit_outlined),
                onPressed: loaded == null ? null : () => _edit(context),
              ),
              IconButton(
                key: const Key('delete-note-button'),
                tooltip: 'Supprimer',
                icon: const Icon(Icons.delete_outline),
                onPressed: loaded == null
                    ? null
                    : () => _confirmDelete(context, loaded.zettel),
              ),
            ],
          ),
          body: const ZettelReadingView(),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<ZettelDetailCubit>();
    await context.push('/note/$zettelId/edit');
    // Reload after coming back: the note may have been modified.
    await cubit.load(ZettelId.fromString(zettelId));
  }

  Future<void> _confirmDelete(BuildContext context, Zettel zettel) async {
    final cubit = context.read<ZettelDetailCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la note ?'),
        content: Text('« ${zettel.title} » sera supprimée du coffre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const Key('confirm-delete-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await cubit.delete();
    }
  }
}
