import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/l10n/app_localizations.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_access_patterns.dart';
import 'package:my_device/features/services/services/service_analysis.dart';
import 'package:my_device/features/services/services/service_topology_layout.dart';
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
  /// pass back; `drafts` — collects the drafts the access-path actions pass;
  /// `reload` — the page's reload callback.
  /// Returns: `Future<void>` that completes once the node cards are laid out.
  /// Side effects: Pumps the widget tree.
  /// Notes: None.
  Future<void> pumpTopology(
    WidgetTester tester, {
    double width = 412,
    double height = 915,
    List<String>? editedServices,
    List<String>? editedRoutes,
    List<ServiceAccessDraft?>? drafts,
    Future<ServiceTopologyInventory> Function()? reload,
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
        onEditService: (service) async => editedServices?.add(service.id),
        onEditRoute: (route) async => editedRoutes?.add(route.id),
        onAddAccess: ({draft}) async => drafts?.add(draft),
        reload: reload,
      ),
      ready: find.byType(ServiceTopologyNodeCard),
    );
  }

  /// Purpose: Select a node by id on a split window and return the details
  /// pane.
  /// Inputs: `tester`, `id`.
  /// Returns: `Finder` of the pane.
  /// Side effects: Taps the node card.
  /// Notes: Scrolls the card into view first.
  Future<Finder> selectOnSplit(WidgetTester tester, String id) async {
    final card = find.byKey(ValueKey('topology-node-$id'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await settle(tester);
    return find.byKey(const Key('topology-details-pane'));
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

  testWidgets('move mode trades node taps for pan and zoom, with fit', (
    tester,
  ) async {
    await pumpTopology(tester);
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byKey(const Key('topology-fit')), findsNothing);

    await tester.tap(find.byIcon(Icons.open_with));
    await settle(tester);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    final card = tester.widget<ServiceTopologyNodeCard>(nodeCard('Jellyfin'));
    expect(card.onTap, isNull);

    Matrix4 transform() => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value;
    expect(transform(), Matrix4.identity());
    await tester.ensureVisible(find.byKey(const Key('topology-reset')));
    await tester.tap(find.byKey(const Key('topology-fit')));
    await settle(tester);
    expect(transform(), isNot(Matrix4.identity()));
    await tester.tap(find.byKey(const Key('topology-reset')));
    await settle(tester);
    expect(transform(), Matrix4.identity());
  });

  /// Purpose: Read whether a node card is drawn dimmed.
  /// Inputs: `tester`, `label`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool dimmed(WidgetTester tester, String label) =>
      tester.widget<ServiceTopologyNodeCard>(nodeCard(label)).dimmed;

  testWidgets('a selected service lights its route and dims the rest', (
    tester,
  ) async {
    await pumpTopology(tester);
    expect(dimmed(tester, 'Home Assistant'), isFalse);

    await tester.ensureVisible(nodeCard('Jellyfin'));
    await tester.tap(nodeCard('Jellyfin'));
    await settle(tester);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await settle(tester);

    expect(
      tester.widget<ServiceTopologyNodeCard>(nodeCard('Jellyfin')).selected,
      isTrue,
    );
    expect(dimmed(tester, 'Jellyfin'), isFalse);
    expect(dimmed(tester, 'media.example.com'), isFalse);
    expect(dimmed(tester, 'Caddy'), isFalse);
    expect(dimmed(tester, 'Home Assistant'), isTrue);
    expect(find.byKey(const Key('topology-selection-chip')), findsOneWidget);

    // The chip's delete button clears the selection.
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await tester.tap(find.byTooltip(l10n.serviceTopologyClearSelection));
    await settle(tester);
    expect(dimmed(tester, 'Home Assistant'), isFalse);
    expect(find.byKey(const Key('topology-selection-chip')), findsNothing);
  });

  testWidgets('a tap on the empty canvas clears the selection', (tester) async {
    await pumpTopology(tester);
    await tester.ensureVisible(nodeCard('Home Assistant'));
    await tester.tap(nodeCard('Home Assistant'));
    await settle(tester);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await settle(tester);
    expect(dimmed(tester, 'Jellyfin'), isTrue);

    final canvas = find.byKey(const Key('topology-canvas'));
    await tester.tapAt(tester.getTopLeft(canvas) + const Offset(3, 3));
    await settle(tester);
    expect(dimmed(tester, 'Jellyfin'), isFalse);
  });

  testWidgets('the lane filter removes public-lane nodes and clears back', (
    tester,
  ) async {
    await pumpTopology(tester);
    expect(nodeCard('media.example.com'), findsOneWidget);

    await tester.tap(find.byKey(const Key('topology-filter')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('topology-filter-lane-vpn')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('topology-filter-lane-public')));
    await settle(tester);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await pumpUntil(tester, find.byType(ServiceTopologyNodeCard));
    await settle(tester);

    expect(nodeCard('media.example.com'), findsNothing);
    expect(nodeCard('Caddy'), findsNothing);
    expect(nodeCard('Home Assistant'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('topology-filter')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('topology-filter')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('topology-filter-clear')));
    await settle(tester);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await pumpUntil(tester, nodeCard('media.example.com'));
    expect(nodeCard('media.example.com'), findsOneWidget);
  });

  testWidgets('a search that matches nothing offers to clear the filters', (
    tester,
  ) async {
    await pumpTopology(tester);
    await tester.tap(find.byKey(const Key('topology-filter')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('topology-filter-search')),
      'nothing-like-this',
    );
    await settle(tester);
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await settle(tester);

    expect(find.byKey(const Key('topology-no-match')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('topology-no-match')),
        matching: find.byType(FilledButton),
      ),
    );
    await pumpUntil(tester, find.byType(ServiceTopologyNodeCard));
    expect(nodeCard('Jellyfin'), findsOneWidget);
  });

  testWidgets('the legend strip expands to lanes and roles', (tester) async {
    await pumpTopology(tester);
    expect(find.byKey(const Key('topology-legend-toggle')), findsOneWidget);
    expect(find.byKey(const Key('topology-legend')), findsNothing);

    await tester.tap(find.byKey(const Key('topology-legend-toggle')));
    await settle(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    final legend = find.byKey(const Key('topology-legend'));
    expect(legend, findsOneWidget);
    for (final text in [
      l10n.serviceLaneLocal,
      l10n.serviceLaneVpn,
      l10n.serviceLanePublic,
      l10n.serviceRoleLocalDevice,
      l10n.serviceRoleDomain,
    ]) {
      expect(
        find.descendant(of: legend, matching: find.text(text)),
        findsOneWidget,
      );
    }
  });

  testWidgets('devices head containers until grouping is turned off', (
    tester,
  ) async {
    await pumpTopology(tester);
    final toggle = find.byKey(const Key('topology-group-by-device'));
    expect(toggle, findsOneWidget);
    expect(tester.widget<IconButton>(toggle).isSelected, isTrue);

    Finder node(String id) => find.byKey(ValueKey('topology-node-$id'));
    ServiceTopologyNodeCard card(String id) =>
        tester.widget<ServiceTopologyNodeCard>(node(id));
    expect(card('device:home').header, isTrue);
    expect(card('device:vps').header, isTrue);
    expect(card('service:jellyfin').header, isFalse);
    expect(
      tester.getSize(node('device:home')).height,
      ServiceTopologyLayout.containerHeaderHeight,
    );

    await tester.tap(toggle);
    await pumpUntil(tester, find.byType(ServiceTopologyNodeCard));
    await settle(tester);
    expect(tester.widget<IconButton>(toggle).isSelected, isFalse);
    expect(card('device:home').header, isFalse);
    expect(
      tester.getSize(node('device:home')).height,
      ServiceTopologyLayout.nodeHeight,
    );
  });

  testWidgets('node cards announce their label, role and lane', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpTopology(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(
      find.bySemanticsLabel('Jellyfin, ${l10n.serviceRoleLocalService}'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'media.example.com, ${l10n.serviceRoleDomain}, ${l10n.serviceLanePublic}',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('a remote relay service is subtitled in the UI language', (
    tester,
  ) async {
    await pumpTopology(tester);
    final card = find.byKey(const ValueKey('topology-node-service:frps'));
    await tester.ensureVisible(card);
    expect(
      find.descendant(of: card, matching: find.textContaining('FRP 服务')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('service')),
      findsNothing,
    );
  });

  testWidgets('node actions open the guided page with the node prefilled', (
    tester,
  ) async {
    final drafts = <ServiceAccessDraft?>[];
    await pumpTopology(tester, width: 1280, height: 800, drafts: drafts);

    Future<void> runAction(String nodeId, String actionKey) async {
      final pane = await selectOnSplit(tester, nodeId);
      final action = find.descendant(
        of: pane,
        matching: find.byKey(Key(actionKey)),
      );
      expect(action, findsOneWidget, reason: '$nodeId: $actionKey');
      await tester.tap(action);
      await settle(tester);
    }

    await runAction('service:frps', 'topology-action-from-here');
    await runAction('service:frps', 'topology-action-expose');
    await runAction('domain:media.example.com', 'topology-action-target');
    await runAction('device:nas', 'topology-action-device');
    await runAction('endpoint:jellyfin:web', 'topology-action-from-here');

    expect(drafts, [
      const ServiceAccessDraft(sourceServiceId: 'frps'),
      const ServiceAccessDraft(
        pattern: ServiceAccessPattern.frp,
        reachability: ServiceReachability.public,
        relayServiceId: 'frps',
        relayEndpointId: 'bind',
      ),
      const ServiceAccessDraft(
        pattern: ServiceAccessPattern.frp,
        reachability: ServiceReachability.public,
        targets: ['https://media.example.com'],
      ),
      const ServiceAccessDraft(),
      const ServiceAccessDraft(
        sourceServiceId: 'jellyfin',
        sourceEndpointId: 'web',
      ),
    ]);
    expect(drafts[3]!.initialDeviceId, 'nas');

    final plain = await selectOnSplit(tester, 'service:jellyfin');
    expect(
      find.descendant(
        of: plain,
        matching: find.byKey(const Key('topology-action-expose')),
      ),
      findsNothing,
      reason: 'Jellyfin is no relay',
    );
  });

  testWidgets('the topology redraws after an editor it opened', (tester) async {
    final f = topologyFixture();
    final added = ServiceNode(
      id: 'immich',
      deviceId: 'nas',
      name: 'Immich',
      endpoints: [ServiceEndpoint(id: 'web', port: 2283, isPrimary: true)],
    );
    var reloads = 0;
    await pumpTopology(
      tester,
      width: 1280,
      height: 800,
      reload: () async {
        reloads++;
        return (
          services: [...f.services, added],
          devices: f.devices,
          routes: f.routes,
        );
      },
    );
    expect(
      find.byKey(const ValueKey('topology-node-service:immich')),
      findsNothing,
    );

    final pane = await selectOnSplit(tester, 'device:nas');
    await tester.tap(
      find.descendant(
        of: pane,
        matching: find.byKey(const Key('topology-action-device')),
      ),
    );
    await pumpUntil(
      tester,
      find.byKey(const ValueKey('topology-node-service:immich')),
    );
    await settle(tester);
    expect(reloads, 1);
    expect(
      find.byKey(const ValueKey('topology-node-service:immich')),
      findsOneWidget,
    );
  });

  testWidgets('a split window shows the details pane instead of a sheet', (
    tester,
  ) async {
    final editedRoutes = <String>[];
    await pumpTopology(
      tester,
      width: 1280,
      height: 800,
      editedRoutes: editedRoutes,
    );
    expect(find.byKey(const Key('topology-details-empty')), findsOneWidget);

    await tester.tap(nodeCard('Jellyfin'));
    await settle(tester);
    expect(find.byType(BottomSheet), findsNothing);
    final pane = find.byKey(const Key('topology-details-pane'));
    expect(pane, findsOneWidget);

    final routeRow = find.byKey(const ValueKey('topology-route-media'));
    expect(find.descendant(of: pane, matching: routeRow), findsOneWidget);
    await tester.tap(routeRow);
    await settle(tester);
    expect(tester.widget<ListTile>(routeRow).selected, isTrue);
    await tester.tap(routeRow);
    await settle(tester);
    expect(tester.widget<ListTile>(routeRow).selected, isFalse);

    await tester.tap(find.byKey(const ValueKey('topology-route-edit-media')));
    await settle(tester);
    expect(editedRoutes, ['media']);

    await tester.tap(find.byKey(const Key('topology-details-close')));
    await settle(tester);
    expect(find.byKey(const Key('topology-details-empty')), findsOneWidget);
    expect(dimmed(tester, 'Home Assistant'), isFalse);
  });

  group('fitTransform', () {
    test('scales to the tighter axis and centres the other', () {
      final m = fitTransform(
        const Size(1000, 500),
        const Size(500, 500),
        minScale: 0.1,
        maxScale: 4,
        boundaryMargin: double.infinity,
      );
      expect(m.getMaxScaleOnAxis(), closeTo(0.5, 1e-9));
      expect(m.getTranslation().x, closeTo(0, 1e-9));
      expect(m.getTranslation().y, closeTo(125, 1e-9));
    });

    test('respects the zoom limits', () {
      final small = fitTransform(
        const Size(100, 100),
        const Size(500, 500),
        minScale: 0.35,
        maxScale: 2.4,
        boundaryMargin: 180,
      );
      expect(small.getMaxScaleOnAxis(), closeTo(2.4, 1e-9));
      expect(small.getTranslation().x, closeTo(130, 1e-9)); // (500 − 240) / 2

      final huge = fitTransform(
        const Size(10000, 100),
        const Size(500, 500),
        minScale: 0.35,
        maxScale: 2.4,
        boundaryMargin: 180,
      );
      expect(huge.getMaxScaleOnAxis(), closeTo(0.35, 1e-9));
      expect(huge.getTranslation().x, 0, reason: 'wider than the viewport');
    });

    test('starts at the edge when centring would leave the margin', () {
      // 35 dp tall at 0.35 in 500: centring needs 232.5 > 180 × 0.35 = 63.
      final m = fitTransform(
        const Size(10000, 100),
        const Size(500, 500),
        minScale: 0.35,
        maxScale: 2.4,
        boundaryMargin: 180,
      );
      expect(m.getTranslation().y, 0);
    });

    test('an empty canvas or viewport gives the identity', () {
      expect(
        fitTransform(Size.zero, const Size(500, 500), minScale: 1, maxScale: 1),
        Matrix4.identity(),
      );
      expect(
        fitTransform(const Size(10, 10), Size.zero, minScale: 1, maxScale: 1),
        Matrix4.identity(),
      );
    });
  });
}
