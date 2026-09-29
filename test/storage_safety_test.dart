import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/datasets/models/dataset.dart';
import 'package:my_device/features/datasets/services/dataset_storage.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/device_storage.dart';
import 'package:my_device/features/network/models/network.dart';
import 'package:my_device/features/network/services/network_storage.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_storage.dart';
import 'package:path/path.dart' as p;

import 'support/fake_storage.dart';

/// Purpose: Test the storages' write safety: serialised, atomic, lossless.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes temporary app storage directories.
/// Notes: Covers the write queue (no lost updates under concurrent
/// read-modify-write), the tmp+rename write (no `.tmp-*` leftovers),
/// preservation of unknown top-level fields when a container is rebuilt,
/// and `modifiedAt` stability of routes a service delete does not touch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory appDir;

  setUp(() async {
    tempDir = await seedAppDir('mydevice_storage_safety');
    appDir = Directory(p.join(tempDir.path, 'docs', 'MyDevice'));
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  /// Purpose: Read one of the seeded app files as a JSON map.
  /// Inputs: `name`.
  /// Returns: The decoded map.
  /// Side effects: Reads the file.
  /// Notes: None.
  Map<String, dynamic> readJson(String name) =>
      jsonDecode(File(p.join(appDir.path, name)).readAsStringSync())
          as Map<String, dynamic>;

  /// Purpose: Write raw JSON into the seeded app folder.
  /// Inputs: `name`, `json`.
  /// Returns: None.
  /// Side effects: Writes the file.
  /// Notes: Lets a test plant fields no model knows about.
  void writeJson(String name, Map<String, dynamic> json) => File(
    p.join(appDir.path, name),
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));

  /// Purpose: List temp files a write may have left in the app folder.
  /// Inputs: None.
  /// Returns: Paths containing `.tmp`.
  /// Side effects: Lists the folder.
  /// Notes: None.
  List<String> leftovers() => appDir
      .listSync(recursive: true)
      .map((e) => e.path)
      .where((path) => path.contains('.tmp'))
      .toList();

  test('20 concurrent device addOrUpdate calls all survive', () async {
    await Future.wait([
      for (var i = 0; i < 20; i++)
        DeviceStorage.addOrUpdate(
          Device(id: 'd$i', name: 'Device $i', category: DeviceCategory.laptop),
        ),
    ]);
    final ids = (await DeviceStorage.load()).devices.map((d) => d.id).toSet();
    expect(ids, {for (var i = 0; i < 20; i++) 'd$i'});
    expect(leftovers(), isEmpty);
  });

  test('concurrent service and network writes all survive too', () async {
    await Future.wait([
      for (var i = 0; i < 10; i++)
        ServiceStorage.addOrUpdateService(
          ServiceNode(id: 's$i', deviceId: 'd', name: 'Svc $i'),
        ),
      for (var i = 0; i < 10; i++)
        NetworkStorage.addOrUpdateNetwork(
          Network(id: 'n$i', name: 'Net $i', type: NetworkType.lan),
        ),
    ]);
    expect((await ServiceStorage.load()).services, hasLength(10));
    expect((await NetworkStorage.load()).networks, hasLength(10));
    expect(leftovers(), isEmpty);
  });

  test('removing a device keeps unknown top-level fields everywhere', () async {
    writeJson('device_data.json', {
      'futureDeviceRoot': 'd',
      'devices': [
        {
          'id': 'gone',
          'name': 'Gone',
          'category': 'laptop',
          'modifiedAt': '2026-01-01T00:00:00.000Z',
        },
      ],
    });
    writeJson('network_data.json', {
      'futureNetworkRoot': 'n',
      'networks': <dynamic>[],
      'assignments': [
        {'networkId': 'n1', 'deviceId': 'gone'},
      ],
    });
    writeJson('dataset_data.json', {
      'futureDataSetRoot': 'ds',
      'datasets': [
        {
          'id': 'ds1',
          'name': 'Photos',
          'emoji': 'x',
          'modifiedAt': '2026-01-01T00:00:00.000Z',
          'storageLinks': [
            {
              'deviceId': 'gone',
              'storageIndices': [0],
            },
          ],
        },
      ],
    });

    await DeviceStorage.deleteDevice('gone');

    expect(readJson('device_data.json')['futureDeviceRoot'], 'd');
    expect(readJson('device_data.json')['devices'], isEmpty);
    final network = readJson('network_data.json');
    expect(network['futureNetworkRoot'], 'n');
    expect(network['assignments'], isEmpty);
    expect(readJson('dataset_data.json')['futureDataSetRoot'], 'ds');
    expect(leftovers(), isEmpty);
  });

  test('every storage keeps its root extras through addOrUpdate', () async {
    writeJson('device_data.json', {'futureDeviceRoot': 1, 'devices': []});
    writeJson('network_data.json', {'futureNetworkRoot': 2, 'networks': []});
    writeJson('dataset_data.json', {'futureDataSetRoot': 3, 'datasets': []});
    writeJson('service_data.json', {'futureServiceRoot': 4, 'services': []});

    await DeviceStorage.addOrUpdate(
      Device(id: 'd', name: 'D', category: DeviceCategory.laptop),
    );
    await NetworkStorage.addOrUpdateNetwork(
      Network(id: 'n', name: 'N', type: NetworkType.lan),
    );
    await DataSetStorage.addOrUpdate(DataSet(id: 'ds', name: 'S', emoji: 'x'));
    await ServiceStorage.addOrUpdateService(
      ServiceNode(id: 's', deviceId: 'd', name: 'S'),
    );

    expect(readJson('device_data.json')['futureDeviceRoot'], 1);
    expect(readJson('network_data.json')['futureNetworkRoot'], 2);
    expect(readJson('dataset_data.json')['futureDataSetRoot'], 3);
    expect(readJson('service_data.json')['futureServiceRoot'], 4);
  });

  test('deleting a service leaves untouched routes byte-identical', () async {
    final stamp = DateTime.utc(2026, 1, 2, 3, 4, 5);
    ServiceRoute route(String id, String source, List<String> hopServices) =>
        ServiceRoute(
          id: id,
          name: id,
          sourceServiceId: source,
          modifiedAt: stamp,
          hops: [
            for (final s in hopServices)
              ServiceRouteHop(id: '$id-$s', serviceId: s),
          ],
        );
    await ServiceStorage.save(
      ServiceData(
        services: [
          ServiceNode(id: 'a', deviceId: 'd', name: 'A'),
          ServiceNode(id: 'b', deviceId: 'd', name: 'B'),
          ServiceNode(id: 'c', deviceId: 'd', name: 'C'),
        ],
        routes: [
          route('untouched', 'a', ['b']),
          route('loses-hop', 'a', ['b', 'c']),
          route('sourced-at-c', 'c', ['b']),
        ],
      ),
    );

    await ServiceStorage.deleteService('c');

    final routes = (await ServiceStorage.load()).routes;
    expect(routes.map((r) => r.id), ['untouched', 'loses-hop']);
    final untouched = routes.firstWhere((r) => r.id == 'untouched');
    final losesHop = routes.firstWhere((r) => r.id == 'loses-hop');
    expect(untouched.modifiedAt, stamp);
    expect(losesHop.hops.map((h) => h.serviceId), ['b']);
    expect(losesHop.modifiedAt.isAfter(stamp), isTrue);
  });

  test('removeDeviceReferences with no reference writes nothing', () async {
    final stamp = DateTime.utc(2026, 1, 2);
    await ServiceStorage.save(
      ServiceData(
        services: [ServiceNode(id: 'a', deviceId: 'd1', name: 'A')],
        routes: [
          ServiceRoute(
            id: 'r',
            name: 'r',
            sourceServiceId: 'a',
            modifiedAt: stamp,
          ),
        ],
      ),
    );
    final file = File(p.join(appDir.path, 'service_data.json'));
    final before = file.readAsStringSync();
    final modified = file.lastModifiedSync();

    await ServiceStorage.removeDeviceReferences('nobody');

    expect(file.readAsStringSync(), before);
    expect(file.lastModifiedSync(), modified);
  });
}
