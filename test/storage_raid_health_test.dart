import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/datasets/models/dataset.dart';
import 'package:my_device/features/datasets/services/dataset_placement.dart';
import 'package:my_device/features/datasets/services/dataset_topology.dart';
import 'package:my_device/features/devices/models/device.dart';

/// Purpose: Build a NAS with four drives — three in a RAID 5 array, one
/// failed — and a desktop with one drive.
/// Inputs: `failedInArray` — how many array members are failed.
/// Returns: The devices and data sets.
/// Side effects: None.
/// Notes: Media is on the array and the desktop; Scratch on the NAS's
/// fourth (failed) drive and the desktop.
({List<Device> devices, List<DataSet> dataSets}) raidFixture({
  int failedInArray = 0,
}) {
  final devices = [
    Device(
      id: 'nas',
      name: 'NAS',
      category: DeviceCategory.other,
      storage: [
        for (var i = 0; i < 3; i++)
          StorageInfo(
            capacity: '8 TB',
            status: i < failedInArray ? StorageHealth.failed : StorageHealth.ok,
          ),
        const StorageInfo(
          capacity: '4 TB',
          status: StorageHealth.offline,
          statusNote: 'dropped',
        ),
      ],
      storageArrays: [
        StorageArray(
          id: 'pool',
          name: 'Pool',
          level: RaidLevel.raid5,
          memberIndices: const [0, 1, 2],
        ),
      ],
    ),
    Device(
      id: 'pc',
      name: 'Desktop',
      category: DeviceCategory.desktop,
      storage: const [StorageInfo(capacity: '2 TB')],
    ),
  ];
  final dataSets = [
    DataSet(
      id: 'media',
      name: 'Media',
      emoji: '🎬',
      storageLinks: const [
        DataSetStorageLink(deviceId: 'nas', arrayIds: ['pool']),
        DataSetStorageLink(deviceId: 'pc', storageIndices: [0]),
      ],
    ),
    DataSet(
      id: 'scratch',
      name: 'Scratch',
      emoji: '📁',
      storageLinks: const [
        DataSetStorageLink(deviceId: 'nas', storageIndices: [3]),
        DataSetStorageLink(deviceId: 'pc', storageIndices: [0]),
      ],
    ),
  ];
  return (devices: devices, dataSets: dataSets);
}

/// Purpose: Test RAID arrays and drive health in the model, placement and
/// topology layout.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: None.
void main() {
  group('model', () {
    test('status and arrays round-trip; ok and empty fields are omitted', () {
      final f = raidFixture(failedInArray: 1);
      final json = f.devices.first.toJson();
      final storage = json['storage'] as List;
      expect((storage[0] as Map)['status'], 'failed');
      expect((storage[1] as Map).containsKey('status'), isFalse);
      expect((storage[3] as Map)['statusNote'], 'dropped');
      final back = Device.fromJson(json);
      expect(back.storage[3].status, StorageHealth.offline);
      expect(back.storage[3].statusNote, 'dropped');
      expect(back.storageArrays.single.id, 'pool');
      expect(back.storageArrays.single.level, RaidLevel.raid5);
      expect(back.storageArrays.single.memberIndices, [0, 1, 2]);
      expect(f.devices.last.toJson().containsKey('storageArrays'), isFalse);

      final link = f.dataSets.first.storageLinks.first;
      expect(link.toJson()['arrayIds'], ['pool']);
      expect(DataSetStorageLink.fromJson(link.toJson()).arrayIds, ['pool']);
      expect(
        f.dataSets.first.storageLinks.last.toJson().containsKey('arrayIds'),
        isFalse,
      );
    });

    test('an unknown status from a newer build survives a save', () {
      final s = StorageInfo.fromJson({
        'capacity': '1 TB',
        'status': 'rebuilding',
      });
      expect(s.status, StorageHealth.ok);
      expect(s.toJson()['status'], 'rebuilding');
    });

    test('unknown array fields merge by id', () {
      final local = raidFixture().devices.first;
      final remote = Device.fromJson({
        ...local.toJson(),
        'storageArrays': [
          {...local.storageArrays.single.toJson(), 'future': 1},
        ],
      });
      final merged = local.mergeUnknownFieldsFrom(remote);
      expect(merged.storageArrays.single.extraJson['future'], 1);
    });
  });

  group('placement', () {
    test('a device lists its arrays, then the slots in no array', () {
      final places = devicePlaces(raidFixture().devices.first);
      expect(places.map((p) => p.key), ['a:pool', '3']);
    });

    test('an array is one copy; failed drives stop counting', () {
      final f = raidFixture();
      final media = resolveReplicas(f.dataSets[0], f.devices);
      expect(media.map((r) => r.place.key), ['a:pool', '0']);
      expect(availableCopyCount(media), 2);
      final scratch = resolveReplicas(f.dataSets[1], f.devices);
      expect(scratch, hasLength(2));
      expect(availableCopyCount(scratch), 1);
      expect(scratch.first.isAvailable, isFalse);
    });

    test('an array degrades within its tolerance and fails beyond it', () {
      PlaceHealth health(int failed) => devicePlaces(
        raidFixture(failedInArray: failed).devices.first,
      ).first.health;
      expect(health(0), PlaceHealth.ok);
      expect(health(1), PlaceHealth.degraded);
      expect(health(2), PlaceHealth.unavailable);
      expect(
        availableCopyCount(
          resolveReplicas(
            raidFixture(failedInArray: 2).dataSets[0],
            raidFixture(failedInArray: 2).devices,
          ),
        ),
        1,
      );
    });

    test('fault tolerance per level', () {
      expect(RaidLevel.raid0.faultTolerance(4), 0);
      expect(RaidLevel.raid1.faultTolerance(3), 2);
      expect(RaidLevel.raid6.faultTolerance(6), 2);
      expect(RaidLevel.raidz3.faultTolerance(8), 3);
      expect(RaidLevel.other.faultTolerance(4), isNull);
    });

    test('grouping by storage gives the array its own group', () {
      final f = raidFixture();
      final groups = groupDataSets(
        f.dataSets,
        f.devices,
        DataSetGroupMode.storage,
      );
      expect(groups.map((g) => g.key), [
        'storage:nas:a:pool',
        'storage:nas:3',
        'storage:pc:0',
      ]);
      expect(groups.first.place!.isArray, isTrue);
    });
  });

  group('topology', () {
    test('an array is one storage box; members are not drawn separately', () {
      final f = raidFixture(failedInArray: 1);
      final layout = DataSetTopologyLayout.build(
        devices: f.devices,
        dataSets: f.dataSets,
      );
      expect(layout.node('storage:nas:a:pool'), isNotNull);
      expect(layout.node('storage:nas:0'), isNull);
      expect(layout.node('storage:nas:3'), isNotNull);
      final media = layout.node(
        DataSetTopologyLayout.copyNodeId('media', 'nas', 'a:pool'),
      )!;
      expect(media.copyCount, 2);
      expect(media.availableCount, 2);
      final scratch = layout.node(
        DataSetTopologyLayout.copyNodeId('scratch', 'pc', 0),
      )!;
      expect(scratch.copyCount, 2);
      expect(scratch.availableCount, 1);
      expect(
        layout.node('storage:nas:a:pool')!.rect.contains(media.rect.center),
        isTrue,
      );
    });

    test('a link still naming an array member keeps its copy drawn', () {
      final f = raidFixture();
      final legacy = DataSet(
        id: 'legacy',
        name: 'Legacy',
        emoji: '📁',
        storageLinks: const [
          DataSetStorageLink(deviceId: 'nas', storageIndices: [1]),
        ],
      );
      final layout = DataSetTopologyLayout.build(
        devices: f.devices,
        dataSets: [...f.dataSets, legacy],
      );
      expect(layout.node('storage:nas:1'), isNotNull);
      expect(
        layout.node(DataSetTopologyLayout.copyNodeId('legacy', 'nas', 1)),
        isNotNull,
      );
    });

    test('selecting an array lights what is on it', () {
      final f = raidFixture();
      final layout = DataSetTopologyLayout.build(
        devices: f.devices,
        dataSets: f.dataSets,
      );
      final lit = layout.highlightFor('storage:nas:a:pool')!;
      expect(lit.dataSetIds, {'media'});
      expect(lit.nodeIds, contains('storage:pc:0'));
    });
  });
}
