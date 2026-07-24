# lib/shared/widgets/shell_scaffold.dart

`ShellScaffold` is the `go_router` `ShellRoute` body: a persistent bottom `NavigationBar` with the
five tabs (Devices/Services/Network/Datasets/Settings) wrapping whichever tab page is active. See
[../../../architecture.md](../../../architecture.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ShellScaffold` constructor | constructor | B | Create the shell scaffold with its child tab page. |
| [`_currentIndex`](#currentindex) | method (`ShellScaffold`) | A | Derive the selected tab index from the current route. |
| `build` | method (`ShellScaffold`) | B | Compose the `Scaffold`/`NavigationBar`. |

## Documentation

### `int _currentIndex(BuildContext context)` <a id="currentindex"></a>
- **Kind:** method of `ShellScaffold`.
- **Source:** `lib/shared/widgets/shell_scaffold.dart` (line 29).
- **Purpose:** Determine which bottom-nav tab is selected based on the current route path.
- **Inputs:** `context` — read for `GoRouterState.of(context).uri.path`.
- **Returns:** `int` — index into the static `_routes` list (`/devices`, `/services`, `/network`,
  `/datasets`, `/settings`); `0` if no route prefix matches.
- **Side effects:** None.
- **Algorithm:** Linear scan over `_routes`, returning the first index whose path the current
  location `startsWith`.
- **Usage:** Called from `build` to set `NavigationBar.selectedIndex`.
- **Notes:** Prefix matching means any sub-route under e.g. `/devices/...` (a device detail page)
  still highlights the Devices tab.

`ShellScaffold`'s constructor and `build` are Tier B: the constructor is a trivial `const` widget
constructor, and `build` is pure widget composition (a `Scaffold` with a `NavigationBar` whose
destinations use localized labels from `AppLocalizations`) with no logic beyond calling
`_currentIndex` and `context.go(_routes[index])` on tap.
