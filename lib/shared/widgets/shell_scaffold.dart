import 'package:flutter/material.dart';
import 'package:myapps_ui/myapps_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../providers/app_settings.dart';

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
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often. The rail
  /// and the bottom bar are two renderings of the same five destinations. The
  /// rail's appearance follows the navigation-position setting (1.7.1):
  /// never (the default), when the shared width rule says the window is wide
  /// enough, or always. The rail sits on the left or, by setting, the right.
  /// Expressive's bottom bar floats over
  /// the pages (`extendBody`), and the Scaffold reports its height as bottom
  /// padding so every page can leave room to scroll its last content above it
  /// (see the app padding helper). Nothing here is stateful, so folding a device
  /// swaps layouts on the next frame with no route change. Each tab page
  /// brings its own `Scaffold` (app bar and floating action buttons), which
  /// avoids the bar on its own.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final expressive = ref.watch(
      appSettingsProvider.select((s) => s.uiStyle == AppUiStyle.expressive),
    );
    final placement = ref.watch(
      appSettingsProvider.select((s) => s.navPlacement),
    );
    final railOnRight = ref.watch(
      appSettingsProvider.select((s) => s.navRailOnRight),
    );
    final destinations = _destinations(l10n);
    final index = _currentIndex(context);

    void select(int i) => context.go(_routes[i]);

    return MyAppsNavigationShell(
      destinations: [
        for (final d in destinations)
          MyAppsDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
      ],
      selectedIndex: index,
      onSelected: select,
      style: expressive ? AppUiStyle.expressive : AppUiStyle.material3,
      placement: placement,
      railOnRight: railOnRight,
      child: child,
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
