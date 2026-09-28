import '../../ai/services/insight_prompts.dart';
import '../../devices/models/device.dart';
import '../../network/models/network.dart';
import '../models/service.dart';
import 'service_analysis.dart';

/// How many values one breakdown line lists at most, largest first. Keeps
/// the prompt well inside a small on-device model's input budget.
const int serviceInsightMaxBreakdown = 5;

/// The slots the services card asks for.
const List<InsightSlot> serviceInsightSlots = [
  InsightSlot('setupSummary', 'Sum up this self-hosting setup.'),
  InsightSlot(
    'warningAdvice',
    'One suggestion about the warnings or port conflicts, or say that none '
        'need attention.',
  ),
  InsightSlot(
    'exposureAdvice',
    'One suggestion about how the services are exposed or organised.',
  ),
];

/// Product and protocol names a reply may keep in Latin letters inside
/// Chinese or Japanese prose. They are passed as quoted terms, so the script
/// check ignores them instead of dropping a sentence such as
/// 「Caddy と Tailscale Funnel で公開中」. Longer names come before the shorter
/// names they contain, because terms are removed in order.
const List<String> serviceInsightTechTerms = [
  'Cloudflare Tunnel',
  'Tailscale Funnel',
  'Docker Compose',
  'Cloudflare',
  'Tailscale',
  'Docker',
  'Caddy',
  'Nginx',
  'nginx',
  'Traefik',
  'Pangolin',
  'FRP',
  'frp',
  'systemd',
  'launchd',
  'HTTPS',
  'HTTP',
  'SSH',
  'TCP',
  'UDP',
  'RTSP',
  'VNC',
  'LAN',
  'VPN',
  'URL',
  'IP',
];

/// Purpose: Render a count breakdown as `a 3, b 1` for a fact line.
/// Inputs: `counts`.
/// Returns: `String` — largest first, capped at [serviceInsightMaxBreakdown],
/// `none` when empty.
/// Side effects: None.
/// Notes: Ties are broken by name so the fingerprint is stable. Internal
/// helper used within this file only.
String _breakdown(Map<String, int> counts) {
  if (counts.isEmpty) return 'none';
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  final shown = entries.take(serviceInsightMaxBreakdown);
  final rest = entries.length - shown.length;
  return [
    for (final e in shown) '${e.key} ${e.value}',
    if (rest > 0) '$rest more',
  ].join(', ');
}

/// Purpose: Count items by a string key.
/// Inputs: `items`, `keyOf`.
/// Returns: `Map<String, int>`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Map<String, int> _countBy<T>(Iterable<T> items, String Function(T) keyOf) {
  final out = <String, int>{};
  for (final item in items) {
    out.update(keyOf(item), (v) => v + 1, ifAbsent: () => 1);
  }
  return out;
}

/// Purpose: Build the services card's facts.
/// Inputs: `now` — local time; the page's `services`, `routes`, `devices`,
/// `networks`.
/// Returns: `InsightFacts?` — null when there are no services.
/// Side effects: None.
/// Notes: Counts and enum names only. The builder never sends a service or
/// access-path name, a bind address, a path, a URL, a hop host, a port
/// number, a tag, a note or a compose file; names are read only to count
/// duplicates. `quotedTerms` is [serviceInsightTechTerms]. Warnings and
/// conflicts come from the same `service_analysis`
/// functions the Overview shows, so the card and the list agree.
InsightFacts? buildServiceInsightFacts({
  required DateTime now,
  required List<ServiceNode> services,
  required List<ServiceRoute> routes,
  required List<Device> devices,
  required List<Network> networks,
}) {
  if (services.isEmpty) return null;
  final deviceMap = {for (final d in devices) d.id: d};
  final endpoints = [for (final s in services) ...s.endpoints];
  final hostIds = services.map((s) => s.deviceId).toSet();
  final inactiveHosts = hostIds
      .where((id) => deviceMap[id] != null && !deviceMap[id]!.isInService)
      .length;
  final uses = listServicePortUses(services);
  final distinctPorts = uses
      .map((u) => '${u.service.deviceId}|${u.transport.name}|${u.port}')
      .toSet()
      .length;
  final conflicts = findServicePortConflicts(services);
  final definite = conflicts.where((c) => !c.potential).length;
  final warnings = findServiceReferenceWarnings(
    services: services,
    routes: routes,
    devices: devices,
    networks: networks,
  );
  final methods = <String, int>{};
  var hopCount = 0;
  for (final r in routes) {
    hopCount += r.hops.length;
    for (final h in r.hops) {
      if (h.method != null) {
        methods.update(h.method!.name, (v) => v + 1, ifAbsent: () => 1);
      }
    }
  }
  final networkIds = {
    for (final e in endpoints)
      if (e.networkId != null) e.networkId!,
  };
  final sameNameOnDevice =
      _countBy(services, (s) => '${s.deviceId}|${s.name.trim().toLowerCase()}')
          .values
          .where((n) => n > 1)
          .length;
  final duplicateUrls = warnings
      .where((w) => w.kind == ServiceWarningKind.duplicateFinalUrl)
      .length;

  final lines = <String>[
    '- Today: ${factDate(now)}',
    '- Services: ${services.length}; by state: '
        '${_breakdown(_countBy(services, (s) => s.state.name))}',
    '- Services by kind: ${_breakdown(_countBy(services, (s) => s.kind.name))}',
    '- Runtimes: '
        '${_breakdown(_countBy(services, (s) => s.runtime?.name ?? 'unspecified'))}',
    '- Hosts: ${hostIds.length} devices run services; $inactiveHosts of them '
        'are retired or sold',
    '- Endpoints: ${endpoints.length}; by protocol: '
        '${_breakdown(_countBy(endpoints, (e) => e.protocol.name))}; by scope: '
        '${_breakdown(_countBy(endpoints, (e) => e.scope.name))}',
    '- Distinct listening ports: $distinctPorts; port conflicts: $definite '
        'definite, ${conflicts.length - definite} potential',
    if (routes.isEmpty)
      '- Access paths: none'
    else
      '- Access paths: ${routes.length}; by access level: '
          '${_breakdown(_countBy(routes, (r) => r.accessLevel.name))}; '
          'by method: ${_breakdown(methods)}; '
          'average ${factNumber(hopCount / routes.length)} hops',
    '- Networks referenced by endpoints: ${networkIds.length}',
    '- Warnings: ${warnings.length}; by kind: '
        '${_breakdown(_countBy(warnings, (w) => w.kind.name))}',
    '- Duplicates: $sameNameOnDevice service names repeated on one device; '
        '$duplicateUrls access paths sharing a final URL',
  ];

  return InsightFacts(
    module: InsightModule.services,
    lines: lines,
    slots: serviceInsightSlots,
    quotedTerms: serviceInsightTechTerms,
  );
}
