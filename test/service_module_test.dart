import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_analysis.dart';
import 'package:my_device/features/services/services/service_template_service.dart';
import 'package:my_device/shared/services/local_api_server.dart';
import 'package:my_device/shared/services/sync_merge.dart';

String encode(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

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
}
