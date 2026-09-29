import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/shared/utils/adaptive_layout.dart';

/// Purpose: Test the pure adaptive-layout policy at real device geometries.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Every viewport below is a real device's logical-pixel size, with the
/// device named in a comment, so a regression names the device it would break
/// rather than a bare number. The module imports nothing but `dart:core`, so
/// these run without a widget tree.
void main() {
  group('split decision', () {
    // (width, height, splits?, why) - every real device/orientation and both
    // sides of each threshold from the individual cases this table replaced.
    const cases = <(double, double, bool, String)>[
      // Z Fold 8 answers differently in each orientation (4:3 inner panel).
      (933, 704, true, 'Z Fold 8 unfolded, landscape'),
      (704, 933, false, 'Z Fold 8 unfolded, portrait'),
      // Near-square foldables split both ways.
      (750, 832, true, 'Z Fold 7 portrait'),
      (832, 750, true, 'Z Fold 7 landscape'),
      (859, 954, true, 'Z Fold 8 Ultra portrait'),
      (954, 859, true, 'Z Fold 8 Ultra landscape'),
      (791, 820, true, 'Pixel 10 Pro Fold portrait'),
      (820, 791, true, 'Pixel 10 Pro Fold landscape'),
      // Older folds still split.
      (659, 791, true, 'Z Fold 5'),
      (675, 786, true, 'Z Fold 6'),
      // Folded cover screens never split.
      (360, 840, false, 'Z Fold 7 / 8 Ultra cover'),
      (416, 657, false, 'Z Fold 8 cover'),
      (411, 923, false, 'Pixel 10 Pro Fold cover'),
      // Short landscape is rejected on height, not width.
      (657, 416, false, 'Z Fold 8 cover, landscape'),
      (915, 412, false, 'ordinary phone, landscape'),
      // Tablets follow the same rule as the Fold 8.
      (768, 1024, false, '4:3 tablet portrait'),
      (1024, 768, true, '4:3 tablet landscape'),
      (800, 1280, false, '16:10 tablet portrait'),
      (1280, 800, true, '16:10 tablet landscape'),
      // Each threshold is exclusive at its boundary.
      (599, 700, false, 'width just under 600'),
      (600, 700, true, 'width exactly 600'),
      (700, 479, false, 'height just under 480'),
      (700, 480, true, 'height exactly 480'),
      (810, 1000, false, 'aspect 0.81'),
      (830, 1000, true, 'aspect 0.83'),
      // Zero or negative height never splits.
      (1200, 0, false, 'zero height'),
      (1200, -100, false, 'negative height'),
    ];
    test('every named viewport and boundary', () {
      for (final (w, h, expected, why) in cases) {
        expect(canSplitLayout(w, h), expected, reason: '$why ($w x $h)');
      }
    });
  });

  group('navigation rail and content width', () {
    test('rail is width-only; content width subtracts it only when shown', () {
      const rail = <(double, bool, String)>[
        (412, false, 'Pixel 9 portrait'),
        (599, false, 'just under 600'),
        (600, true, 'exactly 600'),
        (915, true, 'Pixel 9 landscape: cannot split, but gets a rail'),
        (704, true, 'Z Fold 8 portrait: same'),
      ];
      for (final (w, expected, why) in rail) {
        expect(useNavigationRail(w), expected, reason: '$why ($w)');
      }
      const content = <(double, double, String)>[
        (412, 412, 'Pixel 9'),
        (933, 852, 'Z Fold 8 landscape'),
        (704, 623, 'Z Fold 8 portrait'),
        (1024, 943, 'tablet landscape'),
        (0, 0, 'zero width'),
      ];
      for (final (w, expected, why) in content) {
        expect(shellContentWidth(w), expected, reason: '$why ($w)');
      }
    });
  });

  group('column capacity', () {
    test('capacity, clamps, and row count', () {
      // (width, minItemWidth, maxColumns or null, expected, why)
      const capacity = <(double, double, int?, int, String)>[
        (639, 320, null, 1, 'pays for gaps: 639 fits one'),
        (652, 320, null, 2, '320 + 12 + 320'),
        (0, 320, null, 1, 'zero width'),
        (-50, 320, null, 1, 'negative width'),
        (4000, 320, null, listMaxColumns, 'capped at listMaxColumns'),
        (4000, 320, 2, 2, 'explicit cap of 2'),
        (4000, 320, 0, 1, 'cap of 0 still one'),
        (500, 0, null, listMaxColumns, 'non-positive minimum fills the cap'),
      ];
      for (final (w, min, cap, expected, why) in capacity) {
        final actual = cap == null
            ? columnCapacity(w, minItemWidth: min)
            : columnCapacity(w, minItemWidth: min, maxColumns: cap);
        expect(actual, expected, reason: '$why ($w, $min, $cap)');
      }
      // (items, columns, rows)
      const rows = <(int, int, int)>[
        (0, 2, 0),
        (5, 2, 3),
        (6, 3, 2),
        (4, 0, 4),
      ];
      for (final (items, cols, expected) in rows) {
        expect(listRowCount(items, cols), expected, reason: '$items / $cols');
      }
    });
  });

  group('services overview metric grid', () {
    test('matches the replaced inline rule and named devices', () {
      // The old rule was ((w + 12) / 162).floor().clamp(1, 4).
      for (final w in [
        200.0,
        311.0,
        312.0,
        473.0,
        474.0,
        635.0,
        636.0,
        900.0,
      ]) {
        final old = ((w + 12) / 162).floor().clamp(1, 4);
        expect(serviceMetricColumns(w), old, reason: 'at $w');
      }
      const named = <(double, int, String)>[
        (380, 2, 'Pixel 9, 412 - 32'),
        (820, 4, 'Z Fold 8 landscape, 852 - 32'),
        (591, 3, 'Z Fold 8 portrait, 623 - 32'),
        (802, 4, 'phone landscape, 915 - 81 - 32'),
        (0, 1, 'zero width'),
      ];
      for (final (w, expected, why) in named) {
        expect(serviceMetricColumns(w), expected, reason: '$why ($w)');
      }
    });
  });

  group('access pattern cards', () {
    test('phones two, wide sections three, two-pane left pane one or two', () {
      const cases = <(double, int, String)>[
        (328, 2, '360 dp phone, 360 - 32'),
        (380, 2, 'Pixel 9, 412 - 32'),
        (672, 3, 'Z Fold 8 portrait, 704 - 32'),
        (883, 3, 'Pixel 9 landscape, 915 - 32'),
        (0, 1, 'zero width'),
        (268, 1, 'left pane at the 600 x 480 split floor'),
        (360, 2, 'left pane, Z Fold 8 landscape, 933 wide'),
        (448, 2, 'left pane, desktop, capped at 480'),
      ];
      for (final (w, expected, why) in cases) {
        expect(accessPatternColumns(w), expected, reason: '$why ($w)');
      }
    });
  });

  group('topology card actions row', () {
    test('exclusive at its boundary and measured after the rail', () {
      const cases = <(double, bool, String)>[
        (679, false, 'just under 680'),
        (680, true, 'exactly 680'),
        (646, false, 'Pixel 10 Pro Fold portrait: 791 - 81 - 32 - 32'),
        (788, true, 'Z Fold 8 landscape: 933 - 81 - 32 - 32'),
      ];
      for (final (w, expected, why) in cases) {
        expect(useTopologyActionsRow(w), expected, reason: '$why ($w)');
      }
    });
  });

  group('finance summary columns', () {
    test('third column at 512, two to three, named devices', () {
      const cases = <(double, int, String)>[
        (511, 2, 'just under 512'),
        (512, 3, 'third column arrives'),
        (200, 2, 'Z Fold 8 cover'),
        (0, 2, 'zero width'),
        (3000, 3, 'never above three'),
        (348, 2, 'Pixel 9 portrait (window - 32 page - 32 card)'),
        (869, 3, 'Z Fold 8 landscape'),
        (640, 3, 'Z Fold 8 portrait'),
      ];
      for (final (w, expected, why) in cases) {
        expect(financeSummaryColumns(w), expected, reason: '$why ($w)');
      }
    });
  });

  group('search dialog body height', () {
    test('preferred where there is room, shrinks, never below minimum', () {
      // (window height, preferred, expected, why)
      const cases = <(double, double, double, String)>[
        (704, 560, 560, 'Z Fold 8 landscape'),
        (704, 480, 480, 'Z Fold 8 landscape, smaller preferred'),
        (915, 560, 560, 'Pixel 9 portrait'),
        (412, 560, 332, 'phone landscape'),
        (416, 480, 336, 'Fold 8 cover, landscape'),
        (300, 560, dialogMinBodyHeight, 'very short window'),
        (0, 560, dialogMinBodyHeight, 'zero height'),
        (704, 100, dialogMinBodyHeight, 'tiny preferred'),
      ];
      for (final (h, preferred, expected, why) in cases) {
        expect(
          dialogBodyHeight(h, preferred: preferred),
          expected,
          reason: '$why ($h, $preferred)',
        );
      }
    });

    test('the dialog always clears the window at every named height', () {
      for (final h in [412.0, 416.0, 480.0, 657.0, 704.0, 750.0, 915.0]) {
        final body = dialogBodyHeight(h, preferred: 560);
        expect(
          body + 2 * dialogInsetVertical <= h || body == dialogMinBodyHeight,
          isTrue,
          reason: 'at $h',
        );
      }
    });
  });

  group('list column count', () {
    // (width, height, padding, minItemWidth, preference, expected, why)
    const auto = listColumnsAuto;
    const cases = <(double, double, double, double, int, int, String)>[
      // Device tiles at named devices (16 dp card margin on each side).
      (933, 704, 32, deviceTileMinWidth, auto, 2, 'device: Fold 8 land'),
      (704, 933, 32, deviceTileMinWidth, auto, 1, 'device: Fold 8 port'),
      (750, 832, 32, deviceTileMinWidth, auto, 1, 'device: Fold 7 port'),
      (832, 750, 32, deviceTileMinWidth, auto, 2, 'device: Fold 7 land'),
      (791, 820, 32, deviceTileMinWidth, auto, 2, 'device: Pixel 10 Pro Fold'),
      (659, 791, 32, deviceTileMinWidth, auto, 1, 'device: Fold 5'),
      (675, 786, 32, deviceTileMinWidth, auto, 1, 'device: Fold 6'),
      (1024, 768, 32, deviceTileMinWidth, auto, 2, 'device: tablet land'),
      (768, 1024, 32, deviceTileMinWidth, auto, 1, 'device: tablet port'),
      (915, 412, 32, deviceTileMinWidth, auto, 1, 'device: phone land'),
      (1600, 900, 32, deviceTileMinWidth, auto, 4, 'device: desktop'),
      // Network tiles fit three on a tablet in landscape.
      (933, 704, 16, networkTileMinWidth, auto, 2, 'network: Fold 8 land'),
      (750, 832, 16, networkTileMinWidth, auto, 2, 'network: Fold 7 port'),
      (
        1024,
        768,
        16,
        networkTileMinWidth,
        auto,
        3,
        'network: tablet, 927>=924',
      ),
      (659, 791, 16, networkTileMinWidth, auto, 1, 'network: Fold 5'),
      (1600, 900, 16, networkTileMinWidth, auto, 4, 'network: desktop'),
      // Dataset and service cards share the device minimum at 8 dp padding.
      (933, 704, 16, dataSetTileMinWidth, auto, 2, 'dataset: Fold 8 land'),
      (750, 832, 16, dataSetTileMinWidth, auto, 2, 'dataset: Fold 7 port'),
      (1024, 768, 16, dataSetTileMinWidth, auto, 2, 'dataset: tablet land'),
      (1600, 900, 16, dataSetTileMinWidth, auto, 4, 'dataset: desktop'),
      (933, 704, 16, serviceCardMinWidth, auto, 2, 'service: Fold 8 land'),
      (750, 832, 16, serviceCardMinWidth, auto, 2, 'service: Fold 7 port'),
      (1024, 768, 16, serviceCardMinWidth, auto, 2, 'service: tablet land'),
      (1600, 900, 16, serviceCardMinWidth, auto, 4, 'service: desktop'),
      // A pinned preference is clamped to what fits, never rejected.
      (1600, 900, 32, deviceTileMinWidth, 4, 4, 'pinned 4: desktop'),
      (933, 704, 32, deviceTileMinWidth, 4, 2, 'pinned 4: Fold 8 land'),
      (412, 915, 32, deviceTileMinWidth, 4, 1, 'pinned 4: phone'),
      (1600, 900, 32, deviceTileMinWidth, 1, 1, 'pinned 1: desktop'),
    ];
    test('every tile family and pinned preference', () {
      for (final (w, h, pad, min, pref, expected, why) in cases) {
        final actual = listColumnCount(
          screenWidth: w,
          screenHeight: h,
          contentWidth: shellContentWidth(w) - pad,
          minItemWidth: min,
          preference: pref,
        );
        expect(actual, expected, reason: '$why ($w x $h)');
      }
    });
  });

  group('emoji picker columns', () {
    test('phone keeps eight, grows to twelve', () {
      const cases = <(double, int, String)>[
        (328, 8, '360 dp phone less sheet padding'),
        (380, 9, 'Pixel 9 less padding'),
        (608, 12, 'M3 sheet cap less padding'),
        (3000, emojiMaxColumns, 'capped'),
        (0, 1, 'zero width'),
      ];
      for (final (w, expected, why) in cases) {
        expect(emojiGridColumns(w), expected, reason: '$why ($w)');
      }
    });
  });

  group('draggable sheet initial size', () {
    test('near-full when short, preferred elsewhere, capped at maximum', () {
      // (window height, preferred, expected, why)
      const cases = <(double, double, double, String)>[
        (412, 0.6, sheetMaxSize, 'phone landscape'),
        (416, 0.82, sheetMaxSize, 'cover'),
        (479, 0.6, sheetMaxSize, 'just under 480'),
        (480, 0.6, 0.6, 'exactly 480'),
        (704, 0.82, 0.82, 'Fold 8 landscape'),
        (915, 0.6, 0.6, 'Pixel 9'),
        (915, 0.99, sheetMaxSize, 'never exceeds the maximum'),
      ];
      for (final (h, preferred, expected, why) in cases) {
        expect(
          sheetInitialSize(h, preferred: preferred),
          expected,
          reason: '$why ($h, $preferred)',
        );
      }
    });
  });

  group('settings left pane', () {
    test('proportional, clamped, and yields to the detail pane', () {
      expect(settingsLeftPaneWidth(852), closeTo(374.88, 0.01)); // Fold 8 land
      expect(settingsLeftPaneWidth(943), closeTo(414.92, 0.01)); // tablet land
      // (content width, expected, why)
      const exact = <(double, double, String)>[
        (669, 300, 'Fold 7 portrait: 294 -> 300'),
        (1519, 440, 'desktop: 668 -> 440'),
        (578, 298, 'Z Fold 5 portrait: 659 - 81; 300 would leave 278 < 280'),
        (500, 240, 'the cap own floor'),
      ];
      for (final (w, expected, why) in exact) {
        expect(settingsLeftPaneWidth(w), expected, reason: '$why ($w)');
      }
      expect(578 - settingsLeftPaneWidth(578), settingsRightPaneMinWidth);
    });

    test('the detail pane clears its minimum from the split floor up', () {
      // From 520 up: at the 519 the split floor leaves after the rail the
      // cap's own 240 floor wins and the detail pane is 279, one short.
      for (var w = 520.0; w <= 2000; w += 1) {
        expect(
          w - settingsLeftPaneWidth(w),
          greaterThanOrEqualTo(settingsRightPaneMinWidth - 1e-9),
          reason: 'detail pane starved at $w',
        );
      }
    });
  });
}
