import 'dart:convert';
import 'dart:io';

import '../../../shared/services/auto_sync_service.dart';
import '../../devices/services/device_storage.dart';
import '../models/service.dart';

class ServiceStorage {
  static const dataFileName = 'service_data.json';

  static Future<File> _getFile() async {
    final appDir = await DeviceStorage.getAppDir();
    return File('${appDir.path}/$dataFileName');
  }

  static Future<ServiceData> load() async {
    final file = await _getFile();
    if (!await file.exists()) return const ServiceData();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const ServiceData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ServiceData.fromJson(json);
  }

  static Future<void> save(ServiceData data) async {
    final file = await _getFile();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await file.writeAsString(jsonStr);
    AutoSyncService.instance.notifySaved();
  }

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
