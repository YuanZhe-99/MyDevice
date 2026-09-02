# lib/shared/widgets/adaptive_tile_grid.dart

The three helpers a list page needs to render its tiles in the columns
[`listColumnCount`](../utils/adaptive_layout.md#listcolumncount) returns: one `Row` per row of
tiles, the rows for a whole list, and the app-bar control that picks the count. Used by
`device_list_page.dart`, `network_list_page.dart`, `dataset_list_page.dart` and
`service_list_page.dart`. The reasoning behind the column rule is in
[../../../adaptive-layout.md](../../../adaptive-layout.md#how-many-columns).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`adaptiveTileRow`](#adaptivetilerow) | top-level function | A | Build one row of a multi-column list, filled left to right. |
| [`adaptiveTileRows`](#adaptivetilerows) | top-level function | A | Build a list's children as rows, single column or multi-column. |
| [`listColumnsButton`](#listcolumnsbutton) | top-level function | A | Build the app-bar control that picks a list's column count. |

## Documentation

### `Widget adaptiveTileRow({required int rowIndex, required int columns, required int itemCount, required Widget Function(int index) itemBuilder, double gap = listTileGap})` <a id="adaptivetilerow"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/widgets/adaptive_tile_grid.dart`.
- **Purpose:** Build one row of a multi-column list, filled left to right.
- **Inputs:** `rowIndex` — the zero-based row; `columns` — tiles per row; `itemCount` — total tiles;
  `itemBuilder` — builds one tile by its flat index; `gap` — spacing between columns.
- **Returns:** A `Row` (`crossAxisAlignment: start`) of `columns` `Expanded` cells separated by
  `gap`; cells past `itemCount` hold `SizedBox.shrink()`.
- **Side effects:** None.
- **Usage:** The device, network and dataset lists call it from a `ListView.builder` whose item
  count is `listRowCount`, keeping virtualization.
- **Notes:** Deliberately a `Row` rather than a `GridView`, so a builder-driven list stays lazy and
  a materialized list needs no nested scrollable. Padding short final rows with empty cells keeps
  the remaining tiles at their width instead of stretching them across the row.

### `List<Widget> adaptiveTileRows({required int columns, required int itemCount, required Widget Function(int index) itemBuilder, double gap = listTileGap})` <a id="adaptivetilerows"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/widgets/adaptive_tile_grid.dart`.
- **Purpose:** Build a list's children as rows, single column or multi-column.
- **Inputs:** `columns`, `itemCount`, `itemBuilder`, `gap`.
- **Returns:** At one column the tiles themselves; otherwise one `adaptiveTileRow` per
  `listRowCount` row.
- **Side effects:** None.
- **Usage:** The grouped device list per category, and the services page's devices, routes and
  ports views, whose cards are already children of one `ListView`.
- **Notes:** Returning the tiles untouched at one column is what lets a caller that wraps its
  single-column tile in a `Dismissible` keep its existing widget tree exactly.

### `Widget listColumnsButton(BuildContext context, {required int preference, required int capacity, required ValueChanged<int> onChanged})` <a id="listcolumnsbutton"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/widgets/adaptive_tile_grid.dart`.
- **Purpose:** Build the app-bar control that picks a list's column count.
- **Inputs:** `context`; `preference` — the stored choice; `capacity` — the most columns the
  current width can carry; `onChanged` — receives the new preference.
- **Returns:** A `PopupMenuButton<int>` (`Icons.view_column_outlined`) offering `listColumnsAuto`
  and every count up to `listMaxColumns`, or `SizedBox.shrink()` when `capacity <= 1`.
- **Side effects:** None beyond invoking `onChanged`.
- **Usage:** Each list page's `AppBar.actions`, ahead of the sort menu; hidden in reorder mode and on
  the services overview by the caller.
- **Notes:** Hidden rather than disabled at capacity one, so a phone or a folded cover screen never
  shows a control that could do nothing. The menu always offers every count so a preference can be
  set while folded and take effect on unfolding; the check mark tracks the stored preference while
  what renders is that preference clamped to what fits.
