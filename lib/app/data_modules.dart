/// Purpose: Single source of truth describing MyDevice's syncable data files to
/// the shared `myapps_data` engines.
/// Inputs: `DeviceStorage` for storage paths/settings, the per-module merge
/// wrappers in `sync_merge.dart`, and the feature models for parsing.
/// Returns: A `StorageAdapter` implementation and the app's `ModuleRegistry`.
/// Side effects: None at import time; callbacks perform parsing and storage I/O.
/// Notes: PLAN.md P3.3.2. Registry order is the sync/backup/progress order and
/// matches the previous `_dataFileNames` list exactly. File names and module
/// IDs are persisted compatibility contracts (I1/I2) and must never change.
library;

import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart';
import 'package:path/path.dart' as p;

import '../features/datasets/models/dataset.dart';
import '../features/devices/models/device.dart';
import '../features/devices/services/device_storage.dart';
import '../features/network/models/network.dart';
import '../features/services/models/service.dart';
import '../shared/services/sync_merge.dart';

/// Pretty-printer matching `DeviceStorage`'s local save format.
///
/// Sync writes must use the same indentation the storage hub uses, otherwise an
/// otherwise-unchanged file misses the raw-equality fast path on the next sync
/// and re-uploads forever (I6).
const _prettyJson = JsonEncoder.withIndent('  ');

/// Purpose: Bridge the shared engines to MyDevice's storage hub.
/// Inputs: Optional [appDir] resolver overriding the hub lookup.
/// Returns: Storage root and `storage_config.json` access.
/// Side effects: Delegates to `DeviceStorage`, which performs file I/O.
/// Notes: [appDir] exists so `BackupService` can keep honoring its
/// `@visibleForTesting appDirProvider` seam (I7); it is read on every call, so
/// tests that swap the provider between cases still work.
class DeviceStorageAdapter implements StorageAdapter {
  /// Purpose: Create an adapter over `DeviceStorage`.
  /// Inputs: Optional [appDir] resolver.
  /// Returns: A new adapter.
  /// Side effects: None.
  /// Notes: Pass [appDir] only to preserve an existing test seam.
  const DeviceStorageAdapter({Future<Directory> Function()? appDir})
    : _appDir = appDir;

  final Future<Directory> Function()? _appDir;

  /// Purpose: Resolve the active app data directory.
  /// Inputs: None.
  /// Returns: The custom storage path when configured, else the platform dir.
  /// Side effects: May create the directory via the hub.
  /// Notes: Honors the injected resolver first so `appDirProvider` still wins.
  @override
  Future<Directory> getAppDir() => (_appDir ?? DeviceStorage.getAppDir)();

  /// Purpose: Read `storage_config.json`.
  /// Inputs: None.
  /// Returns: The parsed settings map.
  /// Side effects: Reads local storage.
  /// Notes: Delegates so app-owned keys stay owned by the hub.
  @override
  Future<Map<String, dynamic>> readConfig() => DeviceStorage.readConfig();

  /// Purpose: Persist `storage_config.json`.
  /// Inputs: [config] complete settings map.
  /// Returns: A future completing after the write.
  /// Side effects: Writes local storage.
  /// Notes: The engines read-modify-write, so unknown keys survive.
  @override
  Future<void> writeConfig(Map<String, dynamic> config) =>
      DeviceStorage.writeConfig(config);
}

/// Default remote WebDAV directory for MyDevice.
const deviceDefaultRemotePath = '/MyDevice';

/// Archive name prefix for ZIP exports.
const deviceArchiveNamePrefix = 'mydevice_export_';

/// Data file holding devices — also the source of referenced images.
const deviceDataFileName = 'device_data.json';

/// Backup module key for [deviceDataFileName].
const deviceModuleId = 'devices';

/// Purpose: Extract device image basenames referenced by device records.
/// Inputs: [json] raw or merged `device_data.json`.
/// Returns: Referenced image basenames; empty for malformed input.
/// Side effects: None.
/// Notes: Devices are the only image source in MyDevice; the engine unions the
/// local and remote results, reproducing the previous behavior exactly.
Set<String> deviceReferencedImages(String json) {
  try {
    final data = DeviceData.fromJson(jsonDecode(json) as Map<String, dynamic>);
    return data.devices
        .map((d) => d.imagePath)
        .whereType<String>()
        .map(p.basename)
        .toSet();
  } catch (_) {
    return {};
  }
}

/// Purpose: Build a module whose merge wrapper yields one record container.
/// Inputs: [fileName], [moduleId], [validate], [merge] wrapper adapters.
/// Returns: A configured [DataModule].
/// Side effects: None.
/// Notes: Devices, networks, and datasets all share this shape; services needs
/// its own because it merges two record containers.
DataModule _singleContainerModule<R, D>({
  required String fileName,
  required String moduleId,
  required void Function(String json) validate,
  required _SingleMerge<R, D> merge,
  ModuleImageReferences? referencedImages,
}) {
  return DataModule(
    fileName: fileName,
    moduleId: moduleId,
    validate: validate,
    merge:
        ({
          required String localJson,
          required String remoteJson,
          required String? baseJson,
          required bool autoResolve,
        }) {
          final result = merge.run(
            localJson,
            remoteJson,
            baseJson,
            autoResolve,
          );
          if (!merge.hasConflicts(result)) {
            return ModuleMergeOutcome(
              mergedJson: _prettyJson.convert(merge.encodeMerged(result)),
              state: result,
            );
          }
          return ModuleMergeOutcome(
            state: result,
            conflicts: [
              for (final conflict in merge.conflicts(result))
                ModuleConflict(
                  id: conflict.id,
                  localRecord: conflict.localRecord as Object,
                  remoteRecord: conflict.remoteRecord as Object,
                  displayName: conflict.displayName,
                ),
            ],
            buildResolvedJson: (resolutions) =>
                _prettyJson.convert(merge.encodeResolved(result, resolutions)),
          );
        },
    referencedImages: referencedImages,
  );
}

/// Adapter bundling the callbacks one single-container merge wrapper needs.
class _SingleMerge<R, D> {
  /// Purpose: Bundle a merge wrapper's callbacks.
  /// Inputs: Wrapper entry point and result accessors.
  /// Returns: A new adapter.
  /// Side effects: None.
  /// Notes: Keeps `_singleContainerModule` free of per-model knowledge.
  const _SingleMerge({
    required this.run,
    required this.hasConflicts,
    required this.conflicts,
    required this.encodeMerged,
    required this.encodeResolved,
  });

  /// Invokes the app's merge wrapper.
  final R Function(String local, String remote, String? base, bool autoResolve)
  run;

  /// Whether the wrapper produced unresolved conflicts.
  final bool Function(R result) hasConflicts;

  /// The wrapper's conflict list.
  final List<RecordConflict<D>> Function(R result) conflicts;

  /// Serializable form of a conflict-free merge.
  final Map<String, dynamic> Function(R result) encodeMerged;

  /// Serializable form after applying user choices.
  final Map<String, dynamic> Function(R result, Map<String, Object?> choices)
  encodeResolved;
}

/// Purpose: Describe `device_data.json` to the shared engines.
/// Inputs: None.
/// Returns: The devices [DataModule].
/// Side effects: None.
/// Notes: The only module contributing referenced images.
DataModule buildDevicesModule() => _singleContainerModule<DeviceMergeResult, Device>(
  fileName: deviceDataFileName,
  moduleId: deviceModuleId,
  validate: (json) =>
      DeviceData.fromJson(jsonDecode(json) as Map<String, dynamic>),
  referencedImages: deviceReferencedImages,
  merge: _SingleMerge<DeviceMergeResult, Device>(
    run: (local, remote, base, autoResolve) =>
        mergeDeviceData(local, remote, base, autoResolve: autoResolve),
    hasConflicts: (r) => r.hasConflicts,
    conflicts: (r) => r.conflicts,
    encodeMerged: (r) =>
        DeviceData(devices: r.merged, extraJson: r.extraJson).toJson(),
    encodeResolved: (r, choices) => r
        .buildResolved({
          for (final entry in choices.entries)
            if (entry.value is Device) entry.key: entry.value as Device,
        })
        .toJson(),
  ),
);

/// Purpose: Describe `network_data.json` to the shared engines.
/// Inputs: None.
/// Returns: The networks [DataModule].
/// Side effects: None.
/// Notes: `mergeNetworkData` also runs `mergeAssignments`, MyDevice's
/// composite-key merge for `NetworkDevice` records that carry no timestamps.
/// That stays app-side.
DataModule buildNetworksModule() =>
    _singleContainerModule<NetworkMergeResult, Network>(
      fileName: 'network_data.json',
      moduleId: 'networks',
      validate: (json) =>
          NetworkData.fromJson(jsonDecode(json) as Map<String, dynamic>),
      merge: _SingleMerge<NetworkMergeResult, Network>(
        run: (local, remote, base, autoResolve) =>
            mergeNetworkData(local, remote, base, autoResolve: autoResolve),
        hasConflicts: (r) => r.hasConflicts,
        conflicts: (r) => r.conflicts,
        encodeMerged: (r) => r.buildResolved(const {}).toJson(),
        encodeResolved: (r, choices) => r
            .buildResolved({
              for (final entry in choices.entries)
                if (entry.value is Network) entry.key: entry.value as Network,
            })
            .toJson(),
      ),
    );

/// Purpose: Describe `dataset_data.json` to the shared engines.
/// Inputs: None.
/// Returns: The datasets [DataModule].
/// Side effects: None.
/// Notes: None.
DataModule buildDataSetsModule() =>
    _singleContainerModule<DataSetMergeResult, DataSet>(
      fileName: 'dataset_data.json',
      moduleId: 'datasets',
      validate: (json) =>
          DataSetData.fromJson(jsonDecode(json) as Map<String, dynamic>),
      merge: _SingleMerge<DataSetMergeResult, DataSet>(
        run: (local, remote, base, autoResolve) =>
            mergeDataSetData(local, remote, base, autoResolve: autoResolve),
        hasConflicts: (r) => r.hasConflicts,
        conflicts: (r) => r.conflicts,
        encodeMerged: (r) => r.buildResolved(const {}).toJson(),
        encodeResolved: (r, choices) => r
            .buildResolved({
              for (final entry in choices.entries)
                if (entry.value is DataSet) entry.key: entry.value as DataSet,
            })
            .toJson(),
      ),
    );

/// Purpose: Describe `service_data.json` to the shared engines.
/// Inputs: None.
/// Returns: The services [DataModule].
/// Side effects: None.
/// Notes: Services merge two record containers (nodes and routes), so this one
/// is built directly. `ServiceMergeResult.buildResolved` already disambiguates
/// a shared ID by runtime type, so plain record IDs remain valid resolution
/// keys and no namespacing is needed.
DataModule buildServicesModule() => DataModule(
  fileName: 'service_data.json',
  moduleId: 'services',
  validate: (json) =>
      ServiceData.fromJson(jsonDecode(json) as Map<String, dynamic>),
  merge:
      ({
        required String localJson,
        required String remoteJson,
        required String? baseJson,
        required bool autoResolve,
      }) {
        final result = mergeServiceData(
          localJson,
          remoteJson,
          baseJson,
          autoResolve: autoResolve,
        );
        if (!result.hasConflicts) {
          return ModuleMergeOutcome(
            mergedJson: _prettyJson.convert(
              result.buildResolved(const {}).toJson(),
            ),
            state: result,
          );
        }
        return ModuleMergeOutcome(
          state: result,
          conflicts: [
            for (final conflict in result.allConflicts)
              ModuleConflict(
                id: conflict.id,
                localRecord: conflict.localRecord as Object,
                remoteRecord: conflict.remoteRecord as Object,
                displayName: conflict.displayName,
              ),
          ],
          buildResolvedJson: (resolutions) => _prettyJson.convert(
            result.buildResolved(Map<String, dynamic>.from(resolutions)).toJson(),
          ),
        );
      },
);

/// Purpose: Provide MyDevice's ordered module registry.
/// Inputs: None.
/// Returns: A registry holding devices, networks, datasets, and services.
/// Side effects: None.
/// Notes: Order matches the previous hardcoded `_dataFileNames` list and is
/// behaviorally significant for sync order, progress, and backup key order.
final ModuleRegistry deviceModuleRegistry = ModuleRegistry([
  buildDevicesModule(),
  buildNetworksModule(),
  buildDataSetsModule(),
  buildServicesModule(),
]);
