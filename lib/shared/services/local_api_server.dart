import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../features/devices/models/device.dart';
import '../../features/devices/services/device_storage.dart';

class LocalApiServer {
  static HttpServer? _server;
  static int _port = 7789;
  static String _listenAddress = 'localhost';
  static bool _enabled = false;
  static String? _username;
  static String? _password;
  static String? _lastError;

  static int get port => _port;
  static String get listenAddress => _listenAddress;
  static bool get enabled => _enabled;
  static bool get isRunning => _server != null;
  static String? get lastError => _lastError;

  static Future<void> loadConfig() async {
    final config = await DeviceStorage.readConfig();
    _port = config['apiPort'] as int? ?? 7789;
    _listenAddress = config['apiListenAddress'] as String? ?? 'localhost';
    _enabled = config['apiEnabled'] as bool? ?? false;
    _username = config['apiUsername'] as String?;
    _password = config['apiPassword'] as String?;
  }

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

  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  static Future<void> restart() async {
    await loadConfig();
    await start();
  }

  // ── Route handlers ──

  static Future<Response> _handlePing(Request request) async {
    return _json({'status': 'ok'});
  }

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

  static Future<Response> _handleSearch(Request request) async {
    final q = request.url.queryParameters['q']?.trim();
    if (q == null || q.isEmpty) {
      return _error(400, 'q parameter is required');
    }
    final data = await DeviceStorage.load();
    final lower = q.toLowerCase();
    final matches = data.devices.where((d) {
      return d.name.toLowerCase().contains(lower) ||
          (d.brand?.toLowerCase().contains(lower) ?? false) ||
          (d.model?.toLowerCase().contains(lower) ?? false) ||
          (d.notes?.toLowerCase().contains(lower) ?? false);
    }).toList();
    return _json(matches.map(_deviceToJson).toList());
  }

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
          );
        }
        return const StorageInfo();
      }).toList();
    }

    DateTime? purchaseDate;
    final pdStr = body['purchaseDate'] as String?;
    if (pdStr != null && pdStr.isNotEmpty) {
      purchaseDate = DateTime.tryParse(pdStr);
    }

    DateTime? releaseDate;
    final rdStr = body['releaseDate'] as String?;
    if (rdStr != null && rdStr.isNotEmpty) {
      releaseDate = DateTime.tryParse(rdStr);
    }

    final device = Device(
      name: name,
      category: category,
      brand: body['brand'] as String?,
      model: body['model'] as String?,
      serialNumber: body['serialNumber'] as String?,
      cpu: cpu,
      gpu: gpu,
      ram: body['ram'] as String?,
      ramType: RamType.fromJson(body['ramType'] as String?),
      storage: storageList,
      screenSize: body['screenSize'] as String?,
      battery: body['battery'] as String?,
      os: body['os'] as String?,
      locationName: body['locationName'] as String?,
      purchaseDate: purchaseDate,
      releaseDate: releaseDate,
      notes: body['notes'] as String?,
    );

    await DeviceStorage.addOrUpdate(device);
    return _json({'success': true, 'id': device.id, 'name': device.name});
  }

  static Future<Response> _handleStats(Request request) async {
    final data = await DeviceStorage.load();
    final devices = data.devices;

    final byCategory = <String, int>{};
    for (final d in devices) {
      byCategory[d.category.name] = (byCategory[d.category.name] ?? 0) + 1;
    }

    final sorted = List<Device>.of(devices)
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    final recent = sorted
        .take(5)
        .map((d) => {'id': d.id, 'name': d.name, 'category': d.category.name})
        .toList();

    return _json({
      'total': devices.length,
      'byCategory': byCategory,
      'recentlyAdded': recent,
    });
  }

  // ── Helpers ──

  static Map<String, dynamic> _deviceToJson(Device d) => {
    'id': d.id,
    'name': d.name,
    'category': d.category.name,
    'emoji': d.emoji,
    'brand': d.brand,
    'model': d.model,
    'serialNumber': d.serialNumber,
    'cpu': {
      'model': d.cpu.model,
      'performanceCores': d.cpu.performanceCores,
      'efficiencyCores': d.cpu.efficiencyCores,
      'threads': d.cpu.threads,
      'frequency': d.cpu.frequency,
    },
    'gpu': {'model': d.gpu.model},
    'ram': d.ram,
    'ramType': d.ramType?.name,
    'storage': d.storage
        .map(
          (s) => {
            'capacity': s.capacity,
            'type': s.type?.name,
            'interface': s.interface_?.name,
          },
        )
        .toList(),
    'screenSize': d.screenSize,
    'battery': d.battery,
    'os': d.os,
    'locationName': d.locationName,
    'purchaseDate': d.purchaseDate?.toIso8601String(),
    'releaseDate': d.releaseDate?.toIso8601String(),
    'notes': d.notes,
    'modifiedAt': d.modifiedAt.toIso8601String(),
  };

  static Response _json(Object data) => Response.ok(
    jsonEncode(data),
    headers: {'Content-Type': 'application/json'},
  );

  static Response _error(int status, String message) => Response(
    status,
    body: jsonEncode({'error': message}),
    headers: {'Content-Type': 'application/json'},
  );

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
