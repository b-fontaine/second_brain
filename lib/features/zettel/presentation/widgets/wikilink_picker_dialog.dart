import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/zettel.dart';
import '../../domain/usecases/search_zettels.dart';

/// Note search dialog; pops with the selected [Zettel] (or null on cancel).
/// Used by the editor to insert a `[[id|titre]]` wikilink.
class WikilinkPickerDialog extends StatefulWidget {
  const WikilinkPickerDialog({super.key, this.searchZettels});

  /// Injectable for tests; resolved via getIt when null.
  final SearchZettels? searchZettels;

  @override
  State<WikilinkPickerDialog> createState() => _WikilinkPickerDialogState();
}

class _WikilinkPickerDialogState extends State<WikilinkPickerDialog> {
  late final SearchZettels _searchZettels =
      widget.searchZettels ?? getIt<SearchZettels>();
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  List<Zettel> _results = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Empty query lists all notes (SearchZettels falls back to getAll).
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _searchZettels(query);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((failure) {
        _error = failure.message;
        _results = const [];
      }, (zettels) => _results = zettels);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insérer un lien'),
      content: SizedBox(
        width: 480,
        height: 400,
        child: Column(
          children: [
            TextField(
              key: const Key('wikilink-search-field'),
              controller: _queryController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Rechercher une note…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return Center(child: Text(error));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('Aucune note trouvée.'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final zettel = _results[index];
        return ListTile(
          title: Text(
            zettel.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(zettel.id.value),
          onTap: () => Navigator.of(context).pop(zettel),
        );
      },
    );
  }
}
