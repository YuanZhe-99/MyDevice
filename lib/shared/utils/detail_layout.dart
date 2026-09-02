import 'adaptive_layout.dart';

/// Purpose: Report whether a detail page should use its two-pane layout.
/// Inputs: `width`, `height` — the viewport size in logical pixels.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Delegates to [canSplitLayout], which is the app-wide "when to split"
/// rule shared with the multi-column lists. The thresholds and the reasoning
/// behind each of them live in `lib/shared/utils/adaptive_layout.dart` and,
/// in prose, in `doc/en-us/adaptive-layout.md`. This wrapper exists so the
/// detail pages keep naming the decision in their own vocabulary, and
/// `test/detail_layout_test.dart` asserts the two still agree.
bool useDetailTwoPane(double width, double height) =>
    canSplitLayout(width, height);

/// Purpose: Return the width of a detail page's fixed left pane.
/// Inputs: `totalWidth` — the page body's width in logical pixels, which for
/// the detail pages is the raw window: they are pushed above the shell and
/// have no navigation rail beside them.
/// Returns: `double`.
/// Side effects: None.
/// Notes: Proportional rather than fixed because one foldable generation
/// spans roughly 672 to 954 logical pixels unfolded; the clamps keep the pane
/// usable at the narrow end and stop it sprawling on a desktop window. At the
/// 600 dp split floor the pane is 260 and the right pane 339.
double detailLeftPaneWidth(double totalWidth) {
  return (totalWidth * 0.36).clamp(260.0, 420.0);
}
