import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_storage.dart';
import 'package:my_device/features/services/services/service_template_service.dart';
import 'package:my_device/features/services/views/service_edit_page.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test what the service edit page hands back to its caller.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The guided access-path page relies on both halves: a template
/// prefills a new service, and saving pops a `ServiceEditOutcome` carrying
/// the saved node so the caller can select it. Driven in Simplified Chinese.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_service_edit_outcome',
      devices: [
        Device(id: 'home', name: '主机', category: DeviceCategory.desktop),
        Device(id: 'vps', name: '云主机', category: DeviceCategory.vps),
      ],
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  testWidgets('a template prefills a new service and save returns it', (
    tester,
  ) async {
    final frp = ServiceTemplateService.loadTemplates().singleWhere(
      (template) => template.id == 'frp',
    );
    ServiceEditOutcome? outcome;
    var popped = false;
    await pumpPageAt(
      tester,
      412,
      915,
      page: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                outcome = await Navigator.of(context).push<ServiceEditOutcome>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ServiceEditPage(deviceId: 'vps', template: frp),
                  ),
                );
                popped = true;
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
      ready: find.text('打开'),
    );
    await tester.tap(find.text('打开'));
    await pumpUntil(tester, find.byType(TextFormField));
    await settle(tester);

    expect(find.widgetWithText(TextFormField, 'FRP'), findsOneWidget);
    expect(find.text('云主机'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.save).first);
    await pumpUntil(tester, find.text('打开'));
    for (var i = 0; i < 20 && !popped; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(outcome, isNotNull);
    expect(outcome!.deleted, isFalse);
    final saved = outcome!.saved!;
    expect(saved.name, 'FRP');
    expect(saved.deviceId, 'vps');
    expect(saved.templateId, 'frp');
    expect(saved.kind, ServiceKind.tunnel);
    expect(saved.endpoints.single.port, 7000);

    final stored = await tester.runAsync(ServiceStorage.load);
    expect(stored!.services.single.id, saved.id);
  });
}
