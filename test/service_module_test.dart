import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/datasets/models/dataset.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/network/models/network.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_analysis.dart';
import 'package:my_device/features/services/services/service_template_service.dart';
import 'package:my_device/shared/services/import_export_service.dart';
import 'package:my_device/shared/services/local_api_server.dart';
import 'package:my_device/shared/services/sync_merge.dart';

/// Purpose: Encode the requested value into a serialized form.
/// Inputs: `json`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: None.
String encode(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

/// Purpose: Register the test cases defined in this file.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: This serves as the test entry point for the file.
void main() {
  test('service models preserve unknown fields and docker compose', () {
    final raw = {
      'futureRoot': true,
      'services': [
        {
          'id': 'service-1',
          'deviceId': 'device-1',
          'name': 'Jellyfin',
          'kind': 'media',
          'state': 'active',
          'futureServiceField': 'kept',
          'dockerCompose':
              'services:\n  jellyfin:\n    image: jellyfin/jellyfin',
          'endpoints': [
            {
              'id': 'endpoint-1',
              'protocol': 'http',
              'transport': 'tcp',
              'port': 8096,
              'scope': 'lan',
              'futureEndpointField': 42,
            },
          ],
          'modifiedAt': '2026-05-10T12:00:00.000',
        },
      ],
      'routes': [],
    };

    final data = ServiceData.fromJson(raw);
    final edited = data.services.single.copyWith(name: 'Jellyfin Media');
    final saved = ServiceData(
      services: [edited],
      routes: data.routes,
      extraJson: data.extraJson,
    ).toJson();
    final service = saved['services'][0] as Map<String, dynamic>;
    final endpoint =
        (service['endpoints'] as List<dynamic>)[0] as Map<String, dynamic>;

    expect(saved['futureRoot'], true);
    expect(service['name'], 'Jellyfin Media');
    expect(service['futureServiceField'], 'kept');
    expect(service['dockerCompose'], contains('jellyfin/jellyfin'));
    expect(endpoint['futureEndpointField'], 42);
  });

  test('service sync keeps remote unknown fields when local wins', () {
    final base = encode({
      'services': [
        {
          'id': 'service-1',
          'deviceId': 'device-1',
          'name': 'Gitea',
          'kind': 'git',
          'state': 'active',
          'modifiedAt': '2026-05-10T12:00:00.000',
        },
      ],
      'routes': [],
    });
    final local = encode({
      'services': [
        {
          'id': 'service-1',
          'deviceId': 'device-1',
          'name': 'Gitea Local',
          'kind': 'git',
          'state': 'active',
          'modifiedAt': '2026-05-12T12:00:00.000',
        },
      ],
      'routes': [],
    });
    final remote = encode({
      'services': [
        {
          'id': 'service-1',
          'deviceId': 'device-1',
          'name': 'Gitea Remote',
          'kind': 'git',
          'state': 'active',
          'futureServiceField': 'remote-only',
          'modifiedAt': '2026-05-11T12:00:00.000',
        },
      ],
      'routes': [],
    });

    final result = mergeServiceData(local, remote, base, autoResolve: true);
    final saved = ServiceData(
      services: result.mergedServices,
      routes: result.mergedRoutes,
      extraJson: result.extraJson,
    ).toJson();
    final service = saved['services'][0] as Map<String, dynamic>;

    expect(service['name'], 'Gitea Local');
    expect(service['futureServiceField'], 'remote-only');
  });

  test('port conflict detection groups same device transport and port', () {
    final services = [
      ServiceNode(
        id: 'service-1',
        deviceId: 'device-1',
        name: 'Caddy',
        endpoints: [
          ServiceEndpoint(
            id: 'endpoint-1',
            protocol: ServiceProtocol.https,
            transport: ServiceTransport.tcp,
            port: 443,
          ),
        ],
      ),
      ServiceNode(
        id: 'service-2',
        deviceId: 'device-1',
        name: 'Pangolin',
        endpoints: [
          ServiceEndpoint(
            id: 'endpoint-2',
            protocol: ServiceProtocol.https,
            transport: ServiceTransport.tcp,
            bindAddress: '0.0.0.0',
            port: 443,
          ),
        ],
      ),
    ];

    final conflicts = findServicePortConflicts(services);

    expect(conflicts, hasLength(1));
    expect(conflicts.single.port, 443);
    expect(
      conflicts.single.uses.map((use) => use.service.name),
      contains('Caddy'),
    );
    expect(
      conflicts.single.uses.map((use) => use.service.name),
      contains('Pangolin'),
    );
  });

  test('port conflict ignores different concrete bind addresses', () {
    final services = [
      ServiceNode(
        id: 'service-1',
        deviceId: 'device-1',
        name: 'App A',
        endpoints: [
          ServiceEndpoint(
            id: 'endpoint-1',
            transport: ServiceTransport.tcp,
            bindAddress: '127.0.0.1',
            port: 8080,
          ),
        ],
      ),
      ServiceNode(
        id: 'service-2',
        deviceId: 'device-1',
        name: 'App B',
        endpoints: [
          ServiceEndpoint(
            id: 'endpoint-2',
            transport: ServiceTransport.tcp,
            bindAddress: '192.168.1.20',
            port: 8080,
          ),
        ],
      ),
    ];

    expect(findServicePortConflicts(services), isEmpty);
  });

  test(
    'reference warnings include missing endpoint and duplicate public URL',
    () {
      final service = ServiceNode(
        id: 'service-1',
        deviceId: 'device-1',
        name: 'Jellyfin',
        endpoints: [ServiceEndpoint(id: 'endpoint-1', port: 8096)],
      );
      final routes = [
        ServiceRoute(
          id: 'route-1',
          name: 'Jellyfin Public A',
          sourceServiceId: service.id,
          sourceEndpointId: 'missing-endpoint',
          finalUrl: 'https://jellyfin.example.com',
          accessLevel: ServiceAccessLevel.public,
          hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
        ),
        ServiceRoute(
          id: 'route-2',
          name: 'Jellyfin Public B',
          sourceServiceId: service.id,
          sourceEndpointId: 'endpoint-1',
          finalUrl: 'https://jellyfin.example.com',
          accessLevel: ServiceAccessLevel.public,
          hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
        ),
      ];

      final warnings = findServiceReferenceWarnings(
        services: [service],
        routes: routes,
        devices: const [],
        networks: const [],
      );

      expect(
        warnings.map((warning) => warning.kind),
        contains(ServiceWarningKind.missingSourceEndpoint),
      );
      expect(
        warnings.map((warning) => warning.kind),
        contains(ServiceWarningKind.duplicateFinalUrl),
      );
    },
  );

  test(
    'duplicate public URL ignores same device with different source ports',
    () {
      final services = [
        ServiceNode(
          id: 'service-1',
          deviceId: 'device-1',
          name: 'Jellyfin',
          endpoints: [ServiceEndpoint(id: 'endpoint-1', port: 8096)],
        ),
        ServiceNode(
          id: 'service-2',
          deviceId: 'device-1',
          name: 'Gitea',
          endpoints: [ServiceEndpoint(id: 'endpoint-2', port: 59922)],
        ),
      ];
      final routes = [
        ServiceRoute(
          id: 'route-1',
          name: 'Jellyfin Public',
          sourceServiceId: 'service-1',
          sourceEndpointId: 'endpoint-1',
          finalUrl: 'https://cloud.example.com',
          accessLevel: ServiceAccessLevel.public,
          hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
        ),
        ServiceRoute(
          id: 'route-2',
          name: 'Gitea Public',
          sourceServiceId: 'service-2',
          sourceEndpointId: 'endpoint-2',
          finalUrl: 'https://cloud.example.com',
          accessLevel: ServiceAccessLevel.public,
          hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
        ),
      ];

      final warnings = findServiceReferenceWarnings(
        services: services,
        routes: routes,
        devices: [
          Device(
            id: 'device-1',
            name: 'Mac mini',
            category: DeviceCategory.desktop,
          ),
        ],
        networks: const [],
      );

      expect(
        warnings.map((warning) => warning.kind),
        isNot(contains(ServiceWarningKind.duplicateFinalUrl)),
      );
    },
  );

  test('duplicate public URL warns across devices or overlapping ports', () {
    final services = [
      ServiceNode(
        id: 'service-1',
        deviceId: 'device-1',
        name: 'App A',
        endpoints: [ServiceEndpoint(id: 'endpoint-1', port: 443)],
      ),
      ServiceNode(
        id: 'service-2',
        deviceId: 'device-1',
        name: 'App B',
        endpoints: [ServiceEndpoint(id: 'endpoint-2', port: 443)],
      ),
      ServiceNode(
        id: 'service-3',
        deviceId: 'device-2',
        name: 'App C',
        endpoints: [ServiceEndpoint(id: 'endpoint-3', port: 8443)],
      ),
    ];
    final routes = [
      ServiceRoute(
        id: 'route-1',
        name: 'App A Public',
        sourceServiceId: 'service-1',
        sourceEndpointId: 'endpoint-1',
        finalUrl: 'https://shared.example.com',
        accessLevel: ServiceAccessLevel.public,
        hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
      ),
      ServiceRoute(
        id: 'route-2',
        name: 'App B Public',
        sourceServiceId: 'service-2',
        sourceEndpointId: 'endpoint-2',
        finalUrl: 'https://shared.example.com',
        accessLevel: ServiceAccessLevel.public,
        hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
      ),
      ServiceRoute(
        id: 'route-3',
        name: 'App C Public',
        sourceServiceId: 'service-3',
        sourceEndpointId: 'endpoint-3',
        finalUrl: 'https://shared.example.com',
        accessLevel: ServiceAccessLevel.public,
        hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
      ),
    ];

    final warnings = findServiceReferenceWarnings(
      services: services,
      routes: routes,
      devices: [
        Device(
          id: 'device-1',
          name: 'Mac mini',
          category: DeviceCategory.desktop,
        ),
        Device(id: 'device-2', name: 'NUC', category: DeviceCategory.desktop),
      ],
      networks: const [],
    );

    expect(
      warnings.map((warning) => warning.kind),
      contains(ServiceWarningKind.duplicateFinalUrl),
    );
  });

  test('service templates include featured entries and compose examples', () {
    final templates = ServiceTemplateService.loadTemplates();
    final jellyfin = templates
        .where((template) => template.id == 'jellyfin')
        .single;
    final caddy = templates.where((template) => template.id == 'caddy').single;
    final cloudflared = templates
        .where((template) => template.id == 'cloudflare-tunnel-compose')
        .single;

    expect(jellyfin.featured, isTrue);
    expect(jellyfin.endpoints.map((endpoint) => endpoint.port), contains(8096));
    expect(caddy.dockerCompose, contains('caddy:latest'));
    expect(cloudflared.dockerCompose, contains('cloudflared'));
  });

  test('local API stats can include service summary shape', () {
    final stats = LocalApiServer.buildStatsJson(
      devices: [
        Device(
          id: 'device-1',
          name: 'Mac mini',
          category: DeviceCategory.desktop,
        ),
      ],
      services: [
        ServiceNode(id: 'service-1', deviceId: 'device-1', name: 'Jellyfin'),
      ],
      routes: [
        ServiceRoute(
          id: 'route-1',
          name: 'Jellyfin Public',
          sourceServiceId: 'service-1',
        ),
      ],
    );

    expect(stats['total'], 1);
    expect(stats['services'], {'total': 1, 'routes': 1, 'devices': 1});
  });

  test('markdown export includes services routes and public targets', () {
    final device = Device(
      id: 'mac-mini',
      name: 'Mac mini',
      category: DeviceCategory.desktop,
    );
    final service = ServiceNode(
      id: 'service-1',
      deviceId: device.id,
      name: 'Jellyfin',
      kind: ServiceKind.media,
      runtime: ServiceRuntime.compose,
      endpoints: [
        ServiceEndpoint(
          id: 'endpoint-1',
          label: 'Web UI',
          protocol: ServiceProtocol.http,
          port: 8096,
          scope: ServiceScope.lan,
        ),
      ],
      dockerCompose: 'services:\n  jellyfin:\n    image: jellyfin/jellyfin',
    );
    final route = ServiceRoute(
      id: 'route-1',
      name: 'Jellyfin public',
      sourceServiceId: service.id,
      sourceEndpointId: 'endpoint-1',
      accessLevel: ServiceAccessLevel.public,
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.tunnel,
          method: ServiceRouteMethod.cloudflareTunnel,
        ),
      ],
      finalUrl: 'https://jellyfin.example.com',
      extraJson: const {
        serviceRoutePublicTargetsKey: [
          'https://jellyfin.example.com',
          'https://media.example.com',
        ],
      },
    );

    final markdown = ImportExportService.buildMarkdown(
      deviceData: DeviceData(devices: [device]),
      networkData: const NetworkData(),
      datasetData: const DataSetData(),
      serviceData: ServiceData(services: [service], routes: [route]),
      exportedAt: DateTime(2026, 5, 11, 10, 7),
    );

    expect(markdown, contains('1 services, 1 service routes'));
    expect(markdown, contains('# Services'));
    expect(markdown, contains('## Jellyfin'));
    expect(markdown, contains('- **Device:** Mac mini'));
    expect(markdown, contains('- Web UI, http/tcp, 8096, lan'));
    expect(markdown, contains('image: jellyfin/jellyfin'));
    expect(markdown, contains('# Service Routes'));
    expect(markdown, contains('jellyfin.example.com'));
    expect(markdown, contains('media.example.com'));
    expect(markdown, contains('Cloudflare Tunnel'));
  });

  test('service topology groups one service with multiple public domains', () {
    final service = ServiceNode(
      id: 'service-1',
      deviceId: 'device-1',
      name: 'Jellyfin',
      endpoints: [ServiceEndpoint(id: 'endpoint-1', port: 8096)],
    );
    final graph = buildServiceTopology(
      services: [service],
      routes: [
        ServiceRoute(
          id: 'route-1',
          name: 'Jellyfin Cloudflare',
          sourceServiceId: service.id,
          sourceEndpointId: 'endpoint-1',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.tunnel,
              method: ServiceRouteMethod.cloudflareTunnel,
            ),
          ],
          finalUrl: 'https://jellyfin.example.com',
          accessLevel: ServiceAccessLevel.public,
        ),
        ServiceRoute(
          id: 'route-2',
          name: 'Jellyfin Pangolin',
          sourceServiceId: service.id,
          sourceEndpointId: 'endpoint-1',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.tunnel,
              method: ServiceRouteMethod.pangolin,
            ),
          ],
          finalUrl: 'https://media.example.com',
          accessLevel: ServiceAccessLevel.public,
        ),
      ],
      devices: [
        Device(
          id: 'device-1',
          name: 'Mac mini',
          category: DeviceCategory.desktop,
        ),
      ],
    );

    expect(
      graph.nodes.where((node) => node.kind == ServiceTopologyNodeKind.service),
      hasLength(1),
    );
    expect(
      graph.nodes
          .where((node) => node.kind == ServiceTopologyNodeKind.domain)
          .map((node) => node.label),
      containsAll(['jellyfin.example.com', 'media.example.com']),
    );
  });

  test('service topology models FRP remote entry before domains', () {
    final service = ServiceNode(
      id: 'service-1',
      deviceId: 'device-1',
      name: 'Caddy',
      endpoints: [
        ServiceEndpoint(
          id: 'endpoint-1',
          protocol: ServiceProtocol.https,
          port: 443,
        ),
      ],
    );
    final graph = buildServiceTopology(
      services: [service],
      routes: [
        ServiceRoute(
          id: 'route-1',
          name: 'Caddy FRP Cloud',
          sourceServiceId: service.id,
          sourceEndpointId: 'endpoint-1',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.portForward,
              method: ServiceRouteMethod.frp,
              host: '203.0.113.10',
              port: 443,
            ),
          ],
          finalUrl: 'https://cloud.example.com',
          accessLevel: ServiceAccessLevel.public,
        ),
        ServiceRoute(
          id: 'route-2',
          name: 'Caddy FRP Root',
          sourceServiceId: service.id,
          sourceEndpointId: 'endpoint-1',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.portForward,
              method: ServiceRouteMethod.frp,
              host: '203.0.113.10',
              port: 443,
            ),
          ],
          finalUrl: 'https://example.com',
          accessLevel: ServiceAccessLevel.public,
        ),
      ],
      devices: [
        Device(
          id: 'device-1',
          name: 'Mac mini',
          category: DeviceCategory.desktop,
        ),
      ],
    );

    final remoteEntry = graph.nodes.singleWhere(
      (node) => node.kind == ServiceTopologyNodeKind.remoteEntry,
    );
    expect(remoteEntry.label, '203.0.113.10:443');
    expect(
      graph.edges.where((edge) => edge.from == remoteEntry.id),
      hasLength(2),
    );
  });

  test('service topology shares a VPS node across local devices', () {
    final services = [
      ServiceNode(
        id: 'service-1',
        deviceId: 'device-1',
        name: 'Caddy A',
        endpoints: [ServiceEndpoint(id: 'endpoint-1', port: 443)],
      ),
      ServiceNode(
        id: 'service-2',
        deviceId: 'device-2',
        name: 'Caddy B',
        endpoints: [ServiceEndpoint(id: 'endpoint-2', port: 443)],
      ),
    ];
    final graph = buildServiceTopology(
      services: services,
      routes: [
        for (final service in services)
          ServiceRoute(
            id: 'route-${service.id}',
            name: '${service.name} FRP',
            sourceServiceId: service.id,
            sourceEndpointId: service.endpoints.single.id,
            hops: [
              ServiceRouteHop(
                type: ServiceRouteHopType.portForward,
                method: ServiceRouteMethod.frp,
                deviceId: 'vps-1',
                host: '198.51.100.10',
                port: 443,
              ),
            ],
            finalUrl: 'https://${service.id}.example.com',
            accessLevel: ServiceAccessLevel.public,
          ),
      ],
      devices: [
        Device(
          id: 'device-1',
          name: 'Mac mini',
          category: DeviceCategory.desktop,
        ),
        Device(id: 'device-2', name: 'NUC', category: DeviceCategory.desktop),
        Device(id: 'vps-1', name: 'VPS', category: DeviceCategory.vps),
      ],
    );

    expect(
      graph.nodes.where(
        (node) =>
            node.kind == ServiceTopologyNodeKind.device && node.label == 'VPS',
      ),
      hasLength(1),
    );
    expect(
      graph.nodes.where((node) => node.kind == ServiceTopologyNodeKind.domain),
      hasLength(2),
    );
  });

  test('service topology shows FRP service on remote VPS', () {
    final caddy = ServiceNode(
      id: 'caddy-local',
      deviceId: 'mac-mini',
      name: 'Caddy',
      endpoints: [ServiceEndpoint(id: 'caddy-https', port: 443)],
    );
    final frp = ServiceNode(
      id: 'frp-vps',
      deviceId: 'vps-1',
      name: 'FRP',
      kind: ServiceKind.tunnel,
      endpoints: [ServiceEndpoint(id: 'frp-control', port: 57000)],
    );

    final graph = buildServiceTopology(
      services: [caddy, frp],
      routes: [
        ServiceRoute(
          id: 'route-frp',
          name: 'Caddy via VPS FRP',
          sourceServiceId: caddy.id,
          sourceEndpointId: 'caddy-https',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.portForward,
              method: ServiceRouteMethod.frp,
              serviceId: frp.id,
              host: '203.0.113.20',
              port: 443,
            ),
          ],
          finalUrl: 'https://cloud.example.com',
          accessLevel: ServiceAccessLevel.public,
        ),
      ],
      devices: [
        Device(
          id: 'mac-mini',
          name: 'Mac mini',
          category: DeviceCategory.desktop,
        ),
        Device(
          id: 'vps-1',
          name: 'Cloudcone VPS',
          category: DeviceCategory.vps,
        ),
      ],
    );

    final vps = graph.nodes.singleWhere(
      (node) =>
          node.deviceId == 'vps-1' &&
          node.kind == ServiceTopologyNodeKind.device,
    );
    final frpNode = graph.nodes.singleWhere(
      (node) =>
          node.serviceId == frp.id &&
          node.kind == ServiceTopologyNodeKind.service,
    );
    final remoteEntry = graph.nodes.singleWhere(
      (node) => node.kind == ServiceTopologyNodeKind.remoteEntry,
    );
    final frpIngress = graph.nodes.singleWhere(
      (node) =>
          node.kind == ServiceTopologyNodeKind.endpoint &&
          node.serviceId == frp.id,
    );

    expect(vps.role, ServiceTopologyNodeRole.remoteDevice);
    expect(frpNode.role, ServiceTopologyNodeRole.remoteService);
    expect(frpIngress.detail, contains('57000'));
    expect(remoteEntry.label, '203.0.113.20:443');
    expect(remoteEntry.deviceId, frp.deviceId);
    expect(
      graph.edges.any(
        (edge) =>
            edge.from == 'endpoint:${caddy.id}:caddy-https' &&
            edge.to == frpIngress.id,
      ),
      isTrue,
    );
    expect(
      graph.edges.any((edge) => edge.from == vps.id && edge.to == frpNode.id),
      isTrue,
    );
    expect(
      graph.edges.any(
        (edge) => edge.from == frpNode.id && edge.to == frpIngress.id,
      ),
      isTrue,
    );
    expect(
      graph.edges.any(
        (edge) => edge.from == frpNode.id && edge.to == remoteEntry.id,
      ),
      isTrue,
    );
  });

  test(
    'service topology groups multi-target FRP route through one VPS entry',
    () {
      final caddy = ServiceNode(
        id: 'caddy-local',
        deviceId: 'mac-mini',
        name: 'Caddy',
        endpoints: [ServiceEndpoint(id: 'caddy-https', port: 443)],
      );
      final frp = ServiceNode(
        id: 'frp-vps',
        deviceId: 'vps-1',
        name: 'FRP',
        kind: ServiceKind.tunnel,
        endpoints: [ServiceEndpoint(id: 'frp-control', port: 57000)],
      );
      final route = ServiceRoute(
        id: 'route-frp',
        name: 'Caddy via FRP',
        sourceServiceId: caddy.id,
        sourceEndpointId: 'caddy-https',
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.portForward,
            method: ServiceRouteMethod.frp,
            serviceId: frp.id,
            host: '203.0.113.20',
            port: 443,
          ),
        ],
        finalUrl: 'https://domain1.example.com',
        accessLevel: ServiceAccessLevel.public,
        extraJson: const {
          serviceRoutePublicTargetsKey: [
            'https://domain1.example.com',
            'https://domain2.example.com',
          ],
        },
      );

      final graph = buildServiceTopology(
        services: [caddy, frp],
        routes: [route],
        devices: [
          Device(
            id: 'mac-mini',
            name: 'Mac mini',
            category: DeviceCategory.desktop,
          ),
          Device(
            id: 'vps-1',
            name: 'Cloudcone VPS',
            category: DeviceCategory.vps,
          ),
        ],
      );

      final remoteEntry = graph.nodes.singleWhere(
        (node) => node.kind == ServiceTopologyNodeKind.remoteEntry,
      );
      final frpIngress = graph.nodes.singleWhere(
        (node) =>
            node.kind == ServiceTopologyNodeKind.endpoint &&
            node.serviceId == frp.id,
      );
      expect(remoteEntry.label, '203.0.113.20:443');
      expect(frpIngress.detail, contains('57000'));
      expect(
        graph.nodes
            .where((node) => node.kind == ServiceTopologyNodeKind.domain)
            .map((node) => node.label),
        containsAll(['domain1.example.com', 'domain2.example.com']),
      );
      expect(
        graph.edges.where((edge) => edge.from == remoteEntry.id),
        hasLength(2),
      );
      expect(
        graph.edges.any(
          (edge) =>
              edge.from == 'endpoint:${caddy.id}:caddy-https' &&
              edge.to == frpIngress.id,
        ),
        isTrue,
      );
    },
  );

  test('reference warnings check duplicate publicTargets', () {
    final service = ServiceNode(
      id: 'service-1',
      deviceId: 'device-1',
      name: 'Caddy',
      endpoints: [ServiceEndpoint(id: 'endpoint-1', port: 443)],
    );
    final routes = [
      ServiceRoute(
        id: 'route-1',
        name: 'Caddy Public A',
        sourceServiceId: service.id,
        sourceEndpointId: 'endpoint-1',
        accessLevel: ServiceAccessLevel.public,
        hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
        finalUrl: 'https://domain1.example.com',
        extraJson: const {
          serviceRoutePublicTargetsKey: [
            'https://domain1.example.com',
            'https://domain2.example.com',
          ],
        },
      ),
      ServiceRoute(
        id: 'route-2',
        name: 'Caddy Public B',
        sourceServiceId: service.id,
        sourceEndpointId: 'endpoint-1',
        accessLevel: ServiceAccessLevel.public,
        hops: [ServiceRouteHop(type: ServiceRouteHopType.tunnel)],
        finalUrl: 'https://domain2.example.com',
      ),
    ];

    final warnings = findServiceReferenceWarnings(
      services: [service],
      routes: routes,
      devices: const [],
      networks: const [],
    );

    expect(
      warnings.map((warning) => warning.kind),
      contains(ServiceWarningKind.duplicateFinalUrl),
    );
  });

  test('service topology classifies LAN VPN and public access lanes', () {
    final service = ServiceNode(
      id: 'jellyfin',
      deviceId: 'mac-mini',
      name: 'Jellyfin',
      endpoints: [ServiceEndpoint(id: 'web', port: 8096)],
    );
    final graph = buildServiceTopology(
      services: [service],
      routes: [
        ServiceRoute(
          id: 'lan-route',
          name: 'LAN Jellyfin',
          sourceServiceId: service.id,
          sourceEndpointId: 'web',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.manual,
              method: ServiceRouteMethod.direct,
              label: 'LAN / WiFi',
            ),
          ],
          finalUrl: 'http://192.168.1.10:8096',
          accessLevel: ServiceAccessLevel.lan,
        ),
        ServiceRoute(
          id: 'vpn-route',
          name: 'Tailscale Jellyfin',
          sourceServiceId: service.id,
          sourceEndpointId: 'web',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.tunnel,
              method: ServiceRouteMethod.tailscaleFunnel,
              label: 'Tailscale',
            ),
          ],
          finalUrl: 'http://100.64.0.10:8096',
          accessLevel: ServiceAccessLevel.vpn,
        ),
        ServiceRoute(
          id: 'public-route',
          name: 'Public Jellyfin',
          sourceServiceId: service.id,
          sourceEndpointId: 'web',
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.tunnel,
              method: ServiceRouteMethod.pangolin,
            ),
          ],
          finalUrl: 'https://jellyfin.example.com',
          accessLevel: ServiceAccessLevel.public,
        ),
      ],
      devices: [
        Device(
          id: 'mac-mini',
          name: 'Mac mini',
          category: DeviceCategory.desktop,
        ),
      ],
    );

    expect(
      graph.edges
          .map((edge) => edge.lane)
          .whereType<ServiceAccessLane>()
          .toSet(),
      containsAll([
        ServiceAccessLane.local,
        ServiceAccessLane.vpn,
        ServiceAccessLane.public,
      ]),
    );
    expect(
      graph.nodes.where(
        (node) => node.role == ServiceTopologyNodeRole.vpnAccess,
      ),
      isNotEmpty,
    );
    expect(
      graph.nodes.where(
        (node) => node.role == ServiceTopologyNodeRole.lanAccess,
      ),
      isNotEmpty,
    );
  });

  test('service topology places direct and FRP ingress after endpoint', () {
    final caddy = ServiceNode(
      id: 'caddy-local',
      deviceId: 'mac-mini',
      name: 'Caddy',
      endpoints: [ServiceEndpoint(id: 'caddy-https', port: 443)],
    );
    final frp = ServiceNode(
      id: 'frp-vps',
      deviceId: 'vps-1',
      name: 'FRP',
      kind: ServiceKind.tunnel,
      endpoints: [ServiceEndpoint(id: 'frp-control', port: 57000)],
    );
    final graph = buildServiceTopology(
      services: [caddy, frp],
      routes: [
        ServiceRoute(
          id: 'direct-route',
          name: 'Caddy Direct',
          sourceServiceId: caddy.id,
          sourceEndpointId: 'caddy-https',
          accessLevel: ServiceAccessLevel.lan,
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.manual,
              method: ServiceRouteMethod.direct,
              label: 'Direct',
            ),
          ],
          finalUrl: 'https://mac-mini.local',
        ),
        ServiceRoute(
          id: 'frp-route',
          name: 'Caddy FRP',
          sourceServiceId: caddy.id,
          sourceEndpointId: 'caddy-https',
          accessLevel: ServiceAccessLevel.public,
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.portForward,
              method: ServiceRouteMethod.frp,
              serviceId: frp.id,
              host: '203.0.113.20',
              port: 443,
            ),
          ],
          finalUrl: 'https://cloud.example.com',
        ),
      ],
      devices: [
        Device(
          id: 'mac-mini',
          name: 'Mac mini',
          category: DeviceCategory.desktop,
        ),
        Device(
          id: 'vps-1',
          name: 'Cloudcone VPS',
          category: DeviceCategory.vps,
        ),
      ],
    );

    final endpointId = 'endpoint:${caddy.id}:caddy-https';
    final direct = graph.nodes.singleWhere(
      (node) => node.role == ServiceTopologyNodeRole.lanAccess,
    );
    final vps = graph.nodes.singleWhere(
      (node) =>
          node.kind == ServiceTopologyNodeKind.device &&
          node.deviceId == 'vps-1',
    );
    final frpIngress = graph.nodes.singleWhere(
      (node) =>
          node.kind == ServiceTopologyNodeKind.endpoint &&
          node.serviceId == frp.id,
    );

    expect(
      graph.edges.any(
        (edge) => edge.from == endpointId && edge.to == direct.id,
      ),
      isTrue,
    );
    expect(
      graph.edges.any(
        (edge) => edge.from == endpointId && edge.to == frpIngress.id,
      ),
      isTrue,
    );
    expect(
      graph.edges.any(
        (edge) => edge.from == vps.id && edge.to == 'service:${frp.id}',
      ),
      isTrue,
    );
  });

  test('service topology keeps same-device public proxy service local', () {
    final app = ServiceNode(
      id: 'vaultwarden',
      deviceId: 'mac-mini',
      name: 'Vaultwarden',
      endpoints: [ServiceEndpoint(id: 'app-http', port: 59880)],
    );
    final caddy = ServiceNode(
      id: 'caddy',
      deviceId: 'mac-mini',
      name: 'Caddy',
      kind: ServiceKind.reverseProxy,
      endpoints: [ServiceEndpoint(id: 'caddy-https', port: 443)],
    );
    final graph = buildServiceTopology(
      services: [app, caddy],
      routes: [
        ServiceRoute(
          id: 'route-public-proxy',
          name: 'Vaultwarden via Caddy',
          sourceServiceId: app.id,
          sourceEndpointId: 'app-http',
          accessLevel: ServiceAccessLevel.public,
          hops: [
            ServiceRouteHop(
              type: ServiceRouteHopType.reverseProxy,
              method: ServiceRouteMethod.caddy,
              serviceId: caddy.id,
              endpointId: 'caddy-https',
            ),
          ],
          finalUrl: 'https://vault.example.com',
        ),
      ],
      devices: [
        Device(
          id: 'mac-mini',
          name: 'Mac mini',
          category: DeviceCategory.desktop,
        ),
      ],
    );

    final caddyNode = graph.nodes.singleWhere(
      (node) =>
          node.kind == ServiceTopologyNodeKind.service &&
          node.serviceId == caddy.id,
    );
    final caddyEndpoint = graph.nodes.singleWhere(
      (node) =>
          node.kind == ServiceTopologyNodeKind.endpoint &&
          node.serviceId == caddy.id,
    );

    expect(caddyNode.role, ServiceTopologyNodeRole.localService);
    expect(caddyNode.layoutColumn, 4);
    expect(caddyEndpoint.role, ServiceTopologyNodeRole.localEndpoint);
    expect(caddyEndpoint.layoutColumn, 5);
    expect(caddyEndpoint.compact, isTrue);
    expect(
      graph.nodes.where(
        (node) => node.role == ServiceTopologyNodeRole.remoteService,
      ),
      isEmpty,
    );
  });

  test('service topology marks ports and remote entries as compact nodes', () {
    final caddy = ServiceNode(
      id: 'caddy',
      deviceId: 'mac-mini',
      name: 'Caddy',
      kind: ServiceKind.reverseProxy,
      endpoints: [ServiceEndpoint(id: 'https', port: 443)],
    );
    final graph = buildServiceTopology(
      services: [caddy],
      routes: [
        ServiceRoute(
          id: 'route-public',
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
      ],
      devices: [
        Device(
          id: 'mac-mini',
          name: 'Mac mini',
          category: DeviceCategory.desktop,
        ),
      ],
    );

    final caddyNode = graph.nodes.singleWhere(
      (node) =>
          node.kind == ServiceTopologyNodeKind.service &&
          node.serviceId == caddy.id,
    );
    final sourceEndpoint = graph.nodes.singleWhere(
      (node) =>
          node.kind == ServiceTopologyNodeKind.endpoint &&
          node.endpointId == 'https',
    );
    final remoteEntry = graph.nodes.singleWhere(
      (node) => node.kind == ServiceTopologyNodeKind.remoteEntry,
    );

    expect(caddyNode.compact, isFalse);
    expect(caddyNode.layoutColumn, 4);
    expect(sourceEndpoint.compact, isTrue);
    expect(sourceEndpoint.layoutColumn, 5);
    expect(remoteEntry.compact, isTrue);
  });
}
