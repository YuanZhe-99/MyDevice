import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/device_storage.dart';
import 'package:my_device/features/devices/services/preset_service.dart';
import 'package:my_device/features/devices/views/device_edit_page.dart';
import 'package:my_device/l10n/app_localizations.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test the device edit page's save behaviour.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The page is pushed from a launcher route (the "open" button) so
/// its `Navigator.pop` after saving has somewhere to return to. Driven in
/// Simplified Chinese (see `pumpPageAt`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_edit_save',
      devices: [
        Device(
          id: 'd1',
          name: '旧设备',
          category: DeviceCategory.laptop,
          brand: 'Acme',
          model: 'M1',
        ),
      ],
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  /// Purpose: Open the edit page from a launcher route.
  /// Inputs: `tester`, optional `device` to edit.
  /// Returns: None.
  /// Side effects: Pumps the app and pushes the page.
  /// Notes: Waits for a field that only exists once the page has loaded.
  Future<void> openPage(WidgetTester tester, {Device? device}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(700, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeviceEditPage(device: device),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await settle(tester);
    await pumpUntil(tester, find.widgetWithText(TextFormField, '型号'));
    await settle(tester);
  }

  /// Purpose: Wait until the page has popped back to the launcher.
  /// Inputs: `tester`.
  /// Returns: None.
  /// Side effects: Pumps frames and yields to the real event loop.
  /// Notes: The save writes files, which completes on the real loop.
  Future<void> waitForPop(WidgetTester tester) async {
    for (var i = 0; i < 300; i++) {
      if (find.text('打开').evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    fail('the edit page never closed after saving');
  }

  testWidgets('a typed brand survives rebuilds and is what gets saved', (
    tester,
  ) async {
    await openPage(tester, device: (await _load(tester)).single);
    final brandField = find
        .descendant(
          of: find.byType(Autocomplete<BrandEntry>),
          matching: find.byType(TextFormField),
        )
        .first;
    await tester.enterText(brandField, 'Umbrella');
    await tester.pump();
    // An unrelated edit rebuilds the whole form, including the brand field.
    await tester.enterText(find.widgetWithText(TextFormField, 'M1'), 'M2');
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('保存'));
    await waitForPop(tester);

    final saved = (await _load(tester)).single;
    expect(saved.brand, 'Umbrella');
    expect(saved.model, 'M2');
  });

  testWidgets('tapping Save twice creates the device once', (tester) async {
    await openPage(tester);
    await tester.enterText(find.widgetWithText(TextFormField, '名称'), '新设备');
    await tester.pump();

    final save = find.text('保存');
    await tester.tap(save);
    await tester.tap(save); // second tap lands while the first save runs
    await waitForPop(tester);

    final devices = await _load(tester);
    expect(devices.where((d) => d.name == '新设备'), hasLength(1));
  });
}

/// Purpose: Read the stored devices.
/// Inputs: `tester`.
/// Returns: The saved device list.
/// Side effects: Reads the seeded storage.
/// Notes: Runs on the real event loop because storage uses `dart:io`.
Future<List<Device>> _load(WidgetTester tester) async =>
    (await tester.runAsync(DeviceStorage.load))!.devices;
