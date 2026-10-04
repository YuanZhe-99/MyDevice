import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/network/models/network.dart';
import 'package:my_device/features/network/services/tailscale_csv.dart';

void main() {
  test(
    'automatic matching prefers IDs, normalizes separators and exposes ambiguity',
    () {
      final devices = [
        Device(id: 'a', name: 'Intel NUC', category: DeviceCategory.desktop),
        Device(id: 'b', name: 'intel-nuc', category: DeviceCategory.desktop),
      ];
      final row = {'Device ID': 'node', 'Device name': 'intel_nuc'};
      expect(TailscaleCsv.match(row, devices, []).ids, ['a', 'b']);
      expect(
        TailscaleCsv.match(row, devices, [
          const NetworkDevice(
            networkId: 'n',
            deviceId: 'b',
            tailscale: {'Device ID': 'node'},
          ),
        ]).ids,
        ['b'],
      );
      expect(
        TailscaleCsv.match(
          {'Device ID': 'new', 'Device name': 'Intel NUC'},
          devices,
          [],
        ).ids,
        ['a'],
      );
    },
  );

  test('unselected CSV changes keep existing effective and raw fields', () {
    const old = NetworkDevice(
      networkId: 'n',
      deviceId: 'd',
      hostname: 'keep',
      ipAddress: '100.64.0.1',
      isExitNode: true,
      tailscale: {'Device name': 'keep', 'Domain': 'keep.ts.net'},
    );
    final updated = TailscaleCsv.assignment(
      {
        'Device ID': 'node',
        'Device name': 'changed',
        'Tailscale IPs': '100.64.0.2',
        'Exit node': 'false',
        'Domain': 'changed.ts.net',
      },
      'n',
      'd',
      existing: old,
      selectedColumns: {'Tailscale IPs'},
    );
    expect(updated.hostname, 'keep');
    expect(updated.isExitNode, true);
    expect(updated.ipAddress, '100.64.0.2');
    expect(updated.tailscale['Domain'], 'keep.ts.net');
    expect(updated.tailscale['Device ID'], 'node');
  });
  test('legacy specs migrate deterministically and explicit empties win', () {
    final json = {
      'id': 'device',
      'name': 'PC',
      'category': 'desktop',
      'modifiedAt': '2026-10-04T00:00:00Z',
      'gpu': {'model': 'Integrated', 'future': 42},
      'screenSize': '14"',
      'screenResolutionW': 1920,
      'screenResolutionH': 1080,
    };
    final a = Device.fromJson(json);
    final b = Device.fromJson(json);
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    expect(a.gpus.single.extraJson['future'], 42);
    expect(a.displays.single.ppi, closeTo(157.35, 0.1));
    final empty = Device.fromJson({...json, 'gpus': [], 'displays': []});
    expect(empty.gpu.isEmpty, isTrue);
    expect(empty.screenSize, isNull);
    expect(Device.fromJson(empty.toJson()).gpus, isEmpty);
  });

  test('reordered hardware merges unknown keys by stable identity', () {
    final old = Device(
      id: 'd',
      name: 'PC',
      category: DeviceCategory.desktop,
      gpus: const [
        GpuInfo(id: 'a', model: 'Intel', extraJson: {'future': 1}),
        GpuInfo(id: 'b', model: 'Nvidia', extraJson: {'future': 2}),
      ],
      displays: [
        DisplayInfo(id: 'inner', extraJson: {'future': 'in'}),
        DisplayInfo(id: 'outer', extraJson: {'future': 'out'}),
      ],
    );
    final edited = old.copyWith(
      gpus: const [GpuInfo(id: 'b', model: 'Nvidia')],
      displays: [DisplayInfo(id: 'outer')],
    );
    final merged = edited.mergeUnknownFieldsFrom(old);
    expect(merged.gpus.single.extraJson['future'], 2);
    expect(merged.displays.single.extraJson['future'], 'out');
    expect(Device.fromJson(merged.toJson()).gpu.model, 'Nvidia');
  });

  test('CSV accepts BOM CRLF escaped quotes double-stack and trailing empty', () {
    const csv =
        '\uFEFF"Device name","Device ID","Tailscale IPs","Exit node","Last seen","Future"\r\n'
        '"PC, ""work""","node1","100.64.0.1,fd7a:115c:a1e0::1","true",,""\r\n';
    final rows = TailscaleCsv.parse(csv);
    expect(rows.single['Device name'], 'PC, "work"');
    expect(rows.single['Last seen'], '');
    expect(rows.single['Future'], '');
    final a = TailscaleCsv.assignment(rows.single, 'n', 'd');
    expect(a.ipAddresses, ['100.64.0.1', 'fd7a:115c:a1e0::1']);
    expect(a.ipAddress, '100.64.0.1');
    expect(a.isExitNode, isTrue);
    expect(
      jsonEncode(
        TailscaleCsv.assignment(rows.single, 'n', 'd', existing: a).toJson(),
      ),
      jsonEncode(a.toJson()),
    );
  });

  test('CSV rejects malformed input and preserves unspecified exit/config', () {
    for (final csv in [
      'Device name,Device ID,Tailscale IPs\nx,id',
      'Device name,Device ID,Tailscale IPs\n"x,id,100.64.0.1',
      'Device name,Device ID,Tailscale IPs\nx,id,100.64.0.1\ny,id,100.64.0.2',
    ]) {
      expect(() => TailscaleCsv.parse(csv), throwsFormatException);
    }
    const original = NetworkDevice(
      networkId: 'n',
      deviceId: 'd',
      isExitNode: true,
      configFormat: 'toml',
      configText: '# comment\nkey = "value"\n',
      extraJson: {'future': 1},
    );
    final a = TailscaleCsv.assignment(
      {
        'Device name': 'x',
        'Device ID': 'node',
        'Tailscale IPs': 'fd7a:115c:a1e0::1',
        'Exit node': '',
      },
      'n',
      'd',
      existing: original,
    );
    expect(a.isExitNode, isTrue);
    expect(a.configText, original.configText);
    expect(NetworkDevice.fromJson(a.toJson()).extraJson['future'], 1);
    expect(a.ipAddress, 'fd7a:115c:a1e0::1');
  });
}
