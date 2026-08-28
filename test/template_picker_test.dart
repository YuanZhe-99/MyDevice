import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/app/app.dart';

/// Purpose: Open the "add from template" bottom sheet from the device list.
/// Inputs: `tester`.
/// Returns: `Future<void>`.
/// Side effects: Pumps the app and taps the template FAB.
/// Notes: The FAB is located by its `heroTag` rather than by icon or position,
/// so the test does not break when the FAB row is restyled.
Future<void> openTemplateSheet(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: MyDeviceApp()));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));

  final fab = find.byWidgetPredicate(
    (w) => w is FloatingActionButton && w.heroTag == 'template',
  );
  await pumpUntil(tester, fab);
  await tester.tap(fab);
  // _addFromTemplate awaits PresetService.loadTemplates() (a rootBundle read)
  // before opening the sheet, so wait for the sheet's search field to exist
  // rather than for a fixed number of frames.
  await pumpUntil(tester, find.byType(TextField));
  await settle(tester);
}

/// Purpose: Advance frames until animations and pending work have finished.
/// Inputs: `tester`.
/// Returns: `Future<void>`.
/// Side effects: Pumps frames.
/// Notes: The device list page never reaches a fully idle state, so
/// `pumpAndSettle` times out; a bounded pump loop is used instead.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Purpose: Pump until a finder matches, rather than for a fixed duration.
/// Inputs: `tester`, the `finder` to wait for, and an optional `attempts` cap.
/// Returns: `Future<void>`.
/// Side effects: Pumps frames and yields to the event loop between attempts.
/// Notes: The picker opens only after `PresetService.loadTemplates()` resolves
/// a `rootBundle` read. Waiting a fixed number of frames made this test pass
/// alone but fail under the parallel full-suite run, where that asset load can
/// take longer; waiting on the condition removes the timing dependence.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 40,
}) async {
  for (var i = 0; i < attempts; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('timed out waiting for: $finder');
}

/// Purpose: Type a query into the template picker's search field.
/// Inputs: `tester`, `query`.
/// Returns: `Future<void>`.
/// Side effects: Enters text and settles the frame.
/// Notes: None.
Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField).last, query);
  await settle(tester);
}

void main() {
  testWidgets('a multi-capacity template asks which capacity to use', (
    tester,
  ) async {
    await openTemplateSheet(tester);

    // iPhone 17 Pro Max ships four capacities in the bundled catalog.
    await search(tester, 'iPhone 17 Pro Max');
    await pumpUntil(tester, find.widgetWithText(ListTile, 'iPhone 17 Pro Max'));
    expect(find.widgetWithText(ListTile, 'iPhone 17 Pro Max'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'iPhone 17 Pro Max'));
    await pumpUntil(tester, find.byType(SimpleDialog));

    // The capacity dialog is the whole point: toDevice used to silently take
    // the smallest option, making the authored list decorative.
    expect(find.byType(SimpleDialog), findsOneWidget);
    for (final capacity in ['256 GB', '512 GB', '1 TB', '2 TB']) {
      expect(
        find.textContaining(capacity),
        findsWidgets,
        reason: '$capacity should be offered',
      );
    }
  });

  testWidgets('choosing a capacity closes the sheet and opens the editor', (
    tester,
  ) async {
    await openTemplateSheet(tester);
    await search(tester, 'iPhone 17 Pro Max');
    await pumpUntil(tester, find.widgetWithText(ListTile, 'iPhone 17 Pro Max'));
    await tester.tap(find.widgetWithText(ListTile, 'iPhone 17 Pro Max'));
    await pumpUntil(tester, find.byType(SimpleDialog));

    await tester.tap(find.textContaining('1 TB').first);
    await settle(tester);

    expect(find.byType(SimpleDialog), findsNothing);
    // The picker sheet is gone too - both popped, one choice carried through.
    expect(find.widgetWithText(ListTile, 'iPhone 17 Pro Max'), findsNothing);
  });

  testWidgets('a single-capacity template skips the dialog', (tester) async {
    await openTemplateSheet(tester);

    // Galaxy Z Fold8 has one verified capacity, so it should select in one tap.
    await search(tester, 'Galaxy Z Fold8');
    await pumpUntil(
      tester,
      find.widgetWithText(ListTile, 'Samsung Galaxy Z Fold8'),
    );
    final tile = find.widgetWithText(ListTile, 'Samsung Galaxy Z Fold8');
    expect(tile, findsWidgets);

    await tester.tap(tile.first);
    await settle(tester);

    expect(find.byType(SimpleDialog), findsNothing);
  });

  testWidgets('the picker searches fields beyond the name', (tester) async {
    await openTemplateSheet(tester);

    // Filtering on name alone meant typing a chip shown in the subtitle
    // returned nothing.
    await search(tester, 'Snapdragon');
    await pumpUntil(tester, find.byType(ListTile));
    expect(
      find.byType(ListTile),
      findsWidgets,
      reason: 'a CPU query should match templates whose subtitle shows it',
    );

    await search(tester, 'Exynos 2600');
    expect(find.textContaining('S26'), findsWidgets);
  });
}
