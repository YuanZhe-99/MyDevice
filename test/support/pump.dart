import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/l10n/app_localizations.dart';

/// Purpose: Advance frames until animations and pending work have finished.
/// Inputs: `tester`.
/// Returns: `Future<void>`.
/// Side effects: Pumps frames.
/// Notes: The device list page never reaches a fully idle state, so
/// `pumpAndSettle` times out; a bounded pump loop is used instead. Shared by
/// every widget test that drives a real list page.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Purpose: Pump until a finder matches, rather than for a fixed duration.
/// Inputs: `tester`, the `finder` to wait for, and an optional `attempts` cap.
/// Returns: `Future<void>`.
/// Side effects: Pumps frames and yields to the event loop between attempts.
/// Notes: Pages that load from disk or from `rootBundle` resolve on the real
/// event loop, so each attempt yields through `runAsync` before pumping.
/// Waiting on the condition rather than a frame count removes the timing
/// dependence that made fixed-frame waits flake under the parallel full-suite
/// run.
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

/// Purpose: Pump one real page at a named device's logical-pixel geometry.
/// Inputs: `tester`; `width`, `height` in logical pixels; `page` — the page
/// widget; `ready` — a finder that appears once the page has loaded.
/// Returns: `Future<void>`.
/// Side effects: Pins the test view's size (reset on tear-down) and pumps the
/// page inside a `ProviderScope` and a Simplified-Chinese `MaterialApp`.
/// Notes: Driven in Simplified Chinese on purpose. `flutter_test`'s default
/// font renders every glyph as a full em square, so a Latin label measures
/// roughly two and a half times its real width and overflows rows that fit in
/// production; CJK glyphs really are square, so the test then measures the
/// real layout. The pages load from disk through real `dart:io`, so the first
/// frames run outside the binding's fake-async zone via `pumpUntil`.
Future<void> pumpPageAt(
  WidgetTester tester,
  double width,
  double height, {
  required Widget page,
  required Finder ready,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: page,
      ),
    ),
  );
  await pumpUntil(tester, ready);
  await settle(tester);
}
