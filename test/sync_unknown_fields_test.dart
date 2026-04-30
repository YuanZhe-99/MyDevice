import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/shared/services/sync_merge.dart';

String encode(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

void main() {
  test('device models preserve unknown fields during normal saves', () {
    final raw = {
      'schemaVersion': 2,
      'devices': [
        {
          'id': 'device-1',
          'name': 'Laptop',
          'category': 'laptop',
          'futureDeviceField': {'rating': 5},
          'cpu': {'model': 'Future CPU', 'neuralCores': 16},
          'storage': [
            {'capacity': '1 TB', 'wearLevel': 3},
          ],
          'modifiedAt': '2026-04-01T12:00:00.000',
        },
      ],
    };

    final data = DeviceData.fromJson(raw);
    final edited = data.devices.single.copyWith(name: 'Edited Laptop');
    final saved = DeviceData(
      devices: [edited],
      extraJson: data.extraJson,
    ).toJson();
    final device = saved['devices'][0] as Map<String, dynamic>;
    final cpu = device['cpu'] as Map<String, dynamic>;
    final storage =
        (device['storage'] as List<dynamic>)[0] as Map<String, dynamic>;

    expect(saved['schemaVersion'], 2);
    expect(device['futureDeviceField'], {'rating': 5});
    expect(cpu['neuralCores'], 16);
    expect(storage['wearLevel'], 3);
  });

  test(
    'device sync keeps remote unknown fields when local wins by timestamp',
    () {
      final base = encode({
        'futureRoot': 'old',
        'devices': [
          {
            'id': 'device-1',
            'name': 'Laptop',
            'category': 'laptop',
            'cpu': {'model': 'Base CPU'},
            'modifiedAt': '2026-04-01T12:00:00.000',
          },
        ],
      });
      final local = encode({
        'futureRoot': 'old',
        'devices': [
          {
            'id': 'device-1',
            'name': 'Local Name',
            'category': 'laptop',
            'cpu': {'model': 'Local CPU'},
            'modifiedAt': '2026-04-03T12:00:00.000',
          },
        ],
      });
      final remote = encode({
        'futureRoot': 'new',
        'devices': [
          {
            'id': 'device-1',
            'name': 'Remote Name',
            'category': 'laptop',
            'futureDeviceField': 'remote-only',
            'cpu': {'model': 'Remote CPU', 'neuralCores': 16},
            'modifiedAt': '2026-04-02T12:00:00.000',
          },
        ],
      });

      final result = mergeDeviceData(local, remote, base, autoResolve: true);
      final mergedJson = DeviceData(
        devices: result.merged,
        extraJson: result.extraJson,
      ).toJson();
      final device = mergedJson['devices'][0] as Map<String, dynamic>;
      final cpu = device['cpu'] as Map<String, dynamic>;

      expect(mergedJson['futureRoot'], 'new');
      expect(device['name'], 'Local Name');
      expect(device['futureDeviceField'], 'remote-only');
      expect(cpu['model'], 'Local CPU');
      expect(cpu['neuralCores'], 16);
    },
  );

  test('network assignment sync preserves unknown assignment fields', () {
    final base = encode({
      'networks': [
        {
          'id': 'network-1',
          'name': 'LAN',
          'type': 'lan',
          'modifiedAt': '2026-04-01T12:00:00.000',
        },
      ],
      'assignments': [
        {
          'networkId': 'network-1',
          'deviceId': 'device-1',
          'addressMode': 'dhcp',
        },
      ],
    });
    final local = encode({
      'networks': [
        {
          'id': 'network-1',
          'name': 'LAN',
          'type': 'lan',
          'modifiedAt': '2026-04-01T12:00:00.000',
        },
      ],
      'assignments': [
        {
          'networkId': 'network-1',
          'deviceId': 'device-1',
          'addressMode': 'dhcp',
          'hostname': 'local-host',
        },
      ],
    });
    final remote = encode({
      'networks': [
        {
          'id': 'network-1',
          'name': 'LAN',
          'type': 'lan',
          'modifiedAt': '2026-04-01T12:00:00.000',
        },
      ],
      'assignments': [
        {
          'networkId': 'network-1',
          'deviceId': 'device-1',
          'addressMode': 'dhcp',
          'futureAssignmentField': 'remote-only',
        },
      ],
    });

    final result = mergeNetworkData(local, remote, base, autoResolve: true);
    final assignment = result.mergedAssignments.single.toJson();

    expect(assignment['hostname'], 'local-host');
    expect(assignment['futureAssignmentField'], 'remote-only');
  });
}
