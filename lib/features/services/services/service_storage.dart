import 'dart:convert';
import 'dart:io';

import '../../../app/data_modules.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../devices/services/device_storage.dart';
import '../models/service.dart';

class ServiceStorage {
  static const dataFileName = serviceDataFileName;

  /// Purpose: Serialise [operation] behind earlier writes of `services.json`.
  /// Inputs: `operation`.
  /// Returns: `Future<void>`.
  /// Side effects: See `DeviceStorage.serializeWrite`.
  /// Notes: Internal helper used within this file only.
  static Future<void> _serialised(Future<void> Function() operation) async {
    final file = await _getFile();
    return DeviceStorage.serializeWrite(file.path, operation);
  }

  /// Purpose: Provide the internal get file helper for this file.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  static Future<File> _getFile() async {
    final appDir = await DeviceStorage.getAppDir();
    return File('${appDir.path}/$dataFileName');
  }

  /// Purpose: Load the relevant data into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<ServiceData>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<ServiceData> load() async {
    final file = await _getFile();
    if (!await file.exists()) return const ServiceData();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const ServiceData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ServiceData.fromJson(json);
  }

  /// Purpose: Save the relevant data to the relevant storage or service layer.
  /// Inputs: `data`.
  /// Returns: `Future<void>`.
  /// Side effects: Atomically replaces `services.json` (queued behind earlier
  /// writes) and notifies auto-sync.
  /// Notes: Public entry point; enqueues [_write]. Code already running inside
  /// the write queue must call [_write], never this method (deadlock).
  static Future<void> save(ServiceData data) => _serialised(() => _write(data));

  /// Purpose: Write `services.json` atomically and notify auto-sync.
  /// Inputs: `data`.
  /// Returns: `Future<void>`.
  /// Side effects: tmp-file + rename write; calls `AutoSyncService.notifySaved`.
  /// Notes: Internal helper; the unqueued primitive used from inside [_serialised].
  static Future<void> _write(ServiceData data) async {
    final file = await _getFile();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await DeviceStorage.atomicWrite(file, jsonStr);
    AutoSyncService.instance.notifySaved();
  }

  /// Purpose: Add or update service through the current flow.
  /// Inputs: `service`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `services.json`.
  /// Notes: Keeps routes and unknown top-level fields (`extraJson`).
  static Future<void> addOrUpdateService(ServiceNode service) =>
      _serialised(() async {
        final data = await load();
        final services = List<ServiceNode>.of(data.services);
        final idx = services.indexWhere((s) => s.id == service.id);
        if (idx >= 0) {
          services[idx] = service;
        } else {
          services.add(service);
        }
        await _write(
          ServiceData(
            services: services,
            routes: data.routes,
            extraJson: data.extraJson,
          ),
        );
      });

  /// Purpose: Return [route] without the hops matched by [drop].
  /// Inputs: `route`, `drop` - predicate selecting hops to remove.
  /// Returns: The same [route] instance when no hop matched; otherwise a copy
  /// with the remaining hops (and a bumped `modifiedAt`).
  /// Side effects: None.
  /// Notes: Internal helper. Returning the untouched instance keeps
  /// `modifiedAt` stable on routes the operation did not affect, so a
  /// delete no longer makes every route look changed and cause false sync
  /// conflicts.
  static ServiceRoute _withoutHops(
    ServiceRoute route,
    bool Function(ServiceRouteHop hop) drop,
  ) {
    final kept = route.hops.where((hop) => !drop(hop)).toList();
    if (kept.length == route.hops.length) return route;
    return route.copyWith(hops: kept);
  }

  /// Purpose: Delete service from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `services.json`.
  /// Notes: Routes sourced at the service are removed; other routes lose only
  /// the hops through it, and only routes that actually lose a hop get a new
  /// `modifiedAt`.
  static Future<void> deleteService(String id) => _serialised(() async {
    final data = await load();
    final services = data.services.where((s) => s.id != id).toList();
    final routes = data.routes
        .where((route) => route.sourceServiceId != id)
        .map((route) => _withoutHops(route, (hop) => hop.serviceId == id))
        .toList();
    await _write(
      ServiceData(
        services: services,
        routes: routes,
        extraJson: data.extraJson,
      ),
    );
  });

  /// Purpose: Add or update route through the current flow.
  /// Inputs: `route`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `services.json`.
  /// Notes: Keeps services and unknown top-level fields (`extraJson`).
  static Future<void> addOrUpdateRoute(ServiceRoute route) =>
      _serialised(() async {
        final data = await load();
        final routes = List<ServiceRoute>.of(data.routes);
        final idx = routes.indexWhere((r) => r.id == route.id);
        if (idx >= 0) {
          routes[idx] = route;
        } else {
          routes.add(route);
        }
        await _write(
          ServiceData(
            services: data.services,
            routes: routes,
            extraJson: data.extraJson,
          ),
        );
      });

  /// Purpose: Delete route from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `services.json`.
  /// Notes: Keeps services and unknown top-level fields (`extraJson`).
  static Future<void> deleteRoute(String id) => _serialised(() async {
    final data = await load();
    await _write(
      ServiceData(
        services: data.services,
        routes: data.routes.where((r) => r.id != id).toList(),
        extraJson: data.extraJson,
      ),
    );
  });

  /// Purpose: Implement the remove device references behavior for this file.
  /// Inputs: `deviceId`.
  /// Returns: `Future<void>`.
  /// Side effects: Queued read-modify-write of `services.json`; writes nothing
  /// when the device is not referenced.
  /// Notes: Removes the device's services, routes sourced at them, and hops
  /// through the device or those services. Only routes that lose a hop get a
  /// new `modifiedAt`.
  static Future<void> removeDeviceReferences(String deviceId) => _serialised(
    () async {
      final data = await load();
      final removedServiceIds = data.services
          .where((service) => service.deviceId == deviceId)
          .map((service) => service.id)
          .toSet();
      final services = data.services
          .where((service) => service.deviceId != deviceId)
          .toList();
      final routes = data.routes
          .where((route) => !removedServiceIds.contains(route.sourceServiceId))
          .map(
            (route) => _withoutHops(
              route,
              (hop) =>
                  hop.deviceId == deviceId ||
                  removedServiceIds.contains(hop.serviceId),
            ),
          )
          .toList();

      final changed =
          services.length != data.services.length ||
          routes.length != data.routes.length ||
          routes.any((route) {
            final original = data.routes
                .where((r) => r.id == route.id)
                .firstOrNull;
            return original != null && !identical(original, route);
          });
      if (changed) {
        await _write(
          ServiceData(
            services: services,
            routes: routes,
            extraJson: data.extraJson,
          ),
        );
      }
    },
  );
}
