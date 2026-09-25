import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_access_patterns.dart';
import 'package:my_device/features/services/views/service_access_path_page.dart';
import 'package:my_device/features/services/views/service_list_page.dart';
import 'package:my_device/features/services/views/service_route_edit_page.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test that a saved route reopens in the editor that fits it.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: A route shaped exactly like what the guided page saves (built with
/// `ServiceAccessDraft.toRoute`) opens in the guided page; a three-hop route
/// the guided form cannot represent opens in the advanced editor. The route
/// cards show their method's icon.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  final services = [
    ServiceNode(
      id: 'jellyfin',
      deviceId: 'home',
      name: 'Jellyfin',
      endpoints: [ServiceEndpoint(id: 'web', port: 8096, isPrimary: true)],
    ),
    ServiceNode(
      id: 'caddy',
      deviceId: 'home',
      name: 'Caddy',
      templateId: 'caddy',
      kind: ServiceKind.reverseProxy,
      endpoints: [ServiceEndpoint(id: 'https', port: 443, isPrimary: true)],
    ),
    ServiceNode(
      id: 'frps',
      deviceId: 'vps',
      name: 'frps',
      templateId: 'frp',
      kind: ServiceKind.tunnel,
      endpoints: [ServiceEndpoint(id: 'bind', port: 57000, isPrimary: true)],
    ),
  ];
  final guided = const ServiceAccessDraft(
    sourceServiceId: 'jellyfin',
    sourceEndpointId: 'web',
    pattern: ServiceAccessPattern.frp,
    reachability: ServiceReachability.public,
    viaProxy: true,
    proxyServiceId: 'caddy',
    proxyEndpointId: 'https',
    relayServiceId: 'frps',
    relayEndpointId: 'bind',
    publicHost: 'vps.example.com',
    publicPort: 443,
    targets: ['https://media.example.com'],
  ).toRoute(services: services);
  final threeHops = ServiceRoute(
    id: 'three-hops',
    name: 'Jellyfin - three hops',
    sourceServiceId: 'jellyfin',
    sourceEndpointId: 'web',
    accessLevel: ServiceAccessLevel.public,
    finalUrl: 'https://cdn.example.com',
    hops: [
      ServiceRouteHop(
        type: ServiceRouteHopType.reverseProxy,
        method: ServiceRouteMethod.caddy,
        serviceId: 'caddy',
        endpointId: 'https',
      ),
      ServiceRouteHop(
        type: ServiceRouteHopType.portForward,
        method: ServiceRouteMethod.frp,
        serviceId: 'frps',
        endpointId: 'bind',
        deviceId: 'vps',
        port: 8443,
      ),
      ServiceRouteHop(type: ServiceRouteHopType.manual, label: 'CDN'),
    ],
  );

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_service_route_opening_ui',
      devices: [
        Device(id: 'home', name: '家用服务器', category: DeviceCategory.desktop),
        Device(id: 'vps', name: '云服务器', category: DeviceCategory.vps),
      ],
      services: services,
      routes: [guided, threeHops],
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  /// Purpose: Pump the services page and switch to its routes view.
  /// Inputs: `tester`.
  /// Returns: `Future<void>`.
  /// Side effects: Pumps the widget tree.
  /// Notes: Phone geometry; the routes view is one column there.
  Future<void> openRoutes(WidgetTester tester) async {
    await pumpPageAt(
      tester,
      412,
      915,
      page: const ServiceListPage(),
      ready: find.byType(Card),
    );
    await tester.tap(find.text('链路').first);
    await settle(tester);
  }

  /// Purpose: Find a route card by its display target.
  /// Inputs: `target`.
  /// Returns: `Finder`.
  /// Side effects: None.
  /// Notes: None.
  Finder card(String target) => find.ancestor(
    of: find.text(target),
    matching: find.byType(ListTile),
  );

  testWidgets('a route the guided page saved reopens in the guided page', (
    tester,
  ) async {
    await openRoutes(tester);
    final tile = card('https://media.example.com');
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.alt_route)),
      findsOneWidget,
      reason: 'the route starts with its Caddy hop',
    );
    await tester.tap(tile);
    await pumpUntil(tester, find.byType(ServiceAccessPathPage));
    await settle(tester);
    expect(find.byType(ServiceAccessPathPage), findsOneWidget);
    expect(find.byType(ServiceRouteEditPage), findsNothing);
  });

  testWidgets('a three-hop route reopens in the advanced editor', (
    tester,
  ) async {
    await openRoutes(tester);
    await tester.tap(card('https://cdn.example.com'));
    await pumpUntil(tester, find.byType(ServiceRouteEditPage));
    await settle(tester);
    expect(find.byType(ServiceRouteEditPage), findsOneWidget);
    expect(find.byType(ServiceAccessPathPage), findsNothing);
  });
}
