import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/device_storage.dart';
import 'package:my_device/features/devices/widgets/hardware_entries_editor.dart';
import 'package:my_device/features/devices/views/device_edit_page.dart';
import 'package:my_device/features/network/models/network.dart';
import 'package:my_device/features/network/services/network_storage.dart';
import 'package:my_device/features/network/views/tailscale_import_page.dart';
import 'package:my_device/l10n/app_localizations.dart';
import 'support/fake_storage.dart';
import 'support/pump.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'correcting node association moves only membership and rejects stale previews',
    () async {
      const old = NetworkDevice(
        networkId: 'n',
        deviceId: 'wrong',
        hostname: 'node',
        tailscale: {'Device ID': 'node-id'},
      );
      final dir = await seedAppDir(
        'node_reassignment',
        devices: [
          Device(id: 'wrong', name: 'Wrong', category: DeviceCategory.other),
          Device(id: 'right', name: 'Right', category: DeviceCategory.other),
        ],
        networks: [
          Network(id: 'n', name: 'Tailnet', type: NetworkType.tailscale),
        ],
        assignments: [old],
      );
      addTearDown(() => deleteSeededDir(dir));
      await NetworkStorage.setAssignments(
        [
          NetworkDevice.fromJson({...old.toJson(), 'deviceId': 'right'}),
        ],
        expectedAssignments: [old],
      );
      expect(
        (await NetworkStorage.load()).assignments.single.deviceId,
        'right',
      );
      expect((await DeviceStorage.load()).devices.length, 2);
      await expectLater(
        NetworkStorage.setAssignments([old], expectedAssignments: [old]),
        throwsStateError,
      );
      expect(
        (await NetworkStorage.load()).assignments.single.deviceId,
        'right',
      );
    },
  );
  testWidgets(
    'legacy disk record keeps original specs and saves added GPU and display',
    (tester) async {
      final dir = await tester.runAsync(() => seedAppDir('legacy_hardware'));
      addTearDown(() => deleteSeededDir(dir!));
      await tester.runAsync(() async {
        final app = await DeviceStorage.getAppDir();
        await File('${app.path}/device_data.json').writeAsString(
          jsonEncode({
            'devices': [
              {
                'id': 'legacy',
                'name': 'Old PC',
                'category': 'laptop',
                'modifiedAt': '2026-01-01T00:00:00Z',
                'gpu': {
                  'model': 'Original GPU',
                  'architecture': 'Old architecture',
                  'future': 42,
                },
                'screenSize': '14"',
                'screenResolutionW': 1920,
                'screenResolutionH': 1080,
              },
            ],
          }),
        );
      });
      final old = (await tester.runAsync(DeviceStorage.load))!.devices.single;
      expect(old.gpus.length, 1);
      expect(old.displays.length, 1);
      await pumpPageAt(
        tester,
        900,
        1400,
        page: DeviceEditPage(device: old),
        ready: find.text('保存'),
      );
      final gpuEditor = find.byWidgetPredicate(
        (w) => w is HardwareEntriesEditor && w.gpus != null,
      );
      final displayEditor = find.byWidgetPredicate(
        (w) => w is HardwareEntriesEditor && w.displays != null,
      );
      await tester.scrollUntilVisible(
        gpuEditor,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.descendant(of: gpuEditor, matching: find.byTooltip('添加')),
      );
      await tester.pump();
      final gpuWidget = tester.widget<HardwareEntriesEditor>(gpuEditor);
      final gpuField = find.byKey(ValueKey('${gpuWidget.gpus!.last.id}-model'));
      await tester.ensureVisible(gpuField);
      await tester.enterText(
        find.descendant(of: gpuField, matching: find.byType(TextFormField)),
        'Additional GPU',
      );
      await tester.scrollUntilVisible(
        displayEditor,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.descendant(of: displayEditor, matching: find.byTooltip('添加')),
      );
      await tester.pump();
      final displayWidget = tester.widget<HardwareEntriesEditor>(displayEditor);
      final nameField = find.byKey(
        ValueKey('${displayWidget.displays!.last.id}-name'),
      );
      await tester.ensureVisible(nameField);
      await tester.enterText(
        find.descendant(of: nameField, matching: find.byType(TextFormField)),
        'External monitor',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('保存'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      final saved = (await tester.runAsync(DeviceStorage.load))!.devices.single;
      expect(saved.gpus.length, 2);
      expect(saved.displays.length, 2);
      expect(saved.gpus.first.model, 'Original GPU');
      expect(saved.gpus.first.extraJson['future'], 42);
      expect(saved.gpus.last.model, 'Additional GPU');
      expect(saved.displays.first.screenResolutionW, 1920);
      expect(saved.displays.first.screenSize, '14"');
      expect(saved.displays.last.name, 'External monitor');
    },
  );
  testWidgets('typing and preset changes retain two independent GPU drafts', (
    tester,
  ) async {
    var gpus = [
      const GpuInfo(id: 'a', model: 'Intel', kind: 'integrated'),
      const GpuInfo(id: 'b', model: 'Nvidia', kind: 'discrete'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: HardwareEntriesEditor(
                gpus: gpus,
                presets: const [GpuInfo(model: 'AMD', architecture: 'RDNA')],
                onGpusChanged: (v) => setState(() => gpus = v),
              ),
            ),
          ),
        ),
      ),
    );
    final first = find.byKey(const ValueKey('a-model'));
    await tester.enterText(
      find.descendant(of: first, matching: find.byType(TextFormField)),
      'Intel updated',
    );
    await tester.pump();
    expect(gpus.first.model, 'Intel updated');
    expect(gpus.last.model, 'Nvidia');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stable node ID matches renamed CSV and repeat save does not duplicate',
    (tester) async {
      final d = Device(
        id: 'd',
        name: 'Inventory name',
        category: DeviceCategory.laptop,
        os: 'Manual OS',
        gpus: const [GpuInfo(id: 'g', model: 'Manual GPU')],
      );
      final n = Network(id: 'n', name: 'Tailnet', type: NetworkType.tailscale);
      final dir = await tester.runAsync(
        () => seedAppDir(
          'tailscale_preview',
          devices: [d],
          networks: [n],
          assignments: const [
            NetworkDevice(
              networkId: 'n',
              deviceId: 'd',
              hostname: 'old-name',
              tailscale: {'Device ID': 'node'},
            ),
          ],
        ),
      );
      addTearDown(() => deleteSeededDir(dir!));
      final row = {
        'Device name': 'new-name',
        'Device ID': 'node',
        'Tailscale IPs': '100.64.0.2,fd7a:115c:a1e0::2',
        'OS': 'linux',
        'Exit node': 'true',
      };
      Future<void> open() async {
        final net = await tester.runAsync(NetworkStorage.load);
        final devices = await tester.runAsync(DeviceStorage.load);
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpPageAt(
          tester,
          700,
          1000,
          page: TailscaleImportPage(
            networkId: 'n',
            rows: [row],
            devices: devices!,
            assignments: net!.assignments,
          ),
          ready: find.text('new-name'),
        );
      }

      await open();
      expect(find.text('Inventory name'), findsOneWidget);
      expect(find.text('按节点 ID 匹配: Inventory name'), findsOneWidget);
      await tester.tap(find.text('选择要应用的修改'));
      await tester.pumpAndSettle();
      final hostnameChoice = find.byKey(const ValueKey('column-0-Device name'));
      await tester.ensureVisible(hostnameChoice);
      await tester.tap(hostnameChoice);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('保存'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);
      final saved = await tester.runAsync(NetworkStorage.load);
      expect(saved!.assignments.single.hostname, 'old-name');
      expect(saved.assignments.single.ipAddresses.length, 2);
      final inventory = await tester.runAsync(DeviceStorage.load);
      expect(inventory!.devices.single.os, 'Manual OS');
      expect(inventory.devices.single.gpu.model, 'Manual GPU');
      final file = File(
        '${(await tester.runAsync(DeviceStorage.getAppDir))!.path}/network_data.json',
      );
      final before = await tester.runAsync(file.lastModified);
      await open();
      await tester.tap(find.text('选择要应用的修改'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(hostnameChoice);
      await tester.tap(hostnameChoice);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('保存'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await settle(tester);
      expect(
        (await tester.runAsync(NetworkStorage.load))!.assignments.length,
        1,
      );
      expect(await tester.runAsync(file.lastModified), before);
    },
  );
}
