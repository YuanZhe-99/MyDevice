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

/// Logical pixels the device edit page's two-pane left pane reserves around
/// its avatar, so the avatar can take whatever height is left.
///
/// 16 of top padding, 12 between the avatar and its chips, three rows of
/// 32 dp `ActionChip`s at 8 dp run spacing in the worst case (a 260 dp pane
/// puts the Japanese labels one per row) = 112, 16 under them, a 56 dp name
/// field, 12, a 56 dp category field, 22 of slack for a validation error
/// under the name field, and 16 of bottom padding: 318 in all.
const deviceEditLeftPaneFieldBudget = 318.0;

/// Smallest avatar the device edit page's left pane shows.
///
/// The 56 dp the single-column icon section always used; smaller stops being
/// a usable tap target.
const deviceEditAvatarMinSize = 56.0;

/// Largest avatar the device edit page's left pane shows.
///
/// Stops a desktop window turning the picker into a poster.
const deviceEditAvatarMaxSize = 160.0;

/// Purpose: Return the avatar size for the device edit page's left pane.
/// Inputs: `paneWidth`, `paneHeight` — the left pane's size in logical
/// pixels.
/// Returns: `double` — the avatar's diameter.
/// Side effects: None.
/// Notes: This is what makes the left pane non-scrolling: the avatar takes
/// the height left after [deviceEditLeftPaneFieldBudget], clamped between
/// [deviceEditAvatarMinSize] and [deviceEditAvatarMaxSize], so the column
/// fits by construction rather than by hoping. At the 480 dp split floor the
/// pane is 424 tall after the app bar and the avatar comes out at 106; a Z
/// Fold 8 in landscape (648) reaches the 160 ceiling. The width check keeps a
/// narrow pane from being asked for an avatar wider than itself.
double editAvatarSize(double paneWidth, double paneHeight) {
  var size = (paneHeight - deviceEditLeftPaneFieldBudget).clamp(
    deviceEditAvatarMinSize,
    deviceEditAvatarMaxSize,
  );
  final maxWidth = paneWidth - 32;
  if (maxWidth > 0 && size > maxWidth) size = maxWidth;
  return size;
}

/// Purpose: Return the width of an edit form's fixed left pane.
/// Inputs: `totalWidth` — the page body's width, the raw window.
/// Returns: `double`.
/// Side effects: None.
/// Notes: Wider than [detailLeftPaneWidth] because the service, route and
/// dataset edit pages put form fields on the left rather than a card of
/// text: an `OutlineInputBorder` dropdown whose longest localized label is
/// Japanese needs about 268 inside the pane's 32 dp of padding, hence the 300
/// floor. At the 600 dp split minimum the right pane keeps 299, enough for
/// the Docker Compose editor's monospace text at 267.
double editFormLeftPaneWidth(double totalWidth) {
  return (totalWidth * 0.42).clamp(300.0, 480.0);
}

/// Logical pixels the dataset edit page's fixed left pane needs: 16 of
/// padding, the 56 dp emoji tile and name field row, and 16 of padding.
///
/// No arithmetic is needed to make that pane fit — 88 is far under the 424 a
/// pane has at the 480 dp split floor — but it is stated so the test can pin
/// it.
const dataSetEditLeftPaneHeight = 88.0;
