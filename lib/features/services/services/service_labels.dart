import '../../../l10n/app_localizations.dart';
import '../models/service.dart';
import 'service_access_patterns.dart';
import 'service_analysis.dart';

// UI-only labels for the services module. Persisted route names, the
// Markdown export and the local API keep using the unlocalized
// `serviceRouteMethodLabel` and `serviceRouteGeneratedName`, so nothing a
// sync partner reads changes with the viewer's language.

/// Purpose: Return the localized text of a reference warning.
/// Inputs: `l10n`, `warning`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Moved from the services overview in 1.5.6 so the guided
/// access-path page shows its advisory warnings in the same words.
String serviceWarningLabel(AppLocalizations l10n, ServiceWarning warning) =>
    switch (warning.kind) {
      ServiceWarningKind.missingDevice => l10n.serviceWarningMissingDevice(
        warning.name,
      ),
      ServiceWarningKind.inactiveDevice => l10n.serviceWarningInactiveDevice(
        warning.name,
      ),
      ServiceWarningKind.missingEndpointNetwork =>
        l10n.serviceWarningMissingNetwork(warning.name),
      ServiceWarningKind.missingSourceService =>
        l10n.serviceWarningMissingSource(warning.name),
      ServiceWarningKind.missingSourceEndpoint =>
        l10n.serviceWarningMissingSourceEndpoint(warning.name),
      ServiceWarningKind.missingHopService =>
        l10n.serviceWarningMissingHopService(warning.name),
      ServiceWarningKind.missingHopEndpoint =>
        l10n.serviceWarningMissingHopEndpoint(warning.name),
      ServiceWarningKind.missingHopDevice =>
        l10n.serviceWarningMissingHopDevice(warning.name),
      ServiceWarningKind.emptyRoute => l10n.serviceWarningEmptyRoute(
        warning.name,
      ),
      ServiceWarningKind.publicRouteMissingUrl =>
        l10n.serviceWarningPublicRouteMissingUrl(warning.name),
      ServiceWarningKind.duplicateFinalUrl =>
        l10n.serviceWarningDuplicateFinalUrl(warning.name),
    };

/// Purpose: Return the localized text of a guided-draft warning.
/// Inputs: `l10n`, `warning`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Advisory only, like the reference warnings.
String serviceAccessDraftWarningLabel(
  AppLocalizations l10n,
  ServiceAccessDraftWarning warning,
) => switch (warning) {
  ServiceAccessDraftWarning.relayWithoutIngress =>
    l10n.serviceAccessWarningNoIngress,
  ServiceAccessDraftWarning.relayOnSourceDevice =>
    l10n.serviceAccessWarningSameDevice,
};

/// Purpose: Name a hop that has neither a service nor a label of its own.
/// Inputs: `l10n`, `hop`.
/// Returns: The localized method when the hop has one, else the localized
/// hop type.
/// Side effects: None.
/// Notes: The `hopFallback` both route editors hand to
/// `serviceRouteChainPreview`, so a direct hop previews as "Direct" rather
/// than as its "Manual" hop type.
String serviceHopFallbackLabel(AppLocalizations l10n, ServiceRouteHop hop) {
  final method = hop.method;
  return method != null
      ? serviceRouteMethodUiLabel(l10n, method)
      : serviceHopTypeLabel(l10n, hop.type);
}

/// Purpose: Return the localized label for a route hop type.
/// Inputs: `l10n`, `type`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Used by the advanced route editor and wherever a hop falls back to
/// its type name.
String serviceHopTypeLabel(AppLocalizations l10n, ServiceRouteHopType type) =>
    switch (type) {
      ServiceRouteHopType.origin => l10n.serviceHopTypeOrigin,
      ServiceRouteHopType.reverseProxy => l10n.serviceHopTypeReverseProxy,
      ServiceRouteHopType.tunnel => l10n.serviceHopTypeTunnel,
      ServiceRouteHopType.portForward => l10n.serviceHopTypePortForward,
      ServiceRouteHopType.publicEndpoint => l10n.serviceHopTypePublicEndpoint,
      ServiceRouteHopType.internalEndpoint =>
        l10n.serviceHopTypeInternalEndpoint,
      ServiceRouteHopType.dns => l10n.serviceHopTypeDns,
      ServiceRouteHopType.manual => l10n.serviceHopTypeManual,
    };

/// Purpose: Return the label a route method shows in the UI.
/// Inputs: `l10n`, `method`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Product names (Caddy, Nginx, Traefik, FRP, Cloudflare Tunnel,
/// Pangolin, Tailscale Funnel) come back as-is from
/// `serviceRouteMethodLabel`; only the generic Direct, Custom and Router
/// port forward are translated.
String serviceRouteMethodUiLabel(
  AppLocalizations l10n,
  ServiceRouteMethod method,
) => switch (method) {
  ServiceRouteMethod.direct => l10n.serviceMethodDirect,
  ServiceRouteMethod.custom => l10n.serviceMethodCustom,
  ServiceRouteMethod.routerPortForward => l10n.serviceMethodRouterPortForward,
  _ => serviceRouteMethodLabel(method),
};

/// Purpose: Return the localized label for a route access level.
/// Inputs: `l10n`, `level`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: The four non-custom levels share their labels with
/// [serviceReachabilityLabel], so a route reads the same in both editors.
String serviceAccessLevelLabel(
  AppLocalizations l10n,
  ServiceAccessLevel level,
) => switch (level) {
  ServiceAccessLevel.lan => l10n.serviceAccessLevelLan,
  ServiceAccessLevel.vpn => l10n.serviceAccessLevelVpn,
  ServiceAccessLevel.authenticated => l10n.serviceAccessLevelAuthenticated,
  ServiceAccessLevel.public => l10n.serviceAccessLevelPublic,
  ServiceAccessLevel.custom => l10n.serviceAccessLevelCustom,
};

/// Purpose: Return the localized label for a reachability choice.
/// Inputs: `l10n`, `reachability`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Delegates to [serviceAccessLevelLabel] through the access level the
/// reachability saves.
String serviceReachabilityLabel(
  AppLocalizations l10n,
  ServiceReachability reachability,
) => serviceAccessLevelLabel(l10n, reachability.accessLevel);

/// Purpose: Return the localized label for a topology access lane.
/// Inputs: `l10n`, `lane`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Replaces the English-only lane labels the topology used before
/// 1.5.6.
String serviceAccessLaneLabel(AppLocalizations l10n, ServiceAccessLane lane) =>
    switch (lane) {
      ServiceAccessLane.local => l10n.serviceLaneLocal,
      ServiceAccessLane.vpn => l10n.serviceLaneVpn,
      ServiceAccessLane.public => l10n.serviceLanePublic,
    };

/// Purpose: Return the localized label for a topology node role.
/// Inputs: `l10n`, `role`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Shown in the node details and the legend.
String serviceTopologyRoleLabel(
  AppLocalizations l10n,
  ServiceTopologyNodeRole role,
) => switch (role) {
  ServiceTopologyNodeRole.localDevice => l10n.serviceRoleLocalDevice,
  ServiceTopologyNodeRole.remoteDevice => l10n.serviceRoleRemoteDevice,
  ServiceTopologyNodeRole.localService => l10n.serviceRoleLocalService,
  ServiceTopologyNodeRole.remoteService => l10n.serviceRoleRemoteService,
  ServiceTopologyNodeRole.localEndpoint => l10n.serviceRoleLocalEndpoint,
  ServiceTopologyNodeRole.lanAccess => l10n.serviceRoleLanAccess,
  ServiceTopologyNodeRole.vpnAccess => l10n.serviceRoleVpnAccess,
  ServiceTopologyNodeRole.publicRelay => l10n.serviceRolePublicRelay,
  ServiceTopologyNodeRole.remotePublicEntry =>
    l10n.serviceRoleRemotePublicEntry,
  ServiceTopologyNodeRole.domain => l10n.serviceRoleDomain,
};

/// Purpose: Return the display name of an access pattern.
/// Inputs: `l10n`, `pattern`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Product patterns show their product name; direct access, reverse
/// proxy and router port forward are translated.
String serviceAccessPatternLabel(
  AppLocalizations l10n,
  ServiceAccessPattern pattern,
) => switch (pattern) {
  ServiceAccessPattern.direct => l10n.servicePatternDirect,
  ServiceAccessPattern.reverseProxy => l10n.serviceHopTypeReverseProxy,
  ServiceAccessPattern.routerPortForward => l10n.serviceMethodRouterPortForward,
  _ => serviceRouteMethodLabel(pattern.fixedMethod!),
};

/// Purpose: Return the one-line description shown under a pattern's name.
/// Inputs: `l10n`, `pattern`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Describes the setup in the user's terms rather than the data
/// model's.
String serviceAccessPatternDescription(
  AppLocalizations l10n,
  ServiceAccessPattern pattern,
) => switch (pattern) {
  ServiceAccessPattern.direct => l10n.servicePatternDirectDesc,
  ServiceAccessPattern.reverseProxy => l10n.servicePatternReverseProxyDesc,
  ServiceAccessPattern.cloudflareTunnel =>
    l10n.servicePatternCloudflareTunnelDesc,
  ServiceAccessPattern.pangolin => l10n.servicePatternPangolinDesc,
  ServiceAccessPattern.frp => l10n.servicePatternFrpDesc,
  ServiceAccessPattern.routerPortForward =>
    l10n.servicePatternRouterPortForwardDesc,
  ServiceAccessPattern.tailscaleFunnel =>
    l10n.servicePatternTailscaleFunnelDesc,
};
