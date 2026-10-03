import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/datasets/models/dataset.dart';
import 'package:my_device/features/datasets/services/dataset_placement.dart';
import 'package:my_device/features/datasets/services/dataset_topology.dart';
import 'package:my_device/features/devices/models/device.dart';

/// Purpose: Build a small inventory: a NAS with two disks, a desktop with
/// one, a laptop with one and a phone with no storage.
/// Inputs: None.
/// Returns: The devices and data sets.
/// Side effects: None.
/// Notes: Photos has copies on the NAS's first disk and the desktop; Music
/// on both NAS disks; Docs only on the laptop; Orphan on nothing; Stale on a
/// deleted device and an out-of-range slot.
({List<Device> devices, List<DataSet> dataSets}) placementFixture() {
  final devices = [
    Device(
      id: 'nas',
      name: 'NAS',
      category: DeviceCategory.other,
      storage: const [
        StorageInfo(capacity: '8 TB', type: StorageType.hdd),
        StorageInfo(capacity: '8 TB', type: StorageType.hdd),
      ],
    ),
    Device(
      id: 'pc',
      name: 'Desktop',
      category: DeviceCategory.desktop,
      storage: const [StorageInfo(capacity: '2 TB', type: StorageType.ssd)],
    ),
    Device(
      id: 'laptop',
      name: 'Laptop',
      category: DeviceCategory.laptop,
      storage: const [StorageInfo()],
    ),
    Device(id: 'phone', name: 'Phone', category: DeviceCategory.phone),
  ];
  final dataSets = [
    DataSet(
      id: 'photos',
      name: 'Photos',
      emoji: '📷',
      storageLinks: const [
        DataSetStorageLink(deviceId: 'nas', storageIndices: [0]),
        DataSetStorageLink(deviceId: 'pc', storageIndices: [0]),
      ],
    ),
    DataSet(
      id: 'music',
      name: 'Music',
      emoji: '🎵',
      storageLinks: const [
        DataSetStorageLink(deviceId: 'nas', storageIndices: [0, 1]),
      ],
    ),
    DataSet(
      id: 'docs',
      name: 'Docs',
      emoji: '📄',
      storageLinks: const [
        DataSetStorageLink(deviceId: 'laptop', storageIndices: [0]),
      ],
    ),
    DataSet(id: 'orphan', name: 'Orphan', emoji: '📁'),
    DataSet(
      id: 'stale',
      name: 'Stale',
      emoji: '📁',
      storageLinks: const [
        DataSetStorageLink(deviceId: 'gone', storageIndices: [0]),
        DataSetStorageLink(deviceId: 'pc', storageIndices: [5]),
      ],
    ),
  ];
  return (devices: devices, dataSets: dataSets);
}

/// Purpose: Test data set placement, grouping and the topology layout.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Pure functions only.
void main() {
  final f = placementFixture();
  DataSet ds(String id) => f.dataSets.firstWhere((d) => d.id == id);

  group('resolveReplicas', () {
    test('one copy per linked slot, dangling links skipped', () {
      expect(resolveReplicas(ds('photos'), f.devices).length, 2);
      expect(resolveReplicas(ds('music'), f.devices).length, 2);
      expect(resolveReplicas(ds('orphan'), f.devices), isEmpty);
      expect(resolveReplicas(ds('stale'), f.devices), isEmpty);
    });

    test('a slot listed twice counts once', () {
      final twice = DataSet(
        name: 'x',
        emoji: '📁',
        storageLinks: const [
          DataSetStorageLink(deviceId: 'pc', storageIndices: [0, 0]),
        ],
      );
      expect(resolveReplicas(twice, f.devices).length, 1);
    });
  });

  group('groupDataSets', () {
    test('by device: one group per device in list order, then unlinked', () {
      final groups = groupDataSets(
        f.dataSets,
        f.devices,
        DataSetGroupMode.device,
      );
      expect(groups.map((g) => g.key), [
        'device:nas',
        'device:pc',
        'device:laptop',
        'unlinked',
      ]);
      // Music sits on two NAS disks but shows once under the NAS.
      expect(groups[0].dataSets.map((d) => d.id), ['photos', 'music']);
      expect(groups[1].dataSets.map((d) => d.id), ['photos']);
      expect(groups[3].dataSets.map((d) => d.id), ['orphan', 'stale']);
      expect(groups[3].isUnlinked, isTrue);
    });

    test('by storage: one group per used slot', () {
      final groups = groupDataSets(
        f.dataSets,
        f.devices,
        DataSetGroupMode.storage,
      );
      expect(groups.map((g) => g.key), [
        'storage:nas:0',
        'storage:nas:1',
        'storage:pc:0',
        'storage:laptop:0',
        'unlinked',
      ]);
      expect(groups[0].dataSets.map((d) => d.id), ['photos', 'music']);
      expect(groups[1].dataSets.map((d) => d.id), ['music']);
      expect(groups[1].storageIndex, 1);
    });
  });

  test('storageSlotLabel numbers duplicates and empty slots', () {
    String fallback(int n) => 'Storage $n';
    expect(storageSlotLabel(f.devices[0], 1, fallback), '8 TB HDD #2');
    expect(storageSlotLabel(f.devices[1], 0, fallback), '2 TB SSD');
    expect(storageSlotLabel(f.devices[2], 0, fallback), 'Storage 1');
  });

  group('DataSetTopologyLayout', () {
    DataSetTopologyLayout build({
      Set<String> ids = const {},
      bool showEmpty = false,
    }) => DataSetTopologyLayout.build(
      devices: f.devices,
      dataSets: f.dataSets,
      deviceIds: ids,
      showEmptyDevices: showEmpty,
    );

    test('nests copies in storages in devices', () {
      final layout = build();
      final nas = layout.node('device:nas')!;
      final disk = layout.node('storage:nas:1')!;
      final copy = layout.node(
        DataSetTopologyLayout.copyNodeId('music', 'nas', 1),
      )!;
      expect(nas.rect.contains(disk.rect.topLeft), isTrue);
      expect(nas.rect.contains(disk.rect.bottomRight), isTrue);
      expect(disk.rect.contains(copy.rect.topLeft), isTrue);
      expect(disk.rect.contains(copy.rect.bottomRight), isTrue);
      expect(copy.copyCount, 2);
      expect(layout.node('device:phone'), isNull, reason: 'no storage');
      final canvas = Offset.zero & layout.size;
      for (final node in layout.nodes) {
        expect(canvas.contains(node.rect.bottomRight), isTrue, reason: node.id);
      }
    });

    test('links chain the copies of each data set', () {
      final layout = build();
      final byDataSet = <String, int>{};
      for (final link in layout.links) {
        byDataSet[link.dataSetId] = (byDataSet[link.dataSetId] ?? 0) + 1;
      }
      expect(byDataSet, {'photos': 1, 'music': 1});
    });

    test('devices that share data sets sit next to each other', () {
      final layout = build();
      final order = [
        for (final n in layout.nodes)
          if (n.kind == DataSetTopologyNodeKind.device) n.device.id,
      ];
      expect(order.first, 'nas');
      expect(order[1], 'pc');
    });

    test('devices pack into a square-to-16:10 canvas', () {
      // Twelve one-slot devices with one data set each.
      final devices = [
        for (var i = 0; i < 12; i++)
          Device(
            id: 'd$i',
            name: 'D$i',
            category: DeviceCategory.other,
            storage: const [StorageInfo(capacity: '1 TB')],
          ),
      ];
      final dataSets = [
        for (var i = 0; i < 12; i++)
          DataSet(
            id: 's$i',
            name: 'S$i',
            emoji: '📁',
            storageLinks: [
              DataSetStorageLink(deviceId: 'd$i', storageIndices: const [0]),
            ],
          ),
      ];
      final layout = DataSetTopologyLayout.build(
        devices: devices,
        dataSets: dataSets,
      );
      final aspect = layout.size.width / layout.size.height;
      expect(aspect, inInclusiveRange(0.8, 1.9));
      final columns = {
        for (final n in layout.nodes)
          if (n.kind == DataSetTopologyNodeKind.device) n.rect.left,
      };
      expect(columns.length, greaterThan(1));
    });

    test('a tall device keeps its column while others fill the rest', () {
      final tall = Device(
        id: 'tall',
        name: 'Tall',
        category: DeviceCategory.other,
        storage: List.filled(6, const StorageInfo(capacity: '1 TB')),
      );
      final small = [
        for (var i = 0; i < 3; i++)
          Device(
            id: 'small$i',
            name: 'Small $i',
            category: DeviceCategory.other,
            storage: const [StorageInfo(capacity: '1 TB')],
          ),
      ];
      final dataSets = [
        DataSet(
          id: 'big',
          name: 'Big',
          emoji: '📁',
          storageLinks: const [
            DataSetStorageLink(
              deviceId: 'tall',
              storageIndices: [0, 1, 2, 3, 4, 5],
            ),
          ],
        ),
        for (var i = 0; i < 3; i++)
          DataSet(
            id: 'x$i',
            name: 'X$i',
            emoji: '📁',
            storageLinks: [
              DataSetStorageLink(
                deviceId: 'small$i',
                storageIndices: const [0],
              ),
            ],
          ),
      ];
      final layout = DataSetTopologyLayout.build(
        devices: [tall, ...small],
        dataSets: dataSets,
      );
      final t = layout.node('device:tall')!.rect;
      final others = [
        for (var i = 0; i < 3; i++) layout.node('device:small$i')!.rect,
      ];
      // The small devices stack beside the tall one, not below it.
      for (final r in others) {
        expect(r.left, isNot(t.left));
        expect(r.top, lessThan(t.bottom));
      }
      expect({for (final r in others) r.left}.length, 1);
      // No two device boxes overlap.
      final all = [t, ...others];
      for (var a = 0; a < all.length; a++) {
        for (var b = a + 1; b < all.length; b++) {
          expect(all[a].overlaps(all[b]), isFalse);
        }
      }
    });

    test('a device filter hides other devices and their links', () {
      final layout = build(ids: {'nas'});
      expect(layout.node('device:pc'), isNull);
      expect(layout.links.where((l) => l.dataSetId == 'photos'), isEmpty);
      // The copy count still counts the hidden copy.
      expect(
        layout
            .node(DataSetTopologyLayout.copyNodeId('photos', 'nas', 0))!
            .copyCount,
        2,
      );
    });

    test('showEmptyDevices adds devices with storage but no copy', () {
      final empty = Device(
        id: 'usb',
        name: 'USB',
        category: DeviceCategory.other,
        storage: const [StorageInfo(capacity: '1 TB')],
      );
      DataSetTopologyLayout at(bool show) => DataSetTopologyLayout.build(
        devices: [...f.devices, empty],
        dataSets: f.dataSets,
        showEmptyDevices: show,
      );
      expect(at(false).node('device:usb'), isNull);
      expect(at(true).node('storage:usb:0'), isNotNull);
    });

    test('no copies at all lays out nothing', () {
      final layout = DataSetTopologyLayout.build(
        devices: f.devices,
        dataSets: [ds('orphan')],
      );
      expect(layout.isEmpty, isTrue);
      expect(layout.size, Size.zero);
    });

    test('a selection lights every copy of the data sets on it', () {
      final layout = build();
      final pc = layout.highlightFor('storage:pc:0')!;
      expect(pc.dataSetIds, {'photos'});
      expect(
        pc.nodeIds,
        containsAll([
          'storage:pc:0',
          'device:nas',
          'storage:nas:0',
          DataSetTopologyLayout.copyNodeId('photos', 'nas', 0),
        ]),
      );
      expect(
        pc.nodeIds.contains(
          DataSetTopologyLayout.copyNodeId('music', 'nas', 0),
        ),
        isFalse,
      );
      final nas = layout.highlightFor('device:nas')!;
      expect(nas.dataSetIds, {'photos', 'music'});
      expect(nas.nodeIds, contains('device:pc'));
      expect(layout.highlightFor('device:laptop')!.nodeIds, {
        'device:laptop',
        'storage:laptop:0',
        DataSetTopologyLayout.copyNodeId('docs', 'laptop', 0),
      });
      expect(layout.highlightFor('nope'), isNull);
    });
  });
}
