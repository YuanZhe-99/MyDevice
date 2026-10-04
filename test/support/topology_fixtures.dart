import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_analysis.dart';

// Topology inventories shared by the layout tests and the opt-in PNG
// preview (`test/service_topology_preview_test.dart`).

/// Purpose: Build the FRP walkthrough data as a sample graph.
/// Inputs: None.
/// Returns: `SampleGraph`.
/// Side effects: None.
/// Notes: Caddy on a Mac publishes `example.com` through FRP on a VPS.
SampleGraph frpSample() {
  final data = frpTopologyData();
  return sampleOf(data.devices, data.services, data.routes);
}

/// Purpose: Build one service whose three endpoints are each a route's source.
/// Inputs: None.
/// Returns: `TopologyData` — devices, services and routes.
/// Side effects: None.
/// Notes: The routes have no hops and no targets, so the endpoint chips are
/// alone on their rows except the first, which the service card shares.
TopologyData chipRowsData() {
  final device = Device(
    id: 'box',
    name: 'Box',
    category: DeviceCategory.desktop,
  );
  final service = ServiceNode(
    id: 'app',
    deviceId: device.id,
    name: 'App',
    endpoints: [
      ServiceEndpoint(id: 'a', port: 8001),
      ServiceEndpoint(id: 'b', port: 8002),
      ServiceEndpoint(id: 'c', port: 8003),
    ],
  );
  return TopologyData(
    devices: [device],
    services: [service],
    routes: [
      for (final endpoint in ['a', 'b', 'c'])
        ServiceRoute(
          id: 'route-$endpoint',
          name: 'Route $endpoint',
          sourceServiceId: service.id,
          sourceEndpointId: endpoint,
        ),
    ],
  );
}

/// Purpose: Build two home devices publishing through one shared VPS.
/// Inputs: None.
/// Returns: `SampleGraph`.
/// Side effects: None.
/// Notes: Two services on each home device go out through one FRP server;
/// one domain is shared by a service of each device. Service names are
/// chosen so the label order interleaves the devices, which the row order
/// alone leaves crossed.
SampleGraph sharedVpsSample() {
  final devices = [
    Device(id: 'home-a', name: 'Alpha box', category: DeviceCategory.desktop),
    Device(id: 'home-b', name: 'Beta NAS', category: DeviceCategory.desktop),
    Device(id: 'vps', name: 'VPS', category: DeviceCategory.vps),
  ];
  ServiceNode service(String id, String device, String name, int port) =>
      ServiceNode(
        id: id,
        deviceId: device,
        name: name,
        endpoints: [ServiceEndpoint(id: '$id-ep', port: port, isPrimary: true)],
      );
  final services = [
    service('zapp', 'home-a', 'Zeta app', 8080),
    service('aapp', 'home-a', 'Alpha app', 8081),
    service('bapp', 'home-b', 'Beta app', 9000),
    service('capp', 'home-b', 'Aardvark', 9001),
    ServiceNode(
      id: 'frp',
      deviceId: 'vps',
      name: 'FRP',
      kind: ServiceKind.tunnel,
      endpoints: [ServiceEndpoint(id: 'frp-ep', port: 7000, isPrimary: true)],
    ),
  ];
  ServiceRoute frp(String id, String source, int port, String target) =>
      ServiceRoute(
        id: id,
        name: id,
        sourceServiceId: source,
        sourceEndpointId: '$source-ep',
        accessLevel: ServiceAccessLevel.public,
        finalUrl: target,
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.portForward,
            method: ServiceRouteMethod.frp,
            serviceId: 'frp',
            deviceId: 'vps',
            port: port,
          ),
        ],
      );
  final routes = [
    frp('r1', 'zapp', 443, 'shared.example.com'),
    frp('r2', 'bapp', 8443, 'shared.example.com'),
    frp('r3', 'aapp', 444, 'a.example.com'),
    frp('r4', 'capp', 445, 'c.example.com'),
    ServiceRoute(
      id: 'r5',
      name: 'r5',
      sourceServiceId: 'zapp',
      sourceEndpointId: 'zapp-ep',
      finalUrl: 'http://z.lan',
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.manual,
          method: ServiceRouteMethod.direct,
        ),
      ],
    ),
  ];
  return sampleOf(devices, services, routes);
}

/// Purpose: Build a synthetic inventory of at least 60 nodes and 80 edges.
/// Inputs: None.
/// Returns: `SampleGraph`.
/// Side effects: None.
/// Notes: Three home devices with a Caddy and three services each; every
/// service is published through one of two VPS FRP servers, two of them
/// through their device's Caddy first, and reached on the LAN as well.
SampleGraph syntheticSample() {
  final devices = <Device>[];
  final services = <ServiceNode>[];
  final routes = <ServiceRoute>[];
  for (var v = 0; v < 2; v++) {
    devices.add(
      Device(id: 'vps$v', name: 'VPS $v', category: DeviceCategory.vps),
    );
    services.add(
      ServiceNode(
        id: 'frp$v',
        deviceId: 'vps$v',
        name: 'FRP $v',
        kind: ServiceKind.tunnel,
        endpoints: [ServiceEndpoint(id: 'bind', port: 7000, isPrimary: true)],
      ),
    );
  }
  for (var d = 0; d < 3; d++) {
    devices.add(
      Device(id: 'home$d', name: 'Home $d', category: DeviceCategory.desktop),
    );
    services.add(
      ServiceNode(
        id: 'caddy$d',
        deviceId: 'home$d',
        name: 'Caddy $d',
        kind: ServiceKind.reverseProxy,
        endpoints: [ServiceEndpoint(id: 'https', port: 443, isPrimary: true)],
      ),
    );
    for (var s = 0; s < 3; s++) {
      final id = 'app$d-$s';
      services.add(
        ServiceNode(
          id: id,
          deviceId: 'home$d',
          name: 'App $d.$s',
          endpoints: [
            ServiceEndpoint(id: 'web', port: 8000 + s, isPrimary: true),
          ],
        ),
      );
      routes.add(
        ServiceRoute(
          id: '$id-public',
          name: '$id public',
          sourceServiceId: id,
          sourceEndpointId: 'web',
          accessLevel: ServiceAccessLevel.public,
          finalUrl: 'https://$id.example.com',
          hops: [
            if (s != 1)
              ServiceRouteHop(
                type: ServiceRouteHopType.reverseProxy,
                method: ServiceRouteMethod.caddy,
                serviceId: 'caddy$d',
                endpointId: 'https',
              ),
            ServiceRouteHop(
              type: ServiceRouteHopType.portForward,
              method: ServiceRouteMethod.frp,
              serviceId: 'frp${(d + s) % 2}',
              deviceId: 'vps${(d + s) % 2}',
              port: 10000 + d * 10 + s,
            ),
          ],
        ),
      );
      routes.add(
        ServiceRoute(
          id: '$id-lan',
          name: '$id lan',
          sourceServiceId: id,
          sourceEndpointId: 'web',
          finalUrl: 'http://home$d.lan:${8000 + s}',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.manual,
              method: ServiceRouteMethod.direct,
            ),
          ],
        ),
      );
    }
  }
  return sampleOf(devices, services, routes);
}

/// Purpose: Build and return sample graph for the current context.
/// Inputs: None.
/// Returns: `SampleGraph`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
SampleGraph buildSampleGraph() {
  final devices = [
    Device(id: 'mac-mini', name: 'Mac mini', category: DeviceCategory.desktop),
  ];
  final jellyfin = ServiceNode(
    id: 'jellyfin',
    deviceId: 'mac-mini',
    name: 'Jellyfin',
    endpoints: [ServiceEndpoint(id: 'web', port: 8096)],
  );
  final vaultwarden = ServiceNode(
    id: 'vaultwarden',
    deviceId: 'mac-mini',
    name: 'Vaultwarden',
    endpoints: [ServiceEndpoint(id: 'web', port: 59880)],
  );
  final caddy = ServiceNode(
    id: 'caddy',
    deviceId: 'mac-mini',
    name: 'Caddy',
    kind: ServiceKind.reverseProxy,
    endpoints: [ServiceEndpoint(id: 'https', port: 443)],
  );
  final routes = [
    ServiceRoute(
      id: 'jellyfin-public',
      name: 'Jellyfin via Caddy',
      sourceServiceId: jellyfin.id,
      sourceEndpointId: 'web',
      accessLevel: ServiceAccessLevel.public,
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.reverseProxy,
          method: ServiceRouteMethod.caddy,
          serviceId: caddy.id,
          endpointId: 'https',
        ),
      ],
      finalUrl: 'https://jellyfin.example.com',
    ),
    ServiceRoute(
      id: 'vaultwarden-public',
      name: 'Vaultwarden via Caddy',
      sourceServiceId: vaultwarden.id,
      sourceEndpointId: 'web',
      accessLevel: ServiceAccessLevel.public,
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.reverseProxy,
          method: ServiceRouteMethod.caddy,
          serviceId: caddy.id,
          endpointId: 'https',
        ),
      ],
      finalUrl: 'https://vault.example.com',
    ),
    ServiceRoute(
      id: 'caddy-frp',
      name: 'Caddy FRP',
      sourceServiceId: caddy.id,
      sourceEndpointId: 'https',
      accessLevel: ServiceAccessLevel.public,
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.portForward,
          method: ServiceRouteMethod.frp,
          host: '203.0.113.10',
          port: 443,
        ),
      ],
      finalUrl: 'https://cloud.example.com',
    ),
  ];
  return sampleOf(devices, [jellyfin, vaultwarden, caddy], routes);
}

/// Purpose: Build a graph whose route rows would be sparse without rank-local compaction.
/// Inputs: None.
/// Returns: `SampleGraph`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
SampleGraph buildSparseRouteGraph() {
  final device = Device(
    id: 'device-1',
    name: 'Mac mini',
    category: DeviceCategory.desktop,
  );
  final appA = ServiceNode(
    id: 'app-a',
    deviceId: device.id,
    name: 'App A',
    endpoints: [ServiceEndpoint(id: 'endpoint-a', port: 8000)],
  );
  final appB = ServiceNode(
    id: 'app-b',
    deviceId: device.id,
    name: 'App B',
    endpoints: [ServiceEndpoint(id: 'endpoint-b', port: 9000)],
  );
  final routes = [
    for (var i = 0; i < 6; i++)
      ServiceRoute(
        id: 'app-a-route-$i',
        name: 'App A Public $i',
        sourceServiceId: appA.id,
        sourceEndpointId: 'endpoint-a',
        accessLevel: ServiceAccessLevel.public,
        hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
        finalUrl: 'https://a$i.example.com',
      ),
    ServiceRoute(
      id: 'app-b-route',
      name: 'App B Public',
      sourceServiceId: appB.id,
      sourceEndpointId: 'endpoint-b',
      accessLevel: ServiceAccessLevel.public,
      hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
      finalUrl: 'https://b.example.com',
    ),
  ];
  return sampleOf([device], [appA, appB], routes);
}

/// Purpose: Provide the internal frp topology data helper for this file.
/// Inputs: None.
/// Returns: `TopologyData`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
TopologyData frpTopologyData() {
  final devices = [
    Device(id: 'mac', name: 'Mac mini', category: DeviceCategory.desktop),
    Device(id: 'cloud', name: 'Cloudcone VPS', category: DeviceCategory.vps),
  ];
  final services = [
    ServiceNode(
      id: 'caddy',
      deviceId: 'mac',
      name: 'Caddy',
      kind: ServiceKind.reverseProxy,
      endpoints: [
        ServiceEndpoint(
          id: 'caddy443',
          label: 'HTTPS',
          protocol: ServiceProtocol.https,
          port: 443,
          isPrimary: true,
        ),
      ],
    ),
    ServiceNode(
      id: 'frp',
      deviceId: 'cloud',
      name: 'FRP',
      kind: ServiceKind.tunnel,
      endpoints: [
        ServiceEndpoint(
          id: 'frp57000',
          label: 'Default',
          protocol: ServiceProtocol.http,
          transport: ServiceTransport.tcpUdp,
          port: 57000,
          scope: ServiceScope.public,
          isPrimary: true,
        ),
      ],
    ),
  ];
  final routes = [
    ServiceRoute(
      id: 'route',
      name: 'FRP public route',
      sourceServiceId: 'caddy',
      sourceEndpointId: 'caddy443',
      accessLevel: ServiceAccessLevel.public,
      finalUrl: 'example.com',
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.portForward,
          method: ServiceRouteMethod.frp,
          serviceId: 'frp',
          deviceId: 'cloud',
          port: 443,
        ),
      ],
    ),
  ];
  return TopologyData(devices: devices, services: services, routes: routes);
}

class TopologyData {
  final List<Device> devices;
  final List<ServiceNode> services;
  final List<ServiceRoute> routes;

  /// Purpose: Create a frp topology data instance.
  /// Inputs: None.
  /// Returns: A new `TopologyData` instance.
  /// Side effects: None.
  /// Notes: None.
  const TopologyData({
    required this.devices,
    required this.services,
    required this.routes,
  });
}

class SampleGraph {
  final ServiceTopologyGraph graph;
  final List<ServiceRoute> routes;

  /// The inventory the graph was built from; the preview needs it to draw
  /// node icons.
  final List<ServiceNode> services;
  final List<Device> devices;

  /// Purpose: Create a sample graph instance.
  /// Inputs: `graph`, `routes`; `services`, `devices` — the inventory.
  /// Returns: A new `SampleGraph` instance.
  /// Side effects: None.
  /// Notes: None.
  const SampleGraph(
    this.graph,
    this.routes, {
    this.services = const [],
    this.devices = const [],
  });
}

/// Purpose: Build a graph from an inventory and keep the inventory with it.
/// Inputs: `devices`, `services`, `routes`.
/// Returns: `SampleGraph`.
/// Side effects: None.
/// Notes: None.
SampleGraph sampleOf(
  List<Device> devices,
  List<ServiceNode> services,
  List<ServiceRoute> routes,
) => SampleGraph(
  buildServiceTopology(services: services, routes: routes, devices: devices),
  routes,
  services: services,
  devices: devices,
);

/// Purpose: Build a homelab shaped like a real one that drew badly in 1.8.2.
/// Inputs: None.
/// Returns: `SampleGraph`.
/// Side effects: None.
/// Notes: One Mac mini runs six web services, Caddy and Tailscale; a VPS
/// runs FRP. Five services are published through Caddy and FRP, three paths
/// go over Tailscale, and Termix reaches Tailscale without a port chip, which
/// used to shift every chip below it a row away from its service.
SampleGraph homelabSample() {
  final devices = [
    Device(
      id: 'mac',
      name: 'Mac mini (2024)',
      category: DeviceCategory.desktop,
    ),
    Device(id: 'vps', name: 'Cloud VPS 1C1G', category: DeviceCategory.vps),
  ];
  ServiceNode app(
    String id,
    String name,
    ServiceKind kind,
    List<(String, int)> ports,
  ) => ServiceNode(
    id: id,
    deviceId: 'mac',
    name: name,
    kind: kind,
    endpoints: [
      for (final (index, (endpoint, port)) in ports.indexed)
        ServiceEndpoint(id: endpoint, port: port, isPrimary: index == 0),
    ],
  );
  final services = [
    app('gitea', 'Gitea', ServiceKind.git, [('web', 59922), ('ssh', 59981)]),
    app('jellyfin', 'Jellyfin', ServiceKind.media, [
      ('web', 8096),
      ('https', 8920),
    ]),
    app('termix', 'Termix', ServiceKind.dev, [('web', 59882)]),
    app('nextcloud', 'Nextcloud', ServiceKind.storage, [('web', 59881)]),
    app('vaultwarden', 'Vaultwarden', ServiceKind.web, [('web', 59880)]),
    app('wordpress', 'WordPress', ServiceKind.web, [('web', 59982)]),
    app('caddy', 'Caddy', ServiceKind.reverseProxy, [
      ('https', 443),
      ('http', 80),
    ]),
    app('tailscale', 'Tailscale', ServiceKind.network, const []),
    ServiceNode(
      id: 'frp',
      deviceId: 'vps',
      name: 'FRP',
      kind: ServiceKind.tunnel,
      endpoints: [ServiceEndpoint(id: 'bind', port: 57000, isPrimary: true)],
    ),
  ];
  ServiceRoute public(String source, String endpoint, String target) =>
      ServiceRoute(
        id: '$source-public',
        name: '$source public',
        sourceServiceId: source,
        sourceEndpointId: endpoint,
        accessLevel: ServiceAccessLevel.public,
        finalUrl: target,
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
            serviceId: 'frp',
            deviceId: 'vps',
            host: 'vps.example.com',
            port: 443,
          ),
        ],
      );
  ServiceRoute tailnet(String source, String? endpoint, String target) =>
      ServiceRoute(
        id: '$source-tailnet',
        name: '$source tailnet',
        sourceServiceId: source,
        sourceEndpointId: endpoint,
        accessLevel: ServiceAccessLevel.vpn,
        finalUrl: target,
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.tunnel,
            serviceId: 'tailscale',
          ),
        ],
      );
  final routes = [
    public('gitea', 'web', 'https://example.com'),
    public('jellyfin', 'web', 'https://example.com'),
    public('nextcloud', 'web', 'https://cloud.example.com'),
    public('vaultwarden', 'web', 'https://example.com'),
    public('wordpress', 'web', 'https://example.com'),
    tailnet('gitea', 'ssh', 'mac-mini.tail1234.ts.net'),
    tailnet('termix', null, 'mac-mini.tail1234.ts.net'),
    tailnet('caddy', 'https', 'mac-mini.et.example.net'),
  ];
  return sampleOf(devices, services, routes);
}
