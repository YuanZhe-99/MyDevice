# Adaptive layout

This is the app-wide rule for **when a layout may split** — into panes or columns on a foldable's
inner panel, a tablet or a desktop window — and, once it may, **how many columns** it gets. A
second, narrower rule decides **where navigation lives**. All of it lives in
[`lib/shared/utils/adaptive_layout.dart`](functions/shared/utils/adaptive_layout.md), a module that
deliberately imports nothing but `dart:core` so every decision is directly unit-testable without a
widget tree.

The conventions are the ones MyAnime worked out across its 1.5.2 – 1.5.6 releases, adopted here
wholesale so one device answers the same way in every app of the series. The numbers below are
worthless without the reasoning, so the reasoning is written down.

Before 1.5.0 MyDevice had no rule at all: every page was a fixed single column, and the three width
decisions that did exist were inline literals in three different files (`>= 520`, `< 680`, and a
150 dp metric grid). **If a widget file contains a numeric width comparison, it is a bug** — the
number belongs here, and the page calls a named predicate.

## When to split

Split when **all three** of these hold:

| Constant | Value | What it is |
|---|---|---|
| `splitMinWidth` | `600.0` | Material's *medium* width class; Android's `sw600dp`. |
| `splitMinHeight` | `480.0` | The compact/medium height boundary. |
| `splitMinAspect` | `0.82` | Width divided by height. |

```dart
bool canSplitLayout(double width, double height) {
  if (width < splitMinWidth) return false;
  if (height < splitMinHeight) return false;
  if (height <= 0) return false;
  return width / height >= splitMinAspect;
}
```

Each condition earns its place, and none of them alone is enough.

### The aspect test is the load-bearing one

**It is why this is not a plain width breakpoint, and the Galaxy Z Fold 8 is why it has to exist.**
The Fold 8 unfolds to a 4:3 *landscape* panel (2448 × 1848 px), so held in portrait it is 3:4 —
**narrower relative to its height than the near-square Fold 7 it replaced**, despite being newer,
while the Fold 8 Ultra went the other way. One generation now spans roughly 672 to 954 logical
pixels unfolded, and one device needs two different answers at one width.

Pixel counts are authoritative; logical pixels depend on the density bucket and on Samsung's
user-adjustable **Display size** setting, so a plausible range is shown.

| Device | Inner panel, px | Portrait W:H | Portrait W, dp | Portrait | Landscape |
|---|---|---|---|---|---|
| Galaxy Z Fold 5 | 1812 × 2176 | 0.83 | 659–690 | split | split |
| Galaxy Z Fold 6 | 1856 × 2160 | 0.86 | 675–707 | split | split |
| Galaxy Z Fold 7 | 1968 × 2184 | 0.90 | 716–750 | split | split |
| **Galaxy Z Fold 8** | **2448 × 1848 (4:3 landscape)** | **0.755** | **672–704** | **single** | **split** |
| Galaxy Z Fold 8 Ultra | 2256 × 2504 | 0.90 | 820–859 | split | split |
| Pixel 9 / 10 Pro Fold | 2076 × 2152 | 0.96 | 755–791 | split | split |

`0.82` sits near the middle of the gap between the Fold 8's portrait `0.755` and the Fold 7 /
Fold 8 Ultra's portrait `0.90`, with roughly 9% margin on each side. Keep this constant as-is
unless a device falls in the gap; changing it is a whole-app behaviour change.

### The width floor

Every unfolded panel clears 600 dp by at least 59 dp even at the denser end of the range, and every
folded cover screen sits well below it: Z Fold 7 / 8 Ultra roughly 360 dp, Z Fold 8 roughly
356–416 dp, Pixel 10 Pro Fold roughly 411 dp. The floor separates "unfolded" from "cover screen"
without naming a device.

### The height floor

The aspect test alone admits *wide and short* viewports. Without the floor, a folded Z Fold 8 cover
screen rotated to landscape (~657 × 416 dp) and an ordinary phone in landscape (~915 × 412 dp)
would both split into two cramped panes. Google gives the same advice independently: for a phone or
an open flippable in landscape the window width is typically medium but the height is compact, and
two-pane layouts are not practical there.

### The consequence worth knowing

The rule is about **shape, not device class**, so a 4:3 tablet in portrait (768 × 1024 → 0.75) and a
16:10 tablet in portrait (0.625) also stay single column, exactly like the Fold 8 in portrait. Both
split in landscape. If someone reports "my tablet doesn't split in portrait", that is the rule
working.

## How many columns

Once splitting is allowed, the count comes from the width the content actually gets and a minimum
width per column:

```dart
int columnCapacity(
  double contentWidth, {
  required double minItemWidth,
  double gap = listTileGap,          // 12
  int maxColumns = listMaxColumns,   // 4
}) => ((contentWidth + gap) / (minItemWidth + gap))
        .floor()
        .clamp(1, maxColumns);
```

This is the adaptive-minimum-width approach Google recommends for feed layouts — fit as many
columns of at least a minimum width as the space allows — rather than a hardcoded count per
breakpoint. One gap is added to the numerator so the arithmetic pays for the gaps *between* columns
rather than one after every column. Each caller brings the minimum its own content needs, and the
doc comment on the constant states where the number came from:

| Caller | Minimum | Gap | Max | Why that number |
|---|---|---|---|---|
| Services overview metric cards (`serviceMetricColumns`) | `150` | 12 | 4 | An icon, a headline-sized count and a two-line label inside 16 dp of padding. Arithmetically identical to the inline rule it replaced, so no viewport changed its count. |
| Finance summary metrics (`financeSummaryColumns`) | `160` | 16 | 3, **floor 2** | A `titleLarge` money value runs to roughly 120 dp before its label. The floor keeps the card from stacking one metric per row on a cover screen, which it never did. The third column arrives at 512 dp where the old inline rule asked for 520 — the gap arithmetic paying for two gaps rather than three. |

The four **lists** take columns too, under the split rule first and the capacity second. Each
tile brings its own minimum:

| List | Minimum | Padding taken from the content width | Why that number |
|---|---|---|---|
| Devices (`deviceTileMinWidth`) | `320` | 32 (the 16 dp card margin each side) | A `Card` in a padded row spends 32 on tile padding, 40 on the avatar, 16 on a gap and 24 (chevron) or 48 (menu) plus 16 on the trailing edge — roughly 152 of chrome. 168 keeps a twenty-character name on one line and "category · brand · daily cost" in its two subtitle lines. |
| Networks (`networkTileMinWidth`) | `300` | 16 (8 dp list padding) | The same chrome, but a single-line "type · subnet" subtitle of about twenty-five characters, ~175 dp, so it fits narrower. |
| Datasets (`dataSetTileMinWidth`) | `320` | 16 | A bare `ListTile`: 32 + a 34 dp emoji + 16 + 24 + 16 = 122. The subtitle carries up to four storage lines that must not wrap, or the fourth line hides a device behind the ellipsis. |
| Services — devices / routes / ports views (`serviceCardMinWidth`) | `320` | 16 | Route cards carry a three-line summary; device and port cards nest tiles whose trailing menu is 48 dp wide. The overview is a heterogeneous scroll (metric grid, topology card, warnings, route groups, tiles) and stays single-column. |

`listColumnCount` combines the gate with the capacity: one column when `canSplitLayout` is false,
otherwise the capacity when the user's preference is `listColumnsAuto`, otherwise the preference
clamped to the capacity. Clamping rather than rejecting is what lets a preference set on a desktop
survive being carried onto a folded phone and come back on unfolding. Each list stores its own
preference in `storage_config.json` (`deviceListColumns`, `networkListColumns`,
`dataSetListColumns`, `serviceListColumns`), device-locally, because window size is a property of
the device and not of the account; the default is removed from the file rather than written as
zero. The column control in the app bar is hidden — not disabled — whenever the capacity is one, so
a phone or a cover screen never shows a control that could do nothing, and it is hidden in reorder
mode and on the services overview.

Content width is `shellContentWidth(screenWidth)` less the padding in the table, because these five
pages are the ones inside the shell — see
[the section below](#measure-the-screen-for-the-gate-the-content-box-for-the-capacity).

| Viewport | Splits | Devices (−32, 320) | Networks (−16, 300) | Datasets / services (−16, 320) |
|---|---|---|---|---|
| Z Fold 8 landscape 933 × 704 | yes | 2 | 2 | 2 |
| Z Fold 8 portrait 704 × 933 | no | 1 | 1 | 1 |
| Z Fold 8 Ultra 954 × 859 / 859 × 954 | yes | 2 / 2 | 2 / 2 | 2 / 2 |
| Pixel 10 Pro Fold 820 × 791 / 791 × 820 | yes | 2 / 2 | 2 / 2 | 2 / 2 |
| Z Fold 7 832 × 750 / 750 × 832 | yes | 2 / **1** | 2 / 2 | 2 / 2 |
| Z Fold 6 675 × 786 · Z Fold 5 659 × 791 | yes | 1 / 1 | 1 / 1 | 1 / 1 |
| Tablet 1024 × 768 | yes | 2 | **3** | 2 |
| Tablet 768 × 1024 | no | 1 | 1 | 1 |
| Phone landscape 915 × 412 | no | 1 | 1 | 1 |
| Desktop 1600 × 900 | yes | 4 | 4 | 4 |

Two cells deserve a sentence. A Z Fold 7 in portrait gives the device list 750 − 81 − 32 = 637,
three short of the 652 two 320-dp tiles and their gap need, so it keeps one column while the
dataset list beside it (653) gets two — the rule working at its boundary, not a bug. And a tablet in
landscape gives the network list three columns because its tile's minimum is 300: 1024 − 81 − 16 =
927 clears 3 × 300 + 2 × 12 = 924.

Tiles are laid out **left to right, then top to bottom**, one `Row` of `Expanded` cells per row
rather than a `GridView`, so the device list keeps `ListView.builder` virtualization and the
services views keep their cards as children of one scroll view. Short final rows are padded with
empty cells so the remaining tiles keep their width. See
[`functions/shared/widgets/adaptive_tile_grid.md`](functions/shared/widgets/adaptive_tile_grid.md).

**Gestures change with the columns.** At one column the device and dataset tiles keep their swipe
actions (swipe right to edit, swipe left to delete; datasets delete only). Above one column a
horizontal drag inside one narrow cell is ambiguous, so the `Dismissible` is dropped and the
trailing chevron becomes a menu carrying the same actions — the trailing menu the services tiles
already use. Delete has no other entrance on either page, so the menu is what keeps it reachable.
Reorder mode always renders a single column, because `ReorderableListView` wants one child per item.

## Detail pages: two panes

The device detail page and the network detail page split under the same rule, through a one-line
page-named delegate in [`detail_layout.dart`](functions/shared/utils/detail_layout.md):

```dart
bool useDetailTwoPane(double width, double height) => canSplitLayout(width, height);
double detailLeftPaneWidth(double totalWidth) => (totalWidth * 0.36).clamp(260.0, 420.0);
```

The delegate exists so the pages keep their own vocabulary; `test/detail_layout_test.dart` asserts
it still agrees with `canSplitLayout` at every named viewport, so the delegation cannot drift. The
pane is proportional rather than fixed because one foldable generation spans ~672 to ~954 dp
unfolded; the clamps keep it usable at the narrow end (260 at the 600 dp floor, leaving 339 on the
right) and stop it sprawling on a desktop.

| Page | Left pane (fixed, scrolls only if it must) | Right pane (scrolls) | Extra gate |
|---|---|---|---|
| Device detail | Header card (avatar, name, brand / model, dates), then the location map and the notes | The spec cards: finance, CPU, GPU, memory & storage, display, other | **At least one spec section.** Every section is conditional, so a device with none would face a blank right half; it keeps the single column instead. |
| Network detail | The info card (type logo, type, subnet, gateway, DNS, notes) | The devices header and the assignment list | None: an empty assignment list renders an empty-state card, never nothing. |

The single-column order is untouched — header, specs, map, notes on the device page; info card,
then devices on the network page. Both pages are pushed above the shell, so `constraints.maxWidth`
is the whole window and no rail is subtracted. The 100 dp label gutter in the spec rows stays: at
the 600 dp floor the right pane's cards still have 275 dp inside their padding, and on the network
page's 260 dp info card a long DNS list wraps, which is acceptable.

| Viewport | Splits | Left pane | Right pane |
|---|---|---|---|
| Z Fold 8 landscape 933 × 704 | yes | 336 | 596 |
| Z Fold 8 portrait 704 × 933 | no | — | — |
| Z Fold 7 832 × 750 / 750 × 832 | yes | 300 / 270 | 531 / 479 |
| Fold 8 Ultra 954 × 859 / Pixel 10 Pro Fold 791 × 820 | yes | 343 / 285 | 610 / 505 |
| Tablet 1024 × 768 / 768 × 1024 | yes / no | 369 / — | 654 / — |
| Phone 412 × 915 / 915 × 412 | no | — | — |
| Desktop 1600 × 900 | yes | 420 | 1179 |

## A pane that must not scroll: the device edit page

The device edit page splits through the same `useDetailTwoPane` delegate and
`detailLeftPaneWidth`, but its left pane has a requirement the detail pages do not: it holds the
thing being edited — the avatar picker, the name field and the category dropdown — and should stay
on screen while everything from brand down scrolls on the right. Both panes stay inside the one
`Form`, so `validate()` still reaches fields on both sides, and every controller already lives in
`State`, so a half-typed value survives folding or unfolding mid-edit.

The naive version — a fixed 56 dp avatar above two fields — would fit, but a fixed *large* avatar
would not: at the 480 dp minimum height the split rule admits, the pane has 424 dp after the app
bar. So the avatar is sized **from the height left over**, and the column fits by construction:

```dart
const deviceEditLeftPaneFieldBudget = 318.0;   // everything in the column except the avatar
double editAvatarSize(double paneWidth, double paneHeight) =>
    (paneHeight - 318).clamp(56.0, 160.0)      // then capped at paneWidth − 32
```

The 318 is 16 of top padding, 12 between the avatar and its chips, three rows of 32 dp
`ActionChip`s at 8 dp run spacing in the worst case (a 260 dp pane puts the Japanese labels one per
row) = 112, 16 under them, a 56 dp name field, 12, a 56 dp category field, 22 of slack for a
validation error under the name field, and 16 of bottom padding. At the 480 floor the avatar comes
out at 106; a Z Fold 8 in landscape (704 − 56 = 648) reaches the 160 ceiling; the 56 floor is the
size the single-column icon section always had. `test/detail_layout_test.dart` asserts the
arithmetic, not the pixels: the assembled column stays under the pane height at every window height
from 480 to 1200.

**Brand, model and serial stay on the right, deliberately.** Brand's `Autocomplete` overlay is
hard-capped at 360 dp, wider than a 260 dp pane, and its 68 dp would push the avatar under its 56 dp
floor at the split minimum. The single-column order is untouched: name, category, brand, model,
serial, icon section, dates, finance, CPU, GPU, other specs, notes.

The pane is still wrapped in a `SingleChildScrollView` with `minHeight` pinned to the pane. Not
because it should ever scroll, but because a soft keyboard can shrink the body below what the
arithmetic covers, and degrading to a scroll is far better than an overflow stripe.

| Viewport | Splits | Pane | Pane height | Avatar |
|---|---|---|---|---|
| Z Fold 8 landscape 933 × 704 | yes | 336 | 648 | 160 |
| Z Fold 7 832 × 750 / 750 × 832 | yes | 300 / 270 | 694 / 776 | 160 / 160 |
| Tablet 1024 × 768 | yes | 369 | 712 | 160 |
| Split floor 600 × 480 | yes | 260 | 424 | 106 |
| Z Fold 8 portrait, tablet portrait, phone either way | no | — | — | 56, single column |

## Two blocks side by side: a width floor on top of the split rule

Some layouts need both questions answered. The finance overview is the case: three summary metrics
above a 220 dp pie chart cost most of a Z Fold 8's ~640 dp body before the trend chart appears.
Putting the metrics in a narrow column beside the pie reclaims that — but only where the chart still
has room to draw in.

```dart
canSplitLayout(screenWidth, screenHeight)   // does the window have the shape?
  && useFinanceSideBySide(contentWidth)     // is there room for both blocks?
  && hasDistribution                        // is there a chart at all?
```

`useFinanceSideBySide` is `contentWidth >= 240 + 340 + 12`. The two minimums are the summary pane
(a `titleLarge` money value at ~150 plus card padding and slack for the longest Japanese label) and
the chart (a 232 dp pie plus its labels and the distribution rows under it). The content width is
the raw window less the page's 32 dp of padding, because the page is pushed above the shell.

`financeSummaryPaneWidth` is `(contentWidth * 0.34).clamp(240, 360)` with **no right-hand cap**.
None can bind: above the gate the pane grows at 0.34 of the width while the chart grows at 0.66,
so the chart's floor is met exactly at the boundary and only more comfortably above it. That
invariant is asserted across the whole range in `test/detail_layout_test.dart` rather than defended
by a second clamp. The row sits inside an `IntrinsicHeight` so both cards stretch to the chart's
height instead of the summary hanging off the top.

The third condition is not defensive padding. An empty chart renders a one-line "no data"
placeholder, so without it the metrics would sit in a 240 dp pane beside a nearly blank half rather
than falling back to their full-width row.

Unlike MyAnime's statistics page, **every unfolded foldable clears the width floor** — a Z Fold 5
in portrait leaves 627 against the 592 needed — because MyDevice's two blocks are smaller. That is
the rule working, not slack in it; the floor still binds at the 600 dp split minimum (568).

| Viewport | Splits | Content | Beside | Pane | Chart |
|---|---|---|---|---|---|
| Z Fold 8 landscape 933 × 704 | yes | 901 | **yes** | 306 | 583 |
| Z Fold 8 portrait 704 × 933 | no | — | no | — | — |
| Z Fold 7 750 × 832 | yes | 718 | **yes** | 244 | 462 |
| Z Fold 6 675 · Z Fold 5 659 | yes | 643 / 627 | **yes** / **yes** | 240 / 240 | 391 / 375 |
| Tablet 1024 × 768 / 768 × 1024 | yes / no | 992 / — | **yes** / no | 337 / — | 643 / — |
| Phone landscape 915 × 412 | no | — | no | — | — |
| Split floor 600 × 480 | yes | 568 | no | — | — |
| Desktop 1600 × 900 | yes | 1568 | **yes** | 360 | 1196 |

**The cost of gating this on `canSplitLayout`:** a phone in landscape at 915 × 412 keeps the stacked
layout, although it is the viewport with the least height of any and the one that would benefit
most. A width-only rule — the one `useNavigationRail` uses — would have helped it. The app-wide
split rule was chosen instead, deliberately, for consistency with the detail pages and the lists.

## Where navigation lives

A **second rule, and deliberately a narrower one**:

```dart
bool useNavigationRail(double screenWidth) => screenWidth >= navRailMinWidth; // 600.0
```

Above it the shell renders a `NavigationRail` down the side; below it, the bottom `NavigationBar`
it always had. Both are built from one list of destinations in
[`shell_scaffold.dart`](functions/shared/widgets/shell_scaffold.md), so they cannot drift apart. The
rail centres its destinations (`groupAlignment: 0`) rather than taking the default top alignment: a
rail top-aligns to sit under a leading menu button or FAB, and this one has neither, so five
destinations pinned to the top of a 704 dp rail would leave its whole lower half empty. The rail
sits inside a scroll view so a compact-height window cannot overflow it.

**This is width-only on purpose, and must not be routed through `canSplitLayout`.** A rail is not a
split. It trades width — abundant whenever the test passes — for height, which is not. The case it
helps most is precisely the one the split rule rejects: an ordinary phone in landscape at
915 × 412, where a bottom bar spends 19% of the height on navigation while 915 logical pixels of
width sit unused. A Z Fold 8 in portrait, which the split rule also rejects, gets a rail for the
same reason.

One consequence follows through the rest of the app: `shellContentWidth(screenWidth)` subtracts
`navRailWidth` (81 = an 80 dp rail plus its 1 dp divider) whenever the rail is showing, and every
capacity inside the shell is measured from that, never from the raw screen width: the four lists'
column counts and the topology card's action row on the services overview.

**Deliberately not ported from MyAnime: a bottom-bar inset.** MyAnime's scrolling pages reserve
80 dp for the bottom bar and drop it to 16 under a rail. MyDevice does not need to. Its shell
`Scaffold` holds the bottom bar and each tab page brings its own `Scaffold` for its app bar and
floating action buttons, so a page body never sits under the bar in the first place. The
`bottom: 80` the device list reserves is clearance for its stack of three floating action buttons,
which the rail does not remove — do not "fix" it by routing it through the navigation rule.

Not done, deliberately: a `NavigationDrawer` above 1240 dp. The rail is correct through extra-large
here, and a third navigation mode is not worth its cost.

## Measure the screen for the gate, the content box for the capacity

`canSplitLayout` and `useNavigationRail` read `MediaQuery.sizeOf(context)` — the whole screen.
Capacities and pane widths read what the content actually gets: `shellContentWidth(screenWidth)`
less the page's own padding, or `LayoutBuilder`'s `constraints.maxWidth`. The asymmetry is
deliberate, for two separate reasons:

- Measuring the split decision against the `Scaffold` body would subtract the app bar from the
  height and inflate the ratio, reading a Z Fold 8 in portrait as `0.80` instead of `0.755` and
  leaving almost no margin under the threshold.
- The gate asks about the window's *shape*, which the rail does not change. The capacity asks how
  much room is left, which the rail very much does.

## Pushed pages measure the raw window

Only the five tab pages live inside the `ShellRoute`. Every other page — device and network
detail, every edit page, the finance overview, the maps, the settings sub-pages — is pushed on the
**root** navigator with `Navigator.of(context, rootNavigator: true)`, above the shell. It has no
rail beside it and no bottom bar under it, so `constraints.maxWidth` *is* the whole width. Passing
such a page's width through `shellContentWidth` would silently lose 81 dp. The detail pages and the
finance overview all read their own `LayoutBuilder` and nothing else.

## Dialogs derive their height from the window

The two online-search dialogs (`device_search_dialog.dart`, `chip_search_dialog.dart`) were a
fixed 560 and 480 dp tall with no width cap and a 12 dp horizontal inset. On a tablet they stretched
to the window's full width; on a phone in landscape (915 × 412) or a folded Z Fold 8 cover screen in
landscape (657 × 416) they were taller than the window. They now take
`dialogBodyHeight(availableHeight, preferred: 560 | 480)`, which leaves `dialogInsetVertical`
(40) above and below, never exceeds the preferred height, and never drops below
`dialogMinBodyHeight` (240 — a header, a query field and two result rows). `availableHeight` is the
window less the soft-keyboard inset. Width is capped at `dialogMaxWidth` (560, Material's dialog
maximum); the quick-access route dialog on the services page uses the same constant.

| Window | Device search | Chip search |
|---|---|---|
| Z Fold 8 landscape, 704 tall | 560 (unchanged) | 480 (unchanged) |
| Phone landscape, 412 tall | 332 | 332 |
| Z Fold 8 cover landscape, 416 tall | 336 | 336 |
| Anything under 320 tall | 240 (floor) | 240 (floor) |

Under a soft keyboard on a 412 dp window even the floor overflows; that limit is accepted rather
than shrinking the dialog below anything usable.

## Folding and unfolding

`android/app/src/main/AndroidManifest.xml` declares
`screenLayout|screenSize|smallestScreenSize|density` among the activity's `configChanges` (the
stock Flutter template already did), so folding or unfolding resizes the window **without restarting
the activity**. Everything that reads `MediaQuery.sizeOf` therefore re-evaluates on the next frame,
which is all "switch automatically when the device unfolds" needs — no lifecycle work, and no state
to save and restore.

## Where these rules are used

| Call site | Rule | Notes |
|---|---|---|
| `shell_scaffold.dart` | `useNavigationRail` | Width only; see above. |
| `device_list_page.dart`, `network_list_page.dart`, `dataset_list_page.dart` | `listColumnCount` | Split rule, then capacity at each tile's minimum, then the stored preference clamped. Content width is `shellContentWidth` less the page padding. |
| `service_list_page.dart` (devices / routes / ports views) | `listColumnCount` | As above at `serviceCardMinWidth`; one preference serves the three views and the overview stays single-column. |
| `service_list_page.dart` (overview metric grid) | `serviceMetricColumns` | Width only, from the overview list's `LayoutBuilder`. |
| `service_list_page.dart` (topology card header) | `useTopologyActionsRow` | Width only. The value is the 680 the card used inline before 1.5.0; the card is now handed the width left after the rail, so a Pixel 10 Pro Fold in portrait stacks the actions under the title where it used to row them. |
| `service_list_page.dart` (quick-access route dialog) | `dialogMaxWidth` | A constant, not a rule. |
| `device_detail_page.dart` | `useDetailTwoPane`, `detailLeftPaneWidth` | Plus a third gate: at least one spec section. Pushed outside the shell: measures the raw window. |
| `network_detail_page.dart` | `useDetailTwoPane`, `detailLeftPaneWidth` | Pushed outside the shell. |
| `device_edit_page.dart` | `useDetailTwoPane`, `detailLeftPaneWidth`, `editAvatarSize` | The left pane is non-scrolling by construction; see above. Pushed outside the shell. |
| `device_finance_overview_page.dart` (summary beside chart) | `canSplitLayout`, `useFinanceSideBySide`, `financeSummaryPaneWidth` | The double gate, plus a non-empty distribution; see above. |
| `device_finance_overview_page.dart` (summary card) | `financeSummaryColumns` | Width only, floored at two; forced to one column inside the side-by-side pane. Pushed outside the shell: measures its own `LayoutBuilder`. |
| `device_search_dialog.dart`, `chip_search_dialog.dart` | `dialogBodyHeight`, `dialogMaxWidth` | Height from the window less the keyboard. |
| `_ServiceTopologyPage` / `_ServiceTopologyView` | none needed | Already a `LayoutBuilder`-driven, full-bleed `InteractiveViewer`; the layout cache is keyed on the viewport width. |
| `device_map_page.dart`, `map_picker_page.dart` | none needed | A full-bleed map fills whatever it is given; the picker's search row is already an `Expanded` field beside a button. |

Every other page is still a fixed single column and is scheduled: the remaining edit pages and
sheets in 1.5.4, and the settings family in 1.5.5. Until 1.5.4 one hardcoded
count remains in `lib/`: the emoji picker's `crossAxisCount: 8` in `device_edit_page.dart`, a count
rather than a comparison, listed here so the "no inline width decision" claim stays honest.

## Divergence from Google's guidance

Google's adaptive-layout guidance says window size classes are "explicitly not determined by the
size of the device screen" and "not intended for *isTablet*-type logic", and directs apps to decide
from available width rather than aspect ratio. This app **deliberately diverges** on one point: the
aspect test. It is not an oversight. Width alone cannot give the Fold 8 two different answers in
its two orientations, and that behaviour — split in landscape, original single column in portrait —
is the requirement the rule exists to satisfy.

Everything else follows Google exactly: the width and height floors are its breakpoints, the column
capacity is its feed guidance, and the navigation rail at medium width and up is its recommendation
verbatim.

## Tests

- `test/adaptive_layout_test.dart` — the gate, the rail rule, the content width, the capacity and
  row math, the four lists' column counts and preference clamping, the two overview rules, the
  finance floor and the dialog height, pinned at the real logical-pixel geometry of every device in
  the tables above, with the device named in a comment so a regression names the device it would
  break. It also asserts that `serviceMetricColumns` still agrees with the inline arithmetic it
  replaced.
- `test/detail_layout_test.dart` — the detail delegate's agreement with the split rule, the pane
  width's clamps, the finance width floor at named devices, the loop invariant that the chart
  never falls under its minimum from the gate up to 2000 dp, and the loop invariant that the edit
  page's left column fits its pane at every window height from 480 to 1200.
- `test/device_edit_two_pane_ui_test.dart` — the rendered edit page at a Z Fold 8 both ways, a
  phone, the 600 × 480 floor and under a 300 dp soft-keyboard inset: which fields share the left
  pane, that one `Form` still wraps both, and that nothing overflows.
- `test/device_detail_layout_ui_test.dart`, `test/network_detail_layout_ui_test.dart`,
  `test/finance_overview_layout_ui_test.dart` — the rendered pages at a Z Fold 8 both ways, a
  Z Fold 7 in portrait, a phone both ways, a tablet and the 600 × 480 floor: which pane holds what,
  that the left pane holds still while the right one scrolls, the no-specs and no-data fallbacks.
- `test/list_columns_prefs_test.dart` — the four column preferences round-trip independently, the
  default is absent from the file rather than written, and a malformed value reads as auto.
- `test/list_columns_ui_test.dart`, `test/list_columns_more_ui_test.dart`,
  `test/service_columns_ui_test.dart` — the rendered device, network, dataset and services lists at
  a Z Fold 8 both ways, a Pixel 9 both ways and a tablet, against a seeded storage directory: the
  column count, the hidden control, the stored pick, the clamp, the swipe-or-menu switch and the
  grouped headers.
- `test/shell_nav_ui_test.dart` — the rendered shell at a Pixel 9 both ways, a Z Fold 8 both ways
  and a desktop window: which navigation appears, that the rail carries the same five destinations,
  and that tapping one navigates.
- `test/dialog_layout_ui_test.dart` — both search dialogs opened at five window sizes, asserting the
  dialog clears the window and the width cap.

`flutter_test` renders every glyph of its default font as a full em square, which inflates a Latin
label to roughly two and a half times its real width. Widget tests here therefore run in Simplified
Chinese (`Locale('zh')`), whose glyphs really are square, so they measure the real production layout
rather than a font artifact. Keep it that way; a test that "fixes" the locale back to English will
report overflows that do not exist in production.
