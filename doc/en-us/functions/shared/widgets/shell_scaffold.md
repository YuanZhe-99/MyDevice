# lib/shared/widgets/shell_scaffold.dart

`ShellScaffold` is the `go_router` `ShellRoute` body: the five tabs
(Devices/Services/Network/Datasets/Settings) wrapping whichever tab page is active, rendered as a
bottom `NavigationBar` on a window narrower than 600 logical pixels and as a side `NavigationRail`
from 600 up. Which one appears is `useNavigationRail`'s width-only decision — see
[../../../adaptive-layout.md](../../../adaptive-layout.md#where-navigation-lives) — and both are
built from the same `_destinations` list so they cannot drift apart. See
[../../../architecture.md](../../../architecture.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ShellScaffold` constructor | constructor | B | Create the shell scaffold with its child tab page. |
| [`_currentIndex`](#currentindex) | method (`ShellScaffold`) | A | Derive the selected tab index from the current route. |
| [`_destinations`](#destinations) | method (`ShellScaffold`) | A | Describe the five destinations once, icons and all. |
| `build` | method (`ShellScaffold`) | B | Compose the `Scaffold` with either a `NavigationBar` or a `NavigationRail`. |
| `_ShellDestination` constructor | constructor | B | Hold one destination's outlined icon, filled icon and label. |

## Documentation

### `int _currentIndex(BuildContext context)` <a id="currentindex"></a>
- **Kind:** method of `ShellScaffold`.
- **Source:** `lib/shared/widgets/shell_scaffold.dart` (line 29).
- **Purpose:** Determine which navigation destination is selected based on the current route path.
- **Inputs:** `context` — read for `GoRouterState.of(context).uri.path`.
- **Returns:** `int` — index into the static `_routes` list (`/devices`, `/services`, `/network`,
  `/datasets`, `/settings`); `0` if no route prefix matches.
- **Side effects:** None.
- **Algorithm:** Linear scan over `_routes`, returning the first index whose path the current
  location `startsWith`.
- **Usage:** Called from `build` to set `selectedIndex` on whichever navigation widget is shown.
- **Notes:** Prefix matching means any sub-route under e.g. `/devices/...` still highlights the
  Devices tab.

### `List<_ShellDestination> _destinations(AppLocalizations l10n)` <a id="destinations"></a>
- **Kind:** method of `ShellScaffold`.
- **Source:** `lib/shared/widgets/shell_scaffold.dart` (line 42).
- **Purpose:** Describe the shell's five destinations once, icons and all.
- **Inputs:** `l10n` — for the localized labels.
- **Returns:** `List<_ShellDestination>` in the same order as `_routes`.
- **Side effects:** None.
- **Usage:** `build` maps the list to `NavigationDestination`s for the bottom bar or
  `NavigationRailDestination`s for the rail.
- **Notes:** Both renderings read from this, so a destination can never end up in one and not the
  other, or in a different order between them.

`ShellScaffold`'s constructor, `build` and `_ShellDestination`'s constructor are Tier B. `build`
is pure widget composition: it reads `MediaQuery.sizeOf(context).width`, and below
`navRailMinWidth` returns a `Scaffold` whose `bottomNavigationBar` is a `NavigationBar`; from it up
returns a `Scaffold` whose body is a `Row` of a `NavigationRail` (`groupAlignment: 0` so the five
destinations centre rather than pin to the top, `labelType: all`, wrapped in a
`SingleChildScrollView` + `ConstrainedBox` + `IntrinsicHeight` so a compact-height window scrolls
the rail rather than overflowing it), a 1 dp `VerticalDivider`, and the child in an `Expanded`.
Tapping either navigation calls `context.go(_routes[index])`. Nothing is stateful, so folding a
device swaps one rendering for the other on the next frame with no route change. Each tab page
brings its own `Scaffold` (app bar, floating action buttons), so a page body never sits under the
bottom bar and reserves no inset for it.
