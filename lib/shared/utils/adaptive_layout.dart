import 'package:flutter/widgets.dart';
import 'package:myapps_ui/myapps_ui.dart' show MyAppsShellLayout;
import 'package:myapps_adaptive/myapps_adaptive.dart';

export 'package:myapps_adaptive/myapps_adaptive.dart';

/// Minimum width for an overview icon, count and two-line label.
const serviceMetricMinWidth = 150.0;

/// Maximum number of overview metrics per row.
const serviceMetricMaxColumns = 4;

/// Minimum width for the topology title and both localized actions.
const topologyActionsRowMinWidth = 680.0;

/// Minimum width for a finance amount and its label.
const financeSummaryMetricMinWidth = 160.0;

/// Gap between finance summary metrics.
const financeSummaryGap = 16.0;

/// Minimum columns, retaining the summary's compact height.
const financeSummaryMinColumns = 2;

/// Maximum columns, one for each of the three metrics.
const financeSummaryMaxColumns = 3;

/// Search dialog horizontal window inset.
const dialogInsetHorizontal = 12.0;

/// Search dialog vertical window inset.
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

/// Purpose: Return the width a shell page's content actually receives.
/// Inputs: `screenWidth` — full window width; `context` — actual page context.
/// Returns: `double`, never negative.
/// Side effects: None.
/// Notes: Context reads measured shell width; outside a shell uses full width.
/// The context-free form retains the legacy width rule for compatibility. Pass the
/// result wherever a capacity is being computed; keep passing the untouched
/// screen size to [canSplitLayout], which asks about the window's shape rather
/// than about the room left over inside it. Only the five pages inside the
/// shell may use this: every other page is pushed on the root navigator above
/// the shell, has no rail beside it, and must measure the raw window.
double shellContentWidth(double screenWidth, {BuildContext? context}) {
  if (context != null) {
    return MyAppsShellLayout.maybeOf(context)?.contentWidth ?? screenWidth;
  }
  final width = useNavigationRail(screenWidth)
      ? screenWidth - navRailWidth
      : screenWidth;
  return width < 0 ? 0 : width;
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

/// Minimum width, in logical pixels, one device list tile may occupy.
///
/// The tile is a `Card` inside a 16 dp padded row: 32 of tile padding, a 40 dp
/// avatar, a 16 gap and a 24 dp chevron (or 48 dp menu) plus 16 make roughly
/// 152 of chrome, leaving 168 for a name of about twenty characters on one
/// line and "category · brand · daily cost" in its two subtitle lines.
const deviceTileMinWidth = 320.0;

/// Minimum width, in logical pixels, one network list tile may occupy.
///
/// The same chrome as a device tile, but a single-line "type · subnet"
/// subtitle of about twenty-five characters (~175 dp), so it fits narrower.
const networkTileMinWidth = 300.0;

/// Minimum width, in logical pixels, one dataset list tile may occupy.
///
/// A bare `ListTile`: 32 of padding, a 34 dp emoji, a 16 gap, a 24 dp chevron
/// and 16 make 122. The subtitle carries up to four storage lines that must
/// not wrap, or the fourth line hides a device behind the ellipsis.
const dataSetTileMinWidth = 320.0;

/// Minimum width, in logical pixels, one services-page card may occupy.
///
/// Route cards carry a three-line summary; device and port cards nest tiles
/// whose trailing `PopupMenuButton` is 48 dp wide.
const serviceCardMinWidth = 320.0;

/// Purpose: Return the number of columns a list should actually render.
/// Inputs: `screenWidth`, `screenHeight` — the whole screen, which decides
/// whether splitting is allowed at all; `contentWidth` — the width the list
/// itself gets; `minItemWidth` — the narrowest one tile may be;
/// `preference` — [listColumnsAuto] or a pinned column count.
/// Returns: `int`, at least 1.
/// Side effects: None.
/// Notes: The gate reads the screen while the capacity reads the list's own
/// width, deliberately. Measuring the split decision against the body would
/// subtract the app bar and read a Fold 8 in portrait as 0.80 rather than
/// 0.755, leaving almost no margin under [splitMinAspect]. A pinned preference
/// is clamped to what fits, so a window that shrinks — or a foldable that
/// closes — falls back to a single column without losing the stored choice.
/// Unlike MyAnime's version this takes the minimum as a parameter, because
/// MyDevice has four tile shapes with four different minimums.
int listColumnCount({
  required double screenWidth,
  required double screenHeight,
  required double contentWidth,
  required double minItemWidth,
  required int preference,
}) {
  return resolveLayoutColumns(
    allowSplit: canSplitLayout(screenWidth, screenHeight),
    contentWidth: contentWidth,
    minItemWidth: minItemWidth,
    preference: preference,
  );
}

/// Smallest width, in logical pixels, the finance summary's metric column
/// may occupy when it sits beside the asset-distribution chart.
///
/// A `titleLarge` money value such as "¥123,456.78" runs to roughly 150 dp,
/// the card spends 32 on its own padding, and 58 of slack keeps the longest
/// Japanese label ("財務データのあるデバイス") on one line.
const financeSummaryPaneMinWidth = 240.0;

/// Smallest width, in logical pixels, the asset-distribution chart may be
/// given before the summary stops sitting beside it.
///
/// The pie is 2 × (72 radius + 44 centre) = 232 across, its percentage labels
/// sit inside that, and the distribution rows under it carry a colour dot, a
/// category name, an amount and a count; 340 keeps a typical row on one line.
const financeChartMinWidth = 340.0;

/// Purpose: Report whether the finance summary fits beside the chart.
/// Inputs: `contentWidth` — the width the finance page's body gets, in
/// logical pixels, which is the raw window less the page's own padding: the
/// page is pushed above the shell and has no navigation rail beside it.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: A width floor **on top of** [canSplitLayout], not instead of it —
/// the double gate. Callers must test both, and must also test that the
/// chart has data, because an empty chart renders a one-line placeholder that
/// would strand the summary beside a blank half. Unlike MyAnime's statistics
/// page every unfolded foldable clears this floor, because the two blocks
/// here are smaller; that is the rule working, not slack in it.
bool useFinanceSideBySide(double contentWidth) =>
    contentWidth >=
    financeSummaryPaneMinWidth + financeChartMinWidth + listTileGap;

/// Purpose: Return the width of the finance summary's metric column.
/// Inputs: `contentWidth` — the width both blocks share, in logical pixels.
/// Returns: `double`.
/// Side effects: None.
/// Notes: No right-hand cap is needed: above [useFinanceSideBySide] the pane
/// grows at 0.34 of the width while the chart grows at 0.66, so
/// [financeChartMinWidth] is met exactly at the gate and only more
/// comfortably above it. `test/detail_layout_test.dart` asserts that across
/// the whole range rather than defending it with arithmetic that never fires.
double financeSummaryPaneWidth(double contentWidth) =>
    (contentWidth * 0.34).clamp(financeSummaryPaneMinWidth, 360.0);

/// Widest, in logical pixels, a lone form column may grow.
///
/// Material's guidance for a single text field: past this a label and its
/// value stop fitting in one eye sweep, and a 1600 dp window would otherwise
/// stretch the network edit form across its whole width. Width only — a
/// phone never reaches it and is unchanged.
const formMaxWidth = 600.0;

/// Minimum width, in logical pixels, one cell of the emoji picker may occupy.
///
/// A 24 sp emoji is about 30 dp wide; 37 plus the 4 dp gap reproduces the
/// 41 dp pitch a 360 dp phone had at the old fixed eight columns, so phones
/// keep eight while a Material 3 sheet at its 640 dp cap gets twelve.
const emojiCellMinWidth = 37.0;

/// Gap, in logical pixels, between emoji picker cells.
const emojiCellGap = 4.0;

/// Most columns the emoji picker will use, however wide the sheet is.
const emojiMaxColumns = 12;

/// Height, in logical pixels, under which a window counts as compact for a
/// bottom sheet: the compact/medium height boundary.
///
/// Declared separately from [splitMinHeight] although the value is the same,
/// because it answers a different question — how much of a short window a
/// sheet may take — and the two may diverge.
const sheetCompactHeight = 480.0;

/// Fraction of the window a draggable sheet opens to on a compact-height
/// window, and the most any sheet may be dragged to.
///
/// The four pickers are `isScrollControlled` with an autofocused search
/// field; on a 412 dp tall window with a keyboard, a 0.6 sheet leaves about
/// 100 dp of results. Opening near-full is the fix.
const sheetMaxSize = 0.95;

/// Purpose: Return how many columns the emoji picker lays its cells in.
/// Inputs: `sheetWidth` — the width the grid gets, in logical pixels.
/// Returns: `int`, 1 to [emojiMaxColumns].
/// Side effects: None.
/// Notes: [columnCapacity] at [emojiCellMinWidth]. 328 (a 360 dp phone less
/// the sheet's padding) → 8, the count the picker hardcoded before 1.5.4;
/// 412 → 9; 608 → 12.
int emojiGridColumns(double sheetWidth) => columnCapacity(
  sheetWidth,
  minItemWidth: emojiCellMinWidth,
  gap: emojiCellGap,
  maxColumns: emojiMaxColumns,
);

/// Narrowest, in logical pixels, an access-pattern card may be on the guided
/// access-path page.
///
/// The cards stack an icon row, a title of at most two lines and a
/// three-line description, so they read at this width in every language;
/// 150 is what lets a 360 dp phone (328 inside the page padding) keep two
/// cards per row, which halves the scroll through the eight cards.
const accessPatternCardMinWidth = 150.0;

/// Most access-pattern cards on one row: past three the descriptions turn
/// into single words per line on a desktop window.
const accessPatternMaxColumns = 3;

/// Purpose: Return how many access-pattern cards share a row.
/// Inputs: `sectionWidth` — the width the pattern section gets, in logical
/// pixels.
/// Returns: `int`, 1 to [accessPatternMaxColumns].
/// Side effects: None.
/// Notes: [columnCapacity] at [accessPatternCardMinWidth] with the list tile
/// gap. A 360 dp phone → 2 (158 each), a 412 dp phone → 2 (184), the
/// two-pane left pane at the 600 dp floor (268) → 1, a desktop left pane
/// (448) → 2, a phone in landscape (ca. 850) → 3.
int accessPatternColumns(double sectionWidth) => columnCapacity(
  sectionWidth,
  minItemWidth: accessPatternCardMinWidth,
  gap: listTileGap,
  maxColumns: accessPatternMaxColumns,
);

/// Purpose: Return the fraction of the window a draggable sheet opens to.
/// Inputs: `screenHeight` — the window height in logical pixels;
/// `preferred` — the fraction the sheet wants when the window is tall.
/// Returns: `double`, never above [sheetMaxSize].
/// Side effects: None.
/// Notes: Under [sheetCompactHeight] the sheet opens at [sheetMaxSize] so a
/// phone in landscape with the keyboard up still shows a useful list; at and
/// above it the preferred fraction stands. Capped so a caller's
/// `initialChildSize` can never exceed its `maxChildSize`, which would
/// assert.
double sheetInitialSize(double screenHeight, {required double preferred}) {
  final size = screenHeight < sheetCompactHeight ? sheetMaxSize : preferred;
  return size > sheetMaxSize ? sheetMaxSize : size;
}

/// Smallest width, in logical pixels, the settings detail pane may be given.
///
/// The hosted pages are the WebDAV form, the backup page, the privacy policy
/// and the license: a form field with its label, or a paragraph of prose,
/// stops being usable under this.
const settingsRightPaneMinWidth = 280.0;

/// Widest, in logical pixels, a column of prose may grow.
///
/// About 95 Latin or 48 CJK characters of `bodyMedium` per line — the top of
/// a comfortable reading measure. Separate from [formMaxWidth] because prose
/// and form fields answer different questions and may diverge.
const readingMaxWidth = 680.0;

/// Purpose: Return the width of the settings page's fixed left pane.
/// Inputs: `contentWidth` — the width both panes share, in logical pixels,
/// which is [shellContentWidth] rather than the screen width because the
/// settings page is one of the five inside the shell.
/// Returns: `double`.
/// Side effects: None.
/// Notes: Proportional, then clamped, then capped so the detail pane can
/// never be squeezed below [settingsRightPaneMinWidth]. The left pane needs
/// more room than a detail page's does, because it carries full `ListTile`s
/// with trailing dropdowns rather than a card of text. The cap only binds on
/// a hand-resized desktop window and on the narrowest foldables, where it
/// gives up left-pane width rather than let the right pane become unusable.
double settingsLeftPaneWidth(double contentWidth) {
  final preferred = (contentWidth * 0.44).clamp(300.0, 440.0);
  final capped = contentWidth - settingsRightPaneMinWidth;
  if (preferred <= capped) return preferred;
  return capped.clamp(240.0, 440.0);
}

/// Purpose: Add the floating navigation bar's height to a page's padding.
/// Inputs: `context` — inside a shell page; `padding` — the page's own padding.
/// Returns: `EdgeInsets` — [padding] with the bottom inset reported by the
/// enclosing Scaffold added to its bottom.
/// Side effects: None.
/// Notes: With the Expressive bottom bar the shell uses `extendBody`, so pages
/// draw behind the bar and the Scaffold reports the bar's height as
/// `MediaQuery.padding.bottom`. Scroll views with an explicit padding do not
/// apply that inset themselves; passing their padding through here leaves room
/// to scroll the last content above the bar. Elsewhere (classic bar, rail,
/// routes pushed on the root navigator) the inset is just the system's, so
/// this is harmless. A route pushed on the shell's own navigator (a plain
/// `Navigator.of(context).push` from a tab page) lives inside the shell and
/// is covered by the bar too, as is a bottom sheet opened without
/// `useRootNavigator: true`; this app pushes pages and opens sheets on the
/// root navigator, and any page that does not must use this helper.
EdgeInsets navBarAwarePadding(BuildContext context, EdgeInsets padding) =>
    padding.copyWith(
      bottom: padding.bottom + MediaQuery.paddingOf(context).bottom,
    );
