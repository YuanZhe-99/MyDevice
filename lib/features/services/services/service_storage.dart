import 'dart:convert';
import 'dart:io';

import '../../../shared/services/auto_sync_service.dart';
import '../../devices/services/device_storage.dart';
import '../models/service.dart';

class ServiceStorage {
  static const dataFileName = 'service_data.json';

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
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  static Future<void> save(ServiceData data) async {
    final file = await _getFile();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await file.writeAsString(jsonStr);
    AutoSyncService.instance.notifySaved();
  }

  /// Purpose: Add or update service through the current flow.
  /// Inputs: `service`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> addOrUpdateService(ServiceNode service) async {
    final data = await load();
    final services = List<ServiceNode>.of(data.services);
    final idx = services.indexWhere((s) => s.id == service.id);
    if (idx >= 0) {
      services[idx] = service;
    } else {
      services.add(service);
    }
    await save(
      ServiceData(
        services: services,
        routes: data.routes,
        extraJson: data.extraJson,
      ),
    );
  }

  /// Purpose: Delete service from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> deleteService(String id) async {
    final data = await load();
    final services = data.services.where((s) => s.id != id).toList();
    final routes = data.routes
        .where((route) => route.sourceServiceId != id)
        .map(
          (route) => route.copyWith(
            hops: route.hops.where((hop) => hop.serviceId != id).toList(),
          ),
        )
        .toList();
    await save(
      ServiceData(
        services: services,
        routes: routes,
        extraJson: data.extraJson,
      ),
    );
  }

  /// Purpose: Add or update route through the current flow.
  /// Inputs: `route`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> addOrUpdateRoute(ServiceRoute route) async {
    final data = await load();
    final routes = List<ServiceRoute>.of(data.routes);
    final idx = routes.indexWhere((r) => r.id == route.id);
    if (idx >= 0) {
      routes[idx] = route;
    } else {
      routes.add(route);
    }
    await save(
      ServiceData(
        services: data.services,
        routes: routes,
        extraJson: data.extraJson,
      ),
    );
  }

  /// Purpose: Delete route from the relevant storage or state.
  /// Inputs: `id`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> deleteRoute(String id) async {
    final data = await load();
    await save(
      ServiceData(
        services: data.services,
        routes: data.routes.where((r) => r.id != id).toList(),
        extraJson: data.extraJson,
      ),
    );
  }

  /// Purpose: Implement the remove device references behavior for this file.
  /// Inputs: `deviceId`.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> removeDeviceReferences(String deviceId) async {
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
          (route) => route.copyWith(
            hops: route.hops
                .where(
                  (hop) =>
                      hop.deviceId != deviceId &&
                      !removedServiceIds.contains(hop.serviceId),
                )
                .toList(),
          ),
        )
        .toList();

    if (services.length != data.services.length ||
        routes.length != data.routes.length ||
        routes.any((route) {
          final original = data.routes
              .where((r) => r.id == route.id)
              .firstOrNull;
          return original != null && original.hops.length != route.hops.length;
        })) {
      await save(
        ServiceData(
          services: services,
          routes: routes,
          extraJson: data.extraJson,
        ),
      );
    }
  }
}
