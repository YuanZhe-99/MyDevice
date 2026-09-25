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

  test('local API stats can include cross-module summary shape', () {
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
      networks: [
        Network(id: 'network-1', name: 'Home LAN', type: NetworkType.lan),
      ],
      assignments: const [
        NetworkDevice(
          networkId: 'network-1',
          deviceId: 'device-1',
          ipAddress: '192.168.1.10',
        ),
      ],
      datasets: [
        DataSet(
          id: 'dataset-1',
          name: 'Media',
          emoji: '🎞️',
          storageLinks: const [
            DataSetStorageLink(deviceId: 'device-1', storageIndices: [0]),
          ],
        ),
      ],
    );

    expect(stats['total'], 1);
    expect(stats['byLifecycle'], containsPair('inService', 1));
    expect(stats['services'], containsPair('total', 1));
    expect(stats['services'], containsPair('routes', 1));
    expect(stats['services'], containsPair('devices', 1));
    expect(stats['networks'], containsPair('total', 1));
    expect(stats['networks'], containsPair('assignments', 1));
    expect(stats['datasets'], containsPair('total', 1));
    expect(stats['datasets'], containsPair('storageLinks', 1));
  });

  test('local API serializes device lifecycle finance and search fields', () {
    final device = Device(
      id: 'device-1',
      name: 'Mac mini',
      category: DeviceCategory.desktop,
      imagePath: 'images/mac.png',
      brand: 'Apple',
      model: 'M4',
      serialNumber: 'SERIAL-1',
      cpu: const CpuInfo(model: 'Apple M4', architecture: 'arm64'),
      gpu: const GpuInfo(model: 'M4 GPU', architecture: 'Apple'),
      ram: '24 GB',
      storage: const [
        StorageInfo(
          capacity: '1 TB',
          type: StorageType.ssd,
          interface_: StorageInterface.m2Nvme,
          brand: 'Apple',
          serialNumber: 'SSD-1',
        ),
      ],
      screenResolutionW: 3840,
      screenResolutionH: 2160,
      locationName: 'Desk',
      latitude: 35.0,
      longitude: 139.0,
      purchaseDate: DateTime(2026, 1, 1),
      acquisitionType: DeviceAcquisitionType.purchasedWithSubscription,
      purchasePrice: MoneyValue(
        amount: 1000,
        currency: 'USD',
        defaultCurrency: 'USD',
        convertedAmount: 1000,
        exchangeRate: 1,
        autoRate: false,
      ),
      recurringCosts: [
        DeviceRecurringCost(
          kind: RecurringCostKind.subscription,
          name: 'AppleCare',
          price: MoneyValue(
            amount: 10,
            currency: 'USD',
            defaultCurrency: 'USD',
            convertedAmount: 10,
            exchangeRate: 1,
            autoRate: false,
          ),
        ),
      ],
    );

    final json = LocalApiServer.deviceToJson(device);
    expect(json['imagePath'], 'images/mac.png');
    expect(json['screenResolutionW'], 3840);
    expect(json['latitude'], 35.0);
    expect(json['acquisitionType'], 'purchasedWithSubscription');
    expect(json['lifecycleStatus'], 'inService');
    expect(json['purchasePrice'], isA<Map<String, dynamic>>());
    expect(json['recurringCosts'], hasLength(1));
    expect(json['finance'], containsPair('hasFinancialData', true));

    final matches = LocalApiServer.filterDevicesForSearch(
      devices: [device],
      query: 'SSD-1',
    );
    expect(matches.single.id, device.id);
  });

  test('local API serializes and filters networks datasets and services', () {
    final device = Device(
      id: 'device-1',
      name: 'Mac mini',
      category: DeviceCategory.desktop,
      storage: const [
        StorageInfo(capacity: '2 TB', type: StorageType.ssd, brand: 'Samsung'),
      ],
    );
    final network = Network(
      id: 'network-1',
      name: 'Tailnet',
      type: NetworkType.tailscale,
      subnet: '100.64.0.0/10',
    );
    const assignment = NetworkDevice(
      networkId: 'network-1',
      deviceId: 'device-1',
      hostname: 'mac-mini',
      ipAddress: '100.64.1.2',
    );
    final dataset = DataSet(
      id: 'dataset-1',
      name: 'Backups',
      emoji: '💾',
      storageLinks: const [
        DataSetStorageLink(deviceId: 'device-1', storageIndices: [0]),
      ],
    );
    final service = ServiceNode(
      id: 'service-1',
      deviceId: 'device-1',
      name: 'Gitea',
      kind: ServiceKind.git,
      runtime: ServiceRuntime.compose,
      endpoints: [
        ServiceEndpoint(
          id: 'endpoint-1',
          label: 'Web',
          protocol: ServiceProtocol.http,
          port: 3000,
          networkId: 'network-1',
        ),
      ],
      tags: const ['git'],
    );
    final route = ServiceRoute(
      id: 'route-1',
      name: 'Gitea public',
      sourceServiceId: 'service-1',
      sourceEndpointId: 'endpoint-1',
      finalUrl: 'https://git.example.com',
      extraJson: const {
        'publicTargets': ['https://git.example.com', 'git.example.com'],
      },
    );

    final networks = LocalApiServer.buildNetworkListJson(
      networks: [network],
      assignments: const [assignment],
      devices: [device],
    );
    expect(networks.single['assignments'], hasLength(1));
    expect(
      (networks.single['assignments'] as List).single,
      containsPair('deviceName', 'Mac mini'),
    );
    expect(
      LocalApiServer.filterNetworksForSearch(
        networks: [network],
        assignments: const [assignment],
        devices: [device],
        query: 'mac-mini',
      ),
      hasLength(1),
    );

    final datasets = LocalApiServer.buildDataSetListJson(
      datasets: [dataset],
      devices: [device],
    );
    final storageLinks = datasets.single['storageLinks'] as List<dynamic>;
    expect(storageLinks.single, containsPair('deviceName', 'Mac mini'));
    expect(
      LocalApiServer.filterDataSetsForSearch(
        datasets: [dataset],
        devices: [device],
        query: 'Samsung',
      ),
      hasLength(1),
    );

    final services = LocalApiServer.buildServiceListJson(
      services: [service],
      devices: [device],
      networks: [network],
    );
    expect(services.single, containsPair('deviceName', 'Mac mini'));
    expect(
      ((services.single['endpoints'] as List<dynamic>).single
          as Map<String, dynamic>),
      containsPair('networkName', 'Tailnet'),
    );
    expect(
      LocalApiServer.filterServicesForSearch(
        services: [service],
        devices: [device],
        networks: [network],
        query: '3000',
      ),
      hasLength(1),
    );

    final routes = LocalApiServer.buildServiceRouteListJson(
      routes: [route],
      services: [service],
      devices: [device],
    );
    expect(routes.single, containsPair('sourceServiceName', 'Gitea'));
    expect(routes.single['publicTargets'], hasLength(2));
    expect(
      LocalApiServer.buildServiceStatsJson(
        services: [service],
        routes: [route],
      ),
      containsPair('publicTargets', 2),
    );
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
    expect(caddyEndpoint.role, ServiceTopologyNodeRole.localEndpoint);
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
    expect(sourceEndpoint.compact, isTrue);
    expect(remoteEntry.compact, isTrue);
  });

  test('explicit accessLane overrides method inference', () {
    final app = ServiceNode(
      id: 'gitea',
      deviceId: 'home',
      name: 'Gitea',
      endpoints: [ServiceEndpoint(id: 'web', port: 3000)],
    );
    final caddy = ServiceNode(
      id: 'caddy',
      deviceId: 'home',
      name: 'Caddy',
      kind: ServiceKind.reverseProxy,
      endpoints: [ServiceEndpoint(id: 'http', port: 80)],
    );
    ServiceRoute route(Map<String, dynamic> extraJson) => ServiceRoute(
      id: 'lan-proxy',
      name: 'Gitea via Caddy',
      sourceServiceId: app.id,
      sourceEndpointId: 'web',
      accessLevel: ServiceAccessLevel.lan,
      finalUrl: 'https://git.home.arpa',
      extraJson: extraJson,
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.reverseProxy,
          method: ServiceRouteMethod.caddy,
          serviceId: caddy.id,
          endpointId: 'http',
        ),
      ],
    );

    final inferred = route(const {});
    final pinned = route(const {serviceRouteAccessLaneKey: 'local'});
    expect(serviceAccessLaneForRoute(inferred), ServiceAccessLane.public);
    expect(serviceAccessLaneForRoute(pinned), ServiceAccessLane.local);

    final graph = buildServiceTopology(
      services: [app, caddy],
      routes: [pinned],
      devices: [
        Device(id: 'home', name: 'Home', category: DeviceCategory.desktop),
      ],
    );
    final domain = graph.nodes.singleWhere(
      (node) => node.kind == ServiceTopologyNodeKind.domain,
    );
    expect(domain.lane, ServiceAccessLane.local);
    expect(
      graph.edges
          .where((edge) => edge.routeId == pinned.id)
          .every((edge) => edge.lane == ServiceAccessLane.local),
      isTrue,
    );
  });

  test('invalid accessLane falls back to inference', () {
    ServiceRoute route(Object? lane) => ServiceRoute(
      name: 'r',
      sourceServiceId: 's',
      accessLevel: ServiceAccessLevel.vpn,
      extraJson: {serviceRouteAccessLaneKey: lane},
      hops: [ServiceRouteHop(method: ServiceRouteMethod.frp)],
    );
    expect(
      serviceAccessLaneForRoute(route('sideways')),
      ServiceAccessLane.public,
    );
    expect(serviceAccessLaneForRoute(route(3)), ServiceAccessLane.public);
    expect(serviceAccessLaneForRoute(route(null)), ServiceAccessLane.public);
    expect(serviceAccessLaneForRoute(route('vpn')), ServiceAccessLane.vpn);
  });

  test('the accessLane writer keeps every other extraJson key', () {
    const original = {
      serviceRoutePublicTargetsKey: ['a', 'b'],
      'future': 1,
    };
    final pinned = serviceRouteExtraJsonWithAccessLane(
      original,
      ServiceAccessLane.vpn,
    );
    expect(pinned, {
      serviceRoutePublicTargetsKey: ['a', 'b'],
      'future': 1,
      serviceRouteAccessLaneKey: 'vpn',
    });
    expect(serviceRouteExtraJsonWithAccessLane(pinned, null), original);
    expect(original.containsKey(serviceRouteAccessLaneKey), isFalse);
    final restored = ServiceRoute.fromJson(
      ServiceRoute(name: 'r', sourceServiceId: 's', extraJson: pinned).toJson(),
    );
    expect(serviceRouteExplicitAccessLane(restored), ServiceAccessLane.vpn);
  });

  test('related routes follow the node, not missing references', () {
    final devices = [
      Device(id: 'home', name: 'Home', category: DeviceCategory.desktop),
      Device(id: 'vps', name: 'VPS', category: DeviceCategory.vps),
    ];
    final services = [
      ServiceNode(
        id: 'app',
        deviceId: 'home',
        name: 'App',
        endpoints: [ServiceEndpoint(id: 'web', port: 8080)],
      ),
      ServiceNode(
        id: 'other',
        deviceId: 'home',
        name: 'Other',
        endpoints: [ServiceEndpoint(id: 'web', port: 9090)],
      ),
      ServiceNode(
        id: 'caddy',
        deviceId: 'home',
        name: 'Caddy',
        kind: ServiceKind.reverseProxy,
        endpoints: [ServiceEndpoint(id: 'https', port: 443)],
      ),
      ServiceNode(
        id: 'frps',
        deviceId: 'vps',
        name: 'frps',
        kind: ServiceKind.tunnel,
        endpoints: [ServiceEndpoint(id: 'bind', port: 7000)],
      ),
    ];
    final viaCaddy = ServiceRoute(
      id: 'via-caddy',
      name: 'App via Caddy',
      sourceServiceId: 'app',
      sourceEndpointId: 'web',
      accessLevel: ServiceAccessLevel.public,
      finalUrl: 'https://app.example.com',
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.reverseProxy,
          method: ServiceRouteMethod.caddy,
          serviceId: 'caddy',
          endpointId: 'https',
        ),
      ],
    );
    final direct = ServiceRoute(
      id: 'direct',
      name: 'Other direct',
      sourceServiceId: 'other',
      sourceEndpointId: 'web',
      finalUrl: 'http://192.168.1.2:9090',
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.manual,
          method: ServiceRouteMethod.direct,
          label: 'Direct',
        ),
      ],
    );
    final frp = ServiceRoute(
      id: 'frp',
      name: 'Caddy via FRP',
      sourceServiceId: 'caddy',
      sourceEndpointId: 'https',
      accessLevel: ServiceAccessLevel.public,
      finalUrl: 'https://edge.example.com',
      hops: [
        ServiceRouteHop(
          type: ServiceRouteHopType.portForward,
          method: ServiceRouteMethod.frp,
          serviceId: 'frps',
          deviceId: 'vps',
          port: 443,
        ),
      ],
    );
    final routes = [viaCaddy, direct, frp];
    final graph = buildServiceTopology(
      services: services,
      routes: routes,
      devices: devices,
    );
    ServiceTopologyNode node(String id) =>
        graph.nodes.singleWhere((node) => node.id == id);
    List<String> related(String id) => relatedRoutesForNode(
      node(id),
      routes,
      services: services,
    ).map((route) => route.id).toList();

    expect(related('service:caddy'), ['via-caddy', 'frp']);
    expect(related('domain:app.example.com'), ['via-caddy']);
    expect(related('endpoint:app:web'), ['via-caddy']);
    expect(related('endpoint:frps:bind'), ['frp']);
    expect(
      related(
        graph.nodes
            .singleWhere((node) => node.kind == ServiceTopologyNodeKind.relay)
            .id,
      ),
      ['direct'],
      reason: 'a relay without a service must not match every free-form hop',
    );
    expect(related('device:home'), ['via-caddy', 'direct', 'frp']);
    expect(related('device:vps'), ['frp']);
    expect(
      relatedRoutesForNode(node('device:home'), routes).map((r) => r.id),
      isEmpty,
      reason: 'without services a local device only has its own route ids',
    );
  });

  test('edges shared by routes list every route that runs along them', () {
    final f = _selectionFixture();
    final graph = buildServiceTopology(
      services: f.services,
      routes: f.routes,
      devices: f.devices,
    );
    final shared = graph.edges.singleWhere(
      (edge) => edge.from == 'endpoint:app:web' && edge.to == 'service:caddy',
    );
    expect(shared.routeId, 'via-caddy');
    expect(shared.routeIds, ['via-caddy', 'via-caddy-2']);
    final structural = graph.edges.singleWhere(
      (edge) => edge.from == 'device:home' && edge.to == 'service:app',
    );
    expect(structural.routeIds, isEmpty);
  });

  test('a highlight lights its routes, their machines and nothing else', () {
    final f = _selectionFixture();
    final graph = buildServiceTopology(
      services: f.services,
      routes: f.routes,
      devices: f.devices,
    );
    final lit = serviceTopologyHighlight(graph, [
      f.routes.singleWhere((route) => route.id == 'via-caddy-2'),
    ], selectedNodeId: 'domain:photos.example.com');

    expect(
      lit.nodeIds,
      containsAll([
        'device:home',
        'service:app',
        'endpoint:app:web',
        'service:caddy',
        'domain:photos.example.com',
      ]),
    );
    expect(lit.nodeIds, isNot(contains('domain:app.example.com')));
    expect(lit.nodeIds, isNot(contains('service:other')));
    expect(lit.nodeIds, isNot(contains('service:frps')));
    expect(
      lit.edges.map((edge) => '${edge.from}->${edge.to}'),
      containsAll([
        'device:home->service:app',
        'endpoint:app:web->service:caddy',
      ]),
      reason: 'the shared edge lights for its second route too',
    );
    expect(
      lit.edges.where((edge) => edge.to == 'domain:app.example.com'),
      isEmpty,
    );

    final none = serviceTopologyHighlight(graph, const [], selectedNodeId: 'x');
    expect(none.nodeIds, isEmpty);
    expect(none.edges, isEmpty);
  });

  test('the topology filter narrows routes and keeps their hop services', () {
    final f = _selectionFixture();
    List<String> ids(List<Object> items) => [
      for (final item in items)
        item is ServiceNode ? item.id : (item as ServiceRoute).id,
    ];
    ({List<String> services, List<String> routes}) run(
      ServiceTopologyFilter filter,
    ) {
      final r = filterServiceTopologyInput(
        services: f.services,
        routes: f.routes,
        filter: filter,
      );
      return (services: ids(r.services), routes: ids(r.routes));
    }

    const all = ServiceTopologyFilter();
    expect(all.isActive, isFalse);
    final unfiltered = filterServiceTopologyInput(
      services: f.services,
      routes: f.routes,
      filter: all,
    );
    expect(identical(unfiltered.services, f.services), isTrue);

    final lan = run(
      const ServiceTopologyFilter(lanes: {ServiceAccessLane.local}),
    );
    expect(lan.routes, ['direct']);
    expect(lan.services, ['other'], reason: 'lanes hide route-less services');

    final vps = run(const ServiceTopologyFilter(deviceIds: {'vps'}));
    expect(vps.routes, isEmpty);
    expect(vps.services, ['frps']);

    final home = run(const ServiceTopologyFilter(deviceIds: {'home'}));
    expect(home.routes, ['via-caddy', 'via-caddy-2', 'direct', 'frp']);
    expect(
      home.services,
      ['app', 'other', 'caddy', 'frps'],
      reason: 'the FRP server on the VPS stays for the route through it',
    );

    final edge = run(const ServiceTopologyFilter(query: 'EDGE'));
    expect(edge.routes, ['frp']);
    expect(edge.services, ['caddy', 'frps']);

    final byName = run(const ServiceTopologyFilter(query: 'other'));
    expect(byName.routes, ['direct']);
    expect(byName.services, ['other']);

    expect(
      const ServiceTopologyFilter(deviceIds: {'a', 'b'}),
      const ServiceTopologyFilter(deviceIds: {'b', 'a'}),
    );
    expect(
      const ServiceTopologyFilter(deviceIds: {'a', 'b'}).hashCode,
      const ServiceTopologyFilter(deviceIds: {'b', 'a'}).hashCode,
    );
    expect(
      const ServiceTopologyFilter(
        deviceIds: {'a'},
        lanes: {ServiceAccessLane.vpn},
        query: ' x ',
      ).activeCount,
      3,
    );
    expect(const ServiceTopologyFilter(query: '   ').isActive, isFalse);
  });
}

/// Purpose: Build a small inventory for the selection and filter tests.
/// Inputs: None.
/// Returns: Devices, services and routes.
/// Side effects: None.
/// Notes: App on the home server has two public routes through Caddy that
/// share their first edge (`via-caddy` to app.example.com, `via-caddy-2` to
/// photos.example.com); Other has a direct LAN route; Caddy itself is
/// published through an FRP server on the VPS to edge.example.com.
({List<Device> devices, List<ServiceNode> services, List<ServiceRoute> routes})
_selectionFixture() {
  final caddyHop = ServiceRouteHop(
    type: ServiceRouteHopType.reverseProxy,
    method: ServiceRouteMethod.caddy,
    serviceId: 'caddy',
    endpointId: 'https',
  );
  return (
    devices: [
      Device(id: 'home', name: 'Home', category: DeviceCategory.desktop),
      Device(id: 'vps', name: 'VPS', category: DeviceCategory.vps),
    ],
    services: [
      ServiceNode(
        id: 'app',
        deviceId: 'home',
        name: 'App',
        endpoints: [ServiceEndpoint(id: 'web', port: 8080)],
      ),
      ServiceNode(
        id: 'other',
        deviceId: 'home',
        name: 'Other',
        endpoints: [ServiceEndpoint(id: 'web', port: 9090)],
      ),
      ServiceNode(
        id: 'caddy',
        deviceId: 'home',
        name: 'Caddy',
        kind: ServiceKind.reverseProxy,
        endpoints: [ServiceEndpoint(id: 'https', port: 443)],
      ),
      ServiceNode(
        id: 'frps',
        deviceId: 'vps',
        name: 'frps',
        kind: ServiceKind.tunnel,
        endpoints: [ServiceEndpoint(id: 'bind', port: 7000)],
      ),
    ],
    routes: [
      ServiceRoute(
        id: 'via-caddy',
        name: 'App via Caddy',
        sourceServiceId: 'app',
        sourceEndpointId: 'web',
        accessLevel: ServiceAccessLevel.public,
        finalUrl: 'https://app.example.com',
        hops: [caddyHop],
      ),
      ServiceRoute(
        id: 'via-caddy-2',
        name: 'App photos via Caddy',
        sourceServiceId: 'app',
        sourceEndpointId: 'web',
        accessLevel: ServiceAccessLevel.public,
        finalUrl: 'https://photos.example.com',
        hops: [caddyHop],
      ),
      ServiceRoute(
        id: 'direct',
        name: 'Other direct',
        sourceServiceId: 'other',
        sourceEndpointId: 'web',
        finalUrl: 'http://192.168.1.2:9090',
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.manual,
            method: ServiceRouteMethod.direct,
            label: 'Direct',
          ),
        ],
      ),
      ServiceRoute(
        id: 'frp',
        name: 'Caddy via FRP',
        sourceServiceId: 'caddy',
        sourceEndpointId: 'https',
        accessLevel: ServiceAccessLevel.public,
        finalUrl: 'https://edge.example.com',
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.portForward,
            method: ServiceRouteMethod.frp,
            serviceId: 'frps',
            deviceId: 'vps',
            port: 443,
          ),
        ],
      ),
    ],
  );
}
