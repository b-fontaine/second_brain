import 'package:flutter/material.dart';

import '../../features/sync/presentation/widgets/sync_status_indicator.dart';
import '../theme/app_theme.dart';

/// One destination of the shell navigation.
class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Destination> _destinations = [
  _Destination('Notes', Icons.sticky_note_2_outlined, Icons.sticky_note_2),
  _Destination('Capturer', Icons.add_box_outlined, Icons.add_box),
  _Destination('Assistant', Icons.chat_bubble_outline, Icons.chat_bubble),
  _Destination('Graphe', Icons.hub_outlined, Icons.hub),
];

/// Adaptive navigation shell of the four main tabs.
///
/// Compact widths (< 840 dp) get a bottom [NavigationBar]; expanded widths
/// (>= 840 dp, per [Breakpoints]) get a [NavigationRail] that extends while
/// hovered. A common [AppBar] shows the section title, the git sync status
/// and a (not yet wired) settings button.
class AdaptiveScaffold extends StatefulWidget {
  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.appBarActions,
  }) : assert(
         selectedIndex >= 0 && selectedIndex < 4,
         'selectedIndex must address one of the 4 shell tabs',
       );

  /// Active tab: 0 Notes, 1 Capturer, 2 Assistant, 3 Graphe.
  final int selectedIndex;

  /// Called with the tapped destination index; the caller navigates.
  final ValueChanged<int> onDestinationSelected;

  /// Body of the active tab.
  final Widget child;

  /// Trailing AppBar widgets. Defaults to the git [SyncStatusIndicator];
  /// tests inject a stub here to avoid the DI container.
  final List<Widget>? appBarActions;

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  bool _railExtended = false;

  @override
  Widget build(BuildContext context) {
    return Breakpoints.isExpanded(context)
        ? _buildExpanded(context)
        : _buildCompact(context);
  }

  Scaffold _buildCompact(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
        destinations: [
          for (final destination in _destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }

  Scaffold _buildExpanded(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _railExtended = true),
            onExit: (_) => setState(() => _railExtended = false),
            child: NavigationRail(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              extended: _railExtended,
              labelType: NavigationRailLabelType.none,
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(_destinations[widget.selectedIndex].label),
      actions: [
        ...widget.appBarActions ?? const [SyncStatusIndicator()],
        IconButton(
          tooltip: 'Réglages',
          // Settings screen not wired yet, the button stays disabled.
          onPressed: null,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}
