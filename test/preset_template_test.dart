import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/preset_service.dart';

/// Purpose: Read a bundled preset asset straight from disk.
/// Inputs: `name` — the file name under `assets/presets/`.
/// Returns: The decoded JSON.
/// Side effects: Reads from the local file system.
/// Notes: Reads the file rather than `rootBundle` so these stay plain unit
/// tests. The asset is the same bytes either way.
dynamic preset(String name) =>
    jsonDecode(File('assets/presets/$name').readAsStringSync());

void main() {
  late List<Map<String, dynamic>> raw;
  late List<DeviceTemplate> templates;

  setUpAll(() {
    raw = (preset('device_templates.json') as List).cast<Map<String, dynamic>>();
    templates = raw.map(DeviceTemplate.fromJson).toList();
  });

  group('device_templates.json', () {
    test('every entry parses into a DeviceTemplate', () {
      // fromJson casts `name` and `category` without a null guard, so a
      // malformed entry is a crash in the app, not a warning.
      expect(templates, hasLength(raw.length));
      expect(templates.every((t) => t.name.isNotEmpty), isTrue);
    });

    test('no category silently degrades to other', () {
      // DeviceCategory.fromJson falls back to `other` for an unknown string,
      // so a typo would never throw - it would just show the wrong icon.
      for (final entry in raw) {
        final category = entry['category'] as String;
        if (category == 'other') continue;
        expect(
          DeviceCategory.fromJson(category),
          isNot(DeviceCategory.other),
          reason: '"${entry['name']}" has unknown category "$category"',
        );
      }
    });

    test('names are unique and sorted', () {
      final names = templates.map((t) => t.name).toList();
      expect(names.toSet(), hasLength(names.length), reason: 'duplicate names');

      final sorted = [...names]
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      expect(
        names,
        sorted,
        reason: 'run: dart run tool/sort_templates.dart',
      );
    });
  });

  group('multi-capacity storage', () {
    test('templates offering several capacities keep all of them', () {
      final multi = templates.where((t) => t.storage.length > 1).toList();
      expect(
        multi,
        isNotEmpty,
        reason: 'the catalog should still contain multi-capacity templates',
      );
      for (final t in multi) {
        expect(t.storage.every((s) => s.capacity != null), isTrue);
      }
    });

    test('toDevice honours the chosen capacity', () {
      // toDevice used to hardcode storage.first, so a MacBook Pro listing
      // 512GB through 4TB always produced 512GB with no way to pick.
      final t = templates.firstWhere((t) => t.storage.length > 1);
      for (var i = 0; i < t.storage.length; i++) {
        final device = t.toDevice(storageIndex: i);
        expect(device.storage.single.capacity, t.storage[i].capacity);
      }
    });

    test('an out-of-range index is clamped rather than thrown', () {
      final t = templates.firstWhere((t) => t.storage.length > 1);
      expect(t.toDevice(storageIndex: 999).storage.single.capacity,
          t.storage.last.capacity);
      expect(t.toDevice(storageIndex: -5).storage.single.capacity,
          t.storage.first.capacity);
    });

    test('a template with no storage yields none', () {
      final none = templates.where((t) => t.storage.isEmpty);
      for (final t in none.take(3)) {
        expect(t.toDevice().storage, isEmpty);
      }
    });
  });

  group('object-form cpu', () {
    test('detail survives parsing', () {
      // The VPS templates author architecture and core counts inside `cpu`.
      // _asString kept only ['model'], discarding the rest at parse time.
      final withDetail = templates.where((t) => t.cpuDetail != null).toList();
      expect(withDetail, isNotEmpty, reason: 'VPS templates author object cpu');
      expect(
        withDetail.any((t) => t.cpuDetail!.performanceCores != null),
        isTrue,
      );
    });

    test('detail reaches the created Device', () {
      final t = templates.firstWhere(
        (t) => t.cpuDetail?.performanceCores != null,
      );
      final device = t.toDevice(cpuPresets: const [], gpuPresets: const []);
      expect(device.cpu.model, t.cpu);
      expect(device.cpu.performanceCores, t.cpuDetail!.performanceCores);
    });

    test('a preset match still fills in a plain string cpu', () {
      final t = templates.firstWhere(
        (t) => t.cpuDetail == null && t.cpu != null,
      );
      final presets = [
        CpuInfo(model: t.cpu, architecture: 'test-arch', threads: 99),
      ];
      final device = t.toDevice(cpuPresets: presets);
      expect(device.cpu.architecture, 'test-arch');
      expect(device.cpu.threads, 99);
    });
  });

  group('other preset assets', () {
    test('cpus, gpus and brands have no duplicates', () {
      for (final (file, key, field) in [
        ('cpus.json', 'cpus', 'model'),
        ('gpus.json', 'gpus', 'model'),
        ('brands.json', 'brands', 'name'),
      ]) {
        final list = (preset(file) as Map<String, dynamic>)[key] as List;
        final names = list
            .map((e) => (e as Map<String, dynamic>)[field] as String)
            .map((s) => s.toLowerCase())
            .toList();
        expect(
          names.toSet(),
          hasLength(names.length),
          reason: 'duplicate $field in $file',
        );
      }
    });
  });
}
