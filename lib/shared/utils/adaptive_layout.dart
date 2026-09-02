/// Minimum viewport width, in logical pixels, before a layout may split.
///
/// Material's *medium* width class and Android's `sw600dp` tablet threshold.
const splitMinWidth = 600.0;

/// Minimum viewport height, in logical pixels, before a layout may split.
///
/// Matches the boundary between Android's compact and medium height classes.
/// Google's own guidance is that a window whose height is compact — a phone or
/// an open flippable held in landscape — cannot practically carry two panes.
const splitMinHeight = 480.0;

/// Minimum viewport width-to-height ratio before a layout may split.
///
/// Sits near the middle of the gap between a Galaxy Z Fold 8's portrait ratio
/// (0.755, a 4:3 landscape panel held upright) and the near-square Fold 7 and
/// Fold 8 Ultra (0.90), with roughly 9% of margin on each side.
const splitMinAspect = 0.82;

/// Horizontal gap, in logical pixels, between columns of a multi-column list.
const listTileGap = 12.0;

/// Largest number of columns a list will use, however wide the window is.
const listMaxColumns = 4;

/// Column preference meaning "use whatever the width can fit".
const listColumnsAuto = 0;

/// Minimum viewport width, in logical pixels, before the shell shows its
/// navigation rail instead of a bottom navigation bar.
///
/// Material's *medium* width class, which is where Google's guidance moves
/// navigation to the side. This is a width-only threshold on purpose; see
/// [useNavigationRail].
const navRailMinWidth = 600.0;

/// Logical pixels the navigation rail takes from the content when it is shown.
///
/// An 80 dp `NavigationRail` plus the 1 dp `VerticalDivider` beside it.
const navRailWidth = 81.0;

/// Minimum width, in logical pixels, one services-overview metric card may
/// occupy.
///
/// A card is an icon, a headline-sized count and a label of up to two lines
/// inside 16 dp of padding; narrower and the label wraps to a third line.
const serviceMetricMinWidth = 150.0;

/// Largest number of metric cards the services overview lays on one row.
const serviceMetricMaxColumns = 4;

/// Minimum content width, in logical pixels, before the topology card puts its
/// title and its two action buttons on one row.
///
/// The title is a 24 dp icon, an 8 dp gap and one line of text; the actions are
/// two labelled buttons whose longest localized pair is Japanese; 16 dp sits
/// between them. Below this the actions wrap under the title.
const topologyActionsRowMinWidth = 680.0;

/// Minimum width, in logical pixels, one finance-summary metric may occupy.
///
/// A `titleLarge` money value such as "¥123,456.78" runs to roughly 120 dp
/// before its label; 160 keeps the value and a short label on one line each.
const financeSummaryMetricMinWidth = 160.0;

/// Horizontal gap, in logical pixels, between finance-summary metrics.
const financeSummaryGap = 16.0;

/// Fewest columns the finance summary ever uses.
///
/// The card was never allowed to stack its three metrics one per row: doing so
/// on a 320 dp cover screen makes the summary taller than the pie chart under
/// it. A floor of two keeps that shape.
const financeSummaryMinColumns = 2;

/// Most columns the finance summary ever uses — one per metric.
const financeSummaryMaxColumns = 3;

/// Horizontal inset, in logical pixels, a search dialog keeps from the window.
const dialogInsetHorizontal = 12.0;

/// Vertical inset, in logical pixels, a search dialog keeps from the window.
const dialogInsetVertical = 40.0;

/// Widest, in logical pixels, a search dialog may grow.
///
/// Material's maximum dialog width. Without it the dialog stretches to the
/// window's full width on a tablet, leaving a 560 dp tall strip of results
/// across a 1024 dp window.
const dialogMaxWidth = 560.0;

/// Shortest, in logical pixels, a search dialog body may shrink.
///
/// A 48 dp header, a 56 dp query field and two 68 dp result rows. Under a soft
/// keyboard on a 412 dp tall window even this overflows; that limit is accepted
/// rather than shrinking the dialog below anything usable.
const dialogMinBodyHeight = 240.0;

/// Purpose: Report whether a layout may split into panes or columns.
/// Inputs: `width`, `height` — the viewport size in logical pixels.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Three independent conditions, because none of them alone is enough.
/// The aspect test is the load-bearing one: it keeps a viewport that is
/// meaningfully taller than it is wide on the original single-column layout, so
/// a Galaxy Z Fold 8 splits in landscape (4:3) but not in portrait (3:4), while
/// the near-square Fold 7 and Fold 8 Ultra split in both orientations. The width
/// floor is the usual `sw600dp` tablet threshold. The height floor exists
/// because the aspect test alone admits wide, short viewports — a folded cover
/// screen or an ordinary phone held in landscape would otherwise split into two
/// cramped panes. See `doc/en-us/adaptive-layout.md` for the full derivation.
bool canSplitLayout(double width, double height) {
  if (width < splitMinWidth) return false;
  if (height < splitMinHeight) return false;
  if (height <= 0) return false;
  return width / height >= splitMinAspect;
}

/// Purpose: Report whether the shell should show a navigation rail.
/// Inputs: `screenWidth` — the whole screen width in logical pixels.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: **Width only, deliberately** — this is not [canSplitLayout] and must
/// not be routed through it. A rail is not a split; it trades width, which is
/// abundant whenever this returns true, for height, which is not. The case it
/// helps most is the one the split rule rejects on purpose: an ordinary phone
/// held in landscape at 915 x 412, where a bottom bar spends 19% of the height
/// on navigation while 915 logical pixels of width sit unused.
bool useNavigationRail(double screenWidth) => screenWidth >= navRailMinWidth;

/// Purpose: Return the width a shell page's content actually receives.
/// Inputs: `screenWidth` — the whole screen width in logical pixels.
/// Returns: `double`, never negative.
/// Side effects: None.
/// Notes: Subtracts the navigation rail when the shell is showing one. Pass the
/// result wherever a capacity is being computed; keep passing the untouched
/// screen size to [canSplitLayout], which asks about the window's shape rather
/// than about the room left over inside it. Only the five pages inside the
/// shell may use this: every other page is pushed on the root navigator above
/// the shell, has no rail beside it, and must measure the raw window.
double shellContentWidth(double screenWidth) {
  final width = useNavigationRail(screenWidth)
      ? screenWidth - navRailWidth
      : screenWidth;
  return width < 0 ? 0 : width;
}

/// Purpose: Return how many columns of a given minimum width fit a content box.
/// Inputs: `contentWidth` — the width available, in logical pixels;
/// `minItemWidth` — the narrowest one column may be; `gap` — spacing between
/// columns; `maxColumns` — a ceiling however wide the box is.
/// Returns: `int`, at least 1 and at most `maxColumns`.
/// Side effects: None.
/// Notes: The adaptive-minimum-width approach Google recommends for feeds and
/// grids, rather than a hardcoded count per breakpoint. One gap is added to the
/// numerator so the arithmetic pays for the gaps *between* columns rather than
/// one after every column. Non-positive widths return 1.
int columnCapacity(
  double contentWidth, {
  required double minItemWidth,
  double gap = listTileGap,
  int maxColumns = listMaxColumns,
}) {
  final ceiling = maxColumns < 1 ? 1 : maxColumns;
  if (contentWidth <= 0) return 1;
  if (minItemWidth <= 0) return ceiling;
  final fit = ((contentWidth + gap) / (minItemWidth + gap)).floor();
  return fit.clamp(1, ceiling);
}

/// Purpose: Return how many rows a list of items needs at a column count.
/// Inputs: `itemCount`, `columns`.
/// Returns: `int`.
/// Side effects: None.
/// Notes: The last row may be short; callers pad it so the remaining tiles keep
/// their width instead of stretching across the row.
int listRowCount(int itemCount, int columns) {
  if (itemCount <= 0) return 0;
  final perRow = columns < 1 ? 1 : columns;
  return (itemCount + perRow - 1) ~/ perRow;
}

/// Purpose: Return how many metric cards the services overview lays per row.
/// Inputs: `contentWidth` — the width the overview list gets, in logical
/// pixels, which is the `LayoutBuilder` constraint inside its padding.
/// Returns: `int`, 1 to [serviceMetricMaxColumns].
/// Side effects: None.
/// Notes: [columnCapacity] at [serviceMetricMinWidth]. This is arithmetically
/// identical to the inline rule the overview carried before 1.5.0
/// (`((w + 12) / 162).floor()` clamped to 1..4), so no viewport changed its
/// count when the rule moved here. A width-only packing question: whether four
/// cards fit on a row has nothing to do with whether the window may split.
int serviceMetricColumns(double contentWidth) => columnCapacity(
  contentWidth,
  minItemWidth: serviceMetricMinWidth,
  gap: listTileGap,
  maxColumns: serviceMetricMaxColumns,
);

/// Purpose: Report whether the topology card's title and actions share a row.
/// Inputs: `contentWidth` — the width inside the card's padding, in logical
/// pixels.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Width only, like every "does it fit on one line" question. The value
/// is the 680 the card used inline before 1.5.0; what changed is the width the
/// card is handed, since a navigation rail now takes 81 of the screen first —
/// a Pixel 10 Pro Fold in portrait (791 − 81 − 64 = 646) stacks where it used
/// to row, while a Z Fold 8 in landscape (788) still rows.
bool useTopologyActionsRow(double contentWidth) =>
    contentWidth >= topologyActionsRowMinWidth;

/// Purpose: Return how many columns the finance summary card lays its three
/// metrics in.
/// Inputs: `contentWidth` — the width inside the card's padding, in logical
/// pixels.
/// Returns: `int`, [financeSummaryMinColumns] to [financeSummaryMaxColumns].
/// Side effects: None.
/// Notes: A bare [columnCapacity] would drop to one column on a 320 dp cover
/// screen, which the card never did, so the result is floored at two. The
/// third column arrives at 512 dp — `(w + 16) / 176 >= 3` — where the inline
/// rule before 1.5.0 asked for 520; the 8 dp difference is the gap arithmetic
/// paying for two gaps rather than three.
int financeSummaryColumns(double contentWidth) => columnCapacity(
  contentWidth,
  minItemWidth: financeSummaryMetricMinWidth,
  gap: financeSummaryGap,
  maxColumns: financeSummaryMaxColumns,
).clamp(financeSummaryMinColumns, financeSummaryMaxColumns);

/// Purpose: Return the height a search dialog's body should take.
/// Inputs: `availableHeight` — the window height less any soft-keyboard inset,
/// in logical pixels; `preferred` — the height the dialog wants when the
/// window has room.
/// Returns: `double`, [dialogMinBodyHeight] to `preferred`.
/// Side effects: None.
/// Notes: Before 1.5.0 the two search dialogs were a fixed 560 and 480 tall,
/// which overflowed a phone in landscape (915 × 412) and a folded Z Fold 8
/// cover screen in landscape (657 × 416). The height now leaves
/// [dialogInsetVertical] above and below and stops at the preferred value, so
/// a Z Fold 8 in landscape (704 tall) still gets exactly the old sizes.
double dialogBodyHeight(double availableHeight, {required double preferred}) {
  final room = availableHeight - 2 * dialogInsetVertical;
  if (preferred < dialogMinBodyHeight) return dialogMinBodyHeight;
  return room.clamp(dialogMinBodyHeight, preferred);
}
