import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/views/chip_search_dialog.dart';
import 'package:my_device/features/devices/views/device_search_dialog.dart';
import 'package:my_device/l10n/app_localizations.dart';
import 'package:my_device/shared/utils/adaptive_layout.dart';

/// Purpose: Test that the online search dialogs fit the window they open in.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Before 1.5.0 both dialogs were a fixed 560 / 480 tall, which
/// overflowed a phone or a folded cover screen held in landscape. The dialogs
/// are private classes, so each is opened through its public `show…` entry
/// from a button. Nothing is typed into them: the search never runs, so the
/// test never reaches the network. Driven in Simplified Chinese because
/// `flutter_test`'s default font renders every Latin glyph as a full em
/// square, which would overflow the header row at widths the real fonts fit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    double height, {
    required void Function(BuildContext) open,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // `Dialog` itself lays out over the whole window; the visible card is the
  // `Material` it paints, so that is what the assertions measure.
  final dialogSurface = find
      .descendant(of: find.byType(Dialog), matching: find.byType(Material))
      .first;

  void expectFits(WidgetTester tester, double width, double height) {
    final rect = tester.getRect(dialogSurface);
    expect(rect.height, lessThanOrEqualTo(height - 2 * dialogInsetVertical));
    expect(rect.width, lessThanOrEqualTo(dialogMaxWidth));
    expect(rect.width, lessThanOrEqualTo(width - 2 * dialogInsetHorizontal));
    expect(tester.takeException(), isNull);
  }

  for (final size in const [
    (name: 'Pixel 9 landscape', w: 915.0, h: 412.0),
    (name: 'Z Fold 8 cover landscape', w: 657.0, h: 416.0),
    (name: 'Pixel 9 portrait', w: 412.0, h: 915.0),
    (name: 'Z Fold 8 landscape', w: 933.0, h: 704.0),
    (name: 'tablet landscape', w: 1024.0, h: 768.0),
  ]) {
    testWidgets('the CPU search dialog fits a ${size.name}', (tester) async {
      await pumpAt(
        tester,
        size.w,
        size.h,
        open: (context) => showCpuSearchDialog(context, presets: const []),
      );
      expectFits(tester, size.w, size.h);
    });

    testWidgets('the device search dialog fits a ${size.name}', (tester) async {
      await pumpAt(
        tester,
        size.w,
        size.h,
        open: (context) => showDeviceSearchDialog(context),
      );
      expectFits(tester, size.w, size.h);
    });
  }

  testWidgets('a wide window gets the preferred height, not more', (
    tester,
  ) async {
    await pumpAt(
      tester,
      933,
      704,
      open: (context) => showCpuSearchDialog(context, presets: const []),
    );
    // The dialog is the SizedBox's size plus nothing: 480 was the old fixed
    // height and a Z Fold 8 in landscape still has room for it.
    expect(tester.getRect(dialogSurface).height, 480);
    expect(tester.getRect(dialogSurface).width, dialogMaxWidth);
  });
}
