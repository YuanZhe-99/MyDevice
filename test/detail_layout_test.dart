import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/shared/utils/adaptive_layout.dart';
import 'package:my_device/shared/utils/detail_layout.dart';

/// Purpose: Test the detail-page pane rule and the finance side-by-side gate.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Every viewport is a real device's logical-pixel size, named in a
/// comment. The detail pages and the finance overview are pushed above the
/// shell, so their content width is the raw window less padding — no rail.
void main() {
  group('detail two-pane delegate', () {
    test('agrees with the app-wide split rule everywhere', () {
      const viewports = <List<double>>[
        [933, 704], // Z Fold 8 landscape
        [704, 933], // Z Fold 8 portrait
        [750, 832], // Z Fold 7 portrait
        [411, 914], // Pixel 10 Pro Fold cover
        [915, 412], // phone landscape
        [1024, 768], // tablet landscape
        [768, 1024], // tablet portrait
        [1600, 900], // desktop
        [600, 480], // the split floor
      ];
      for (final v in viewports) {
        expect(
          useDetailTwoPane(v[0], v[1]),
          canSplitLayout(v[0], v[1]),
          reason: 'detail page disagreed at ${v[0]}x${v[1]}',
        );
      }
    });
  });

  group('detail left pane width', () {
    test('is proportional between its clamps', () {
      expect(detailLeftPaneWidth(933), closeTo(335.88, 0.01)); // Z Fold 8
      expect(detailLeftPaneWidth(1024), closeTo(368.64, 0.01)); // tablet
    });

    test('clamps at both ends', () {
      expect(detailLeftPaneWidth(600), 260); // split floor: 216 → 260
      expect(detailLeftPaneWidth(700), 260); // 252 → 260
      expect(detailLeftPaneWidth(1600), 420); // desktop: 576 → 420
    });

    test('leaves the right pane at least 339 at the split floor', () {
      expect(600 - 1 - detailLeftPaneWidth(600), 339);
    });
  });

  group('finance side by side', () {
    test('needs both minimums and a gap', () {
      expect(useFinanceSideBySide(591), isFalse);
      expect(useFinanceSideBySide(592), isTrue); // 240 + 340 + 12
    });

    test('at named devices (window − 32 page padding)', () {
      expect(useFinanceSideBySide(933 - 32), isTrue); // Z Fold 8 landscape
      expect(useFinanceSideBySide(750 - 32), isTrue); // Z Fold 7 portrait
      expect(useFinanceSideBySide(675 - 32), isTrue); // Z Fold 6
      expect(useFinanceSideBySide(659 - 32), isTrue); // Z Fold 5
      expect(useFinanceSideBySide(600 - 32), isFalse); // the split floor
      // The gate is only half the decision: 704 x 933 and 915 x 412 fail
      // canSplitLayout before the width is ever asked.
      expect(canSplitLayout(704, 933), isFalse);
      expect(canSplitLayout(915, 412), isFalse);
    });

    test('the summary pane never starves the chart', () {
      for (var w = 592.0; w <= 2000; w += 1) {
        final pane = financeSummaryPaneWidth(w);
        expect(pane, greaterThanOrEqualTo(financeSummaryPaneMinWidth));
        expect(pane, lessThanOrEqualTo(360));
        expect(
          w - pane - listTileGap,
          greaterThanOrEqualTo(financeChartMinWidth),
          reason: 'chart starved at $w',
        );
      }
    });

    test('pane width at named devices', () {
      expect(financeSummaryPaneWidth(901), closeTo(306.34, 0.01)); // Fold 8
      expect(financeSummaryPaneWidth(627), closeTo(240, 0.01)); // Fold 5 floor
      expect(financeSummaryPaneWidth(1568), 360); // desktop cap
    });
  });
}
