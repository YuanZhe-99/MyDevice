import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/shared/services/local_api_server.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

import 'support/fake_storage.dart';

/// Purpose: Test the local API's browser-Origin policy.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Drives `LocalApiServer.buildHandler()` in-process (no socket), so
/// the real middleware pipeline is exercised. A request without `Origin`
/// models a non-browser client (curl, scripts) and must keep working.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isAllowedOrigin', () {
    const allowed = <String?>[
      null,
      'http://localhost',
      'http://localhost:5173',
      'https://localhost:8443',
      'http://127.0.0.1:3000',
      'http://127.1.2.3',
      'http://[::1]:8080',
      'HTTP://LOCALHOST:80',
    ];
    const rejected = <String?>[
      'null',
      'file://',
      'https://evil.com',
      'http://localhost.evil.com',
      'http://evil.com/localhost',
      'http://192.168.1.10:7789',
      'http://0.0.0.0:7789',
      'chrome-extension://abcdefghijklmnop',
      'moz-extension://abcdef',
      'ftp://localhost',
      '',
      'not a url',
    ];
    for (final origin in allowed) {
      test('allows ${origin ?? '<no Origin header>'}', () {
        expect(LocalApiServer.isAllowedOrigin(origin), isTrue);
      });
    }
    for (final origin in rejected) {
      test('rejects "$origin"', () {
        expect(LocalApiServer.isAllowedOrigin(origin), isFalse);
      });
    }
  });

  group('request pipeline', () {
    late Directory tempDir;
    late Handler handler;

    setUp(() async {
      tempDir = await seedAppDir('mydevice_api_origin');
      handler = LocalApiServer.buildHandler();
    });

    tearDown(() {
      deleteSeededDir(tempDir);
    });

    Future<Response> send(
      String method,
      String path, {
      String? origin,
      Object? body,
    }) async => await handler(
      Request(
        method,
        Uri.parse('http://localhost:7789$path'),
        headers: {
          'origin': ?origin,
          if (body != null) 'content-type': 'application/json',
        },
        body: body == null ? null : jsonEncode(body),
      ),
    );

    File deviceFile() =>
        File(p.join(tempDir.path, 'docs', 'MyDevice', 'device_data.json'));

    test('no Origin passes and gets no CORS headers', () async {
      final response = await send('GET', '/ping');
      expect(response.statusCode, 200);
      expect(
        response.headers.containsKey('access-control-allow-origin'),
        isFalse,
      );
    });

    test('a foreign Origin is rejected with 403 and no CORS header', () async {
      for (final method in ['GET', 'POST', 'OPTIONS']) {
        final response = await send(
          method,
          '/ping',
          origin: 'https://evil.com',
        );
        expect(response.statusCode, 403, reason: method);
        expect(
          response.headers.containsKey('access-control-allow-origin'),
          isFalse,
          reason: method,
        );
        expect(jsonDecode(await response.readAsString()), {
          'error': 'origin not allowed',
        });
      }
    });

    test('a local Origin is echoed back, never a wildcard', () async {
      final response = await send(
        'GET',
        '/ping',
        origin: 'http://localhost:5173',
      );
      expect(response.statusCode, 200);
      expect(
        response.headers['access-control-allow-origin'],
        'http://localhost:5173',
      );
      expect(response.headers['vary'], 'Origin');
    });

    test('an allowed preflight answers 200 with methods and headers', () async {
      final response = await send(
        'OPTIONS',
        '/device/add',
        origin: 'http://127.0.0.1:3000',
      );
      expect(response.statusCode, 200);
      expect(
        response.headers['access-control-allow-origin'],
        'http://127.0.0.1:3000',
      );
      expect(
        response.headers['access-control-allow-methods'],
        contains('POST'),
      );
      expect(
        response.headers['access-control-allow-headers'],
        contains('Content-Type'),
      );
    });

    test('POST /device/add from a foreign Origin creates nothing', () async {
      final response = await send(
        'POST',
        '/device/add',
        origin: 'https://evil.com',
        body: {'name': 'Injected', 'category': 'laptop'},
      );
      expect(response.statusCode, 403);
      expect(deviceFile().existsSync(), isFalse);
    });

    test('POST /device/add without Origin still works', () async {
      final response = await send(
        'POST',
        '/device/add',
        body: {'name': 'Local', 'category': 'laptop'},
      );
      expect(response.statusCode, lessThan(300));
      expect(deviceFile().existsSync(), isTrue);
      expect(deviceFile().readAsStringSync(), contains('Local'));
    });
  });
}
