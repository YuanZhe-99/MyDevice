// Golden (characterization) harness for MyDevice.
//
// Drives the REAL, unmodified `WebDAVService` / `BackupService` /
// `ImportExportService` against an in-memory fake WebDAV server, recording the
// exact request sequence and on-disk formats into golden files. This is PLAN
// task P0.2: post-extraction (Phase 3), the new shared engine must reproduce
// these identical sequences (invariants I1-I3). Re-run / re-record with:
//   flutter test test/golden/webdav_golden_test.dart            (verify)
//   flutter test --dart-define=GOLDEN_RECORD=true test/golden/webdav_golden_test.dart  (record)
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/src/client.dart' show runWithClient;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:my_device/shared/services/backup_service.dart';
import 'package:my_device/shared/services/import_export_service.dart';
import 'package:my_device/shared/services/webdav_service.dart';

import '../../packages/myapps_data/test/golden/fake_webdav_server.dart';
import '../../packages/myapps_data/test/golden/request_recorder.dart';

/// Whether to rewrite goldens instead of verifying them.
const bool _record =
    bool.fromEnvironment('GOLDEN_RECORD', defaultValue: false);

/// Fake application-documents provider (pattern from existing app tests).
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Fixed WebDAV config pointing at the fake server.
WebDAVConfig _config() => const WebDAVConfig(
      serverUrl: 'https://golden.test/dav/files/u',
      username: 'u',
      password: 'p',
      remotePath: '/MyDevice',
    );

/// A full set of valid per-module data payloads. [overrides] replaces a module.
Map<String, String> _dataSet({Map<String, String>? overrides}) {
  const ts = '2026-01-02T00:00:00.000Z';
  final data = <String, String>{
    'device_data.json': const JsonEncoder.withIndent('  ').convert({
      'devices': [
        {
          'id': 'dev-1',
          'name': 'Test Device',
          'category': 'other',
          'modifiedAt': ts,
        }
      ],
    }),
    'network_data.json': const JsonEncoder.withIndent('  ').convert({
      'networks': [
        {'id': 'net-1', 'name': 'LAN', 'type': 'lan', 'modifiedAt': ts}
      ],
      'assignments': [
        {'networkId': 'net-1', 'deviceId': 'dev-1'}
      ],
    }),
    'dataset_data.json': const JsonEncoder.withIndent('  ').convert({
      'datasets': [
        {'id': 'ds-1', 'name': 'Dataset', 'modifiedAt': ts}
      ],
    }),
    'service_data.json': const JsonEncoder.withIndent('  ').convert({
      'services': [
        {
          'id': 'svc-1',
          'deviceId': 'dev-1',
          'name': 'Service',
          'modifiedAt': ts,
        }
      ],
      'routes': [
        {
          'id': 'route-1',
          'name': 'Route',
          'sourceServiceId': 'svc-1',
          'modifiedAt': ts,
        }
      ],
    }),
  };
  data.addAll(overrides ?? const {});
  return data;
}

/// One scenario sandbox: a fresh temp dir + fresh fake server + recorder.
class _Sandbox {
  _Sandbox(this.dir, this.server, this.recorder);
  final Directory dir;
  final FakeWebDAVServer server;
  final RequestRecorder recorder;

  String get appDir => p.join(dir.path, 'MyDevice');

  /// Remote path for a data file (server keys on full request path).
  String remote(String name) => '/dav/files/u/MyDevice/$name';

  Future<File> dataFile(String name) async => File(p.join(appDir, name));

  /// Write all local module files from [data].
  Future<void> writeLocalData(Map<String, String> data) async {
    await Directory(appDir).create(recursive: true);
    for (final entry in data.entries) {
      await (await dataFile(entry.key)).writeAsString(entry.value);
    }
  }

  /// Seed the remote store from [data].
  void seedRemote(Map<String, String> data) {
    for (final entry in data.entries) {
      server.seed(remote(entry.key), entry.value);
    }
  }

  /// Write base snapshots from [data].
  Future<void> writeBase(Map<String, String> data) async {
    final baseDir = Directory(p.join(appDir, '.sync_base'));
    await baseDir.create(recursive: true);
    for (final entry in data.entries) {
      await File(p.join(baseDir.path, entry.key)).writeAsString(entry.value);
    }
  }

  String transcript() => GoldenTranscript(recorder.exchanges).render();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final goldensDir =
      Directory(p.join('test', 'golden', 'goldens', 'mydevice'));

  Future<_Sandbox> newSandbox() async {
    final dir = await Directory.systemTemp.createTemp('mydevice_golden_');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
    final server = FakeWebDAVServer();
    final recorder = RequestRecorder(server);
    return _Sandbox(dir, server, recorder);
  }

  Future<void> expectGolden(_Sandbox sb, String name) async {
    final file = File(p.join(goldensDir.path, '$name.txt'));
    final mismatch =
        await GoldenMatcher(file, record: _record).check(sb.transcript());
    expect(mismatch, isNull, reason: 'golden "$name" mismatch:\n$mismatch');
  }

  Future<T> zone<T>(_Sandbox sb, Future<T> Function() body) =>
      runWithClient(body, () => sb.recorder);

  group('webdav sync request-sequence goldens', () {
    test('first sync (local data, empty remote)', () async {
      final sb = await newSandbox();
      await sb.writeLocalData(_dataSet());
      final result = await zone(sb, () => WebDAVService.sync(_config()));
      expect(result.success, isTrue, reason: result.error);
      await expectGolden(sb, 'sync_first');
      expect(sb.server.readText(sb.remote('device_data.json')),
          contains('Test Device'));
      await sb.dir.delete(recursive: true);
    });

    test('true conflict then finalize', () async {
      final sb = await newSandbox();
      final base = _dataSet();
      final local = _dataSet(overrides: {
        'device_data.json': const JsonEncoder.withIndent('  ').convert({
          'devices': [
            {
              'id': 'dev-1',
              'name': 'Local Name',
              'category': 'other',
              'modifiedAt': '2026-01-05T00:00:00.000Z',
            }
          ],
        }),
      });
      final remote = _dataSet(overrides: {
        'device_data.json': const JsonEncoder.withIndent('  ').convert({
          'devices': [
            {
              'id': 'dev-1',
              'name': 'Remote Name',
              'category': 'other',
              'modifiedAt': '2026-01-06T00:00:00.000Z',
            }
          ],
        }),
      });
      await sb.writeLocalData(local);
      sb.seedRemote(remote);
      await sb.writeBase(base);

      final syncResult = await zone(sb, () => WebDAVService.sync(_config()));
      expect(syncResult.pending, isNotNull,
          reason: 'both-changed-different must conflict');

      // Resolve: choose the remote record for each conflict id.
      final resolutions = <String, dynamic>{
        for (final c in syncResult.pending!.allConflicts) c.id: c.remoteRecord,
      };
      final fin = await zone(
          sb,
          () => WebDAVService.finalizePendingSync(
              _config(), syncResult.pending!, resolutions));
      expect(fin, isTrue);
      await expectGolden(sb, 'sync_conflict_finalize');
      expect(sb.server.readText(sb.remote('device_data.json')),
          contains('Remote Name'));
      await sb.dir.delete(recursive: true);
    });

    test('image add on each side (additive image sync)', () async {
      final sb = await newSandbox();
      // Local device references img_local.jpg; remote device references
      // img_remote.jpg.
      final local = _dataSet(overrides: {
        'device_data.json': const JsonEncoder.withIndent('  ').convert({
          'devices': [
            {
              'id': 'dev-1',
              'name': 'Test Device',
              'category': 'other',
              'imagePath': 'img_local.jpg',
              'modifiedAt': '2026-01-02T00:00:00.000Z',
            }
          ],
        }),
      });
      final remote = _dataSet(overrides: {
        'device_data.json': const JsonEncoder.withIndent('  ').convert({
          'devices': [
            {
              'id': 'dev-1',
              'name': 'Test Device',
              'category': 'other',
              'imagePath': 'img_remote.jpg',
              'modifiedAt': '2026-01-02T00:00:00.000Z',
            }
          ],
        }),
      });
      await sb.writeLocalData(local);
      final imgDir = Directory(p.join(sb.appDir, 'images'));
      await imgDir.create(recursive: true);
      await File(p.join(imgDir.path, 'img_local.jpg')).writeAsBytes([1, 2, 3]);
      sb.seedRemote(remote);
      sb.server.seed(sb.remote('images/img_remote.jpg'), [9, 9, 9]);
      await sb.writeBase(local);
      final result = await zone(sb, () => WebDAVService.sync(_config()));
      expect(result.success, isTrue, reason: result.error);
      await expectGolden(sb, 'sync_image_add_both_sides');
      expect(sb.server.exists(sb.remote('images/img_local.jpg')), isTrue);
      expect(await File(p.join(imgDir.path, 'img_remote.jpg')).exists(),
          isTrue);
      await sb.dir.delete(recursive: true);
    });
  });

  group('backup goldens (on-disk format)', () {
    test('corrupt bundle flagged in listBackups', () async {
      final sb = await newSandbox();
      BackupService.appDirProvider = () async => Directory(sb.appDir);
      final backupDir = Directory(p.join(sb.appDir, 'backups'));
      await backupDir.create(recursive: true);
      await File(p.join(backupDir.path, 'backup_20260101_000000.json'))
          .writeAsString('{corrupt not json');
      final list = await BackupService.listBackups();
      expect(list.single.corrupt, isTrue);
      BackupService.appDirProvider = null;
      await sb.dir.delete(recursive: true);
    });
  });

  group('zip goldens', () {
    test('import rejects an archive containing path traversal', () async {
      final sb = await newSandbox();
      final zip = _buildZip({
        '../evil.json': utf8.encode('{"devices":[]}'),
        'device_data.json': utf8.encode('{"devices":[]}'),
      });
      final zipFile = File(p.join(sb.dir.path, 'evil.zip'));
      await zipFile.writeAsBytes(zip);
      final ok = await ImportExportService.importZip(zipFile.path);
      // Accepted unification (step P3.3.3 of the myapps_data migration): MyDevice used to skip the bad
      // entry and import the rest. The shared engine classifies every entry
      // before writing any, so an archive containing a traversal entry is
      // rejected outright. Strictly safer — a tampered archive can no longer be
      // half-applied — and it matches MyDay's long-standing behavior.
      expect(ok, isFalse);
      expect(await File(p.join(sb.dir.path, 'evil.json')).exists(), isFalse,
          reason: 'traversal entry must not be written outside appDir');
      expect(await File(p.join(sb.appDir, 'device_data.json')).exists(), isFalse,
          reason: 'a rejected archive must not write any of its entries');
      await sb.dir.delete(recursive: true);
    });
  });
}

/// Build a ZIP in-memory from a name->bytes map.
List<int> _buildZip(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach((name, bytes) {
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive);
}
