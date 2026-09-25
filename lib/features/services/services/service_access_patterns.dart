import '../../devices/models/device.dart';
import '../../network/models/network.dart';
import '../models/service.dart';
import 'service_analysis.dart';

/// The common self-hosting setups the guided access-path page offers.
///
/// A pattern is never persisted: a saved route is re-classified from its hops
/// with [detectServiceAccessPattern] every time it is opened.
enum ServiceAccessPattern {
  direct,
  reverseProxy,
  cloudflareTunnel,
  pangolin,
  frp,
  routerPortForward,
  tailscaleFunnel;

  /// Purpose: Return the route method this pattern's access hop records.
  /// Inputs: None.
  /// Returns: `ServiceRouteMethod?` — null for [reverseProxy], whose method
  /// comes from the chosen proxy service.
  /// Side effects: None.
  /// Notes: None.
  ServiceRouteMethod? get fixedMethod => switch (this) {
    ServiceAccessPattern.direct => ServiceRouteMethod.direct,
    ServiceAccessPattern.reverseProxy => null,
    ServiceAccessPattern.cloudflareTunnel =>
      ServiceRouteMethod.cloudflareTunnel,
    ServiceAccessPattern.pangolin => ServiceRouteMethod.pangolin,
    ServiceAccessPattern.frp => ServiceRouteMethod.frp,
    ServiceAccessPattern.routerPortForward =>
      ServiceRouteMethod.routerPortForward,
    ServiceAccessPattern.tailscaleFunnel => ServiceRouteMethod.tailscaleFunnel,
  };

  /// Purpose: Report whether the "through a reverse proxy first" prefix hop
  /// is offered for this pattern.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: The prefix builds the two-hop chain app → reverse proxy → tunnel
  /// or port mapping. Direct access and a plain reverse proxy have no second
  /// hop to put behind it.
  bool get allowsProxyPrefix => switch (this) {
    ServiceAccessPattern.direct || ServiceAccessPattern.reverseProxy => false,
    _ => true,
  };

  /// Purpose: Report whether a saved route of this pattern needs at least one
  /// URL or domain.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Port mappings are reachable by host and port alone, and direct
  /// access by the device address, so their targets stay optional.
  bool get requiresTargets => switch (this) {
    ServiceAccessPattern.reverseProxy ||
    ServiceAccessPattern.cloudflareTunnel ||
    ServiceAccessPattern.pangolin ||
    ServiceAccessPattern.tailscaleFunnel => true,
    _ => false,
  };

  /// Purpose: Report whether the pattern records a public entry port.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: The port is required (1–65535) for these patterns; the public
  /// host beside it stays optional.
  bool get requiresPublicPort =>
      this == ServiceAccessPattern.frp ||
      this == ServiceAccessPattern.routerPortForward;

  /// Purpose: Report whether the pattern's access hop can reference a relay
  /// service.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Optional for the tunnels, required for FRP (see
  /// [requiresRelayService]).
  bool get usesRelayService => switch (this) {
    ServiceAccessPattern.cloudflareTunnel ||
    ServiceAccessPattern.pangolin ||
    ServiceAccessPattern.tailscaleFunnel ||
    ServiceAccessPattern.frp => true,
    _ => false,
  };

  /// Purpose: Report whether the pattern cannot be saved without a relay
  /// service.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: FRP is modeled as the FRP server service on the VPS with its
  /// ingress and public ports as sibling chips, so the service must exist.
  bool get requiresRelayService => this == ServiceAccessPattern.frp;

  /// Purpose: Return the reachability a newly chosen pattern starts with.
  /// Inputs: None.
  /// Returns: `ServiceReachability`.
  /// Side effects: None.
  /// Notes: The page applies it only while the user has not picked a
  /// reachability themselves.
  ServiceReachability get defaultReachability =>
      this == ServiceAccessPattern.direct
      ? ServiceReachability.lan
      : ServiceReachability.public;
}

/// Who can reach a service through an access path.
///
/// Persisted as the pair of the route's `accessLevel` and its
/// `extraJson['accessLane']` override.
enum ServiceReachability {
  lan,
  vpn,
  public,
  publicAuthenticated;

  /// Purpose: Return the route access level this reachability saves.
  /// Inputs: None.
  /// Returns: `ServiceAccessLevel`.
  /// Side effects: None.
  /// Notes: [publicAuthenticated] maps to `authenticated`.
  ServiceAccessLevel get accessLevel => switch (this) {
    ServiceReachability.lan => ServiceAccessLevel.lan,
    ServiceReachability.vpn => ServiceAccessLevel.vpn,
    ServiceReachability.public => ServiceAccessLevel.public,
    ServiceReachability.publicAuthenticated => ServiceAccessLevel.authenticated,
  };

  /// Purpose: Return the topology lane this reachability pins.
  /// Inputs: None.
  /// Returns: `ServiceAccessLane`.
  /// Side effects: None.
  /// Notes: Both public variants draw in the public lane.
  ServiceAccessLane get lane => switch (this) {
    ServiceReachability.lan => ServiceAccessLane.local,
    ServiceReachability.vpn => ServiceAccessLane.vpn,
    ServiceReachability.public ||
    ServiceReachability.publicAuthenticated => ServiceAccessLane.public,
  };
}

/// Blocking problems that keep a draft from being saved.
enum ServiceAccessDraftIssue {
  missingSource,
  missingProxy,
  missingRelay,
  invalidPublicPort,
  missingTargets,
}

/// Advisory findings about a draft; they never block saving.
enum ServiceAccessDraftWarning { relayWithoutIngress, relayOnSourceDevice }

/// The form state of one access path, edited by the guided page.
///
/// Immutable; the page replaces it through [copyWith]. [toRoute] turns it into
/// exactly one `ServiceRoute` whose hops `buildServiceTopology` already
/// understands, and [ServiceAccessDraft.fromRoute] reads a saved route back
/// when — and only when — that round trip is lossless.
class ServiceAccessDraft {
  /// Id of the route being edited, or null for a new access path.
  final String? routeId;
  final String? sourceServiceId;
  final String? sourceEndpointId;
  final ServiceAccessPattern pattern;
  final ServiceReachability reachability;

  /// Whether a reverse-proxy hop comes before the pattern's own hop.
  final bool viaProxy;
  final String? proxyServiceId;
  final String? proxyEndpointId;

  /// The proxy hop's method as saved, or null to derive it from the proxy
  /// service with [serviceProxyMethodFor].
  final ServiceRouteMethod? proxyMethod;
  final String? relayServiceId;

  /// The relay endpoint; for FRP this is the ingress the source connects to.
  final String? relayEndpointId;

  /// The router device of a router port forward.
  final String? remoteDeviceId;
  final String? publicHost;
  final int? publicPort;
  final List<String> targets;
  final String? notes;

  /// The edited route's `extraJson` without the keys the draft manages
  /// (`publicTargets`, `accessLane`), carried through unchanged.
  final Map<String, dynamic> extraJson;

  /// The edited route's hops, kept so saving reuses their ids and unknown
  /// fields; empty for a new access path.
  final List<ServiceRouteHop> baseHops;

  /// Purpose: Create an access-path draft.
  /// Inputs: Every field is optional except that [pattern] and
  /// [reachability] default to a direct LAN path.
  /// Returns: A new `ServiceAccessDraft`.
  /// Side effects: None.
  /// Notes: Use [ServiceAccessDraft.fromRoute] to edit a saved route.
  const ServiceAccessDraft({
    this.routeId,
    this.sourceServiceId,
    this.sourceEndpointId,
    this.pattern = ServiceAccessPattern.direct,
    this.reachability = ServiceReachability.lan,
    this.viaProxy = false,
    this.proxyServiceId,
    this.proxyEndpointId,
    this.proxyMethod,
    this.relayServiceId,
    this.relayEndpointId,
    this.remoteDeviceId,
    this.publicHost,
    this.publicPort,
    this.targets = const [],
    this.notes,
    this.extraJson = const {},
    this.baseHops = const [],
  });

  /// Purpose: Report whether the proxy prefix hop is in effect.
  /// Inputs: None.
  /// Returns: `bool` — [viaProxy] when the pattern allows the prefix.
  /// Side effects: None.
  /// Notes: The flag survives switching to a pattern without the prefix, so
  /// switching back restores it.
  bool get usesProxyPrefix => viaProxy && pattern.allowsProxyPrefix;

  /// Purpose: Report whether the draft needs a proxy service at all.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: True for the reverse-proxy pattern and for the prefix hop.
  bool get needsProxy =>
      pattern == ServiceAccessPattern.reverseProxy || usesProxyPrefix;

  /// Purpose: Create a copy with selected fields replaced or cleared.
  /// Inputs: Any field to replace; a `clearX` flag sets nullable field `X` to
  /// null.
  /// Returns: `ServiceAccessDraft`.
  /// Side effects: None.
  /// Notes: [routeId] and [baseHops] always carry over.
  ServiceAccessDraft copyWith({
    String? sourceServiceId,
    String? sourceEndpointId,
    ServiceAccessPattern? pattern,
    ServiceReachability? reachability,
    bool? viaProxy,
    String? proxyServiceId,
    String? proxyEndpointId,
    ServiceRouteMethod? proxyMethod,
    String? relayServiceId,
    String? relayEndpointId,
    String? remoteDeviceId,
    String? publicHost,
    int? publicPort,
    List<String>? targets,
    String? notes,
    bool clearSourceServiceId = false,
    bool clearSourceEndpointId = false,
    bool clearProxyServiceId = false,
    bool clearProxyEndpointId = false,
    bool clearProxyMethod = false,
    bool clearRelayServiceId = false,
    bool clearRelayEndpointId = false,
    bool clearRemoteDeviceId = false,
    bool clearPublicHost = false,
    bool clearPublicPort = false,
    bool clearNotes = false,
  }) {
    return ServiceAccessDraft(
      routeId: routeId,
      sourceServiceId: clearSourceServiceId
          ? null
          : (sourceServiceId ?? this.sourceServiceId),
      sourceEndpointId: clearSourceEndpointId
          ? null
          : (sourceEndpointId ?? this.sourceEndpointId),
      pattern: pattern ?? this.pattern,
      reachability: reachability ?? this.reachability,
      viaProxy: viaProxy ?? this.viaProxy,
      proxyServiceId: clearProxyServiceId
          ? null
          : (proxyServiceId ?? this.proxyServiceId),
      proxyEndpointId: clearProxyEndpointId
          ? null
          : (proxyEndpointId ?? this.proxyEndpointId),
      proxyMethod: clearProxyMethod ? null : (proxyMethod ?? this.proxyMethod),
      relayServiceId: clearRelayServiceId
          ? null
          : (relayServiceId ?? this.relayServiceId),
      relayEndpointId: clearRelayEndpointId
          ? null
          : (relayEndpointId ?? this.relayEndpointId),
      remoteDeviceId: clearRemoteDeviceId
          ? null
          : (remoteDeviceId ?? this.remoteDeviceId),
      publicHost: clearPublicHost ? null : (publicHost ?? this.publicHost),
      publicPort: clearPublicPort ? null : (publicPort ?? this.publicPort),
      targets: targets ?? this.targets,
      notes: clearNotes ? null : (notes ?? this.notes),
      extraJson: extraJson,
      baseHops: baseHops,
    );
  }

  /// Purpose: Build the one `ServiceRoute` this draft describes.
  /// Inputs: `services` — the current services, for the source name, the
  /// proxy method and the FRP relay's device and default ingress.
  /// Returns: `ServiceRoute`.
  /// Side effects: None.
  /// Notes: Keeps the edited route's id and, position by position, its hop
  /// ids and hop `extraJson`, so sync sees an update rather than a delete and
  /// an add. Sets `finalUrl` to the first target and stores the others with
  /// `serviceRouteExtraJsonWithTargets`, pins the lane with
  /// `serviceRouteExtraJsonWithAccessLane`, and names the route with
  /// `serviceRouteGeneratedName`. Works on an incomplete draft too, which is
  /// what the live preview shows; saving is gated by
  /// [serviceAccessDraftIssues].
  ServiceRoute toRoute({required List<ServiceNode> services}) {
    final byId = {for (final service in services) service.id: service};
    final source = sourceServiceId == null ? null : byId[sourceServiceId];
    final accessBase = baseHops.isEmpty ? null : baseHops.last;
    final proxyBase = baseHops.length >= 2 ? baseHops.first : null;
    final hops = <ServiceRouteHop>[
      if (pattern == ServiceAccessPattern.reverseProxy)
        _proxyHop(byId, accessBase)
      else ...[
        if (usesProxyPrefix) _proxyHop(byId, proxyBase),
        _accessHop(byId, accessBase),
      ],
    ];
    final cleanTargets = _cleanTargets(targets);
    final trimmedNotes = notes?.trim();
    return ServiceRoute(
      id: routeId,
      name: serviceRouteGeneratedName(
        sourceName: source?.name ?? '',
        hops: hops,
        targets: cleanTargets,
      ),
      sourceServiceId: sourceServiceId ?? '',
      sourceEndpointId: sourceEndpointId,
      hops: hops,
      finalUrl: cleanTargets.firstOrNull,
      accessLevel: reachability.accessLevel,
      notes: trimmedNotes == null || trimmedNotes.isEmpty ? null : trimmedNotes,
      extraJson: serviceRouteExtraJsonWithAccessLane(
        serviceRouteExtraJsonWithTargets(extraJson, cleanTargets),
        reachability.lane,
      ),
    );
  }

  /// Purpose: Build the reverse-proxy hop, either the whole reverse-proxy
  /// pattern or the prefix in front of another pattern.
  /// Inputs: `byId` — services by id; `base` — the edited hop at this
  /// position, if any.
  /// Returns: `ServiceRouteHop`.
  /// Side effects: None.
  /// Notes: Internal helper of [toRoute].
  ServiceRouteHop _proxyHop(
    Map<String, ServiceNode> byId,
    ServiceRouteHop? base,
  ) {
    final proxy = proxyServiceId == null ? null : byId[proxyServiceId];
    return ServiceRouteHop(
      id: base?.id,
      type: ServiceRouteHopType.reverseProxy,
      method:
          proxyMethod ??
          (proxy == null
              ? ServiceRouteMethod.custom
              : serviceProxyMethodFor(proxy)),
      serviceId: proxyServiceId,
      endpointId: proxyServiceId == null ? null : proxyEndpointId,
      extraJson: base?.extraJson ?? const {},
    );
  }

  /// Purpose: Build the pattern's own access hop.
  /// Inputs: `byId` — services by id; `base` — the edited hop at this
  /// position, if any.
  /// Returns: `ServiceRouteHop`.
  /// Side effects: None.
  /// Notes: Internal helper of [toRoute]. The hop shapes are the ones
  /// `buildServiceTopology` already renders: a manual direct hop, a tunnel
  /// hop, or a port-forward hop whose FRP ingress is always explicit.
  ServiceRouteHop _accessHop(
    Map<String, ServiceNode> byId,
    ServiceRouteHop? base,
  ) {
    final hopExtra = base?.extraJson ?? const <String, dynamic>{};
    switch (pattern) {
      case ServiceAccessPattern.direct:
        return ServiceRouteHop(
          id: base?.id,
          type: ServiceRouteHopType.manual,
          method: ServiceRouteMethod.direct,
          label: serviceRouteMethodLabel(ServiceRouteMethod.direct),
          extraJson: hopExtra,
        );
      case ServiceAccessPattern.cloudflareTunnel:
      case ServiceAccessPattern.pangolin:
      case ServiceAccessPattern.tailscaleFunnel:
        final method = pattern.fixedMethod!;
        return ServiceRouteHop(
          id: base?.id,
          type: ServiceRouteHopType.tunnel,
          method: method,
          serviceId: relayServiceId,
          endpointId: relayServiceId == null ? null : relayEndpointId,
          label: relayServiceId == null
              ? serviceRouteMethodLabel(method)
              : null,
          extraJson: hopExtra,
        );
      case ServiceAccessPattern.frp:
        final relay = relayServiceId == null ? null : byId[relayServiceId];
        final ingress = relay == null
            ? null
            : (relay.endpoints
                      .where((endpoint) => endpoint.id == relayEndpointId)
                      .firstOrNull ??
                  serviceDefaultIngressEndpoint(relay));
        return ServiceRouteHop(
          id: base?.id,
          type: ServiceRouteHopType.portForward,
          method: ServiceRouteMethod.frp,
          serviceId: relayServiceId,
          endpointId: ingress?.id,
          deviceId: relay?.deviceId,
          label: relayServiceId == null
              ? serviceRouteMethodLabel(ServiceRouteMethod.frp)
              : null,
          host: _trimmedOrNull(publicHost),
          port: publicPort,
          extraJson: hopExtra,
        );
      case ServiceAccessPattern.routerPortForward:
        return ServiceRouteHop(
          id: base?.id,
          type: ServiceRouteHopType.portForward,
          method: ServiceRouteMethod.routerPortForward,
          deviceId: remoteDeviceId,
          label: serviceRouteMethodLabel(ServiceRouteMethod.routerPortForward),
          host: _trimmedOrNull(publicHost),
          port: publicPort,
          extraJson: hopExtra,
        );
      case ServiceAccessPattern.reverseProxy:
        return _proxyHop(byId, base);
    }
  }

  /// Purpose: Read a saved route back into a draft for the guided page.
  /// Inputs: `route`; `services` — the current services.
  /// Returns: The draft, or null when the guided page cannot edit the route
  /// without changing or losing something.
  /// Side effects: None.
  /// Notes: A saved proxy method equal to what the proxy service implies reads
  /// back as null ("derive"), so changing the proxy re-derives it. A route
  /// qualifies when it has one or two hops, an optional first
  /// reverse-proxy hop is the prefix, the last hop names a pattern (see
  /// [detectServiceAccessPattern]), its access level and any lane override
  /// form one reachability, the draft rebuilt from it reproduces every hop
  /// field, and the draft has no blocking issue. Everything else — three
  /// hops, hop notes or paths, a custom access level, a lane that disagrees
  /// with the access level — stays with the advanced editor.
  static ServiceAccessDraft? fromRoute(
    ServiceRoute route,
    List<ServiceNode> services,
  ) {
    final reachability = serviceReachabilityForRoute(route);
    if (reachability == null) return null;
    final hops = route.hops;
    if (hops.isEmpty || hops.length > 2) return null;
    final last = hops.last;
    final prefix = hops.length == 2 ? hops.first : null;
    if (prefix != null && !_isProxyHop(prefix)) return null;
    final pattern = _patternForHop(last);
    if (pattern == null) return null;
    if (prefix != null && !pattern.allowsProxyPrefix) return null;
    final proxyHop = pattern == ServiceAccessPattern.reverseProxy
        ? last
        : prefix;
    final byId = {for (final service in services) service.id: service};
    final proxyService = proxyHop?.serviceId == null
        ? null
        : byId[proxyHop!.serviceId];
    final savedProxyMethod = proxyHop?.method;
    final proxyMethod =
        proxyService != null &&
            savedProxyMethod == serviceProxyMethodFor(proxyService)
        ? null
        : savedProxyMethod;
    String? relayEndpointId;
    if (pattern.usesRelayService) {
      relayEndpointId = last.endpointId;
      final relay = last.serviceId == null ? null : byId[last.serviceId];
      if (pattern == ServiceAccessPattern.frp &&
          relayEndpointId == null &&
          relay != null) {
        relayEndpointId = serviceDefaultIngressEndpoint(relay)?.id;
      }
    }
    final draft = ServiceAccessDraft(
      routeId: route.id,
      sourceServiceId: route.sourceServiceId,
      sourceEndpointId: route.sourceEndpointId,
      pattern: pattern,
      reachability: reachability,
      viaProxy: prefix != null,
      proxyServiceId: proxyHop?.serviceId,
      proxyEndpointId: proxyHop?.endpointId,
      proxyMethod: proxyMethod,
      relayServiceId: pattern.usesRelayService ? last.serviceId : null,
      relayEndpointId: relayEndpointId,
      remoteDeviceId: pattern == ServiceAccessPattern.routerPortForward
          ? last.deviceId
          : null,
      publicHost: pattern.requiresPublicPort ? last.host : null,
      publicPort: pattern.requiresPublicPort ? last.port : null,
      targets: serviceRouteAccessTargets(route),
      notes: route.notes,
      extraJson: Map<String, dynamic>.of(route.extraJson)
        ..remove(serviceRoutePublicTargetsKey)
        ..remove(serviceRouteAccessLaneKey),
      baseHops: hops,
    );
    if (!_sameAccessShape(route, draft.toRoute(services: services), byId)) {
      return null;
    }
    if (serviceAccessDraftIssues(draft, services).isNotEmpty) return null;
    return draft;
  }

  /// Purpose: Compare two drafts by form content.
  /// Inputs: `other`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Identity metadata — [routeId] and [baseHops] — is not compared,
  /// so a draft read back from the route it produced equals the original.
  /// [extraJson] and [targets] compare by value.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceAccessDraft &&
          other.sourceServiceId == sourceServiceId &&
          other.sourceEndpointId == sourceEndpointId &&
          other.pattern == pattern &&
          other.reachability == reachability &&
          other.viaProxy == viaProxy &&
          other.proxyServiceId == proxyServiceId &&
          other.proxyEndpointId == proxyEndpointId &&
          other.proxyMethod == proxyMethod &&
          other.relayServiceId == relayServiceId &&
          other.relayEndpointId == relayEndpointId &&
          other.remoteDeviceId == remoteDeviceId &&
          other.publicHost == publicHost &&
          other.publicPort == publicPort &&
          _jsonEquals(other.targets, targets) &&
          other.notes == notes &&
          _jsonEquals(other.extraJson, extraJson);

  /// Purpose: Hash the fields [operator ==] compares.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: [extraJson] contributes only its key count, which keeps the hash
  /// consistent with the deep equality without hashing nested JSON.
  @override
  int get hashCode => Object.hash(
    sourceServiceId,
    sourceEndpointId,
    pattern,
    reachability,
    viaProxy,
    proxyServiceId,
    proxyEndpointId,
    proxyMethod,
    relayServiceId,
    relayEndpointId,
    remoteDeviceId,
    publicHost,
    publicPort,
    Object.hashAll(targets),
    notes,
    extraJson.length,
  );

  /// Purpose: Describe the draft for test failure messages.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Not shown in the UI.
  @override
  String toString() =>
      'ServiceAccessDraft(${pattern.name}, ${reachability.name}, '
      'source: $sourceServiceId/$sourceEndpointId, viaProxy: $viaProxy, '
      'proxy: $proxyServiceId/$proxyEndpointId/${proxyMethod?.name}, '
      'relay: $relayServiceId/$relayEndpointId, device: $remoteDeviceId, '
      'public: $publicHost:$publicPort, targets: $targets, notes: $notes, '
      'extra: $extraJson)';
}

/// Purpose: Name the access pattern a saved route follows.
/// Inputs: `route`; `services` — the current services.
/// Returns: The pattern, or null when the route belongs in the advanced
/// editor.
/// Side effects: None.
/// Notes: The last hop decides: method direct ⇒ direct; a reverse-proxy hop
/// (type, or method Caddy / Nginx / Traefik) as the only hop ⇒ reverse
/// proxy; method Cloudflare Tunnel, Pangolin or Tailscale Funnel ⇒ that
/// pattern; method FRP, or a port-forward hop with a service ⇒ FRP; method
/// router port forward, or a port-forward hop without a service ⇒ router
/// port forward. A route matches only when [ServiceAccessDraft.fromRoute]
/// can edit it losslessly.
ServiceAccessPattern? detectServiceAccessPattern(
  ServiceRoute route,
  List<ServiceNode> services,
) => ServiceAccessDraft.fromRoute(route, services)?.pattern;

/// Purpose: Read the reachability a saved route expresses.
/// Inputs: `route`.
/// Returns: The reachability, or null when the route's access level and lane
/// override do not form one.
/// Side effects: None.
/// Notes: Without an `accessLane` override the access level alone decides
/// (`authenticated` ⇒ public with login). With one, the override must be the
/// lane that access level maps to; a custom access level never qualifies.
ServiceReachability? serviceReachabilityForRoute(ServiceRoute route) {
  final fromLevel = switch (route.accessLevel) {
    ServiceAccessLevel.lan => ServiceReachability.lan,
    ServiceAccessLevel.vpn => ServiceReachability.vpn,
    ServiceAccessLevel.public => ServiceReachability.public,
    ServiceAccessLevel.authenticated => ServiceReachability.publicAuthenticated,
    ServiceAccessLevel.custom => null,
  };
  if (fromLevel == null) return null;
  final explicitLane = serviceRouteExplicitAccessLane(route);
  if (explicitLane != null && explicitLane != fromLevel.lane) return null;
  return fromLevel;
}

/// Purpose: List the problems that keep a draft from being saved.
/// Inputs: `draft`; `services` — the current services.
/// Returns: The issues, empty when the draft can be saved.
/// Side effects: None.
/// Notes: A referenced service that no longer exists counts as missing. The
/// source endpoint is not checked: a service without endpoints is still a
/// valid source.
List<ServiceAccessDraftIssue> serviceAccessDraftIssues(
  ServiceAccessDraft draft,
  List<ServiceNode> services,
) {
  final ids = {for (final service in services) service.id};

  /// Purpose: Report whether an id names an existing service.
  /// Inputs: `id`.
  /// Returns: `bool` — false for null.
  /// Side effects: None.
  /// Notes: Local helper of [serviceAccessDraftIssues].
  bool present(String? id) => id != null && ids.contains(id);
  final port = draft.publicPort;
  final pattern = draft.pattern;
  return [
    if (!present(draft.sourceServiceId)) ServiceAccessDraftIssue.missingSource,
    if (draft.needsProxy && !present(draft.proxyServiceId))
      ServiceAccessDraftIssue.missingProxy,
    if (pattern.usesRelayService &&
        (pattern.requiresRelayService || draft.relayServiceId != null) &&
        !present(draft.relayServiceId))
      ServiceAccessDraftIssue.missingRelay,
    if (pattern.requiresPublicPort &&
        (port == null || port < 1 || port > 65535))
      ServiceAccessDraftIssue.invalidPublicPort,
    if (pattern.requiresTargets && _cleanTargets(draft.targets).isEmpty)
      ServiceAccessDraftIssue.missingTargets,
  ];
}

/// Purpose: List advisory findings the guided page shows beside the preview.
/// Inputs: `draft`; `services` — the current services.
/// Returns: The warnings, possibly empty.
/// Side effects: None.
/// Notes: FRP only: a relay without any endpoint has nothing to act as the
/// ingress, and a relay on the source's own device rarely reflects a real FRP
/// setup. Neither blocks saving.
List<ServiceAccessDraftWarning> serviceAccessDraftWarnings(
  ServiceAccessDraft draft,
  List<ServiceNode> services,
) {
  if (draft.pattern != ServiceAccessPattern.frp) return const [];
  final byId = {for (final service in services) service.id: service};
  final relay = draft.relayServiceId == null
      ? null
      : byId[draft.relayServiceId];
  if (relay == null) return const [];
  final source = draft.sourceServiceId == null
      ? null
      : byId[draft.sourceServiceId];
  return [
    if (relay.endpoints.isEmpty) ServiceAccessDraftWarning.relayWithoutIngress,
    if (source != null && source.deviceId == relay.deviceId)
      ServiceAccessDraftWarning.relayOnSourceDevice,
  ];
}

/// Purpose: Pick the route method a reverse-proxy hop through a service
/// records.
/// Inputs: `proxy` — the proxy service.
/// Returns: Caddy, Nginx or Traefik when the template id, name or icon says
/// so, else custom.
/// Side effects: None.
/// Notes: Checked in that order, case-insensitively.
ServiceRouteMethod serviceProxyMethodFor(ServiceNode proxy) {
  final text = [
    proxy.templateId,
    proxy.name,
    proxy.icon,
  ].whereType<String>().join(' ').toLowerCase();
  if (text.contains('caddy')) return ServiceRouteMethod.caddy;
  if (text.contains('nginx')) return ServiceRouteMethod.nginx;
  if (text.contains('traefik')) return ServiceRouteMethod.traefik;
  return ServiceRouteMethod.custom;
}

/// Purpose: Report whether a service looks like a reverse proxy.
/// Inputs: `service`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Kind `reverseProxy`, or a Caddy / Nginx / Traefik template or name.
bool isReverseProxyLikeService(ServiceNode service) =>
    service.kind == ServiceKind.reverseProxy ||
    serviceProxyMethodFor(service) != ServiceRouteMethod.custom;

/// Purpose: Report whether a service looks like an FRP server or another
/// tunnel endpoint.
/// Inputs: `service`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: The heuristic the quick access dialog used to order FRP relay
/// candidates: "frp" anywhere in the name, template id, icon or kind name, or
/// kind `tunnel`.
bool isFrpLikeService(ServiceNode service) {
  final text = [
    service.name,
    service.templateId,
    service.icon,
    service.kind.name,
  ].whereType<String>().join(' ').toLowerCase();
  return text.contains('frp') || service.kind == ServiceKind.tunnel;
}

/// Purpose: List the services worth suggesting as a reverse proxy.
/// Inputs: `services`; `sourceServiceId` — excluded, and its device's
/// proxies come first.
/// Returns: Service ids, same-device proxies first, then by name.
/// Side effects: None.
/// Notes: Uses [isReverseProxyLikeService]. The picker still lists every
/// other service below the suggestions.
List<String> serviceAccessProxySuggestions(
  List<ServiceNode> services, {
  String? sourceServiceId,
}) {
  final source = services
      .where((service) => service.id == sourceServiceId)
      .firstOrNull;
  final candidates = [
    for (final service in services)
      if (service.id != sourceServiceId && isReverseProxyLikeService(service))
        service,
  ];
  candidates.sort((a, b) {
    final aLocal = a.deviceId == source?.deviceId ? 0 : 1;
    final bLocal = b.deviceId == source?.deviceId ? 0 : 1;
    if (aLocal != bLocal) return aLocal.compareTo(bLocal);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return [for (final service in candidates) service.id];
}

/// Purpose: List the services worth suggesting as the relay of a pattern.
/// Inputs: `pattern`, `services`, `devices`; `sourceServiceId` — excluded.
/// Returns: Service ids, services on VPS devices first, then by name; empty
/// for patterns without a relay.
/// Side effects: None.
/// Notes: FRP suggests services with "frp" in their name, template or icon,
/// falling back to [isFrpLikeService]; Pangolin, Cloudflare Tunnel and
/// Tailscale Funnel suggest services whose name, template or icon names the
/// product (`cloudflare`/`cloudflared` for the tunnel).
List<String> serviceAccessRelaySuggestions(
  ServiceAccessPattern pattern,
  List<ServiceNode> services,
  List<Device> devices, {
  String? sourceServiceId,
}) {
  final keywords = switch (pattern) {
    ServiceAccessPattern.frp => const ['frp'],
    ServiceAccessPattern.pangolin => const ['pangolin'],
    ServiceAccessPattern.cloudflareTunnel => const ['cloudflare'],
    ServiceAccessPattern.tailscaleFunnel => const ['tailscale'],
    _ => const <String>[],
  };
  if (keywords.isEmpty) return const [];
  final others = [
    for (final service in services)
      if (service.id != sourceServiceId) service,
  ];

  /// Purpose: Report whether a service's name, template or icon names the
  /// pattern's product.
  /// Inputs: `service`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Local helper of [serviceAccessRelaySuggestions].
  bool named(ServiceNode service) {
    final text = [
      service.name,
      service.templateId,
      service.icon,
    ].whereType<String>().join(' ').toLowerCase();
    return keywords.any(text.contains);
  }

  var candidates = others.where(named).toList();
  if (candidates.isEmpty && pattern == ServiceAccessPattern.frp) {
    candidates = others.where(isFrpLikeService).toList();
  }
  final vps = {
    for (final device in devices)
      if (device.category == DeviceCategory.vps) device.id,
  };
  candidates.sort((a, b) {
    final aVps = vps.contains(a.deviceId) ? 0 : 1;
    final bVps = vps.contains(b.deviceId) ? 0 : 1;
    if (aVps != bVps) return aVps.compareTo(bVps);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return [for (final service in candidates) service.id];
}

/// Purpose: Return the template "Create relay service…" starts from.
/// Inputs: `pattern`.
/// Returns: A template id, or null for patterns without a relay.
/// Side effects: None.
/// Notes: `frp`, `pangolin`, `cloudflare-tunnel` and `tailscale` are ids
/// from `service_template_service.dart`.
String? serviceAccessRelayTemplateId(ServiceAccessPattern pattern) =>
    switch (pattern) {
      ServiceAccessPattern.frp => 'frp',
      ServiceAccessPattern.pangolin => 'pangolin',
      ServiceAccessPattern.cloudflareTunnel => 'cloudflare-tunnel',
      ServiceAccessPattern.tailscaleFunnel => 'tailscale',
      _ => null,
    };

/// Purpose: Order devices for the router picker of a router port forward.
/// Inputs: `devices`.
/// Returns: Every device, routers first, then by name.
/// Side effects: None.
/// Notes: Any device may still be picked; the router is optional.
List<Device> serviceAccessRouterCandidates(List<Device> devices) {
  final ordered = [...devices];
  ordered.sort((a, b) {
    final aRouter = a.category == DeviceCategory.router ? 0 : 1;
    final bRouter = b.category == DeviceCategory.router ? 0 : 1;
    if (aRouter != bRouter) return aRouter.compareTo(bRouter);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return ordered;
}

/// Purpose: Suggest the address a direct access path opens.
/// Inputs: `source`; `endpoint` — the chosen source endpoint, if any;
/// `assignments`, `networks` — where the source's device sits;
/// `reachability`.
/// Returns: `scheme://host:port/path` built from what is known, or null.
/// Side effects: None.
/// Notes: VPN reachability prefers the device's Tailscale / ZeroTier /
/// EasyTier / WireGuard assignment and its host name (MagicDNS); LAN prefers a
/// LAN assignment and its IP address. Public reachability gets no
/// suggestion — a direct public address is not something the inventory can
/// guess. The scheme comes from an http/https endpoint; other protocols get
/// none. With several endpoints and none chosen, the port is left out.
String? suggestedDirectTarget({
  required ServiceNode source,
  ServiceEndpoint? endpoint,
  required List<NetworkDevice> assignments,
  required List<Network> networks,
  required ServiceReachability reachability,
}) {
  if (reachability != ServiceReachability.lan &&
      reachability != ServiceReachability.vpn) {
    return null;
  }
  final vpn = reachability == ServiceReachability.vpn;
  final types = {for (final network in networks) network.id: network.type};

  /// Purpose: Report whether an assignment records an IP address or a host
  /// name.
  /// Inputs: `assignment`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Local helper of [suggestedDirectTarget].
  bool hasAddress(NetworkDevice assignment) =>
      (assignment.ipAddress?.trim().isNotEmpty ?? false) ||
      (assignment.hostname?.trim().isNotEmpty ?? false);

  /// Purpose: Report whether an assignment's network suits the
  /// reachability: a LAN network for LAN, an overlay network for VPN.
  /// Inputs: `assignment`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Local helper of [suggestedDirectTarget].
  bool matches(NetworkDevice assignment) {
    final type = types[assignment.networkId];
    return vpn
        ? type != null && type != NetworkType.lan && type != NetworkType.other
        : type == NetworkType.lan;
  }

  final own = [
    for (final assignment in assignments)
      if (assignment.deviceId == source.deviceId && hasAddress(assignment))
        assignment,
  ];
  final pick = own.where(matches).firstOrNull ?? own.firstOrNull;
  if (pick == null) return null;
  final ip = _trimmedOrNull(pick.ipAddress);
  final name = _trimmedOrNull(pick.hostname);
  final host = vpn ? (name ?? ip) : (ip ?? name);
  if (host == null) return null;
  final chosen =
      endpoint ??
      (source.endpoints.length == 1 ? source.endpoints.single : null);
  final scheme = switch (chosen?.protocol) {
    ServiceProtocol.https => 'https://',
    ServiceProtocol.http => 'http://',
    _ => '',
  };
  final port = chosen?.port == null ? '' : ':${chosen!.port}';
  final path = _trimmedOrNull(chosen?.path) ?? '';
  return '$scheme$host$port$path';
}

/// Purpose: Suggest the public host of an FRP relay.
/// Inputs: `relay`; `assignments`.
/// Returns: The host name, else the IP address, of the relay device's only
/// network assignment; null when it has none or several.
/// Side effects: None.
/// Notes: Several assignments make the guess ambiguous, so none is made.
String? suggestedPublicHost(
  ServiceNode relay,
  List<NetworkDevice> assignments,
) {
  final own = [
    for (final assignment in assignments)
      if (assignment.deviceId == relay.deviceId) assignment,
  ];
  if (own.length != 1) return null;
  return _trimmedOrNull(own.single.hostname) ??
      _trimmedOrNull(own.single.ipAddress);
}

/// Purpose: Report whether a hop can be the reverse-proxy prefix or the
/// reverse-proxy pattern's hop.
/// Inputs: `hop`.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper of this file.
bool _isProxyHop(ServiceRouteHop hop) =>
    hop.type == ServiceRouteHopType.reverseProxy ||
    hop.method == ServiceRouteMethod.caddy ||
    hop.method == ServiceRouteMethod.nginx ||
    hop.method == ServiceRouteMethod.traefik;

/// Purpose: Classify a route's last hop into a pattern.
/// Inputs: `hop`.
/// Returns: The pattern, or null.
/// Side effects: None.
/// Notes: Internal helper of [ServiceAccessDraft.fromRoute]; the rules are
/// listed on [detectServiceAccessPattern].
ServiceAccessPattern? _patternForHop(ServiceRouteHop hop) {
  switch (hop.method) {
    case ServiceRouteMethod.direct:
      return ServiceAccessPattern.direct;
    case ServiceRouteMethod.cloudflareTunnel:
      return ServiceAccessPattern.cloudflareTunnel;
    case ServiceRouteMethod.pangolin:
      return ServiceAccessPattern.pangolin;
    case ServiceRouteMethod.tailscaleFunnel:
      return ServiceAccessPattern.tailscaleFunnel;
    case ServiceRouteMethod.frp:
      return ServiceAccessPattern.frp;
    case ServiceRouteMethod.routerPortForward:
      return ServiceAccessPattern.routerPortForward;
    case ServiceRouteMethod.caddy:
    case ServiceRouteMethod.nginx:
    case ServiceRouteMethod.traefik:
      return ServiceAccessPattern.reverseProxy;
    case ServiceRouteMethod.custom:
    case null:
      if (hop.type == ServiceRouteHopType.reverseProxy) {
        return ServiceAccessPattern.reverseProxy;
      }
      if (hop.type == ServiceRouteHopType.portForward) {
        return hop.serviceId != null
            ? ServiceAccessPattern.frp
            : ServiceAccessPattern.routerPortForward;
      }
      return null;
  }
}

/// Purpose: Check that a rebuilt route reproduces a saved route's content.
/// Inputs: `saved`, `rebuilt`; `byId` — services by id.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Compares the source, access level, targets, notes and every hop
/// field; ignores ids, the generated name, timestamps and `extraJson`. A
/// saved FRP hop without an endpoint compares as its default ingress, which
/// the rebuilt hop records explicitly.
bool _sameAccessShape(
  ServiceRoute saved,
  ServiceRoute rebuilt,
  Map<String, ServiceNode> byId,
) {
  if (saved.sourceServiceId != rebuilt.sourceServiceId ||
      saved.sourceEndpointId != rebuilt.sourceEndpointId ||
      saved.accessLevel != rebuilt.accessLevel ||
      _trimmedOrNull(saved.notes) != _trimmedOrNull(rebuilt.notes) ||
      !_jsonEquals(
        serviceRouteAccessTargets(saved),
        serviceRouteAccessTargets(rebuilt),
      ) ||
      saved.hops.length != rebuilt.hops.length) {
    return false;
  }
  for (var i = 0; i < saved.hops.length; i++) {
    final a = saved.hops[i];
    final b = rebuilt.hops[i];
    var savedEndpointId = a.endpointId;
    if (savedEndpointId == null &&
        a.method == ServiceRouteMethod.frp &&
        a.serviceId != null) {
      final relay = byId[a.serviceId];
      savedEndpointId = relay == null
          ? null
          : serviceDefaultIngressEndpoint(relay)?.id;
    }
    if (a.type != b.type ||
        a.method != b.method ||
        a.serviceId != b.serviceId ||
        savedEndpointId != b.endpointId ||
        a.deviceId != b.deviceId ||
        _trimmedOrNull(a.label) != _trimmedOrNull(b.label) ||
        _trimmedOrNull(a.scheme) != _trimmedOrNull(b.scheme) ||
        _trimmedOrNull(a.host) != _trimmedOrNull(b.host) ||
        a.port != b.port ||
        _trimmedOrNull(a.path) != _trimmedOrNull(b.path) ||
        _trimmedOrNull(a.notes) != _trimmedOrNull(b.notes)) {
      return false;
    }
  }
  return true;
}

/// Purpose: Trim targets and drop empty and duplicate entries.
/// Inputs: `targets`.
/// Returns: The cleaned list, first occurrence kept.
/// Side effects: None.
/// Notes: Duplicates compare case-insensitively after trimming.
List<String> _cleanTargets(List<String> targets) {
  final seen = <String>{};
  return [
    for (final target in targets)
      if (target.trim().isNotEmpty && seen.add(target.trim().toLowerCase()))
        target.trim(),
  ];
}

/// Purpose: Trim a string and turn an empty result into null.
/// Inputs: `value`.
/// Returns: `String?`.
/// Side effects: None.
/// Notes: Internal helper of this file.
String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Purpose: Compare JSON-shaped values deeply.
/// Inputs: `a`, `b` — maps, lists or scalars.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Map key order does not matter; list order does.
bool _jsonEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_jsonEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
