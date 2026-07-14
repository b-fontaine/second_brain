import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../features/capture/presentation/widgets/seed_dial.dart';
import '../../features/sync/presentation/widgets/sync_status_indicator.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../theme/serre_tokens.dart';

/// One destination of the shell navigation.
class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon, this.tabIndex);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Index into `shellTabPaths`; differs from the visual position because
  /// Assistant sits left of the central seed button and Explorer right.
  final int tabIndex;
}

/// Visual order: Assistant on the left/top, Explorer on the right/bottom.
const List<_Destination> _destinations = [
  _Destination('Assistant', Icons.chat_bubble_outline, Icons.chat_bubble, 1),
  _Destination('Explorer', Icons.park_outlined, Icons.park, 0),
];

/// « 2 + 1 » navigation shell: Assistant and Explorer around the central
/// « Semer » button.
///
/// Compact widths (< 840 dp, per [Breakpoints]) get a 62 dp bottom bar with
/// the round seed button overflowing above it; expanded widths get a
/// [NavigationRail] (settings gear at its bottom) plus a floating seed FAB
/// and the ⌘⇧D / ⌘⇧V / ⌘⇧O seeding shortcuts (Ctrl on non-Apple desktops).
/// A common [AppBar] shows the section title and the git sync status.
class AdaptiveScaffold extends StatefulWidget {
  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.appBarActions,
    this.openSeedDial = false,
  }) : assert(
         selectedIndex >= 0 && selectedIndex < 2,
         'selectedIndex must address one of the 2 shell tabs',
       );

  /// Active tab: 0 Explorer (`/`), 1 Assistant (`/chat`).
  final int selectedIndex;

  /// Called with the tapped destination tab index; the caller navigates.
  final ValueChanged<int> onDestinationSelected;

  /// Body of the active tab.
  final Widget child;

  /// Trailing AppBar widgets. Defaults to the git [SyncStatusIndicator];
  /// tests inject a stub here to avoid the DI container.
  final List<Widget>? appBarActions;

  /// Opens the seed dial once when true at mount or on a false → true
  /// transition (deep link `/?semer=1`). Closing the dial does not reopen
  /// it on unrelated rebuilds.
  final bool openSeedDial;

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  /// Height of the compact bottom bar, above the system SafeArea.
  static const double _barHeight = 62;

  /// How far the seed button rises above the compact bar.
  static const double _seedOverflow = 24;

  /// Gap kept between the dial chips and the seed button they cover.
  static const double _dialGap = 12;

  bool _railExtended = false;
  bool _dialOpen = false;

  @override
  void initState() {
    super.initState();
    _dialOpen = widget.openSeedDial;
  }

  @override
  void didUpdateWidget(AdaptiveScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rising edge only: `?semer=1` stays in the location after the user
    // closes the dial, and must not reopen it.
    if (widget.openSeedDial && !oldWidget.openSeedDial) {
      _dialOpen = true;
    }
  }

  void _openDial() => setState(() => _dialOpen = true);

  void _closeDial() => setState(() => _dialOpen = false);

  @override
  Widget build(BuildContext context) {
    final expanded = Breakpoints.isExpanded(context);
    final content = Stack(
      children: [
        expanded ? _buildExpanded(context) : _buildCompact(context),
        if (_dialOpen)
          SeedDial(
            onDismiss: _closeDial,
            alignEnd: expanded,
            bottomInset: expanded
                // 16 dp FAB margin + the 60 dp seed button.
                ? 16 + _SeedButton.size + _dialGap
                : _barHeight + _seedOverflow + _dialGap,
          ),
      ],
    );
    return expanded ? _buildShortcuts(content) : content;
  }

  /// Shell-level seeding shortcuts, desktop/expanded only.
  Widget _buildShortcuts(Widget child) {
    final useMeta = defaultTargetPlatform == TargetPlatform.macOS;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        SingleActivator(
          LogicalKeyboardKey.keyD,
          shift: true,
          meta: useMeta,
          control: !useMeta,
        ): () => seedByDictation(context),
        SingleActivator(
          LogicalKeyboardKey.keyV,
          shift: true,
          meta: useMeta,
          control: !useMeta,
        ): () => seedByClipboard(context),
        SingleActivator(
          LogicalKeyboardKey.keyO,
          shift: true,
          meta: useMeta,
          control: !useMeta,
        ): () => seedByFile(context),
      },
      // The shortcuts need a focused descendant to receive key events even
      // when no field has focus.
      child: Focus(autofocus: true, child: child),
    );
  }

  Scaffold _buildCompact(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: widget.child,
      bottomNavigationBar: _SeedNavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
        onSeedPressed: _openDial,
        barHeight: _barHeight,
        seedOverflow: _seedOverflow,
      ),
    );
  }

  Scaffold _buildExpanded(BuildContext context) {
    final selectedRailIndex = _destinations.indexWhere(
      (destination) => destination.tabIndex == widget.selectedIndex,
    );
    return Scaffold(
      appBar: _buildAppBar(context),
      floatingActionButton: _SeedButton(onPressed: _openDial),
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _railExtended = true),
            onExit: (_) => setState(() => _railExtended = false),
            child: NavigationRail(
              selectedIndex: selectedRailIndex,
              onDestinationSelected: (index) =>
                  widget.onDestinationSelected(_destinations[index].tabIndex),
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
              // Desktop settings access; mobile goes through the gear of
              // the Explorer search bar.
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IconButton(
                      tooltip: 'Réglages',
                      onPressed: () => context.push(AppRoutes.settings),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final active = _destinations.firstWhere(
      (destination) => destination.tabIndex == widget.selectedIndex,
    );
    return AppBar(
      title: Text(active.label),
      actions: widget.appBarActions ?? const [SyncStatusIndicator()],
    );
  }
}

/// Compact bottom bar: the two destinations flanking the raised « Semer »
/// button. The bar itself is [barHeight] dp over the bottom SafeArea; the
/// button rises [seedOverflow] dp above it into a transparent strip so it
/// stays fully hit-testable.
class _SeedNavigationBar extends StatelessWidget {
  const _SeedNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSeedPressed,
    required this.barHeight,
    required this.seedOverflow,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSeedPressed;
  final double barHeight;
  final double seedOverflow;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SerreTokens>()!;
    return Stack(
      key: const Key('seed-navigation-bar'),
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Transparent strip the seed button rises into (scaffold paper
            // shows through, which the 4 dp paper border relies on).
            SizedBox(height: seedOverflow),
            Container(
              decoration: BoxDecoration(
                color: tokens.surface,
                border: Border(top: BorderSide(color: tokens.line)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: barHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _NavBarItem(
                          destination: _destinations[0],
                          selected:
                              _destinations[0].tabIndex == selectedIndex,
                          onTap: () => onDestinationSelected(
                            _destinations[0].tabIndex,
                          ),
                        ),
                      ),
                      // Clearance under the central button.
                      const SizedBox(width: 84),
                      Expanded(
                        child: _NavBarItem(
                          destination: _destinations[1],
                          selected:
                              _destinations[1].tabIndex == selectedIndex,
                          onTap: () => onDestinationSelected(
                            _destinations[1].tabIndex,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(child: _SeedButton(onPressed: onSeedPressed)),
        ),
      ],
    );
  }
}

/// One destination of the compact bar.
class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SerreTokens>()!;
    final color = selected ? tokens.accent : tokens.sub;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round « Semer » button: green gradient, 4 dp paper border cutting a
/// notch effect out of the bar behind, soft green shadow. Used both as the
/// compact bar's central button and as the expanded floating FAB.
class _SeedButton extends StatelessWidget {
  const _SeedButton({required this.onPressed});

  static const double size = 60;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<SerreTokens>()!;
    return Semantics(
      button: true,
      label: 'Semer',
      child: Tooltip(
        message: 'Semer',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Gradient from the mockups (kept as-is in dark mode until the
            // « serre de nuit » design iteration).
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4F8B63), Color(0xFF2F6B4F)],
            ),
            border: Border.all(color: tokens.paper, width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F6B4F).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('seed-button'),
              onTap: onPressed,
              child: const Center(
                child: Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
