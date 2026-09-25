import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_analysis.dart';
import 'package:my_device/features/services/services/service_storage.dart';
import 'package:my_device/features/services/views/service_access_path_page.dart';
import 'package:my_device/features/services/views/service_edit_page.dart';
import 'package:my_device/features/services/views/service_route_edit_page.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test the advanced route editor's 1.5.6 additions and the two
/// edit dialogs that no longer dispose their controllers too early.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Driven in Simplified Chinese; widgets found by key or zh text.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  final guidedRoute = ServiceRoute(
    id: 'guided',
    name: 'Gitea via Caddy - git.home.arpa',
    sourceServiceId: 'gitea',
    sourceEndpointId: 'web',
    accessLevel: ServiceAccessLevel.lan,
    finalUrl: 'https://git.home.arpa',
    hops: [
      ServiceRouteHop(
        id: 'h1',
        type: ServiceRouteHopType.reverseProxy,
        method: ServiceRouteMethod.caddy,
        serviceId: 'caddy',
        endpointId: 'https',
      ),
    ],
  );
  final threeHops = ServiceRoute(
    id: 'three',
    name: 'three',
    sourceServiceId: 'gitea',
    sourceEndpointId: 'web',
    accessLevel: ServiceAccessLevel.public,
    finalUrl: 'https://git.example.com',
    hops: [
      ServiceRouteHop(
        type: ServiceRouteHopType.reverseProxy,
        method: ServiceRouteMethod.caddy,
        serviceId: 'caddy',
      ),
      ServiceRouteHop(
        type: ServiceRouteHopType.tunnel,
        method: ServiceRouteMethod.cloudflareTunnel,
        label: 'Cloudflare Tunnel',
      ),
      ServiceRouteHop(type: ServiceRouteHopType.dns, host: 'example.com'),
    ],
  );

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_route_edit_page',
      devices: [
        Device(id: 'home', name: '家庭服务器', category: DeviceCategory.desktop),
      ],
      services: [
        ServiceNode(
          id: 'gitea',
          deviceId: 'home',
          name: 'Gitea',
          endpoints: [ServiceEndpoint(id: 'web', port: 3000)],
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
      ],
      routes: [guidedRoute, threeHops],
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  // Pushes `page` from a host page, so a pop has somewhere to go, and waits
  // for the editor to finish loading its services.
  Future<void> pumpEditor(WidgetTester tester, Widget page) async {
    await pumpPageAt(
      tester,
      412,
      915,
      page: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<bool>(builder: (_) => page)),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
      ready: find.text('打开'),
    );
    await tester.tap(find.text('打开'));
    await pumpUntil(tester, find.byKey(const Key('route-lane')));
    await settle(tester);
  }

  // Text fields carry scrollables of their own, so name the page's list.
  Future<void> reveal(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('the lane dropdown pins the lane on save', (tester) async {
    await pumpEditor(tester, ServiceRouteEditPage(route: guidedRoute));
    expect(serviceAccessLaneForRoute(guidedRoute), ServiceAccessLane.public);

    await tester.tap(find.byKey(const Key('route-lane')));
    await settle(tester);
    await tester.tap(find.text('局域网 / WiFi').last);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.save).first);
    await pumpUntil(tester, find.text('打开'));

    final saved = (await tester.runAsync(
      ServiceStorage.load,
    ))!.routes.singleWhere((route) => route.id == 'guided');
    expect(saved.extraJson[serviceRouteAccessLaneKey], 'local');
    expect(serviceAccessLaneForRoute(saved), ServiceAccessLane.local);
    expect(saved.hops.single.id, 'h1');
  });

  testWidgets('a pattern route offers the guided editor', (tester) async {
    await pumpEditor(tester, ServiceRouteEditPage(route: guidedRoute));
    final action = find.byKey(const Key('route-guided-editor'));
    await reveal(tester, action);
    await tester.tap(action);
    await pumpUntil(tester, find.byKey(const Key('access-source-picker')));
    await settle(tester);
    expect(find.byType(ServiceAccessPathPage), findsOneWidget);
    expect(find.text('编辑访问路径'), findsOneWidget);
  });

  testWidgets('a three-hop route stays in the advanced editor', (tester) async {
    await pumpEditor(tester, ServiceRouteEditPage(route: threeHops));
    expect(find.byKey(const Key('route-guided-editor')), findsNothing);
  });

  testWidgets('a draft opens as a new route and keeps its fields', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      ServiceRouteEditPage(
        draft: ServiceRoute(
          id: 'draft-id',
          name: 'draft',
          sourceServiceId: 'gitea',
          sourceEndpointId: 'web',
          finalUrl: 'https://draft.example.com',
          extraJson: const {serviceRouteAccessLaneKey: 'vpn'},
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.manual,
              method: ServiceRouteMethod.direct,
              label: 'Direct',
            ),
          ],
        ),
      ),
    );
    expect(find.text('添加链路'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.delete_outline),
      ),
      findsNothing,
    );
    expect(find.text('VPN / Tailscale'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'https://draft.example.com',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a draft without a known source falls back safely', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      ServiceRouteEditPage(
        draft: ServiceRoute(name: 'draft', sourceServiceId: ''),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Gitea'), findsWidgets);
  });

  testWidgets('the hop dialog closes without touching disposed fields', (
    tester,
  ) async {
    await pumpEditor(tester, ServiceRouteEditPage(route: guidedRoute));
    final addHop = find.text('添加节点');
    await reveal(tester, addHop);
    await tester.tap(addHop);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '节点标签'), '备用入口');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('备用入口'));
    expect(find.text('备用入口'), findsOneWidget);
  });

  testWidgets('the endpoint dialog closes without touching disposed fields', (
    tester,
  ) async {
    await pumpPageAt(
      tester,
      412,
      915,
      page: const ServiceEditPage(),
      ready: find.byType(TextFormField),
    );
    final add = find.text('添加端点').first;
    await reveal(tester, add);
    await tester.tap(add);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '端口'), '8080');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, '保存'),
      ),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('http/8080'), findsOneWidget);
  });
}
