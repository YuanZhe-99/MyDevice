import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/device_storage.dart';
import 'package:path/path.dart' as p;

import 'support/fake_storage.dart';

/// Purpose: Test that changing the storage location keeps the preferences
/// in one place and reports anything the move left behind.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes temporary app storage directories.
/// Notes: `DeviceStorage` keeps the custom path in static state, so every
/// test resets to the default location before its directory is deleted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String defaultDir;

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_storage_path',
      devices: [
        Device(id: 'd1', name: 'Laptop', category: DeviceCategory.laptop),
      ],
    );
    defaultDir = p.join(tempDir.path, 'docs', 'MyDevice');
  });

  tearDown(() async {
    await DeviceStorage.setStoragePath(null);
    deleteSeededDir(tempDir);
  });

  /// Purpose: Read a JSON file as a map.
  /// Inputs: `path`.
  /// Returns: The decoded map.
  /// Side effects: Reads the file.
  /// Notes: None.
  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  test('preferences survive a move and stay in the default folder', () async {
    await DeviceStorage.setThemeMode('dark');
    final custom = p.join(tempDir.path, 'custom');

    final result = await DeviceStorage.setStoragePath(custom);

    expect(result.saved, isTrue);
    expect(result.unmoved, isEmpty);
    expect(result.complete, isTrue);
    expect(await DeviceStorage.getStoragePath(), custom);
    expect(await DeviceStorage.getThemeMode(), 'dark');
    expect((await DeviceStorage.load()).devices.single.id, 'd1');
    expect(File(p.join(custom, 'device_data.json')).existsSync(), isTrue);
    expect(File(p.join(custom, 'storage_config.json')).existsSync(), isFalse);

    await DeviceStorage.setThemeMode('light');
    final config = readJson(p.join(defaultDir, 'storage_config.json'));
    expect(config['themeMode'], 'light');
    expect(config['storagePath'], custom);
    expect(File(p.join(custom, 'storage_config.json')).existsSync(), isFalse);
  });

  test('a preference write cannot change or drop the storage path', () async {
    final custom = p.join(tempDir.path, 'custom');
    await DeviceStorage.setStoragePath(custom);

    await DeviceStorage.writeConfig({'themeMode': 'dark'});
    expect(
      readJson(p.join(defaultDir, 'storage_config.json'))['storagePath'],
      custom,
    );
    await DeviceStorage.writeConfig({'storagePath': '/elsewhere'});
    expect(
      readJson(p.join(defaultDir, 'storage_config.json'))['storagePath'],
      custom,
    );
    expect(await DeviceStorage.getStoragePath(), custom);
  });

  test('a config an older build left in the custom folder is adopted', () async {
    await DeviceStorage.setThemeMode('dark');
    final custom = p.join(tempDir.path, 'custom-older');
    await DeviceStorage.setStoragePath(custom);
    // What a pre-1.5.7 build wrote after the move: the preferences changed
    // since, in the custom folder.
    final stray = File(p.join(custom, 'storage_config.json'))
      ..writeAsStringSync(
        jsonEncode({'themeMode': 'system', 'locale': 'ja', 'storagePath': 'x'}),
      );
    // Moving on to another folder checks the current one first.
    final next = p.join(tempDir.path, 'custom-next');
    await DeviceStorage.setStoragePath(next);

    final config = await DeviceStorage.readConfig();
    expect(config['themeMode'], 'system');
    expect(config['locale'], 'ja');
    expect(config['storagePath'], next);
    expect(stray.existsSync(), isFalse);
    expect(File(p.join(next, 'storage_config.json')).existsSync(), isFalse);
  });

  test('files the move could not place are reported', () async {
    final custom = p.join(tempDir.path, 'occupied');
    // The destination already holds a device file, which wins, so the
    // default folder's copy stays behind.
    Directory(custom).createSync(recursive: true);
    File(
      p.join(custom, 'device_data.json'),
    ).writeAsStringSync(jsonEncode({'devices': <Object>[]}));
    Directory(p.join(defaultDir, 'images')).createSync();
    File(p.join(defaultDir, 'images', 'a.png')).writeAsBytesSync([1, 2, 3]);

    final result = await DeviceStorage.setStoragePath(custom);

    expect(result.saved, isTrue);
    expect(result.complete, isFalse);
    expect(result.unmoved, ['device_data.json']);
    expect(result.from, defaultDir);
    expect(File(p.join(custom, 'images', 'a.png')).existsSync(), isTrue);
  });
}
