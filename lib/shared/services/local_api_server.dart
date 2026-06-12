import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../features/datasets/models/dataset.dart';
import '../../features/datasets/services/dataset_storage.dart';
import '../../features/devices/models/device.dart';
import '../../features/devices/services/device_storage.dart';
import '../../features/network/models/network.dart';
import '../../features/network/services/network_storage.dart';
import '../../features/services/models/service.dart';
import '../../features/services/services/service_storage.dart';

class LocalApiServer {
  static HttpServer? _server;
  static int _port = 7789;
  static String _listenAddress = 'localhost';
  static bool _enabled = false;
  static String? _username;
  static String? _password;
  static String? _lastError;

  /// Purpose: Return the current port value.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: None.
  static int get port => _port;

  /// Purpose: Collect and return en address.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  static String get listenAddress => _listenAddress;

  /// Purpose: Return the current enabled value.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  static bool get enabled => _enabled;

  /// Purpose: Return whether running is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  static bool get isRunning => _server != null;

  /// Purpose: Return the current last error value.
  /// Inputs: None.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: None.
  static String? get lastError => _lastError;

  /// Purpose: Load config into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> loadConfig() async {
    final config = await DeviceStorage.readConfig();
    _port = config['apiPort'] as int? ?? 7789;
    _listenAddress = config['apiListenAddress'] as String? ?? 'localhost';
    _enabled = config['apiEnabled'] as bool? ?? false;
    _username = config['apiUsername'] as String?;
    _password = config['apiPassword'] as String?;
  }

  /// Purpose: Start the current workflow for the current workflow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> start() async {
    await loadConfig();
    await stop();
    _lastError = null;
    if (!_enabled) return;

    final isNonLoopback =
        _listenAddress == '0.0.0.0' ||
        (_listenAddress != 'localhost' && _listenAddress != '127.0.0.1');
    final hasCredentials =
        _username != null &&
        _username!.isNotEmpty &&
        _password != null &&
        _password!.isNotEmpty;
    if (isNonLoopback && !hasCredentials) {
      _lastError = 'credentials_required';
      return;
    }

    final router = Router();
    router.get('/ping', _handlePing);
    router.get('/device/list', _handleList);
    router.get('/device/search', _handleSearch);
    router.post('/device/add', _handleAdd);
    router.get('/device/stats', _handleStats);
    router.get('/network/list', _handleNetworkList);
    router.get('/network/search', _handleNetworkSearch);
    router.get('/dataset/list', _handleDatasetList);
    router.get('/dataset/search', _handleDatasetSearch);
    router.get('/service/list', _handleServiceList);
    router.get('/service/search', _handleServiceSearch);
    router.get('/service/routes', _handleServiceRoutes);
    router.get('/service/stats', _handleServiceStats);

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addMiddleware(_errorMiddleware())
        .addHandler(router.call);

    try {
      final InternetAddress bindAddress;
      if (_listenAddress == '0.0.0.0') {
        bindAddress = InternetAddress.anyIPv4;
      } else if (_listenAddress == 'localhost' ||
          _listenAddress == '127.0.0.1') {
        bindAddress = InternetAddress.loopbackIPv4;
      } else {
        bindAddress = InternetAddress(
          _listenAddress,
          type: InternetAddressType.any,
        );
      }
      _server = await shelf_io.serve(handler, bindAddress, _port);
      // ignore: avoid_print
      print('[LocalApiServer] listening on port $_port');
    } catch (e) {
      _lastError = e.toString();
      // ignore: avoid_print
      print('[LocalApiServer] failed to start: $e');
    }
  }

  /// Purpose: Stop the current workflow and clean up any related activity.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// Purpose: Implement the restart behavior for this file.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<void> restart() async {
    await loadConfig();
    await start();
  }

  // ── Route handlers ──

  /// Purpose: Handle ping and trigger the appropriate follow-up work.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Future<Response> _handlePing(Request request) async {
    return _json({'status': 'ok'});
  }

  /// Purpose: Return saved devices, optionally filtered by category.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads device storage.
  /// Notes: Category values match `DeviceCategory.name`.
  static Future<Response> _handleList(Request request) async {
    final data = await DeviceStorage.load();
    final category = request.url.queryParameters['category'];

    var devices = data.devices;
    if (category != null && category.isNotEmpty) {
      final cat = DeviceCategory.values
          .where((e) => e.name == category)
          .firstOrNull;
      if (cat == null) {
        return _error(400, 'invalid category: $category');
      }
      devices = devices.where((d) => d.category == cat).toList();
    }

    return _json(devices.map(_deviceToJson).toList());
  }

  /// Purpose: Search saved devices by human-readable inventory fields.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads device storage.
  /// Notes: Returns an empty list when there are no matches.
  static Future<Response> _handleSearch(Request request) async {
    final q = request.url.queryParameters['q']?.trim();
    if (q == null || q.isEmpty) {
      return _error(400, 'q parameter is required');
    }
    final data = await DeviceStorage.load();
    final matches = filterDevicesForSearch(devices: data.devices, query: q);
    return _json(matches.map(_deviceToJson).toList());
  }

  /// Purpose: Add a device from a JSON request body.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Writes device storage and can trigger auto-sync.
  /// Notes: Unknown or malformed optional fields are ignored rather than blocking minimal adds.
  static Future<Response> _handleAdd(Request request) async {
    final body = await _parseBody(request);
    if (body == null) return _error(400, 'invalid JSON body');

    final name = body['name'] as String?;
    final categoryStr = body['category'] as String?;
    if (name == null || name.isEmpty) {
      return _error(400, 'name is required');
    }
    if (categoryStr == null || categoryStr.isEmpty) {
      return _error(400, 'category is required');
    }
    final category = DeviceCategory.values
        .where((e) => e.name == categoryStr)
        .firstOrNull;
    if (category == null) {
      return _error(400, 'invalid category: $categoryStr');
    }

    CpuInfo cpu = const CpuInfo();
    if (body['cpu'] is Map<String, dynamic>) {
      final c = body['cpu'] as Map<String, dynamic>;
      cpu = CpuInfo(
        model: c['model'] as String?,
        architecture: c['architecture'] as String?,
        frequency: c['frequency'] as String?,
        performanceCores: c['performanceCores'] as int?,
        efficiencyCores: c['efficiencyCores'] as int?,
        threads: c['threads'] as int?,
        cache: c['cache'] as String?,
      );
    }

    GpuInfo gpu = const GpuInfo();
    if (body['gpu'] is Map<String, dynamic>) {
      final g = body['gpu'] as Map<String, dynamic>;
      gpu = GpuInfo(
        model: g['model'] as String?,
        architecture: g['architecture'] as String?,
      );
    }

    List<StorageInfo> storageList = [];
    if (body['storage'] is List) {
      storageList = (body['storage'] as List).map((s) {
        if (s is Map<String, dynamic>) {
          return StorageInfo(
            capacity: s['capacity'] as String?,
            type: StorageType.fromJson(s['type'] as String?),
            interface_: StorageInterface.fromJson(s['interface'] as String?),
            serialNumber: s['serialNumber'] as String?,
            brand: s['brand'] as String?,
          );
        }
        return const StorageInfo();
      }).toList();
    }

    final recurringCosts = (body['recurringCosts'] is List)
        ? (body['recurringCosts'] as List<dynamic>)
              .map(_recurringCostFromJson)
              .whereType<DeviceRecurringCost>()
              .toList()
        : const <DeviceRecurringCost>[];

    final device = Device(
      name: name,
      category: category,
      emoji: body['emoji'] as String?,
      imagePath: body['imagePath'] as String?,
      brand: body['brand'] as String?,
      model: body['model'] as String?,
      serialNumber: body['serialNumber'] as String?,
      cpu: cpu,
      gpu: gpu,
      ram: body['ram'] as String?,
      ramType: RamType.fromJson(body['ramType'] as String?),
      storage: storageList,
      screenSize: body['screenSize'] as String?,
      screenResolutionW: _intValue(body['screenResolutionW']),
      screenResolutionH: _intValue(body['screenResolutionH']),
      battery: body['battery'] as String?,
      os: body['os'] as String?,
      locationName: body['locationName'] as String?,
      latitude: _doubleValue(body['latitude']),
      longitude: _doubleValue(body['longitude']),
      purchaseDate: _dateValue(body['purchaseDate']),
      releaseDate: _dateValue(body['releaseDate']),
      acquisitionType: DeviceAcquisitionType.fromJson(
        body['acquisitionType'] as String?,
      ),
      isRetired: body['isRetired'] as bool? ?? false,
      retiredDate: _dateValue(body['retiredDate']),
      purchasePrice: _moneyValueFromJson(body['purchasePrice']),
      isSold: body['isSold'] as bool? ?? false,
      soldPrice: _moneyValueFromJson(body['soldPrice']),
      recurringCosts: recurringCosts,
      notes: body['notes'] as String?,
    );

    await DeviceStorage.addOrUpdate(device);
    return _json({'success': true, 'id': device.id, 'name': device.name});
  }

  /// Purpose: Return cross-module summary statistics for the local API.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads device, service, network, and dataset storage.
  /// Notes: Keeps the existing top-level device summary fields for compatibility.
  static Future<Response> _handleStats(Request request) async {
    final data = await DeviceStorage.load();
    final serviceData = await ServiceStorage.load();
    final networkData = await NetworkStorage.load();
    final dataSetData = await DataSetStorage.load();
    final devices = data.devices;

    return _json(
      buildStatsJson(
        devices: devices,
        services: serviceData.services,
        routes: serviceData.routes,
        networks: networkData.networks,
        assignments: networkData.assignments,
        datasets: dataSetData.datasets,
      ),
    );
  }

  /// Purpose: Return saved networks with enriched assignment details.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads network and device storage.
  /// Notes: This endpoint is read-only.
  static Future<Response> _handleNetworkList(Request request) async {
    final networkData = await NetworkStorage.load();
    final deviceData = await DeviceStorage.load();
    return _json(
      buildNetworkListJson(
        networks: networkData.networks,
        assignments: networkData.assignments,
        devices: deviceData.devices,
      ),
    );
  }

  /// Purpose: Search saved networks and their device assignments.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads network and device storage.
  /// Notes: Searches network names, addressing fields, notes, and assignment host/IP data.
  static Future<Response> _handleNetworkSearch(Request request) async {
    final q = request.url.queryParameters['q']?.trim();
    if (q == null || q.isEmpty) {
      return _error(400, 'q parameter is required');
    }
    final networkData = await NetworkStorage.load();
    final deviceData = await DeviceStorage.load();
    final matches = filterNetworksForSearch(
      networks: networkData.networks,
      assignments: networkData.assignments,
      devices: deviceData.devices,
      query: q,
    );
    return _json(
      buildNetworkListJson(
        networks: matches,
        assignments: networkData.assignments,
        devices: deviceData.devices,
      ),
    );
  }

  /// Purpose: Return saved datasets with linked device storage details.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads dataset and device storage.
  /// Notes: This endpoint is read-only.
  static Future<Response> _handleDatasetList(Request request) async {
    final dataSetData = await DataSetStorage.load();
    final deviceData = await DeviceStorage.load();
    return _json(
      buildDataSetListJson(
        datasets: dataSetData.datasets,
        devices: deviceData.devices,
      ),
    );
  }

  /// Purpose: Search saved datasets and their linked device storage slots.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads dataset and device storage.
  /// Notes: Searches dataset names plus linked device and storage summaries.
  static Future<Response> _handleDatasetSearch(Request request) async {
    final q = request.url.queryParameters['q']?.trim();
    if (q == null || q.isEmpty) {
      return _error(400, 'q parameter is required');
    }
    final dataSetData = await DataSetStorage.load();
    final deviceData = await DeviceStorage.load();
    final matches = filterDataSetsForSearch(
      datasets: dataSetData.datasets,
      devices: deviceData.devices,
      query: q,
    );
    return _json(
      buildDataSetListJson(datasets: matches, devices: deviceData.devices),
    );
  }

  /// Purpose: Return saved service nodes with optional simple filters.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads service, device, and network storage.
  /// Notes: Filter values use serialized enum names where applicable.
  static Future<Response> _handleServiceList(Request request) async {
    final params = request.url.queryParameters;
    final serviceData = await ServiceStorage.load();
    final deviceData = await DeviceStorage.load();
    final networkData = await NetworkStorage.load();
    final services = filterServicesForList(
      services: serviceData.services,
      deviceId: params['deviceId'],
      kind: params['kind'],
      state: params['state'],
    );
    return _json(
      buildServiceListJson(
        services: services,
        devices: deviceData.devices,
        networks: networkData.networks,
      ),
    );
  }

  /// Purpose: Search saved service nodes by name, device, endpoint, tags, and notes.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads service, device, and network storage.
  /// Notes: This endpoint does not scan live ports or inspect running services.
  static Future<Response> _handleServiceSearch(Request request) async {
    final q = request.url.queryParameters['q']?.trim();
    if (q == null || q.isEmpty) {
      return _error(400, 'q parameter is required');
    }
    final serviceData = await ServiceStorage.load();
    final deviceData = await DeviceStorage.load();
    final networkData = await NetworkStorage.load();
    final matches = filterServicesForSearch(
      services: serviceData.services,
      devices: deviceData.devices,
      networks: networkData.networks,
      query: q,
    );
    return _json(
      buildServiceListJson(
        services: matches,
        devices: deviceData.devices,
        networks: networkData.networks,
      ),
    );
  }

  /// Purpose: Return saved service access routes.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads service and device storage.
  /// Notes: Route names may be generated; callers should prefer notes/final targets for display.
  static Future<Response> _handleServiceRoutes(Request request) async {
    final serviceData = await ServiceStorage.load();
    final deviceData = await DeviceStorage.load();
    return _json(
      buildServiceRouteListJson(
        routes: serviceData.routes,
        services: serviceData.services,
        devices: deviceData.devices,
      ),
    );
  }

  /// Purpose: Return service-specific summary statistics.
  /// Inputs: `request`.
  /// Returns: `Future<Response>`.
  /// Side effects: Reads service storage.
  /// Notes: This is a narrower companion to `/device/stats`.
  static Future<Response> _handleServiceStats(Request request) async {
    final serviceData = await ServiceStorage.load();
    return _json(
      buildServiceStatsJson(
        services: serviceData.services,
        routes: serviceData.routes,
      ),
    );
  }

  /// Purpose: Build cross-module stats JSON for API responses and tests.
  /// Inputs: `devices`, `services`, `routes`, plus optional network and dataset lists.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: The `total`, `byCategory`, `recentlyAdded`, and `services` fields remain stable.
  static Map<String, dynamic> buildStatsJson({
    required List<Device> devices,
    required List<ServiceNode> services,
    required List<ServiceRoute> routes,
    List<Network> networks = const [],
    List<NetworkDevice> assignments = const [],
    List<DataSet> datasets = const [],
  }) {
    final byCategory = <String, int>{};
    for (final d in devices) {
      byCategory[d.category.name] = (byCategory[d.category.name] ?? 0) + 1;
    }
    final byLifecycle = <String, int>{
      for (final status in DeviceLifecycleStatus.values) status.name: 0,
    };
    for (final d in devices) {
      byLifecycle[d.lifecycleStatus.name] =
          (byLifecycle[d.lifecycleStatus.name] ?? 0) + 1;
    }

    final sorted = List<Device>.of(devices)
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    final recent = sorted
        .take(5)
        .map((d) => {'id': d.id, 'name': d.name, 'category': d.category.name})
        .toList();

    final financeDevices = devices.where((d) => d.hasFinancialData).toList();
    final dailyCosts = financeDevices
        .map((d) => d.averageDailyCost())
        .whereType<double>()
        .toList();

    return {
      'total': devices.length,
      'byCategory': byCategory,
      'byLifecycle': byLifecycle,
      'recentlyAdded': recent,
      'finance': {
        'devices': financeDevices.length,
        'totalCost': financeDevices.fold<double>(
          0,
          (sum, device) => sum + device.totalCost(),
        ),
        'averageDailyCost': dailyCosts.isEmpty
            ? null
            : dailyCosts.fold<double>(0, (sum, value) => sum + value) /
                  dailyCosts.length,
      },
      'services': {
        'total': services.length,
        'routes': routes.length,
        'devices': services.map((s) => s.deviceId).toSet().length,
        'endpoints': services.fold<int>(
          0,
          (sum, service) => sum + service.endpoints.length,
        ),
        'byKind': _countBy(services, (service) => service.kind.name),
        'byState': _countBy(services, (service) => service.state.name),
      },
      'networks': {
        'total': networks.length,
        'assignments': assignments.length,
        'byType': _countBy(networks, (network) => network.type.name),
      },
      'datasets': {
        'total': datasets.length,
        'storageLinks': datasets.fold<int>(
          0,
          (sum, dataset) => sum + dataset.storageLinks.length,
        ),
        'linkedDevices': datasets
            .expand(
              (dataset) => dataset.storageLinks.map((link) => link.deviceId),
            )
            .toSet()
            .length,
      },
    };
  }

  // ── Helpers ──

  /// Purpose: Serialize a device into the local API response shape.
  /// Inputs: `device`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Keeps legacy keys while adding lifecycle, location, image, and finance fields.
  static Map<String, dynamic> deviceToJson(Device device) => {
    'id': device.id,
    'name': device.name,
    'category': device.category.name,
    'emoji': device.emoji,
    'imagePath': device.imagePath,
    'brand': device.brand,
    'model': device.model,
    'serialNumber': device.serialNumber,
    'cpu': {
      'model': device.cpu.model,
      'architecture': device.cpu.architecture,
      'frequency': device.cpu.frequency,
      'performanceCores': device.cpu.performanceCores,
      'efficiencyCores': device.cpu.efficiencyCores,
      'threads': device.cpu.threads,
      'cache': device.cpu.cache,
    },
    'gpu': {'model': device.gpu.model, 'architecture': device.gpu.architecture},
    'ram': device.ram,
    'ramType': device.ramType?.name,
    'storage': device.storage.map(storageToJson).toList(),
    'screenSize': device.screenSize,
    'screenResolutionW': device.screenResolutionW,
    'screenResolutionH': device.screenResolutionH,
    'battery': device.battery,
    'os': device.os,
    'locationName': device.locationName,
    'latitude': device.latitude,
    'longitude': device.longitude,
    'purchaseDate': device.purchaseDate?.toIso8601String(),
    'releaseDate': device.releaseDate?.toIso8601String(),
    'acquisitionType': device.acquisitionType?.name,
    'lifecycleStatus': device.lifecycleStatus.name,
    'isRetired': device.isRetired,
    'retiredDate': device.retiredDate?.toIso8601String(),
    'purchasePrice': device.purchasePrice?.toJson(),
    'isSold': device.isSold,
    'soldPrice': device.soldPrice?.toJson(),
    'recurringCosts': device.recurringCosts
        .map((cost) => cost.toJson())
        .toList(),
    'finance': {
      'hasFinancialData': device.hasFinancialData,
      'serviceDays': device.serviceDays(),
      'recurringCostThrough': device.recurringCostThrough(),
      'totalCost': device.totalCost(),
      'averageDailyCost': device.averageDailyCost(),
    },
    'notes': device.notes,
    'modifiedAt': device.modifiedAt.toIso8601String(),
  };

  /// Purpose: Serialize storage information for device and dataset API responses.
  /// Inputs: `storage`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Includes brand and serial number added after the original API contract.
  static Map<String, dynamic> storageToJson(StorageInfo storage) => {
    'capacity': storage.capacity,
    'type': storage.type?.name,
    'interface': storage.interface_?.name,
    'serialNumber': storage.serialNumber,
    'brand': storage.brand,
  };

  /// Purpose: Filter devices for a case-insensitive local API search query.
  /// Inputs: `devices`, `query`.
  /// Returns: Matching devices in original order.
  /// Side effects: None.
  /// Notes: Searches inventory fields only and never performs online lookup.
  static List<Device> filterDevicesForSearch({
    required List<Device> devices,
    required String query,
  }) {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return const [];
    return devices.where((device) {
      return _containsText([
        device.name,
        device.category.name,
        device.brand,
        device.model,
        device.serialNumber,
        device.cpu.model,
        device.cpu.architecture,
        device.gpu.model,
        device.gpu.architecture,
        device.ram,
        device.ramType?.name,
        device.os,
        device.locationName,
        device.acquisitionType?.name,
        device.lifecycleStatus.name,
        device.notes,
        ...device.storage.expand(
          (storage) => [
            storage.capacity,
            storage.type?.name,
            storage.interface_?.name,
            storage.brand,
            storage.serialNumber,
          ],
        ),
      ], lower);
    }).toList();
  }

  /// Purpose: Serialize networks with assignment details for API responses.
  /// Inputs: `networks`, `assignments`, `devices`.
  /// Returns: JSON-compatible list.
  /// Side effects: None.
  /// Notes: Assignments are grouped under their network record.
  static List<Map<String, dynamic>> buildNetworkListJson({
    required List<Network> networks,
    required List<NetworkDevice> assignments,
    required List<Device> devices,
  }) {
    final deviceNames = _deviceNameMap(devices);
    return networks
        .map(
          (network) => networkToJson(
            network,
            assignments: assignments
                .where((assignment) => assignment.networkId == network.id)
                .toList(),
            deviceNames: deviceNames,
          ),
        )
        .toList();
  }

  /// Purpose: Serialize one network for API output.
  /// Inputs: `network`, optional `assignments` and `deviceNames`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  static Map<String, dynamic> networkToJson(
    Network network, {
    List<NetworkDevice> assignments = const [],
    Map<String, String> deviceNames = const {},
  }) => {
    'id': network.id,
    'name': network.name,
    'type': network.type.name,
    'subnet': network.subnet,
    'gateway': network.gateway,
    'dnsServers': network.dnsServers,
    'notes': network.notes,
    'assignments': assignments
        .map(
          (assignment) => {
            'networkId': assignment.networkId,
            'deviceId': assignment.deviceId,
            'deviceName': deviceNames[assignment.deviceId],
            'addressMode': assignment.addressMode.jsonValue,
            'ipAddress': assignment.ipAddress,
            'hostname': assignment.hostname,
            'isExitNode': assignment.isExitNode,
          },
        )
        .toList(),
    'modifiedAt': network.modifiedAt.toIso8601String(),
  };

  /// Purpose: Filter networks by network and assignment text fields.
  /// Inputs: `networks`, `assignments`, `devices`, `query`.
  /// Returns: Matching networks in original order.
  /// Side effects: None.
  /// Notes: Device names are included so callers can ask for a device's network.
  static List<Network> filterNetworksForSearch({
    required List<Network> networks,
    required List<NetworkDevice> assignments,
    required List<Device> devices,
    required String query,
  }) {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return const [];
    final deviceNames = _deviceNameMap(devices);
    return networks.where((network) {
      final networkAssignments = assignments
          .where((assignment) => assignment.networkId == network.id)
          .toList();
      return _containsText([
        network.name,
        network.type.name,
        network.subnet,
        network.gateway,
        network.notes,
        ...network.dnsServers,
        ...networkAssignments.expand(
          (assignment) => [
            deviceNames[assignment.deviceId],
            assignment.deviceId,
            assignment.addressMode.jsonValue,
            assignment.ipAddress,
            assignment.hostname,
            assignment.isExitNode ? 'exitNode' : null,
          ],
        ),
      ], lower);
    }).toList();
  }

  /// Purpose: Serialize datasets with linked device storage details.
  /// Inputs: `datasets`, `devices`.
  /// Returns: JSON-compatible list.
  /// Side effects: None.
  /// Notes: Storage links retain slot indices because datasets are index-based.
  static List<Map<String, dynamic>> buildDataSetListJson({
    required List<DataSet> datasets,
    required List<Device> devices,
  }) {
    return datasets
        .map((dataset) => dataSetToJson(dataset, devices: devices))
        .toList();
  }

  /// Purpose: Serialize one dataset for API output.
  /// Inputs: `dataset`, optional `devices`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Linked storage entries include index plus current storage summary.
  static Map<String, dynamic> dataSetToJson(
    DataSet dataset, {
    List<Device> devices = const [],
  }) {
    final devicesById = {for (final device in devices) device.id: device};
    return {
      'id': dataset.id,
      'name': dataset.name,
      'emoji': dataset.emoji,
      'storageLinks': dataset.storageLinks.map((link) {
        final device = devicesById[link.deviceId];
        return {
          'deviceId': link.deviceId,
          'deviceName': device?.name,
          'storageIndices': link.storageIndices,
          'storage': link.storageIndices.map((index) {
            final storage =
                device != null && index >= 0 && index < device.storage.length
                ? device.storage[index]
                : null;
            return {
              'index': index,
              if (storage != null) ...storageToJson(storage),
            };
          }).toList(),
        };
      }).toList(),
      'modifiedAt': dataset.modifiedAt.toIso8601String(),
    };
  }

  /// Purpose: Filter datasets by dataset, linked device, and linked storage text.
  /// Inputs: `datasets`, `devices`, `query`.
  /// Returns: Matching datasets in original order.
  /// Side effects: None.
  /// Notes: None.
  static List<DataSet> filterDataSetsForSearch({
    required List<DataSet> datasets,
    required List<Device> devices,
    required String query,
  }) {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return const [];
    final devicesById = {for (final device in devices) device.id: device};
    return datasets.where((dataset) {
      return _containsText([
        dataset.name,
        dataset.emoji,
        ...dataset.storageLinks.expand((link) {
          final device = devicesById[link.deviceId];
          return [
            link.deviceId,
            device?.name,
            device?.brand,
            device?.model,
            ...link.storageIndices.expand((index) {
              final storage =
                  device != null && index >= 0 && index < device.storage.length
                  ? device.storage[index]
                  : null;
              return [
                storage?.capacity,
                storage?.type?.name,
                storage?.interface_?.name,
                storage?.brand,
                storage?.serialNumber,
              ];
            }),
          ];
        }),
      ], lower);
    }).toList();
  }

  /// Purpose: Serialize service nodes for API responses.
  /// Inputs: `services`, `devices`, `networks`.
  /// Returns: JSON-compatible list.
  /// Side effects: None.
  /// Notes: This exposes saved notes only; it does not query live service state.
  static List<Map<String, dynamic>> buildServiceListJson({
    required List<ServiceNode> services,
    required List<Device> devices,
    required List<Network> networks,
  }) {
    final deviceNames = _deviceNameMap(devices);
    final networkNames = {
      for (final network in networks) network.id: network.name,
    };
    return services
        .map(
          (service) => serviceToJson(
            service,
            deviceNames: deviceNames,
            networkNames: networkNames,
          ),
        )
        .toList();
  }

  /// Purpose: Serialize one service node for API output.
  /// Inputs: `service`, optional device and network name maps.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Endpoint port ranges use both `port` and `portText`.
  static Map<String, dynamic> serviceToJson(
    ServiceNode service, {
    Map<String, String> deviceNames = const {},
    Map<String, String> networkNames = const {},
  }) => {
    'id': service.id,
    'deviceId': service.deviceId,
    'deviceName': deviceNames[service.deviceId],
    'name': service.name,
    'templateId': service.templateId,
    'icon': service.icon,
    'kind': service.kind.name,
    'runtime': service.runtime?.name,
    'state': service.state.name,
    'endpoints': service.endpoints
        .map((endpoint) => _serviceEndpointToJson(endpoint, networkNames))
        .toList(),
    'tags': service.tags,
    'notes': service.notes,
    'dockerCompose': service.dockerCompose,
    'modifiedAt': service.modifiedAt.toIso8601String(),
  };

  /// Purpose: Filter service nodes by optional list endpoint parameters.
  /// Inputs: `services`, optional `deviceId`, `kind`, and `state`.
  /// Returns: Matching services in original order.
  /// Side effects: None.
  /// Notes: Empty filter strings are ignored.
  static List<ServiceNode> filterServicesForList({
    required List<ServiceNode> services,
    String? deviceId,
    String? kind,
    String? state,
  }) {
    return services.where((service) {
      final deviceMatches =
          deviceId == null || deviceId.isEmpty || service.deviceId == deviceId;
      final kindMatches =
          kind == null || kind.isEmpty || service.kind.name == kind;
      final stateMatches =
          state == null || state.isEmpty || service.state.name == state;
      return deviceMatches && kindMatches && stateMatches;
    }).toList();
  }

  /// Purpose: Filter service nodes for a case-insensitive search query.
  /// Inputs: `services`, `devices`, `networks`, `query`.
  /// Returns: Matching services in original order.
  /// Side effects: None.
  /// Notes: Searches saved metadata, endpoint definitions, and linked names only.
  static List<ServiceNode> filterServicesForSearch({
    required List<ServiceNode> services,
    required List<Device> devices,
    required List<Network> networks,
    required String query,
  }) {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return const [];
    final deviceNames = _deviceNameMap(devices);
    final networkNames = {
      for (final network in networks) network.id: network.name,
    };
    return services.where((service) {
      return _containsText([
        service.name,
        service.templateId,
        service.icon,
        service.kind.name,
        service.runtime?.name,
        service.state.name,
        service.notes,
        service.dockerCompose,
        deviceNames[service.deviceId],
        ...service.tags,
        ...service.endpoints.expand(
          (endpoint) => [
            endpoint.label,
            endpoint.protocol.name,
            endpoint.transport.name,
            endpoint.bindAddress,
            endpoint.port?.toString(),
            endpoint.portEnd?.toString(),
            endpoint.portText,
            endpoint.path,
            endpoint.networkId,
            networkNames[endpoint.networkId],
            endpoint.scope.name,
            endpoint.notes,
          ],
        ),
      ], lower);
    }).toList();
  }

  /// Purpose: Serialize service routes for API responses.
  /// Inputs: `routes`, `services`, `devices`.
  /// Returns: JSON-compatible list.
  /// Side effects: None.
  /// Notes: Includes grouped `publicTargets` from preserved route extra JSON.
  static List<Map<String, dynamic>> buildServiceRouteListJson({
    required List<ServiceRoute> routes,
    required List<ServiceNode> services,
    required List<Device> devices,
  }) {
    final servicesById = {for (final service in services) service.id: service};
    final deviceNames = _deviceNameMap(devices);
    return routes
        .map(
          (route) => serviceRouteToJson(
            route,
            servicesById: servicesById,
            deviceNames: deviceNames,
          ),
        )
        .toList();
  }

  /// Purpose: Serialize one service route for API output.
  /// Inputs: `route`, optional service and device lookup maps.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: `finalUrl` remains the first target for compatibility.
  static Map<String, dynamic> serviceRouteToJson(
    ServiceRoute route, {
    Map<String, ServiceNode> servicesById = const <String, ServiceNode>{},
    Map<String, String> deviceNames = const {},
  }) {
    final sourceService = servicesById[route.sourceServiceId];
    final sourceEndpoint = sourceService?.endpoints
        .where((endpoint) => endpoint.id == route.sourceEndpointId)
        .firstOrNull;
    return {
      'id': route.id,
      'name': route.name,
      'sourceServiceId': route.sourceServiceId,
      'sourceServiceName': sourceService?.name,
      'sourceDeviceId': sourceService?.deviceId,
      'sourceDeviceName': sourceService == null
          ? null
          : deviceNames[sourceService.deviceId],
      'sourceEndpointId': route.sourceEndpointId,
      'sourceEndpoint': sourceEndpoint == null
          ? null
          : _serviceEndpointToJson(sourceEndpoint, const {}),
      'hops': route.hops
          .map((hop) => _serviceRouteHopToJson(hop, servicesById, deviceNames))
          .toList(),
      'finalUrl': route.finalUrl,
      'publicTargets': _publicTargets(route),
      'accessLevel': route.accessLevel.name,
      'notes': route.notes,
      'modifiedAt': route.modifiedAt.toIso8601String(),
    };
  }

  /// Purpose: Build service-only stats JSON for `/service/stats`.
  /// Inputs: `services`, `routes`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Mirrors the service portion embedded in `/device/stats`.
  static Map<String, dynamic> buildServiceStatsJson({
    required List<ServiceNode> services,
    required List<ServiceRoute> routes,
  }) {
    return {
      'total': services.length,
      'routes': routes.length,
      'devices': services.map((service) => service.deviceId).toSet().length,
      'endpoints': services.fold<int>(
        0,
        (sum, service) => sum + service.endpoints.length,
      ),
      'byKind': _countBy(services, (service) => service.kind.name),
      'byState': _countBy(services, (service) => service.state.name),
      'byAccessLevel': _countBy(routes, (route) => route.accessLevel.name),
      'publicTargets': routes.fold<int>(
        0,
        (sum, route) => sum + _publicTargets(route).length,
      ),
    };
  }

  /// Purpose: Provide the internal device serialization helper for route handlers.
  /// Inputs: `device`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Internal helper preserves the previous private call sites.
  static Map<String, dynamic> _deviceToJson(Device device) =>
      deviceToJson(device);

  /// Purpose: Serialize a service endpoint with optional network display name.
  /// Inputs: `endpoint`, `networkNames`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Internal helper used for service and route responses.
  static Map<String, dynamic> _serviceEndpointToJson(
    ServiceEndpoint endpoint,
    Map<String, String> networkNames,
  ) => {
    'id': endpoint.id,
    'label': endpoint.label,
    'protocol': endpoint.protocol.name,
    'transport': endpoint.transport.name,
    'bindAddress': endpoint.bindAddress,
    'port': endpoint.port,
    'portEnd': endpoint.portEnd,
    'portText': endpoint.portText,
    'path': endpoint.path,
    'networkId': endpoint.networkId,
    'networkName': networkNames[endpoint.networkId],
    'scope': endpoint.scope.name,
    'isPrimary': endpoint.isPrimary,
    'notes': endpoint.notes,
  };

  /// Purpose: Serialize a service route hop with resolved names where possible.
  /// Inputs: `hop`, `servicesById`, `deviceNames`.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Internal helper keeps free-form hop fields intact.
  static Map<String, dynamic> _serviceRouteHopToJson(
    ServiceRouteHop hop,
    Map<String, ServiceNode> servicesById,
    Map<String, String> deviceNames,
  ) {
    final service = hop.serviceId == null ? null : servicesById[hop.serviceId];
    return {
      'id': hop.id,
      'type': hop.type.name,
      'serviceId': hop.serviceId,
      'serviceName': service?.name,
      'endpointId': hop.endpointId,
      'deviceId': hop.deviceId,
      'deviceName': hop.deviceId == null ? null : deviceNames[hop.deviceId],
      'label': hop.label,
      'scheme': hop.scheme,
      'host': hop.host,
      'port': hop.port,
      'path': hop.path,
      'method': hop.method?.name,
      'notes': hop.notes,
    };
  }

  /// Purpose: Return grouped public targets stored on a service route.
  /// Inputs: `route`.
  /// Returns: `List<String>`.
  /// Side effects: None.
  /// Notes: Supports forward-compatible JSON by ignoring non-string entries.
  static List<String> _publicTargets(ServiceRoute route) {
    final raw = route.extraJson['publicTargets'];
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  /// Purpose: Return a map from device id to display name.
  /// Inputs: `devices`.
  /// Returns: `Map<String, String>`.
  /// Side effects: None.
  /// Notes: Internal helper for enriched cross-module API output.
  static Map<String, String> _deviceNameMap(List<Device> devices) => {
    for (final device in devices) device.id: device.name,
  };

  /// Purpose: Count records by a selected string key.
  /// Inputs: `values`, `keyOf`.
  /// Returns: `Map<String, int>`.
  /// Side effects: None.
  /// Notes: Internal helper for API stats responses.
  static Map<String, int> _countBy<T>(
    Iterable<T> values,
    String Function(T value) keyOf,
  ) {
    final counts = <String, int>{};
    for (final value in values) {
      final key = keyOf(value);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// Purpose: Return whether any provided value contains a lowercase query.
  /// Inputs: `values`, `lowerQuery`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper skips nulls.
  static bool _containsText(Iterable<Object?> values, String lowerQuery) {
    return values.any(
      (value) =>
          value != null && value.toString().toLowerCase().contains(lowerQuery),
    );
  }

  /// Purpose: Parse an integer from JSON-compatible input.
  /// Inputs: `value`.
  /// Returns: `int?`.
  /// Side effects: None.
  /// Notes: Internal helper tolerates numeric strings.
  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Purpose: Parse a double from JSON-compatible input.
  /// Inputs: `value`.
  /// Returns: `double?`.
  /// Side effects: None.
  /// Notes: Internal helper tolerates numeric strings.
  static double? _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Purpose: Parse a date-time from JSON-compatible input.
  /// Inputs: `value`.
  /// Returns: `DateTime?`.
  /// Side effects: None.
  /// Notes: Invalid strings are ignored for compatibility with minimal adds.
  static DateTime? _dateValue(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// Purpose: Parse a money value from an optional JSON map.
  /// Inputs: `value`.
  /// Returns: `MoneyValue?`.
  /// Side effects: None.
  /// Notes: Malformed money maps are ignored instead of rejecting the whole add request.
  static MoneyValue? _moneyValueFromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    try {
      return MoneyValue.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Parse a recurring device cost from an optional JSON map.
  /// Inputs: `value`.
  /// Returns: `DeviceRecurringCost?`.
  /// Side effects: None.
  /// Notes: Malformed cost maps are skipped.
  static DeviceRecurringCost? _recurringCostFromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    try {
      return DeviceRecurringCost.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Provide the internal json helper for this file.
  /// Inputs: None.
  /// Returns: `Response`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Response _json(Object data) => Response.ok(
    jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );

  /// Purpose: Provide the internal error helper for this file.
  /// Inputs: `status`.
  /// Returns: `Response`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Response _error(int status, String message) => Response(
    status,
    body: jsonEncode({'error': message}),
    headers: {'Content-Type': 'application/json'},
  );

  /// Purpose: Provide the internal parse body helper for this file.
  /// Inputs: `request`.
  /// Returns: `Future<Map<String, dynamic>?>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  static Future<Map<String, dynamic>?> _parseBody(Request request) async {
    try {
      final raw = await request.readAsString();
      if (raw.trim().isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Middleware ──

  /// Purpose: Provide the internal cors middleware helper for this file.
  /// Inputs: None.
  /// Returns: `Middleware`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  /// Purpose: Provide the internal auth middleware helper for this file.
  /// Inputs: None.
  /// Returns: `Middleware`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Middleware _authMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final remoteAddr =
            (request.context['shelf.io.connection_info'] as HttpConnectionInfo?)
                ?.remoteAddress;
        final isLoopback = remoteAddr == null || remoteAddr.isLoopback;

        final hasCredentials =
            _username != null &&
            _username!.isNotEmpty &&
            _password != null &&
            _password!.isNotEmpty;
        if (!isLoopback && !hasCredentials) {
          return _error(
            403,
            'authentication required for non-localhost access',
          );
        }
        if (hasCredentials && !isLoopback) {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !_validateBasicAuth(authHeader)) {
            return Response(
              401,
              body: jsonEncode({'error': 'unauthorized'}),
              headers: {
                'Content-Type': 'application/json',
                'WWW-Authenticate': 'Basic realm="MyDevice API"',
              },
            );
          }
        }
        return innerHandler(request);
      };
    };
  }

  /// Purpose: Provide the internal validate basic auth helper for this file.
  /// Inputs: `header`.
  /// Returns: `bool`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static bool _validateBasicAuth(String header) {
    if (!header.startsWith('Basic ')) return false;
    try {
      final decoded = utf8.decode(base64Decode(header.substring(6)));
      final parts = decoded.split(':');
      if (parts.length < 2) return false;
      return parts[0] == _username && parts.sublist(1).join(':') == _password;
    } catch (_) {
      return false;
    }
  }

  /// Purpose: Provide the internal error middleware helper for this file.
  /// Inputs: None.
  /// Returns: `Middleware`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static Middleware _errorMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        try {
          return await innerHandler(request);
        } catch (e) {
          return _error(500, 'internal error: $e');
        }
      };
    };
  }
}
