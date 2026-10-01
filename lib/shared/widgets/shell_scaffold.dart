import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../providers/app_settings.dart';
import '../utils/adaptive_layout.dart';

class ShellScaffold extends ConsumerWidget {
  final Widget child;

  /// Purpose: Create a shell scaffold instance.
  /// Inputs: `key`, `child`.
  /// Returns: A new `ShellScaffold` instance.
  /// Side effects: None.
  /// Notes: None.
  const ShellScaffold({super.key, required this.child});

  static const _routes = [
    '/devices',
    '/services',
    '/network',
    '/datasets',
    '/settings',
  ];

  /// Purpose: Provide the internal current index helper for this file.
  /// Inputs: `context`.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  /// Purpose: Describe the shell's five destinations once, icons and all.
  /// Inputs: `l10n`.
  /// Returns: `List<_ShellDestination>` in the same order as `_routes`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Both the bottom bar and
  /// the rail read from this, so a destination can never end up in one and not
  /// the other, or in a different order between them.
  List<_ShellDestination> _destinations(AppLocalizations l10n) {
    return [
      _ShellDestination(Icons.devices_outlined, Icons.devices, l10n.navDevices),
      _ShellDestination(Icons.dns_outlined, Icons.dns, l10n.navServices),
      _ShellDestination(Icons.lan_outlined, Icons.lan, l10n.navNetworks),
      _ShellDestination(Icons.folder_outlined, Icons.folder, l10n.navDataSets),
      _ShellDestination(
        Icons.settings_outlined,
        Icons.settings,
        l10n.navSettings,
      ),
    ];
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often. The rail
  /// and the bottom bar are two renderings of the same five destinations; which
  /// one appears is [useNavigationRail]'s width-only decision, deliberately not
  /// the app-wide split rule. Nothing here is stateful, so folding a device
  /// swaps one for the other on the next frame with no route change. Each tab
  /// page brings its own `Scaffold` (app bar and floating action buttons), so
  /// the page body never sits under the bottom bar and needs no inset for it.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Expressive (the default style) floats the bottom bar; Material 3 keeps
    // the classic full-width bar.
    final floatingNavBar = ref.watch(
      appSettingsProvider.select((s) => s.uiStyle == AppUiStyle.expressive),
    );
    final destinations = _destinations(l10n);
    final index = _currentIndex(context);

    void select(int i) => context.go(_routes[i]);

    if (!useNavigationRail(MediaQuery.sizeOf(context).width)) {
      final navDestinations = [
        for (final d in destinations)
          NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
      ];
      return Scaffold(
        body: child,
        bottomNavigationBar: floatingNavBar
            ? _FloatingNavBar(
                selectedIndex: index,
                onDestinationSelected: select,
                destinations: navDestinations,
              )
            : NavigationBar(
                selectedIndex: index,
                onDestinationSelected: select,
                destinations: navDestinations,
              ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Five destinations with labels run to roughly 370 logical pixels,
          // which fits every window wide enough to earn a rail — but a rail can
          // appear at compact heights, so let it scroll rather than overflow.
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: select,
                    labelType: NavigationRailLabelType.all,
                    // Centred rather than the default top alignment. A rail
                    // top-aligns to sit under a leading menu button or FAB;
                    // this one has neither, so five destinations pinned to the
                    // top of a tall rail would leave the whole lower half
                    // empty. Centring also keeps them near the thumb when the
                    // window is tall.
                    groupAlignment: 0,
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The bottom navigation bar drawn as a floating, pill-shaped island (1.7.0,
/// the default). Flutter ships no floating navigation bar, so this wraps the
/// stock [NavigationBar] in a stadium-shaped [Material] with side and bottom
/// margins. It sits in the Scaffold's `bottomNavigationBar` slot rather than
/// over the body, so pages never draw underneath it and keep their layout and
/// FAB positions.
class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> destinations;

  /// Key on the island's surface, so tests can tell the floating bar from the
  /// classic one.
  static const islandKey = ValueKey('floatingNavBarIsland');

  /// Purpose: Create a floating navigation bar instance.
  /// Inputs: `selectedIndex`, `onDestinationSelected`, `destinations` — passed
  /// through unchanged to the inner [NavigationBar].
  /// Returns: A new `_FloatingNavBar` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  /// Purpose: Build the island: margins, rounded surface, inner bar.
  /// Inputs: `context`.
  /// Returns: The widget tree for the floating bar.
  /// Side effects: None.
  /// Notes: The bottom system inset (gesture bar) is applied once, outside
  /// the island, and removed for the inner [NavigationBar] so it does not pad
  /// itself a second time. The island is capped in width so it stays a
  /// compact pill on wider phones and small tablets in portrait.
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              key: islandKey,
              color: colorScheme.surfaceContainer,
              surfaceTintColor: Colors.transparent,
              shadowColor: colorScheme.shadow,
              elevation: 3,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: true,
                removeRight: true,
                removeBottom: true,
                child: NavigationBar(
                  height: 68,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: destinations,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Purpose: Create a shell destination instance.
  /// Inputs: `icon`, `selectedIcon`, `label`.
  /// Returns: A new `_ShellDestination` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _ShellDestination(this.icon, this.selectedIcon, this.label);
}
