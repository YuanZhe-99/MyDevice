# lib/shared/utils/detail_layout.dart

The two helpers the detail pages need on top of the app-wide rule in
[`adaptive_layout.md`](adaptive_layout.md): a page-named delegate that decides whether the page
splits, and the width of its fixed left pane. Like the module it imports, this one depends on
nothing but `dart:core`, so both helpers are covered by `test/detail_layout_test.dart` without a
widget tree; the rendered pages are covered by `test/device_detail_layout_ui_test.dart` and
`test/network_detail_layout_ui_test.dart`. The reasoning is in
[../../../adaptive-layout.md](../../../adaptive-layout.md#detail-pages-two-panes).

Consumers: `device_detail_page.dart` and `network_detail_page.dart`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`useDetailTwoPane`](#usedetailtwopane) | top-level function | A | Report whether a detail page should use its two-pane layout. |
| [`detailLeftPaneWidth`](#detailleftpanewidth) | top-level function | A | Return the width of a detail page's fixed left pane. |

## Documentation

### `bool useDetailTwoPane(double width, double height)` <a id="usedetailtwopane"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/detail_layout.dart`.
- **Purpose:** Report whether a detail page should use its two-pane layout.
- **Inputs:** `width`, `height` — the viewport size in logical pixels, from `MediaQuery.sizeOf`.
- **Returns:** `bool` — exactly `canSplitLayout(width, height)`.
- **Side effects:** None.
- **Usage:** `_buildBody` in both detail pages.
- **Notes:** A one-line delegate so the pages keep naming the decision in their own vocabulary;
  `test/detail_layout_test.dart` asserts it still agrees with `canSplitLayout` at every named
  viewport, so the delegation cannot silently drift.

### `double detailLeftPaneWidth(double totalWidth)` <a id="detailleftpanewidth"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/detail_layout.dart`.
- **Purpose:** Return the width of a detail page's fixed left pane.
- **Inputs:** `totalWidth` — the page body's width, which is the raw window because the detail
  pages are pushed above the shell and have no rail beside them.
- **Returns:** `double` — `(totalWidth × 0.36).clamp(260, 420)`.
- **Side effects:** None.
- **Usage:** Both detail pages' `LayoutBuilder`, sizing the `SizedBox` around the left pane.
- **Notes:** Proportional because one foldable generation spans roughly 672 to 954 logical pixels
  unfolded; the clamps keep the pane usable at the narrow end (260 at the 600 dp floor, leaving
  339 on the right) and stop it sprawling on a desktop window.
