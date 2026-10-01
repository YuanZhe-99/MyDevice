# lib/shared/widgets/shell_scaffold.dart

`ShellScaffold` is the `go_router` `ShellRoute` body: the five tabs
(Devices/Services/Network/Datasets/Settings) wrapping whichever tab page is active, rendered as a
bottom bar on a window narrower than 600 logical pixels and as a side `NavigationRail` from 600 up.
Which one appears is `useNavigationRail`'s width-only decision — see
[../../../adaptive-layout.md](../../../adaptive-layout.md#where-navigation-lives) — except that the
Expressive style can keep its bottom bar on wide windows too (1.7.1). Both are built from the same
`_destinations` list so they cannot drift apart. See [../../../architecture.md](../../../architecture.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ShellScaffold` constructor | constructor | B | Create the shell scaffold with its child tab page. |
| [`_currentIndex`](#currentindex) | method (`ShellScaffold`) | A | Derive the selected tab index from the current route. |
| [`_destinations`](#destinations) | method (`ShellScaffold`) | A | Describe the five destinations once, icons and all. |
| `build` | method (`ShellScaffold`) | B | Compose the `Scaffold` with the Expressive bar, the classic bar or a rail. |
| [`_ExpressiveNavBar`](#expressivenavbar) | class (private) | A | The compact floating pill that is the Expressive bottom bar. |
| `_ExpressiveNavBar.new` | constructor | B | Create the bar from `destinations`, `selectedIndex`, `onSelected`. |
| `_ExpressiveNavBar.build` | method | B | Build the island and its items. |
| [`_ExpressiveNavItem`](#expressivenavitem) | class (private) | A | One destination of the bar: icon, plus its label while selected. |
| `_ExpressiveNavItem.new` | constructor | B | Create one item from `destination`, `selected`, `onTap`. |
| `_ExpressiveNavItem.build` | method | B | Build the tappable pill. |
| `_ShellDestination` constructor | constructor | B | Hold one destination's outlined icon, filled icon and label. |

## Documentation

### `int _currentIndex(BuildContext context)` <a id="currentindex"></a>
- **Kind:** method of `ShellScaffold`.
- **Source:** `lib/shared/widgets/shell_scaffold.dart`.
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
- **Source:** `lib/shared/widgets/shell_scaffold.dart`.
- **Purpose:** Describe the shell's five destinations once, icons and all.
- **Inputs:** `l10n` — for the localized labels.
- **Returns:** `List<_ShellDestination>` in the same order as `_routes`.
- **Side effects:** None.
- **Usage:** `build` maps the list to `_ExpressiveNavItem`s or `NavigationDestination`s for the
  bottom bars, or `NavigationRailDestination`s for the rail.
- **Notes:** Every rendering reads from this, so a destination can never end up in one and not the
  other, or in a different order between them.

## `build` (Tier B)

`ShellScaffold` is a `ConsumerWidget` (`build(BuildContext context, WidgetRef ref)`). It watches
four settings with `select`: `uiStyle == AppUiStyle.expressive`, `expressiveWideBottomNav`,
`navRailOnRight` and `alwaysSideNav` (the last three since 1.7.1). Pure widget composition:

- `wide = useNavigationRail(width)`; `showRail = alwaysSide || (wide && !(expressive && wideBottom))`.
  Material 3 ignores `wideBottomNav`, so on a wide window it always gets the rail. `alwaysSideNav`
  (off by default, labelled not recommended) forces the rail on narrow windows too, in both styles,
  and overrides `wideBottomNav`.
- **No rail, Expressive:** `Scaffold(extendBody: true, body: ..., bottomNavigationBar:
  _ExpressiveNavBar)`. `extendBody` lets the page draw **behind** the floating bar, and the
  Scaffold reports the bar's height to the page as `MediaQuery.padding.bottom`. A page's own
  `Scaffold` places its floating action button from `viewPadding`, not `padding`, so the body is
  wrapped in a `Builder` that raises `viewPadding.bottom` to `max(viewPadding.bottom,
  padding.bottom)`; without it the FABs would sit behind the bar. Scroll views that pass an explicit
  `padding` must add the bar's height themselves — see `navBarAwarePadding` in
  [`adaptive_layout.md`](../utils/adaptive_layout.md).
- **No rail, Material 3:** the classic full-width `NavigationBar` in `bottomNavigationBar`, no
  `extendBody`.
- **Rail:** a `Row` of a `NavigationRail` (`groupAlignment: 0`, `labelType: all`, wrapped in a
  `SingleChildScrollView` + `ConstrainedBox` + `IntrinsicHeight` so a compact-height window scrolls
  the rail rather than overflowing it), a 1 dp `VerticalDivider` and the child in an `Expanded`. The
  rail is first on the left (default) or last when `navRailOnRight` is set, in both styles.

Tapping any navigation calls `context.go(_routes[index])`. Nothing is stateful, so folding a device
swaps one rendering for the other on the next frame with no route change.

## `_ExpressiveNavBar` <a id="expressivenavbar"></a>

Replaces 1.7.0's `_FloatingNavBar`, which wrapped a stock `NavigationBar` in a full-width island.
The 1.7.1 bar is a **compact** pill modelled on Material 3 Expressive's floating navigation: a
`Material` with `StadiumBorder`, `surfaceContainer` colour and elevation 3, hugging its items (it
does not stretch), centred in a `SafeArea` with a minimum 16/0/16/12 margin, padding 8 and 4 dp
between items. A `FittedBox(fit: scaleDown)` shrinks it on very narrow screens instead of
overflowing. It carries `ValueKey('floatingNavBarIsland')` so tests can tell it from the classic
bar. Used on narrow windows and, with the wide-screen setting, on wide ones.

## `_ExpressiveNavItem` <a id="expressivenavitem"></a>

The **selected** destination shows its filled icon and its label side by side in a `secondaryContainer`
pill (48 high, 20 dp horizontal padding, `labelLarge`); the others show only their outlined icon
(16 dp padding) with a `Tooltip` and a `Semantics` label, since their text is hidden. Width
(`AnimatedSize`) and colour (`AnimatedContainer`) animate over 250 ms. It is an `InkWell` with a
`StadiumBorder` ripple.
