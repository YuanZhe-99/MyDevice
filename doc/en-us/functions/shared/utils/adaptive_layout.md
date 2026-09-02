# lib/shared/utils/adaptive_layout.dart

The app-wide adaptive-layout policy: the `splitMinWidth`, `splitMinHeight` and `splitMinAspect`
thresholds that decide whether a layout may split at all; `listTileGap`, `listMaxColumns` and
`listColumnsAuto` for multi-column lists; `navRailMinWidth` and `navRailWidth` for the shell's
navigation rail; `serviceMetricMinWidth`, `serviceMetricMaxColumns` and
`topologyActionsRowMinWidth` for the services overview; `financeSummaryMetricMinWidth`,
`financeSummaryGap`, `financeSummaryMinColumns` and `financeSummaryMaxColumns` for the finance
summary card; and `dialogInsetHorizontal`, `dialogInsetVertical`, `dialogMaxWidth` and
`dialogMinBodyHeight` for the search dialogs; and `deviceTileMinWidth`, `networkTileMinWidth`,
`dataSetTileMinWidth` and `serviceCardMinWidth` for the four multi-column lists. Nine pure helpers
sit on top of them.

The module deliberately depends on nothing but `dart:core` — it holds no Flutter imports, and
`canSplitLayout` takes two doubles rather than a `Size` for exactly that reason — so every helper
is directly unit-testable (`test/adaptive_layout_test.dart`), and the rendered result is covered
separately at real device geometries by `test/shell_nav_ui_test.dart`,
`test/dialog_layout_ui_test.dart`, `test/list_columns_ui_test.dart`,
`test/list_columns_more_ui_test.dart` and `test/service_columns_ui_test.dart`.

The prose derivation of these numbers, the foldable device tables and the reconciliation with
Google's guidance live in [../../../adaptive-layout.md](../../../adaptive-layout.md). This page
documents the declarations.

Consumers: `shell_scaffold.dart` for `useNavigationRail`; the four list pages for
`listColumnCount`, `columnCapacity`, `shellContentWidth` and their tile minimums, and
`device_storage.dart` for `listColumnsAuto` and `listMaxColumns` when validating the stored
preference; `adaptive_tile_grid.dart` for `listRowCount` and `listTileGap`;
`service_list_page.dart` for `serviceMetricColumns`, `useTopologyActionsRow` and `dialogMaxWidth`;
`device_finance_overview_page.dart` for `financeSummaryColumns`; `device_search_dialog.dart` and
`chip_search_dialog.dart` for `dialogBodyHeight`, `dialogMaxWidth` and the two inset constants.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`canSplitLayout`](#cansplitlayout) | top-level function | A | Report whether a layout may split into panes or columns. |
| [`useNavigationRail`](#usenavigationrail) | top-level function | A | Report whether the shell should show a navigation rail. |
| [`shellContentWidth`](#shellcontentwidth) | top-level function | A | Return the width a shell page's content actually receives. |
| [`columnCapacity`](#columncapacity) | top-level function | A | Return how many columns of a given minimum width fit a content box. |
| [`listRowCount`](#listrowcount) | top-level function | A | Return how many rows a list of items needs at a column count. |
| [`listColumnCount`](#listcolumncount) | top-level function | A | Return the number of columns a list should actually render. |
| [`serviceMetricColumns`](#servicemetriccolumns) | top-level function | A | Return how many metric cards the services overview lays per row. |
| [`useTopologyActionsRow`](#usetopologyactionsrow) | top-level function | A | Report whether the topology card's title and actions share a row. |
| [`financeSummaryColumns`](#financesummarycolumns) | top-level function | A | Return how many columns the finance summary card lays its metrics in. |
| [`dialogBodyHeight`](#dialogbodyheight) | top-level function | A | Return the height a search dialog's body should take. |

The twenty-three constants are documented in source with the reason for each value and are not
repeated as rows here.

## Documentation

### `bool canSplitLayout(double width, double height)` <a id="cansplitlayout"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/adaptive_layout.dart`.
- **Purpose:** Report whether a layout may split into panes or columns.
- **Inputs:** `width`, `height` — the viewport size in logical pixels, from `MediaQuery.sizeOf`.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** `false` if `width < 600`, if `height < 480`, or if `height <= 0`; otherwise
  `width / height >= 0.82`.
- **Usage:** `listColumnCount`, and the four list pages' capacity for the column control; the
  two-pane pages (1.5.2 onward) gate on it too.
- **Notes:** Three independent conditions, because none alone is enough. The aspect test is the
  load-bearing one: a Galaxy Z Fold 8 splits in landscape (4:3) but not in portrait (3:4), while
  the near-square Fold 7 and Fold 8 Ultra split in both orientations. The height floor exists
  because the aspect test alone admits wide, short viewports — a cover screen or a phone in
  landscape.

### `bool useNavigationRail(double screenWidth)` <a id="usenavigationrail"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/adaptive_layout.dart`.
- **Purpose:** Report whether the shell should show a navigation rail.
- **Inputs:** `screenWidth` — the whole screen width in logical pixels.
- **Returns:** `bool` — `screenWidth >= 600`.
- **Side effects:** None.
- **Usage:** `ShellScaffold.build`.
- **Notes:** Width only, deliberately, and not routed through `canSplitLayout`. A rail trades
  width, which is abundant whenever this is true, for height, which is not; the case it helps most
  is a phone in landscape, which the split rule rejects.

### `double shellContentWidth(double screenWidth)` <a id="shellcontentwidth"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/adaptive_layout.dart`.
- **Purpose:** Return the width a shell page's content actually receives.
- **Inputs:** `screenWidth` — the whole screen width in logical pixels.
- **Returns:** `double`, never negative — `screenWidth − 81` when the rail is shown, else
  `screenWidth`.
- **Side effects:** None.
- **Usage:** The four list pages, which subtract their own padding and pass the result to
  `columnCapacity` and `listColumnCount`.
- **Notes:** Only the five pages inside the shell may use this. Every other page is pushed on the
  root navigator above the shell and must measure the raw window.

### `int columnCapacity(double contentWidth, {required double minItemWidth, double gap = listTileGap, int maxColumns = listMaxColumns})` <a id="columncapacity"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/adaptive_layout.dart`.
- **Purpose:** Return how many columns of a given minimum width fit a content box.
- **Inputs:** `contentWidth`; `minItemWidth`; `gap` (default 12); `maxColumns` (default 4).
- **Returns:** `int`, 1 to `maxColumns`.
- **Side effects:** None.
- **Algorithm:** `((contentWidth + gap) / (minItemWidth + gap)).floor().clamp(1, maxColumns)`. A
  non-positive width returns 1; a non-positive minimum returns the ceiling; a ceiling below 1 is
  read as 1.
- **Usage:** `listColumnCount`, `serviceMetricColumns`, `financeSummaryColumns`, and the four list
  pages for the capacity that decides whether the column control is shown.
- **Notes:** One gap in the numerator so the arithmetic pays for the gaps *between* columns rather
  than one after every column.

### `int listRowCount(int itemCount, int columns)` <a id="listrowcount"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/adaptive_layout.dart`.
- **Purpose:** Return how many rows a list of items needs at a column count.
- **Inputs:** `itemCount`, `columns`.
- **Returns:** `int` — `ceil(itemCount / columns)`, 0 for an empty list; a column count below 1 is
  read as 1.
- **Side effects:** None.
- **Usage:** `adaptiveTileRows`, and the device, network and dataset lists' `ListView.builder`
  item counts.
- **Notes:** None.

### `int listColumnCount({required double screenWidth, required double screenHeight, required double contentWidth, required double minItemWidth, required int preference})` <a id="listcolumncount"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/adaptive_layout.dart`.
- **Purpose:** Return the number of columns a list should actually render.
- **Inputs:** `screenWidth`, `screenHeight` — the whole screen, which decides whether splitting is
  allowed at all; `contentWidth` — the width the list itself gets; `minItemWidth` — the narrowest
  one tile may be; `preference` — `listColumnsAuto` or a pinned count.
- **Returns:** `int`, at least 1.
- **Side effects:** None.
- **Algorithm:** 1 when `canSplitLayout` is false; otherwise `columnCapacity(contentWidth,
  minItemWidth)` when the preference is auto, else the preference clamped to 1..capacity.
- **Usage:** `build` in the four list pages, with `shellContentWidth(screen.width)` less the page
  padding as `contentWidth`.
- **Notes:** The gate reads the screen while the capacity reads the list's own width, deliberately.
  A pinned preference is clamped rather than rejected, so a window that shrinks — or a foldable that
  closes — falls back to one column without losing the stored choice. Unlike MyAnime's version the
  minimum is a parameter, because MyDevice has four tile shapes.

### `int serviceMetricColumns(double contentWidth)` <a id="servicemetriccolumns"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/adaptive_layout.dart`.
- **Purpose:** Return how many metric cards the services overview lays per row.
- **Inputs:** `contentWidth` — the overview list's `LayoutBuilder` constraint.
- **Returns:** `int`, 1 to 4.
- **Side effects:** None.
- **Algorithm:** `columnCapacity(contentWidth, minItemWidth: 150, gap: 12, maxColumns: 4)`.
- **Usage:** `_ServiceListPageState._buildOverview`.
- **Notes:** Arithmetically identical to the inline `((w + 12) / 162).floor()` clamped to 1..4 the
  overview carried before 1.5.0, so no viewport changed its count when the rule moved here.

### `bool useTopologyActionsRow(double contentWidth)` <a id="usetopologyactionsrow"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/adaptive_layout.dart`.
- **Purpose:** Report whether the topology card's title and actions share a row.
- **Inputs:** `contentWidth` — the width inside the card's padding.
- **Returns:** `bool` — `contentWidth >= 680`.
- **Side effects:** None.
- **Usage:** `_ServiceListPageState._topologyCard`, negated into its `compact` flag.
- **Notes:** The value is the 680 the card used inline before 1.5.0; what changed is the width the
  card is handed, since a navigation rail now takes 81 of the screen first.

### `int financeSummaryColumns(double contentWidth)` <a id="financesummarycolumns"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/adaptive_layout.dart`.
- **Purpose:** Return how many columns the finance summary card lays its three metrics in.
- **Inputs:** `contentWidth` — the width inside the card's padding.
- **Returns:** `int`, 2 or 3.
- **Side effects:** None.
- **Algorithm:** `columnCapacity(contentWidth, minItemWidth: 160, gap: 16, maxColumns: 3)` clamped
  to 2..3.
- **Usage:** `_DeviceFinanceOverviewPageState._buildSummaryCard`.
- **Notes:** A bare `columnCapacity` would drop to one column on a 320 dp cover screen, which the
  card never did, hence the floor. The third column arrives at 512 dp where the inline rule before
  1.5.0 asked for 520.

### `double dialogBodyHeight(double availableHeight, {required double preferred})` <a id="dialogbodyheight"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/adaptive_layout.dart`.
- **Purpose:** Return the height a search dialog's body should take.
- **Inputs:** `availableHeight` — the window height less any soft-keyboard inset; `preferred` —
  the height the dialog wants when the window has room.
- **Returns:** `double`, `dialogMinBodyHeight` (240) to `preferred`.
- **Side effects:** None.
- **Algorithm:** `(availableHeight − 2 × 40).clamp(240, preferred)`; a `preferred` below 240
  returns 240.
- **Usage:** `_DeviceSearchDialogState.build` (preferred 560) and `_ChipSearchDialogState.build`
  (preferred 480).
- **Notes:** Before 1.5.0 both dialogs were fixed at their preferred height, which overflowed a
  phone or a folded cover screen held in landscape.
