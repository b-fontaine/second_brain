import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';

/// Floating search bar of the Explorer surface.
///
/// Keeps the `notes-search-bar` key (the boot assertion of every BDD
/// scenario) and, on compact layouts, the settings gear — desktop reaches
/// the settings through the navigation rail instead.
class ExplorerSearchBar extends StatelessWidget {
  const ExplorerSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.showSettingsButton,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Compact layouts only: settings gear as trailing action.
  final bool showSettingsButton;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      key: const Key('notes-search-bar'),
      controller: controller,
      hintText: 'Rechercher dans les notes',
      leading: const Icon(Icons.search),
      trailing: [
        // Clear button, shown only while a query is typed.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Effacer la recherche',
              icon: const Icon(Icons.close),
              onPressed: () {
                controller.clear();
                onChanged('');
              },
            );
          },
        ),
        if (showSettingsButton)
          IconButton(
            tooltip: 'Réglages',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
