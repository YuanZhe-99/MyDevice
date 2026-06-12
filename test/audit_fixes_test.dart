import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/datasets/models/dataset.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/shared/services/sync_merge.dart';

/// Purpose: Register regression tests for the 2026-06-12 pre-release audit fixes.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: This serves as the test entry point for the file.
void main() {
  Map<String, dynamic> deviceJson(String id, String name, String modifiedAt) =>
      {'id': id, 'name': name, 'category': 'laptop', 'modifiedAt': modifiedAt};

  const t0 = '2026-06-01T00:00:00.000Z';
  const t1 = '2026-06-02T00:00:00.000Z';
  const t2 = '2026-06-03T00:00:00.000Z';

  test('identical concurrent edits merge without a conflict', () {
    final base = jsonEncode({
      'devices': [deviceJson('d1', 'Old', t0), deviceJson('d2', 'B', t0)],
    });
    // d1 received the exact same edit on both devices; d2 changed only
    // locally so the files differ overall.
    final local = jsonEncode({
      'devices': [deviceJson('d1', 'New', t1), deviceJson('d2', 'B local', t1)],
    });
    final remote = jsonEncode({
      'devices': [deviceJson('d1', 'New', t1), deviceJson('d2', 'B', t0)],
    });

    final result = mergeDeviceData(local, remote, base);
    expect(result.hasConflicts, isFalse);
    final names = {for (final d in result.merged) d.id: d.name};
    expect(names['d1'], 'New');
    expect(names['d2'], 'B local');
  });

  test('differing concurrent edits still raise a conflict', () {
    final base = jsonEncode({
      'devices': [deviceJson('d1', 'Old', t0)],
    });
    final local = jsonEncode({
      'devices': [deviceJson('d1', 'Local', t1)],
    });
    final remote = jsonEncode({
      'devices': [deviceJson('d1', 'Remote', t2)],
    });

    final result = mergeDeviceData(local, remote, base);
    expect(result.conflicts, hasLength(1));
  });

  test('new record timestamps default to UTC for cross-timezone LWW', () {
    expect(
      Device(name: 'D', category: DeviceCategory.laptop).modifiedAt.isUtc,
      isTrue,
    );
    expect(DataSet(name: 'S', emoji: '📁').modifiedAt.isUtc, isTrue);
  });
}
