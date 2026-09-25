import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/network/models/network.dart';
import 'package:my_device/features/services/models/service.dart';
import 'package:my_device/features/services/services/service_access_patterns.dart';
import 'package:my_device/features/services/services/service_analysis.dart';

/// Purpose: Test the guided access-path draft layer: pattern detection, the
/// lossless route round trip, validation, and the advisory warnings.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Pure tests; no widgets and no storage.
void main() {
  final devices = [
    Device(id: 'home', name: 'Home Server', category: DeviceCategory.desktop),
    Device(id: 'vps', name: 'VPS', category: DeviceCategory.vps),
    Device(id: 'router', name: 'Router', category: DeviceCategory.router),
  ];
  final services = _services();

  group('round trip', () {
    for (final pattern in ServiceAccessPattern.values) {
      for (final viaProxy in [false, true]) {
        if (viaProxy && !pattern.allowsProxyPrefix) continue;
        for (final reachability in ServiceReachability.values) {
          test('${pattern.name} viaProxy=$viaProxy ${reachability.name}', () {
            final draft = _draftFor(
              pattern,
              viaProxy: viaProxy,
              reachability: reachability,
            );
            expect(serviceAccessDraftIssues(draft, services), isEmpty);
            final route = draft.toRoute(services: services);

            expect(detectServiceAccessPattern(route, services), pattern);
            final readBack = ServiceAccessDraft.fromRoute(route, services);
            expect(readBack, draft);
            expect(readBack!.routeId, route.id);
            expect(
              route.hops.length,
              pattern == ServiceAccessPattern.reverseProxy
                  ? 1
                  : (viaProxy ? 2 : 1),
            );
            if (viaProxy) {
              expect(route.hops.first.type, ServiceRouteHopType.reverseProxy);
              expect(route.hops.first.serviceId, 'caddy');
            }
            expect(route.accessLevel, reachability.accessLevel);
            expect(
              route.extraJson[serviceRouteAccessLaneKey],
              reachability.lane.name,
            );
            expect(serviceAccessLaneForRoute(route), reachability.lane);
          });
        }
      }
    }

    test('optional tunnel relays round-trip with and without a service', () {
      for (final pattern in [
        ServiceAccessPattern.cloudflareTunnel,
        ServiceAccessPattern.pangolin,
        ServiceAccessPattern.tailscaleFunnel,
      ]) {
        final withoutRelay = _draftFor(
          pattern,
        ).copyWith(clearRelayServiceId: true, clearRelayEndpointId: true);
        final route = withoutRelay.toRoute(services: services);
        expect(route.hops.single.serviceId, isNull);
        expect(
          route.hops.single.label,
          serviceRouteMethodLabel(pattern.fixedMethod!),
        );
        expect(ServiceAccessDraft.fromRoute(route, services), withoutRelay);
      }
    });

    test('the route name is generated and stays unlocalized', () {
      final route = _draftFor(
        ServiceAccessPattern.frp,
        viaProxy: true,
      ).toRoute(services: services);
      expect(route.name, 'Jellyfin via Caddy - media.example.com');
    });
  });

  group('FRP', () {
    test(
      'the hop carries the chosen ingress endpoint and the relay device',
      () {
        final route = _draftFor(
          ServiceAccessPattern.frp,
        ).toRoute(services: services);
        final hop = route.hops.single;
        expect(hop.type, ServiceRouteHopType.portForward);
        expect(hop.method, ServiceRouteMethod.frp);
        expect(hop.serviceId, 'frps');
        expect(hop.endpointId, 'bind');
        expect(hop.deviceId, 'vps');
        expect(hop.host, 'vps.example.com');
        expect(hop.port, 443);
      },
    );

    test('an untouched draft records the ingress the builder would infer', () {
      final draft = _draftFor(
        ServiceAccessPattern.frp,
      ).copyWith(clearRelayEndpointId: true);
      final route = draft.toRoute(services: services);
      // `alt` is the primary endpoint, which the inference picks over `bind`.
      expect(route.hops.single.endpointId, 'alt');

      final legacy = ServiceRoute(
        id: 'legacy',
        name: 'legacy',
        sourceServiceId: 'jellyfin',
        sourceEndpointId: 'web',
        accessLevel: ServiceAccessLevel.public,
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.portForward,
            method: ServiceRouteMethod.frp,
            serviceId: 'frps',
            deviceId: 'vps',
            host: 'vps.example.com',
            port: 443,
          ),
        ],
      );
      bool connectsToAlt(ServiceRoute r) {
        final graph = buildServiceTopology(
          services: services,
          routes: [r],
          devices: devices,
        );
        return graph.edges.any(
          (edge) =>
              edge.from == 'endpoint:jellyfin:web' &&
              edge.to == 'endpoint:frps:alt',
        );
      }

      expect(connectsToAlt(legacy), isTrue);
      expect(connectsToAlt(route), isTrue);
    });

    test('a legacy quick-dialog FRP route opens with its inferred ingress', () {
      final legacy = ServiceRoute(
        id: 'legacy-frp',
        name: 'Jellyfin via FRP',
        sourceServiceId: 'jellyfin',
        sourceEndpointId: 'web',
        accessLevel: ServiceAccessLevel.public,
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
      final draft = ServiceAccessDraft.fromRoute(legacy, services);
      expect(draft, isNotNull);
      expect(draft!.pattern, ServiceAccessPattern.frp);
      expect(draft.relayEndpointId, 'alt');
    });

    test('a hop pointing at another device than the relay stays advanced', () {
      final route = ServiceRoute(
        id: 'moved',
        name: 'moved',
        sourceServiceId: 'jellyfin',
        accessLevel: ServiceAccessLevel.public,
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.portForward,
            method: ServiceRouteMethod.frp,
            serviceId: 'frps',
            endpointId: 'bind',
            deviceId: 'router',
            port: 443,
          ),
        ],
      );
      expect(detectServiceAccessPattern(route, services), isNull);
    });
  });

  group('detection', () {
    test('a legacy quick-dialog Cloudflare route is detected', () {
      final route = ServiceRoute(
        id: 'cf',
        name: 'Jellyfin via Cloudflare Tunnel - media.example.com',
        sourceServiceId: 'jellyfin',
        sourceEndpointId: 'web',
        accessLevel: ServiceAccessLevel.public,
        finalUrl: 'https://media.example.com',
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.tunnel,
            method: ServiceRouteMethod.cloudflareTunnel,
            label: 'Cloudflare Tunnel',
          ),
        ],
      );
      final draft = ServiceAccessDraft.fromRoute(route, services)!;
      expect(draft.pattern, ServiceAccessPattern.cloudflareTunnel);
      expect(draft.reachability, ServiceReachability.public);
      expect(draft.relayServiceId, isNull);
      expect(draft.targets, ['https://media.example.com']);
    });

    test('three hops belong to the advanced editor', () {
      final route = ServiceRoute(
        id: 'three',
        name: 'three',
        sourceServiceId: 'jellyfin',
        accessLevel: ServiceAccessLevel.public,
        finalUrl: 'https://media.example.com',
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.reverseProxy,
            method: ServiceRouteMethod.caddy,
            serviceId: 'caddy',
            endpointId: 'https',
          ),
          ServiceRouteHop(
            type: ServiceRouteHopType.tunnel,
            method: ServiceRouteMethod.cloudflareTunnel,
            label: 'Cloudflare Tunnel',
          ),
          ServiceRouteHop(type: ServiceRouteHopType.dns, host: 'example.com'),
        ],
      );
      expect(detectServiceAccessPattern(route, services), isNull);
    });

    test('routes the guided page cannot reproduce stay advanced', () {
      ServiceRoute cloudflare({
        ServiceAccessLevel level = ServiceAccessLevel.public,
        Map<String, dynamic> extra = const {},
        String? hopNotes,
        String? finalUrl = 'https://media.example.com',
      }) => ServiceRoute(
        id: 'r',
        name: 'r',
        sourceServiceId: 'jellyfin',
        accessLevel: level,
        finalUrl: finalUrl,
        extraJson: extra,
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.tunnel,
            method: ServiceRouteMethod.cloudflareTunnel,
            label: 'Cloudflare Tunnel',
            notes: hopNotes,
          ),
        ],
      );

      expect(detectServiceAccessPattern(cloudflare(), services), isNotNull);
      expect(
        detectServiceAccessPattern(
          cloudflare(level: ServiceAccessLevel.custom),
          services,
        ),
        isNull,
        reason: 'a custom access level has no reachability',
      );
      expect(
        detectServiceAccessPattern(
          cloudflare(extra: const {serviceRouteAccessLaneKey: 'local'}),
          services,
        ),
        isNull,
        reason: 'a lane that disagrees with the access level',
      );
      expect(
        detectServiceAccessPattern(cloudflare(hopNotes: 'kept'), services),
        isNull,
        reason: 'hop notes are not part of the guided form',
      );
      expect(
        detectServiceAccessPattern(cloudflare(finalUrl: null), services),
        isNull,
        reason: 'a tunnel needs a target',
      );
    });

    test('a prefix before a direct hop is not a pattern', () {
      final route = ServiceRoute(
        id: 'r',
        name: 'r',
        sourceServiceId: 'jellyfin',
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.reverseProxy,
            method: ServiceRouteMethod.caddy,
            serviceId: 'caddy',
          ),
          ServiceRouteHop(
            type: ServiceRouteHopType.manual,
            method: ServiceRouteMethod.direct,
            label: 'Direct',
          ),
        ],
      );
      expect(detectServiceAccessPattern(route, services), isNull);
    });

    test('a free-form FRP hop without a service stays advanced', () {
      final route = ServiceRoute(
        id: 'r',
        name: 'r',
        sourceServiceId: 'jellyfin',
        accessLevel: ServiceAccessLevel.public,
        hops: [
          ServiceRouteHop(
            type: ServiceRouteHopType.portForward,
            method: ServiceRouteMethod.frp,
            label: 'FRP',
            port: 443,
          ),
        ],
      );
      expect(detectServiceAccessPattern(route, services), isNull);
    });
  });

  test('editing keeps the route id, hop ids and unknown fields', () {
    final saved = ServiceRoute(
      id: 'route-1',
      name: 'old name',
      sourceServiceId: 'jellyfin',
      sourceEndpointId: 'web',
      accessLevel: ServiceAccessLevel.public,
      finalUrl: 'https://media.example.com',
      extraJson: const {
        'newerField': {'nested': true},
        serviceRouteAccessLaneKey: 'public',
      },
      hops: [
        ServiceRouteHop(
          id: 'hop-proxy',
          type: ServiceRouteHopType.reverseProxy,
          method: ServiceRouteMethod.caddy,
          serviceId: 'caddy',
          endpointId: 'https',
          extraJson: const {'hopFuture': 1},
        ),
        ServiceRouteHop(
          id: 'hop-frp',
          type: ServiceRouteHopType.portForward,
          method: ServiceRouteMethod.frp,
          serviceId: 'frps',
          endpointId: 'bind',
          deviceId: 'vps',
          port: 443,
          extraJson: const {'hopFuture': 2},
        ),
      ],
    );
    final draft = ServiceAccessDraft.fromRoute(saved, services)!;
    expect(draft.viaProxy, isTrue);
    expect(draft.extraJson, {
      'newerField': {'nested': true},
    });

    final edited = draft
        .copyWith(
          targets: ['https://media.example.com', 'https://tv.example.com'],
        )
        .toRoute(services: services);
    expect(edited.id, 'route-1');
    expect(edited.hops.map((hop) => hop.id), ['hop-proxy', 'hop-frp']);
    expect(edited.hops.first.extraJson, {'hopFuture': 1});
    expect(edited.hops.last.extraJson, {'hopFuture': 2});
    expect(edited.extraJson['newerField'], {'nested': true});
    expect(edited.extraJson[serviceRoutePublicTargetsKey], [
      'https://media.example.com',
      'https://tv.example.com',
    ]);
    expect(edited.extraJson[serviceRouteAccessLaneKey], 'public');
    expect(edited.finalUrl, 'https://media.example.com');

    final json = edited.toJson();
    expect(ServiceRoute.fromJson(json).extraJson['newerField'], {
      'nested': true,
    });
  });

  test(
    'a saved proxy method that matches the service reads back as derived',
    () {
      final route = _draftFor(
        ServiceAccessPattern.reverseProxy,
      ).toRoute(services: services);
      expect(route.hops.single.method, ServiceRouteMethod.caddy);
      expect(
        ServiceAccessDraft.fromRoute(route, services)!.proxyMethod,
        isNull,
      );

      final nginxOnCaddy = _draftFor(
        ServiceAccessPattern.reverseProxy,
      ).copyWith(proxyMethod: ServiceRouteMethod.nginx);
      final saved = nginxOnCaddy.toRoute(services: services);
      expect(saved.hops.single.method, ServiceRouteMethod.nginx);
      expect(ServiceAccessDraft.fromRoute(saved, services), nginxOnCaddy);
    },
  );

  test('reachability reads the access level and a consistent lane', () {
    ServiceRoute route(ServiceAccessLevel level, [String? lane]) =>
        ServiceRoute(
          name: 'r',
          sourceServiceId: 's',
          accessLevel: level,
          extraJson: {serviceRouteAccessLaneKey: ?lane},
        );
    expect(
      serviceReachabilityForRoute(route(ServiceAccessLevel.lan)),
      ServiceReachability.lan,
    );
    expect(
      serviceReachabilityForRoute(route(ServiceAccessLevel.authenticated)),
      ServiceReachability.publicAuthenticated,
    );
    expect(
      serviceReachabilityForRoute(
        route(ServiceAccessLevel.authenticated, 'public'),
      ),
      ServiceReachability.publicAuthenticated,
    );
    expect(
      serviceReachabilityForRoute(route(ServiceAccessLevel.vpn, 'vpn')),
      ServiceReachability.vpn,
    );
    expect(
      serviceReachabilityForRoute(route(ServiceAccessLevel.public, 'local')),
      isNull,
    );
    expect(
      serviceReachabilityForRoute(route(ServiceAccessLevel.lan, 'nonsense')),
      ServiceReachability.lan,
      reason: 'an unknown lane value is ignored',
    );
    expect(
      serviceReachabilityForRoute(route(ServiceAccessLevel.custom)),
      isNull,
    );
  });

  test('issues block saving until the pattern has what it needs', () {
    expect(serviceAccessDraftIssues(const ServiceAccessDraft(), services), [
      ServiceAccessDraftIssue.missingSource,
    ]);
    final frp = _draftFor(ServiceAccessPattern.frp);
    expect(
      serviceAccessDraftIssues(
        frp.copyWith(clearRelayServiceId: true, clearPublicPort: true),
        services,
      ),
      [
        ServiceAccessDraftIssue.missingRelay,
        ServiceAccessDraftIssue.invalidPublicPort,
      ],
    );
    expect(
      serviceAccessDraftIssues(frp.copyWith(publicPort: 70000), services),
      [ServiceAccessDraftIssue.invalidPublicPort],
    );
    expect(
      serviceAccessDraftIssues(
        _draftFor(
          ServiceAccessPattern.cloudflareTunnel,
        ).copyWith(targets: const ['  '], relayServiceId: 'deleted-service'),
        services,
      ),
      [
        ServiceAccessDraftIssue.missingRelay,
        ServiceAccessDraftIssue.missingTargets,
      ],
    );
    expect(
      serviceAccessDraftIssues(
        _draftFor(
          ServiceAccessPattern.pangolin,
          viaProxy: true,
        ).copyWith(clearProxyServiceId: true),
        services,
      ),
      [ServiceAccessDraftIssue.missingProxy],
    );
    expect(
      serviceAccessDraftIssues(
        _draftFor(
          ServiceAccessPattern.direct,
        ).copyWith(targets: const [], viaProxy: true),
        services,
      ),
      isEmpty,
      reason: 'direct access ignores the prefix and needs no target',
    );
  });

  test('FRP warnings flag a relay without ingress or on the source device', () {
    final bare = ServiceNode(id: 'bare', deviceId: 'home', name: 'frpc');
    final withBare = [...services, bare];
    final draft = _draftFor(
      ServiceAccessPattern.frp,
    ).copyWith(relayServiceId: 'bare', clearRelayEndpointId: true);
    expect(serviceAccessDraftWarnings(draft, withBare), [
      ServiceAccessDraftWarning.relayWithoutIngress,
      ServiceAccessDraftWarning.relayOnSourceDevice,
    ]);
    expect(
      serviceAccessDraftWarnings(_draftFor(ServiceAccessPattern.frp), services),
      isEmpty,
    );
    expect(
      serviceAccessDraftWarnings(
        _draftFor(ServiceAccessPattern.pangolin),
        services,
      ),
      isEmpty,
    );
  });

  test('proxy methods and relay heuristics read the service', () {
    ServiceNode named(String name, {String? templateId}) =>
        ServiceNode(deviceId: 'home', name: name, templateId: templateId);
    expect(
      serviceProxyMethodFor(named('Edge', templateId: 'caddy')),
      ServiceRouteMethod.caddy,
    );
    expect(
      serviceProxyMethodFor(named('NGINX proxy')),
      ServiceRouteMethod.nginx,
    );
    expect(serviceProxyMethodFor(named('traefik')), ServiceRouteMethod.traefik);
    expect(serviceProxyMethodFor(named('HAProxy')), ServiceRouteMethod.custom);
    expect(isReverseProxyLikeService(named('HAProxy')), isFalse);
    expect(
      isReverseProxyLikeService(
        ServiceNode(
          deviceId: 'home',
          name: 'HAProxy',
          kind: ServiceKind.reverseProxy,
        ),
      ),
      isTrue,
    );
    expect(isFrpLikeService(named('frps')), isTrue);
    expect(isFrpLikeService(named('Jellyfin')), isFalse);
  });

  group('suggestions', () {
    final networks = [
      Network(id: 'lan', name: 'LAN', type: NetworkType.lan),
      Network(id: 'ts', name: 'Tailnet', type: NetworkType.tailscale),
      Network(id: 'net', name: 'Internet', type: NetworkType.other),
    ];
    const assignments = [
      NetworkDevice(
        networkId: 'lan',
        deviceId: 'home',
        ipAddress: '192.168.1.10',
      ),
      NetworkDevice(
        networkId: 'ts',
        deviceId: 'home',
        ipAddress: '100.64.0.2',
        hostname: 'home.tailnet.ts.net',
      ),
      NetworkDevice(
        networkId: 'net',
        deviceId: 'vps',
        ipAddress: '203.0.113.10',
        hostname: 'vps.example.net',
      ),
    ];
    final jellyfin = services.first;

    test('direct targets follow the reachability and the endpoint', () {
      String? suggest(
        ServiceReachability reachability, {
        ServiceEndpoint? endpoint,
      }) => suggestedDirectTarget(
        source: jellyfin,
        endpoint: endpoint,
        assignments: assignments,
        networks: networks,
        reachability: reachability,
      );
      expect(suggest(ServiceReachability.lan), 'http://192.168.1.10:8096');
      expect(
        suggest(ServiceReachability.vpn),
        'http://home.tailnet.ts.net:8096',
      );
      expect(suggest(ServiceReachability.public), isNull);
      expect(
        suggest(
          ServiceReachability.lan,
          endpoint: ServiceEndpoint(
            port: 443,
            protocol: ServiceProtocol.https,
            path: '/app',
          ),
        ),
        'https://192.168.1.10:443/app',
      );
      expect(
        suggest(
          ServiceReachability.lan,
          endpoint: ServiceEndpoint(port: 22, protocol: ServiceProtocol.ssh),
        ),
        '192.168.1.10:22',
      );
      final caddy = services[1];
      expect(
        suggestedDirectTarget(
          source: caddy,
          assignments: assignments,
          networks: networks,
          reachability: ServiceReachability.lan,
        ),
        '192.168.1.10',
        reason: 'several endpoints and none chosen: no port is guessed',
      );
    });

    test('the FRP public host comes from a single assignment only', () {
      final frps = services[2];
      expect(suggestedPublicHost(frps, assignments), 'vps.example.net');
      expect(
        suggestedPublicHost(frps, [
          ...assignments,
          const NetworkDevice(
            networkId: 'lan',
            deviceId: 'vps',
            ipAddress: '10.0.0.2',
          ),
        ]),
        isNull,
      );
      expect(suggestedPublicHost(jellyfin, const []), isNull);
    });

    test('relay suggestions follow the pattern and prefer VPS devices', () {
      final extra = [
        ...services,
        ServiceNode(id: 'frpc', deviceId: 'home', name: 'frpc'),
        ServiceNode(
          id: 'ts',
          deviceId: 'home',
          name: 'Tailscale',
          templateId: 'tailscale',
        ),
      ];
      expect(
        serviceAccessRelaySuggestions(
          ServiceAccessPattern.frp,
          extra,
          devices,
          sourceServiceId: 'jellyfin',
        ),
        ['frps', 'frpc'],
      );
      expect(
        serviceAccessRelaySuggestions(
          ServiceAccessPattern.cloudflareTunnel,
          extra,
          devices,
        ),
        ['cloudflared'],
      );
      expect(
        serviceAccessRelaySuggestions(
          ServiceAccessPattern.tailscaleFunnel,
          extra,
          devices,
        ),
        ['ts'],
      );
      expect(
        serviceAccessRelaySuggestions(
          ServiceAccessPattern.direct,
          extra,
          devices,
        ),
        isEmpty,
      );
      expect(
        serviceAccessRelaySuggestions(ServiceAccessPattern.frp, [
          ServiceNode(
            id: 'tunnel',
            deviceId: 'vps',
            name: 'Relay',
            kind: ServiceKind.tunnel,
          ),
        ], devices),
        ['tunnel'],
        reason: 'without an FRP-named service, tunnel-kind services count',
      );
    });

    test('proxy suggestions put the source device first', () {
      final remoteProxy = ServiceNode(
        id: 'edge',
        deviceId: 'vps',
        name: 'A Nginx edge',
        templateId: 'nginx',
      );
      expect(
        serviceAccessProxySuggestions([
          ...services,
          remoteProxy,
        ], sourceServiceId: 'jellyfin'),
        ['caddy', 'edge'],
      );
    });

    test('router candidates list routers first', () {
      expect(
        serviceAccessRouterCandidates(devices).map((device) => device.id),
        ['router', 'home', 'vps'],
      );
      expect(serviceAccessRelayTemplateId(ServiceAccessPattern.frp), 'frp');
      expect(
        serviceAccessRelayTemplateId(ServiceAccessPattern.cloudflareTunnel),
        'cloudflare-tunnel',
      );
      expect(serviceAccessRelayTemplateId(ServiceAccessPattern.direct), isNull);
    });
  });

  test('the chain preview names every step once', () {
    final route = _draftFor(
      ServiceAccessPattern.frp,
      viaProxy: true,
    ).toRoute(services: services);
    expect(
      serviceRouteChainPreview(route, services: services, devices: devices),
      'Jellyfin 8096 -> Caddy 443 -> FRP Server 7000 (VPS) -> '
      'vps.example.com:443 -> media.example.com',
    );
    final direct = _draftFor(
      ServiceAccessPattern.direct,
    ).toRoute(services: services);
    expect(
      serviceRouteChainPreview(
        direct,
        services: services,
        hopFallback: (hop) => '直连',
      ),
      'Jellyfin 8096 -> 直连 -> 192.168.1.10:8096',
      reason: 'a generated method label is replaced by the fallback',
    );
    expect(
      serviceRouteChainPreview(
        ServiceRoute(name: 'r', sourceServiceId: 'missing'),
        services: services,
      ),
      '-',
    );
  });

  test('the documented walkthrough is exactly what the guided draft saves', () {
    // doc/en-us/examples/service-topology-walkthrough.md
    final walkDevices = [
      Device(
        id: 'dev-home',
        name: 'dev-home',
        category: DeviceCategory.desktop,
      ),
      Device(id: 'dev-vps', name: 'dev-vps', category: DeviceCategory.vps),
    ];
    final walkServices = [
      ServiceNode(
        id: 'svc-jellyfin',
        deviceId: 'dev-home',
        name: 'Jellyfin',
        kind: ServiceKind.media,
        endpoints: [ServiceEndpoint(id: 'ep-jellyfin', port: 8096)],
      ),
      ServiceNode(
        id: 'svc-caddy',
        deviceId: 'dev-home',
        name: 'Caddy',
        templateId: 'caddy',
        kind: ServiceKind.reverseProxy,
        endpoints: [
          ServiceEndpoint(
            id: 'ep-caddy',
            port: 443,
            protocol: ServiceProtocol.https,
            isPrimary: true,
          ),
        ],
      ),
      ServiceNode(
        id: 'svc-frp',
        deviceId: 'dev-vps',
        name: 'FRP',
        templateId: 'frp',
        kind: ServiceKind.tunnel,
        endpoints: [
          ServiceEndpoint(id: 'ep-frp-ingress', port: 57000, isPrimary: true),
        ],
      ),
    ];
    final route = const ServiceAccessDraft(
      sourceServiceId: 'svc-jellyfin',
      sourceEndpointId: 'ep-jellyfin',
      pattern: ServiceAccessPattern.frp,
      reachability: ServiceReachability.public,
      viaProxy: true,
      proxyServiceId: 'svc-caddy',
      proxyEndpointId: 'ep-caddy',
      relayServiceId: 'svc-frp',
      publicHost: 'vps.example.com',
      publicPort: 443,
      targets: ['https://media.example.com'],
    ).toRoute(services: walkServices);

    expect(route.name, 'Jellyfin via Caddy - media.example.com');
    expect(route.finalUrl, 'https://media.example.com');
    expect(route.accessLevel, ServiceAccessLevel.public);
    expect(route.extraJson, {serviceRouteAccessLaneKey: 'public'});
    final proxy = route.hops.first;
    expect(proxy.type, ServiceRouteHopType.reverseProxy);
    expect(proxy.method, ServiceRouteMethod.caddy);
    expect(proxy.serviceId, 'svc-caddy');
    expect(proxy.endpointId, 'ep-caddy');
    final frp = route.hops.last;
    expect(frp.type, ServiceRouteHopType.portForward);
    expect(frp.method, ServiceRouteMethod.frp);
    expect(frp.serviceId, 'svc-frp');
    expect(frp.endpointId, 'ep-frp-ingress');
    expect(frp.deviceId, 'dev-vps');
    expect(frp.host, 'vps.example.com');
    expect(frp.port, 443);
    expect(
      serviceRouteChainPreview(
        route,
        services: walkServices,
        devices: walkDevices,
      ),
      'Jellyfin 8096 -> Caddy 443 -> FRP 57000 (dev-vps) -> '
      'vps.example.com:443 -> media.example.com',
    );

    final graph = buildServiceTopology(
      services: walkServices,
      routes: [route],
      devices: walkDevices,
    );
    bool edge(String from, String to) =>
        graph.edges.any((e) => e.from == from && e.to == to);
    expect(
      edge('endpoint:svc-jellyfin:ep-jellyfin', 'service:svc-caddy'),
      isTrue,
    );
    expect(edge('service:svc-caddy', 'endpoint:svc-caddy:ep-caddy'), isTrue);
    expect(
      edge('endpoint:svc-caddy:ep-caddy', 'endpoint:svc-frp:ep-frp-ingress'),
      isTrue,
    );
    expect(
      edge('service:svc-frp', 'remote:dev-vps:vps.example.com:443'),
      isTrue,
    );
    expect(
      edge('remote:dev-vps:vps.example.com:443', 'domain:media.example.com'),
      isTrue,
    );
    expect(
      edge(
        'endpoint:svc-frp:ep-frp-ingress',
        'remote:dev-vps:vps.example.com:443',
      ),
      isFalse,
      reason: 'ingress and public entry are siblings, not a chain',
    );
  });

  test('pattern defaults', () {
    expect(
      ServiceAccessPattern.direct.defaultReachability,
      ServiceReachability.lan,
    );
    for (final pattern in ServiceAccessPattern.values.skip(1)) {
      expect(pattern.defaultReachability, ServiceReachability.public);
    }
    expect(
      ServiceAccessPattern.values.where((p) => p.allowsProxyPrefix).toSet(),
      {
        ServiceAccessPattern.cloudflareTunnel,
        ServiceAccessPattern.pangolin,
        ServiceAccessPattern.frp,
        ServiceAccessPattern.routerPortForward,
        ServiceAccessPattern.tailscaleFunnel,
      },
    );
  });
}

/// Purpose: Build the services the pattern tests route through.
/// Inputs: None.
/// Returns: `List<ServiceNode>`.
/// Side effects: None.
/// Notes: The FRP server's primary endpoint (`alt`) differs from the one the
/// drafts choose (`bind`), so an explicit ingress is distinguishable from
/// the inferred default.
List<ServiceNode> _services() => [
  ServiceNode(
    id: 'jellyfin',
    deviceId: 'home',
    name: 'Jellyfin',
    kind: ServiceKind.media,
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
      ServiceEndpoint(id: 'http', port: 80),
    ],
  ),
  ServiceNode(
    id: 'frps',
    deviceId: 'vps',
    name: 'FRP Server',
    templateId: 'frp',
    kind: ServiceKind.tunnel,
    endpoints: [
      ServiceEndpoint(id: 'bind', port: 7000),
      ServiceEndpoint(id: 'alt', port: 7001, isPrimary: true),
    ],
  ),
  ServiceNode(
    id: 'cloudflared',
    deviceId: 'home',
    name: 'cloudflared',
    templateId: 'cloudflare-tunnel',
    kind: ServiceKind.tunnel,
  ),
  ServiceNode(
    id: 'pangolin',
    deviceId: 'vps',
    name: 'Pangolin',
    templateId: 'pangolin',
    kind: ServiceKind.tunnel,
    endpoints: [ServiceEndpoint(id: 'pg', port: 443, isPrimary: true)],
  ),
];

/// Purpose: Build a complete, saveable draft for one pattern.
/// Inputs: `pattern`; `viaProxy` — add the Caddy prefix hop;
/// `reachability`.
/// Returns: `ServiceAccessDraft`.
/// Side effects: None.
/// Notes: Every optional field the pattern uses is filled so the round trip
/// exercises it.
ServiceAccessDraft _draftFor(
  ServiceAccessPattern pattern, {
  bool viaProxy = false,
  ServiceReachability reachability = ServiceReachability.public,
}) {
  final base = ServiceAccessDraft(
    sourceServiceId: 'jellyfin',
    sourceEndpointId: 'web',
    pattern: pattern,
    reachability: reachability,
    viaProxy: viaProxy,
    proxyServiceId: viaProxy || pattern == ServiceAccessPattern.reverseProxy
        ? 'caddy'
        : null,
    proxyEndpointId: viaProxy || pattern == ServiceAccessPattern.reverseProxy
        ? 'https'
        : null,
    targets: const ['https://media.example.com'],
    notes: 'Kept in the notes',
    extraJson: const {'futureKey': 'kept'},
  );
  return switch (pattern) {
    ServiceAccessPattern.direct => base.copyWith(
      targets: const ['http://192.168.1.10:8096'],
    ),
    ServiceAccessPattern.reverseProxy => base,
    ServiceAccessPattern.cloudflareTunnel => base.copyWith(
      relayServiceId: 'cloudflared',
    ),
    ServiceAccessPattern.pangolin => base.copyWith(
      relayServiceId: 'pangolin',
      relayEndpointId: 'pg',
    ),
    ServiceAccessPattern.frp => base.copyWith(
      relayServiceId: 'frps',
      relayEndpointId: 'bind',
      publicHost: 'vps.example.com',
      publicPort: 443,
    ),
    ServiceAccessPattern.routerPortForward => base.copyWith(
      remoteDeviceId: 'router',
      publicHost: 'home.example.com',
      publicPort: 8443,
      targets: const [],
    ),
    ServiceAccessPattern.tailscaleFunnel => base.copyWith(
      targets: const ['https://home.tailnet.ts.net'],
    ),
  };
}
