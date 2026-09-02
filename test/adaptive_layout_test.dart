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
    test('a Z Fold 8 answers differently in each orientation', () {
      // 4:3 landscape inner panel: 2448 x 1848 px.
      expect(canSplitLayout(933, 704), isTrue); // unfolded, landscape
      expect(canSplitLayout(704, 933), isFalse); // unfolded, portrait
    });

    test('near-square foldables split both ways', () {
      expect(canSplitLayout(750, 832), isTrue); // Z Fold 7 portrait
      expect(canSplitLayout(832, 750), isTrue); // Z Fold 7 landscape
      expect(canSplitLayout(859, 954), isTrue); // Z Fold 8 Ultra portrait
      expect(canSplitLayout(954, 859), isTrue); // Z Fold 8 Ultra landscape
      expect(canSplitLayout(791, 820), isTrue); // Pixel 10 Pro Fold portrait
      expect(canSplitLayout(820, 791), isTrue); // Pixel 10 Pro Fold landscape
    });

    test('older folds still split', () {
      expect(canSplitLayout(659, 791), isTrue); // Z Fold 5
      expect(canSplitLayout(675, 786), isTrue); // Z Fold 6
    });

    test('folded cover screens never split', () {
      expect(canSplitLayout(360, 840), isFalse); // Z Fold 7 / 8 Ultra cover
      expect(canSplitLayout(416, 657), isFalse); // Z Fold 8 cover
      expect(canSplitLayout(411, 923), isFalse); // Pixel 10 Pro Fold cover
    });

    test('short landscape is rejected on height, not width', () {
      expect(canSplitLayout(657, 416), isFalse); // Z Fold 8 cover, landscape
      expect(canSplitLayout(915, 412), isFalse); // ordinary phone, landscape
    });

    test('tablets follow the same rule as the Fold 8', () {
      expect(canSplitLayout(768, 1024), isFalse); // 4:3 tablet portrait
      expect(canSplitLayout(1024, 768), isTrue); // 4:3 tablet landscape
      expect(canSplitLayout(800, 1280), isFalse); // 16:10 tablet portrait
      expect(canSplitLayout(1280, 800), isTrue); // 16:10 tablet landscape
    });

    test('each threshold is exclusive at its boundary', () {
      expect(canSplitLayout(599, 700), isFalse);
      expect(canSplitLayout(600, 700), isTrue);
      expect(canSplitLayout(700, 479), isFalse);
      expect(canSplitLayout(700, 480), isTrue);
      expect(canSplitLayout(810, 1000), isFalse); // aspect 0.81
      expect(canSplitLayout(830, 1000), isTrue); // aspect 0.83
    });

    test('zero or negative height never splits', () {
      expect(canSplitLayout(1200, 0), isFalse);
      expect(canSplitLayout(1200, -100), isFalse);
    });
  });

  group('navigation rail', () {
    test('is a width-only decision', () {
      expect(useNavigationRail(412), isFalse); // Pixel 9 portrait
      expect(useNavigationRail(599), isFalse);
      expect(useNavigationRail(600), isTrue);
      expect(useNavigationRail(915), isTrue); // Pixel 9 landscape: cannot
      // split, but gets a rail
      expect(useNavigationRail(704), isTrue); // Z Fold 8 portrait: same
    });

    test('content width subtracts the rail only when it is shown', () {
      expect(shellContentWidth(412), 412); // Pixel 9
      expect(shellContentWidth(933), 852); // Z Fold 8 landscape
      expect(shellContentWidth(704), 623); // Z Fold 8 portrait
      expect(shellContentWidth(1024), 943); // tablet landscape
      expect(shellContentWidth(0), 0);
    });
  });

  group('column capacity', () {
    test('pays for the gaps between columns, not after each one', () {
      expect(columnCapacity(639, minItemWidth: 320), 1);
      expect(columnCapacity(652, minItemWidth: 320), 2); // 320 + 12 + 320
    });

    test('never below one nor above the cap', () {
      expect(columnCapacity(0, minItemWidth: 320), 1);
      expect(columnCapacity(-50, minItemWidth: 320), 1);
      expect(columnCapacity(4000, minItemWidth: 320), listMaxColumns);
      expect(columnCapacity(4000, minItemWidth: 320, maxColumns: 2), 2);
      expect(columnCapacity(4000, minItemWidth: 320, maxColumns: 0), 1);
    });

    test('a non-positive minimum fills the cap', () {
      expect(columnCapacity(500, minItemWidth: 0), listMaxColumns);
    });

    test('row count rounds up and tolerates bad input', () {
      expect(listRowCount(0, 2), 0);
      expect(listRowCount(5, 2), 3);
      expect(listRowCount(6, 3), 2);
      expect(listRowCount(4, 0), 4);
    });
  });

  group('services overview metric grid', () {
    test('matches the inline rule it replaced', () {
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
    });

    test('at named devices', () {
      expect(serviceMetricColumns(380), 2); // Pixel 9, 412 − 32
      expect(serviceMetricColumns(820), 4); // Z Fold 8 landscape, 852 − 32
      expect(serviceMetricColumns(591), 3); // Z Fold 8 portrait, 623 − 32
      expect(serviceMetricColumns(802), 4); // phone landscape, 915 − 81 − 32
      expect(serviceMetricColumns(0), 1);
    });
  });

  group('topology card actions row', () {
    test('is exclusive at its boundary', () {
      expect(useTopologyActionsRow(679), isFalse);
      expect(useTopologyActionsRow(680), isTrue);
    });

    test('is measured after the rail takes its width', () {
      // Pixel 10 Pro Fold portrait: 791 − 81 rail − 32 page − 32 card.
      expect(useTopologyActionsRow(646), isFalse);
      // Z Fold 8 landscape: 933 − 81 − 32 − 32.
      expect(useTopologyActionsRow(788), isTrue);
    });
  });

  group('finance summary columns', () {
    test('third column arrives at 512', () {
      expect(financeSummaryColumns(511), 2);
      expect(financeSummaryColumns(512), 3);
    });

    test('never drops below two nor above three', () {
      expect(financeSummaryColumns(200), 2); // Z Fold 8 cover, 416 − 64 − ...
      expect(financeSummaryColumns(0), 2);
      expect(financeSummaryColumns(3000), 3);
    });

    test('at named devices (window − 32 page − 32 card)', () {
      expect(financeSummaryColumns(348), 2); // Pixel 9 portrait
      expect(financeSummaryColumns(869), 3); // Z Fold 8 landscape
      expect(financeSummaryColumns(640), 3); // Z Fold 8 portrait
    });
  });

  group('search dialog body height', () {
    test('keeps the preferred height where the window has room', () {
      expect(dialogBodyHeight(704, preferred: 560), 560); // Z Fold 8 landscape
      expect(dialogBodyHeight(704, preferred: 480), 480);
      expect(dialogBodyHeight(915, preferred: 560), 560); // Pixel 9 portrait
    });

    test('shrinks to fit a short window', () {
      expect(dialogBodyHeight(412, preferred: 560), 332); // phone landscape
      expect(dialogBodyHeight(416, preferred: 480), 336); // Fold 8 cover, land
    });

    test('never shrinks below the minimum body', () {
      expect(dialogBodyHeight(300, preferred: 560), dialogMinBodyHeight);
      expect(dialogBodyHeight(0, preferred: 560), dialogMinBodyHeight);
      expect(dialogBodyHeight(704, preferred: 100), dialogMinBodyHeight);
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
    int columnsAt(
      double w,
      double h, {
      required double padding,
      required double minItemWidth,
      int preference = listColumnsAuto,
    }) => listColumnCount(
      screenWidth: w,
      screenHeight: h,
      contentWidth: shellContentWidth(w) - padding,
      minItemWidth: minItemWidth,
      preference: preference,
    );

    test('device tiles at named devices', () {
      const pad = 32.0; // 16 dp card margin on each side
      const min = deviceTileMinWidth;
      expect(
        columnsAt(933, 704, padding: pad, minItemWidth: min),
        2,
      ); // Fold 8 land
      expect(
        columnsAt(704, 933, padding: pad, minItemWidth: min),
        1,
      ); // Fold 8 port
      expect(
        columnsAt(750, 832, padding: pad, minItemWidth: min),
        1,
      ); // Fold 7 port: 637 < 652
      expect(
        columnsAt(832, 750, padding: pad, minItemWidth: min),
        2,
      ); // Fold 7 land
      expect(
        columnsAt(791, 820, padding: pad, minItemWidth: min),
        2,
      ); // Pixel 10 Pro Fold
      expect(columnsAt(659, 791, padding: pad, minItemWidth: min), 1); // Fold 5
      expect(columnsAt(675, 786, padding: pad, minItemWidth: min), 1); // Fold 6
      expect(
        columnsAt(1024, 768, padding: pad, minItemWidth: min),
        2,
      ); // tablet land
      expect(
        columnsAt(768, 1024, padding: pad, minItemWidth: min),
        1,
      ); // tablet port
      expect(
        columnsAt(915, 412, padding: pad, minItemWidth: min),
        1,
      ); // phone land
      expect(
        columnsAt(1600, 900, padding: pad, minItemWidth: min),
        4,
      ); // desktop
    });

    test('network tiles fit three on a tablet in landscape', () {
      const pad = 16.0;
      const min = networkTileMinWidth;
      expect(columnsAt(933, 704, padding: pad, minItemWidth: min), 2);
      expect(
        columnsAt(750, 832, padding: pad, minItemWidth: min),
        2,
      ); // Fold 7 port
      expect(
        columnsAt(1024, 768, padding: pad, minItemWidth: min),
        3,
      ); // 927 >= 924
      expect(columnsAt(659, 791, padding: pad, minItemWidth: min), 1); // Fold 5
      expect(columnsAt(1600, 900, padding: pad, minItemWidth: min), 4);
    });

    test(
      'dataset and service cards share the device minimum at 8 dp padding',
      () {
        const pad = 16.0;
        for (final min in [dataSetTileMinWidth, serviceCardMinWidth]) {
          expect(columnsAt(933, 704, padding: pad, minItemWidth: min), 2);
          expect(
            columnsAt(750, 832, padding: pad, minItemWidth: min),
            2,
          ); // 653 >= 652
          expect(columnsAt(1024, 768, padding: pad, minItemWidth: min), 2);
          expect(columnsAt(1600, 900, padding: pad, minItemWidth: min), 4);
        }
      },
    );

    test('a pinned preference is clamped to what fits, never rejected', () {
      const pad = 32.0;
      const min = deviceTileMinWidth;
      expect(
        columnsAt(1600, 900, padding: pad, minItemWidth: min, preference: 4),
        4,
      );
      expect(
        columnsAt(933, 704, padding: pad, minItemWidth: min, preference: 4),
        2,
      );
      expect(
        columnsAt(412, 915, padding: pad, minItemWidth: min, preference: 4),
        1,
      );
      expect(
        columnsAt(1600, 900, padding: pad, minItemWidth: min, preference: 1),
        1,
      );
    });
  });

  group('emoji picker columns', () {
    test('a phone keeps the eight it always had', () {
      expect(emojiGridColumns(328), 8); // 360 dp phone less sheet padding
    });

    test('grows with the sheet up to twelve', () {
      expect(emojiGridColumns(380), 9); // Pixel 9 less padding
      expect(emojiGridColumns(608), 12); // M3 sheet cap less padding
      expect(emojiGridColumns(3000), emojiMaxColumns);
      expect(emojiGridColumns(0), 1);
    });
  });

  group('draggable sheet initial size', () {
    test('opens near-full on a compact-height window', () {
      expect(sheetInitialSize(412, preferred: 0.6), sheetMaxSize); // phone land
      expect(sheetInitialSize(416, preferred: 0.82), sheetMaxSize); // cover
      expect(sheetInitialSize(479, preferred: 0.6), sheetMaxSize);
    });

    test('keeps the preferred fraction elsewhere', () {
      expect(sheetInitialSize(480, preferred: 0.6), 0.6);
      expect(sheetInitialSize(704, preferred: 0.82), 0.82); // Fold 8 land
      expect(sheetInitialSize(915, preferred: 0.6), 0.6); // Pixel 9
    });

    test('never exceeds the maximum a sheet may be dragged to', () {
      expect(sheetInitialSize(915, preferred: 0.99), sheetMaxSize);
    });
  });
}
