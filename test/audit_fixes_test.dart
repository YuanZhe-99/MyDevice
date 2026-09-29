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

  // Concurrent edits of the same record: identical content merges silently,
  // differing content is a true conflict. d2 changes only locally so the
  // identical-edit case still has files that differ overall.
  final concurrentEdits =
      <
        ({
          String name,
          String local,
          String remote,
          bool conflict,
          Map<String, String>? merged,
        })
      >[
        (
          name: 'identical concurrent edits merge without a conflict',
          local: 'New',
          remote: 'New',
          conflict: false,
          merged: {'d1': 'New', 'd2': 'B local'},
        ),
        (
          name: 'differing concurrent edits still raise a conflict',
          local: 'Local',
          remote: 'Remote',
          conflict: true,
          merged: null,
        ),
      ];
  for (final c in concurrentEdits) {
    test(c.name, () {
      final base = jsonEncode({
        'devices': [deviceJson('d1', 'Old', t0), deviceJson('d2', 'B', t0)],
      });
      final local = jsonEncode({
        'devices': [
          deviceJson('d1', c.local, t1),
          deviceJson('d2', 'B local', t1),
        ],
      });
      final remote = jsonEncode({
        'devices': [
          deviceJson('d1', c.remote, c.conflict ? t2 : t1),
          deviceJson('d2', 'B', t0),
        ],
      });

      final result = mergeDeviceData(local, remote, base);
      expect(result.hasConflicts, c.conflict);
      if (c.conflict) {
        expect(result.conflicts.map((x) => x.id), contains('d1'));
      } else {
        final names = {for (final d in result.merged) d.id: d.name};
        expect(names, c.merged);
      }
    });
  }

  test('new record timestamps default to UTC for cross-timezone LWW', () {
    expect(
      Device(name: 'D', category: DeviceCategory.laptop).modifiedAt.isUtc,
      isTrue,
    );
    expect(DataSet(name: 'S', emoji: '📁').modifiedAt.isUtc, isTrue);
  });
}
