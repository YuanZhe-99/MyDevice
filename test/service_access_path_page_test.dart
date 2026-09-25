import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/network/models/network.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_access_patterns.dart';
import 'package:my_device/features/services/services/service_analysis.dart';
import 'package:my_device/features/services/services/service_storage.dart';
import 'package:my_device/features/services/views/service_access_path_page.dart';
import 'package:my_device/features/services/views/service_route_edit_page.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test the guided access-path page end to end against seeded
/// storage.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: A home server runs Jellyfin (8096) and Caddy (443); a VPS runs an
/// FRP server with a bind port (57000, primary) and a dashboard (7500) and
/// has one network assignment with a hostname; a NAS already publishes
/// `media.example.com`. Driven in Simplified Chinese; widgets are found by
/// key.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_access_path_page',
      devices: [
        Device(id: 'home', name: '家庭服务器', category: DeviceCategory.desktop),
        Device(id: 'nas', name: '存储', category: DeviceCategory.other),
        Device(id: 'vps', name: '云主机', category: DeviceCategory.vps),
      ],
      networks: [
        Network(id: 'lan', name: '家庭网络', type: NetworkType.lan),
        Network(id: 'net', name: '公网', type: NetworkType.other),
      ],
      assignments: const [
        NetworkDevice(
          networkId: 'lan',
          deviceId: 'home',
          ipAddress: '192.168.1.10',
        ),
        NetworkDevice(
          networkId: 'net',
          deviceId: 'vps',
          ipAddress: '203.0.113.10',
          hostname: 'vps.example.net',
        ),
      ],
      services: [
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
          endpoints: [
            ServiceEndpoint(
              id: 'bind',
              label: 'bind',
              port: 57000,
              isPrimary: true,
            ),
            ServiceEndpoint(id: 'dash', label: 'dash', port: 7500),
          ],
        ),
        ServiceNode(
          id: 'nextcloud',
          deviceId: 'nas',
          name: 'Nextcloud',
          endpoints: [ServiceEndpoint(id: 'nc', port: 8080)],
        ),
        ServiceNode(id: 'bare', deviceId: 'home', name: '无端点服务'),
      ],
      routes: [
        ServiceRoute(
          id: 'existing',
          name: 'Nextcloud via Cloudflare Tunnel - media.example.com',
          sourceServiceId: 'nextcloud',
          sourceEndpointId: 'nc',
          accessLevel: ServiceAccessLevel.public,
          finalUrl: 'https://media.example.com',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.tunnel,
              method: ServiceRouteMethod.cloudflareTunnel,
              label: 'Cloudflare Tunnel',
            ),
          ],
        ),
      ],
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  /// Pumps a host page whose button pushes the guided page, and returns a
  /// getter for the value the guided page popped.
  Future<bool? Function()> pumpGuided(
    WidgetTester tester, {
    double width = 412,
    double height = 915,
    ServiceAccessDraft? draft,
    ServiceRoute? route,
  }) async {
    bool? result;
    await pumpPageAt(
      tester,
      width,
      height,
      page: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ServiceAccessPathPage(draft: draft, route: route),
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
      ready: find.text('打开'),
    );
    await tester.tap(find.text('打开'));
    await pumpUntil(tester, find.byKey(const Key('access-source-picker')));
    await settle(tester);
    return () => result;
  }

  // The page is a lazy list on a phone: widgets out of view are not built
  // until scrolled to, so every interaction scrolls its target into view —
  // downwards first, then back up for targets above the viewport.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    final scrollable = find
        .descendant(
          of: find.byType(ServiceAccessPathPage),
          matching: find.byType(Scrollable),
        )
        .first;
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
    } else {
      try {
        await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
      } on StateError {
        await tester.scrollUntilVisible(finder, -200, scrollable: scrollable);
      }
    }
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await reveal(tester, finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> enterKey(WidgetTester tester, Key key, String text) async {
    final finder = find.byKey(key);
    await reveal(tester, finder);
    await tester.enterText(finder, text);
    await settle(tester);
  }

  Future<List<ServiceRoute>> storedRoutes(WidgetTester tester) async {
    final data = await tester.runAsync(ServiceStorage.load);
    return data!.routes;
  }

  Future<void> waitForPop(WidgetTester tester, bool? Function() popped) async {
    await pumpUntil(tester, find.text('打开'));
    for (var i = 0; i < 20 && popped() == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  const jellyfinDraft = ServiceAccessDraft(sourceServiceId: 'jellyfin');

  testWidgets('FRP needs a public port and saves the chosen ingress', (
    tester,
  ) async {
    final popped = await pumpGuided(tester, draft: jellyfinDraft);
    await tapKey(tester, const ValueKey('access-pattern-frp'));

    // The only FRP-like service is preselected with its primary ingress, and
    // the relay device's single assignment prefills the public host.
    await reveal(tester, find.byKey(const ValueKey('access-ingress-bind')));
    expect(find.byKey(const ValueKey('access-ingress-bind')), findsOneWidget);
    expect(find.byKey(const ValueKey('access-ingress-dash')), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('access-ingress-bind')))
          .selected,
      isTrue,
    );
    await reveal(tester, find.byKey(const Key('access-public-host')));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('access-public-host')))
          .controller!
          .text,
      'vps.example.net',
    );

    await tapKey(tester, const ValueKey('access-ingress-dash'));
    await tapKey(tester, const Key('access-save'));
    await reveal(tester, find.byKey(const Key('access-public-port')));
    expect(find.text('请输入 1–65535 之间的公网端口。'), findsOneWidget);
    expect((await storedRoutes(tester)).length, 1);
    // The "fill in the highlighted fields" snackbar covers the bottom save
    // button on a phone until it times out; the app-bar save stays usable.
    ScaffoldMessenger.of(
      tester.element(find.byType(ServiceAccessPathPage)),
    ).clearSnackBars();
    await settle(tester);

    await enterKey(tester, const Key('access-public-port'), '443');
    await tapKey(tester, const Key('access-save'));
    await waitForPop(tester, popped);

    expect(popped(), isTrue);
    final routes = await storedRoutes(tester);
    final saved = routes.singleWhere((route) => route.id != 'existing');
    final hop = saved.hops.single;
    expect(hop.method, ServiceRouteMethod.frp);
    expect(hop.type, ServiceRouteHopType.portForward);
    expect(hop.serviceId, 'frps');
    expect(hop.endpointId, 'dash');
    expect(hop.deviceId, 'vps');
    expect(hop.host, 'vps.example.net');
    expect(hop.port, 443);
    expect(saved.sourceEndpointId, 'web');
    expect(saved.extraJson[serviceRouteAccessLaneKey], 'public');
    expect(saved.accessLevel, ServiceAccessLevel.public);
  });

  testWidgets('the proxy prefix puts a reverse-proxy hop first', (
    tester,
  ) async {
    final popped = await pumpGuided(tester, draft: jellyfinDraft);
    await tapKey(tester, const ValueKey('access-pattern-frp'));
    await tapKey(tester, const Key('access-proxy-switch'));
    await enterKey(tester, const Key('access-public-port'), '443');
    await enterKey(tester, const Key('access-targets'), 'media2.example.com');
    await tapKey(tester, const Key('access-save'));
    await waitForPop(tester, popped);

    expect(popped(), isTrue);
    final saved = (await storedRoutes(
      tester,
    )).singleWhere((route) => route.id != 'existing');
    expect(saved.hops.length, 2);
    expect(saved.hops.first.type, ServiceRouteHopType.reverseProxy);
    expect(saved.hops.first.method, ServiceRouteMethod.caddy);
    expect(saved.hops.first.serviceId, 'caddy');
    expect(saved.hops.first.endpointId, 'https');
    expect(saved.hops.last.method, ServiceRouteMethod.frp);
    expect(saved.hops.last.endpointId, 'bind');
    expect(saved.name, 'Jellyfin via Caddy - media2.example.com');
  });

  testWidgets('a duplicate target warns but still saves', (tester) async {
    final popped = await pumpGuided(tester, draft: jellyfinDraft);
    await tapKey(tester, const ValueKey('access-pattern-cloudflareTunnel'));
    await reveal(tester, find.byKey(const Key('access-preview')));
    expect(find.byKey(const Key('access-warning')), findsNothing);

    await enterKey(
      tester,
      const Key('access-targets'),
      'https://media.example.com',
    );
    await reveal(tester, find.byKey(const Key('access-warning')));
    expect(find.byKey(const Key('access-warning')), findsOneWidget);

    await tapKey(tester, const Key('access-save'));
    await waitForPop(tester, popped);
    expect(popped(), isTrue);
    expect((await storedRoutes(tester)).length, 2);
  });

  testWidgets('the advanced editor receives the draft', (tester) async {
    await pumpGuided(tester, draft: jellyfinDraft);
    await tapKey(tester, const ValueKey('access-pattern-tailscaleFunnel'));
    await enterKey(
      tester,
      const Key('access-targets'),
      'https://jf.tailnet.ts.net',
    );
    await tapKey(tester, const Key('access-advanced'));
    // The editor loads its services from storage before it shows the form.
    await pumpUntil(tester, find.byKey(const Key('route-lane')));
    await settle(tester);

    expect(find.byType(ServiceRouteEditPage), findsOneWidget);
    expect(find.textContaining('Tailscale Funnel'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'https://jf.tailnet.ts.net',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the source sheet picks a service and its only endpoint', (
    tester,
  ) async {
    await pumpGuided(tester);
    expect(
      find.byKey(const ValueKey('access-source-endpoint-web')),
      findsNothing,
    );
    await tapKey(tester, const Key('access-source-picker'));
    await tester.enterText(
      find.byKey(const Key('access-picker-search')),
      'jelly',
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('access-pick-caddy')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('access-pick-jellyfin')));
    await settle(tester);

    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('access-source-endpoint-web')),
          )
          .selected,
      isTrue,
    );
    // Direct is the default pattern: its target is suggested from the home
    // server's LAN address.
    await reveal(tester, find.byKey(const Key('access-targets')));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('access-targets')))
          .controller!
          .text,
      'http://192.168.1.10:8096',
    );
  });

  testWidgets('leaving direct access takes its suggested address back', (
    tester,
  ) async {
    await pumpGuided(tester, draft: jellyfinDraft);
    TextField targets() =>
        tester.widget<TextField>(find.byKey(const Key('access-targets')));
    await reveal(tester, find.byKey(const Key('access-targets')));
    expect(targets().controller!.text, 'http://192.168.1.10:8096');

    await reveal(tester, find.byKey(const Key('access-preview')));
    expect(
      find.text('Jellyfin 8096 -> 直连 -> 192.168.1.10:8096'),
      findsOneWidget,
    );

    await tapKey(tester, const ValueKey('access-pattern-frp'));
    await reveal(tester, find.byKey(const Key('access-targets')));
    expect(targets().controller!.text, isEmpty);

    // A typed address is the user's and stays.
    await tapKey(tester, const ValueKey('access-pattern-direct'));
    await enterKey(tester, const Key('access-targets'), 'http://jf.lan');
    await tapKey(tester, const ValueKey('access-pattern-frp'));
    await reveal(tester, find.byKey(const Key('access-targets')));
    expect(targets().controller!.text, 'http://jf.lan');
  });

  testWidgets('adding an endpoint inline saves it onto the service', (
    tester,
  ) async {
    await pumpGuided(
      tester,
      draft: const ServiceAccessDraft(sourceServiceId: 'bare'),
    );
    await tapKey(tester, const ValueKey('access-source-endpoint-add'));
    await tester.enterText(find.widgetWithText(TextField, '端口'), '9000');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    // Wait for the new endpoint's chip, which only exists once the service
    // was saved with it and the page reloaded.
    await pumpUntil(
      tester,
      find.byWidgetPredicate(
        (widget) =>
            widget is ChoiceChip &&
            widget.selected &&
            '${(widget.key as ValueKey?)?.value}'.startsWith(
              'access-source-endpoint-',
            ),
      ),
    );
    await settle(tester);

    final data = await tester.runAsync(ServiceStorage.load);
    final bare = data!.services.singleWhere((s) => s.id == 'bare');
    expect(bare.endpoints.single.port, 9000);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(
              ValueKey('access-source-endpoint-${bare.endpoints.single.id}'),
            ),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('editing a saved path keeps its id and offers delete', (
    tester,
  ) async {
    final draft = const ServiceAccessDraft(
      sourceServiceId: 'jellyfin',
      sourceEndpointId: 'web',
      pattern: ServiceAccessPattern.cloudflareTunnel,
      reachability: ServiceReachability.public,
      targets: ['https://jf.example.com'],
    );
    final services = (await tester.runAsync(ServiceStorage.load))!.services;
    final route = draft.toRoute(services: services);
    await tester.runAsync(() => ServiceStorage.addOrUpdateRoute(route));

    final popped = await pumpGuided(tester, route: route);
    expect(find.text('编辑访问路径'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    await tapKey(tester, const ValueKey('access-reach-publicAuthenticated'));
    await tapKey(tester, const Key('access-save'));
    await waitForPop(tester, popped);

    final saved = (await storedRoutes(
      tester,
    )).singleWhere((r) => r.id == route.id);
    expect(saved.accessLevel, ServiceAccessLevel.authenticated);
    expect(saved.extraJson[serviceRouteAccessLaneKey], 'public');
  });

  testWidgets('a phone keeps one column and a split window two panes', (
    tester,
  ) async {
    await pumpGuided(tester, draft: jellyfinDraft);
    expect(find.byKey(const Key('access-single-pane')), findsOneWidget);
    expect(find.byKey(const Key('access-two-pane')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Z Fold 8 unfolded in landscape gets two panes', (
    tester,
  ) async {
    await pumpGuided(tester, width: 933, height: 704, draft: jellyfinDraft);
    expect(find.byKey(const Key('access-two-pane')), findsOneWidget);
    final preview = tester.getTopLeft(find.byKey(const Key('access-preview')));
    final pattern = tester.getTopLeft(
      find.byKey(const ValueKey('access-pattern-frp')),
    );
    expect(preview.dx, greaterThan(pattern.dx));
    expect(tester.takeException(), isNull);
  });
}
