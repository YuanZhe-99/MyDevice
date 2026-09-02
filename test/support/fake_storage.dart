import 'dart:convert';
import 'dart:io';

import 'package:my_device/features/datasets/models/dataset.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/network/models/network.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Purpose: Point `path_provider` at a temporary documents directory.
/// Inputs: `documentsPath`.
/// Returns: None.
/// Side effects: None until installed as `PathProviderPlatform.instance`.
/// Notes: `DeviceStorage.getAppDir()` resolves `<documents>/MyDevice`, so a
/// test that installs this and seeds that folder drives the real pages against
/// its own data without touching the user's.
class FakePathProvider extends PathProviderPlatform {
  FakePathProvider(this.documentsPath);
  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Purpose: Create a temporary app storage directory and install it.
/// Inputs: `prefix` — a name for the temp directory; optional `devices`,
/// `networks`, `assignments`, `datasets`, `services`, `routes` to seed.
/// Returns: The temp directory, which the caller deletes in `tearDown`.
/// Side effects: Creates `<tmp>/docs/MyDevice`, writes the seeded data files
/// through the real models' `toJson`, and replaces
/// `PathProviderPlatform.instance`.
/// Notes: Seeding through `toJson` rather than hand-written JSON keeps the
/// fixtures aligned with the persisted format for free.
Future<Directory> seedAppDir(
  String prefix, {
  List<Device> devices = const [],
  List<Network> networks = const [],
  List<NetworkDevice> assignments = const [],
  List<DataSet> datasets = const [],
  List<ServiceNode> services = const [],
  List<ServiceRoute> routes = const [],
}) async {
  final tempDir = await Directory.systemTemp.createTemp(prefix);
  final docsDir = Directory(p.join(tempDir.path, 'docs'))
    ..createSync(recursive: true);
  final appDir = Directory(p.join(docsDir.path, 'MyDevice'))
    ..createSync(recursive: true);
  PathProviderPlatform.instance = FakePathProvider(docsDir.path);

  const encoder = JsonEncoder.withIndent('  ');
  void write(String name, Map<String, dynamic> json) {
    File(p.join(appDir.path, name)).writeAsStringSync(encoder.convert(json));
  }

  if (devices.isNotEmpty) {
    write('device_data.json', DeviceData(devices: devices).toJson());
  }
  if (networks.isNotEmpty || assignments.isNotEmpty) {
    write(
      'network_data.json',
      NetworkData(networks: networks, assignments: assignments).toJson(),
    );
  }
  if (datasets.isNotEmpty) {
    write('dataset_data.json', DataSetData(datasets: datasets).toJson());
  }
  if (services.isNotEmpty || routes.isNotEmpty) {
    write(
      'service_data.json',
      ServiceData(services: services, routes: routes).toJson(),
    );
  }
  return tempDir;
}

/// Purpose: Read the seeded storage's `storage_config.json`.
/// Inputs: `tempDir` — the directory `seedAppDir` returned.
/// Returns: The decoded map, or an empty map when the file does not exist.
/// Side effects: None.
/// Notes: Lets a test assert what a preference wrote, or that it wrote
/// nothing.
Map<String, dynamic> readSeededConfig(Directory tempDir) {
  final file = File(
    p.join(tempDir.path, 'docs', 'MyDevice', 'storage_config.json'),
  );
  if (!file.existsSync()) return {};
  // A page writes the file without awaiting it, so a poll can catch it
  // half-written; an unparseable read counts as "not there yet".
  try {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } on FormatException {
    return {};
  }
}

/// Purpose: Delete a seeded storage directory, retrying while a write holds it.
/// Inputs: `tempDir` — the directory `seedAppDir` returned.
/// Returns: None.
/// Side effects: Deletes the directory tree; sleeps briefly between attempts.
/// Notes: A page's fire-and-forget preference write can still hold
/// `storage_config.json` open when the test body ends, and Windows refuses to
/// delete an open file. Five attempts a tenth of a second apart cover it; the
/// last attempt is allowed to throw so a genuinely stuck handle still fails
/// the test rather than leaking the directory silently.
void deleteSeededDir(Directory tempDir) {
  for (var attempt = 0; attempt < 5; attempt++) {
    if (!tempDir.existsSync()) return;
    try {
      tempDir.deleteSync(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 4) rethrow;
      sleep(const Duration(milliseconds: 100));
    }
  }
}
