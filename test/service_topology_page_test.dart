import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_analysis.dart';
import 'package:my_device/features/services/views/service_topology_page.dart';
import 'package:my_device/features/services/views/service_topology_widgets.dart';

import 'support/pump.dart';

/// Purpose: Build the inventory the topology tests draw.
/// Inputs: None.
/// Returns: The devices, services and routes of a small homelab.
/// Side effects: None.
/// Notes: Jellyfin on the home server is published through Caddy and an FRP
/// server on a VPS to `media.example.com`; Home Assistant on a NAS is reached
/// directly on the LAN. The two routes share no node, so a selection on one
/// leaves the other unrelated.
({List<Device> devices, List<ServiceNode> services, List<ServiceRoute> routes})
topologyFixture() {
  final devices = [
    Device(id: 'home', name: 'Home server', category: DeviceCategory.desktop),
    Device(id: 'nas', name: 'NAS', category: DeviceCategory.other),
    Device(id: 'vps', name: 'VPS', category: DeviceCategory.vps),
  ];
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
      endpoints: [
        ServiceEndpoint(
          id: 'https',
          port: 443,
          protocol: ServiceProtocol.https,
          isPrimary: true,
        ),
      ],
    ),
    ServiceNode(
      id: 'frps',
      deviceId: 'vps',
      name: 'frps',
      templateId: 'frp',
      kind: ServiceKind.tunnel,
      endpoints: [ServiceEndpoint(id: 'bind', port: 57000, isPrimary: true)],
    ),
    ServiceNode(
      id: 'hass',
      deviceId: 'nas',
      name: 'Home Assistant',
      endpoints: [ServiceEndpoint(id: 'ui', port: 8123, isPrimary: true)],
    ),
  ];
  final routes = [
    ServiceRoute(
      id: 'media',
      name: 'Jellyfin via Caddy - media.example.com',
      sourceServiceId: 'jellyfin',
      sourceEndpointId: 'web',
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
          host: 'vps.example.com',
          port: 443,
        ),
      ],
      finalUrl: 'https://media.example.com',
      accessLevel: ServiceAccessLevel.public,
    ),
    ServiceRoute(
      id: 'hass-lan',
      name: 'Home Assistant - LAN',
      sourceServiceId: 'hass',
      sourceEndpointId: 'ui',
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.manual,
          method: ServiceRouteMethod.direct,
        ),
      ],
      finalUrl: 'http://192.168.1.20:8123',
      accessLevel: ServiceAccessLevel.lan,
    ),
  ];
  return (devices: devices, services: services, routes: routes);
}

/// Purpose: Test the full-screen topology page against a built graph.
/// Inputs: None.
/// Returns: None.
/// Side effects: None; the page never touches storage.
/// Notes: Driven in Simplified Chinese at real device geometries; the
/// layout runs after the first frame, so every test waits for the node cards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Purpose: Pump the topology page over the fixture.
  /// Inputs: `tester`; `width`, `height` — the window in logical pixels;
  /// `editedServices`, `editedRoutes` — collect the ids the details' actions
  /// pass back.
  /// Returns: `Future<void>` that completes once the node cards are laid out.
  /// Side effects: Pumps the widget tree.
  /// Notes: None.
  Future<void> pumpTopology(
    WidgetTester tester, {
    double width = 412,
    double height = 915,
    List<String>? editedServices,
    List<String>? editedRoutes,
  }) async {
    final f = topologyFixture();
    final graph = buildServiceTopology(
      services: f.services,
      routes: f.routes,
      devices: f.devices,
    );
    await pumpPageAt(
      tester,
      width,
      height,
      page: ServiceTopologyPage(
        graph: graph,
        services: f.services,
        devices: f.devices,
        routes: f.routes,
        onEditService: (service) => editedServices?.add(service.id),
        onEditRoute: (route) => editedRoutes?.add(route.id),
        onAddAccess: ({draft}) async {},
      ),
      ready: find.byType(ServiceTopologyNodeCard),
    );
  }

  /// Purpose: Find the node card that shows a label.
  /// Inputs: `label`.
  /// Returns: `Finder`.
  /// Side effects: None.
  /// Notes: None.
  Finder nodeCard(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(ServiceTopologyNodeCard),
  );

  testWidgets('lays the graph out and opens a service node\'s details', (
    tester,
  ) async {
    final edited = <String>[];
    await pumpTopology(tester, editedRoutes: edited);

    expect(nodeCard('Jellyfin'), findsOneWidget);
    expect(nodeCard('media.example.com'), findsOneWidget);

    await tester.ensureVisible(nodeCard('Jellyfin'));
    await tester.tap(nodeCard('Jellyfin'));
    await settle(tester);

    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    final routeTile = find.descendant(
      of: sheet,
      matching: find.widgetWithText(ListTile, 'https://media.example.com'),
    );
    expect(routeTile, findsOneWidget);
    await tester.tap(routeTile);
    await settle(tester);
    expect(edited, ['media']);
  });

  testWidgets('move mode trades node taps for pan and zoom', (tester) async {
    await pumpTopology(tester);
    expect(find.byType(InteractiveViewer), findsNothing);

    await tester.tap(find.byIcon(Icons.open_with));
    await settle(tester);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    final card = tester.widget<ServiceTopologyNodeCard>(nodeCard('Jellyfin'));
    expect(card.onTap, isNull);
  });
}
