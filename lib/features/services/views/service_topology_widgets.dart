import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../devices/models/device.dart';
import '../../devices/widgets/device_category_icon.dart';
import '../models/service.dart';
import '../services/service_analysis.dart';
import '../services/service_labels.dart';
import '../services/service_topology_layout.dart';

/// One node of the topology canvas: a full card, or a small port chip for
/// compact nodes (endpoints and remote entries).
class ServiceTopologyNodeCard extends StatelessWidget {
  final ServiceTopologyNode node;
  final IconData icon;
  final VoidCallback? onTap;

  /// Purpose: Create a topology node card.
  /// Inputs: `node`; `icon` — from `iconForTopologyNode`; `onTap` — null in move
  /// mode, so the card does not take the pan gesture.
  /// Returns: A new `ServiceTopologyNodeCard`.
  /// Side effects: None.
  /// Notes: The layout sizes the card; it fills the rect it is given.
  const ServiceTopologyNodeCard({
    super.key,
    required this.node,
    required this.icon,
    required this.onTap,
  });

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = _nodeBorder(context, node);
    final compact = node.compact;
    if (compact) {
      return Tooltip(
        message: [
          node.label,
          node.detail,
          node.lane == null ? null : topologyLaneLabel(node.lane!),
        ].whereType<String>().join('\n'),
        child: SizedBox.square(
          dimension: ServiceTopologyLayout.portChipSize,
          child: Card(
            margin: EdgeInsets.zero,
            color: _nodeFill(context, node),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: border, width: 1.2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 16, color: border),
                    const SizedBox(height: 2),
                    Text(
                      _compactTopologyLabel(node),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Tooltip(
      message: [node.label, node.detail].whereType<String>().join('\n'),
      child: Card(
        margin: EdgeInsets.zero,
        color: _nodeFill(context, node),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: 1.4),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: border.withValues(alpha: 0.18),
                  foregroundColor: border,
                  child: Icon(icon, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_nodeSubtitle(context, node) != null ||
                          node.lane != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            _nodeSubtitle(context, node),
                            if (node.lane != null)
                              topologyLaneLabel(node.lane!),
                          ].whereType<String>().join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the topology's routed edges with an arrow head, coloured by lane.
class ServiceTopologyEdgePainter extends CustomPainter {
  final ServiceTopologyGraph graph;
  final ServiceTopologyLayout layout;
  final ColorScheme colorScheme;

  /// Purpose: Create the edge painter.
  /// Inputs: `graph`; `layout` — supplies each edge's routed polyline;
  /// `colorScheme` — the lane colours.
  /// Returns: A new `ServiceTopologyEdgePainter`.
  /// Side effects: None.
  /// Notes: None.
  const ServiceTopologyEdgePainter({
    required this.graph,
    required this.layout,
    required this.colorScheme,
  });

  /// Purpose: Paint every edge that has a routed path.
  /// Inputs: `canvas`, `size`.
  /// Returns: None.
  /// Side effects: Draws on the canvas.
  /// Notes: Edges without a path of at least two points are skipped.
  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in graph.edges) {
      final points = layout.edgePaths[edge];
      if (points == null || points.length < 2) continue;
      final paint = Paint()
        ..color = _edgeColor(edge).withValues(alpha: 0.62)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _drawPolyline(canvas, paint, points);
    }
  }

  /// Purpose: Draw one polyline and an arrow head at its end.
  /// Inputs: `canvas`, `paint`, `points` — at least two.
  /// Returns: `void`.
  /// Side effects: Draws on the canvas.
  /// Notes: The arrow follows the last segment longer than half a pixel, so a
  /// zero-length stub at the end cannot turn it.
  void _drawPolyline(Canvas canvas, Paint paint, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);

    final end = points.last;
    var previous = points[points.length - 2];
    for (var i = points.length - 2; i >= 0; i--) {
      if ((end - points[i]).distance > 0.5) {
        previous = points[i];
        break;
      }
    }
    final angle = math.atan2(end.dy - previous.dy, end.dx - previous.dx);
    final arrow = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - 9 * math.cos(angle - 0.45),
        end.dy - 9 * math.sin(angle - 0.45),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - 9 * math.cos(angle + 0.45),
        end.dy - 9 * math.sin(angle + 0.45),
      );
    canvas.drawPath(arrow, paint);
  }

  /// Purpose: Return an edge's lane colour.
  /// Inputs: `edge`.
  /// Returns: `Color` — local tertiary, VPN secondary, public primary, no lane
  /// outline.
  /// Side effects: None.
  /// Notes: `serviceAccessLaneColor` on the guided page matches these.
  Color _edgeColor(ServiceTopologyEdge edge) => switch (edge.lane) {
    ServiceAccessLane.local => colorScheme.tertiary,
    ServiceAccessLane.vpn => colorScheme.secondary,
    ServiceAccessLane.public => colorScheme.primary,
    null => colorScheme.outline,
  };

  /// Purpose: Report whether the edges must be repainted.
  /// Inputs: `oldDelegate`.
  /// Returns: `bool` — true when the graph, layout or colour scheme changed.
  /// Side effects: None.
  /// Notes: None.
  @override
  bool shouldRepaint(covariant ServiceTopologyEdgePainter oldDelegate) =>
      oldDelegate.graph != graph ||
      oldDelegate.layout != layout ||
      oldDelegate.colorScheme != colorScheme;
}

/// Purpose: Return the subtitle a topology node card shows under its label.
/// Inputs: `context`, `node`.
/// Returns: `String?` — null when there is nothing to show.
/// Side effects: None.
/// Notes: A relay node shows its localized route method, or its localized hop
/// type when the builder only recorded the raw type name; every other node
/// shows the builder's `detail` unchanged.
String? _nodeSubtitle(BuildContext context, ServiceTopologyNode node) {
  final detail = node.detail?.trim();
  if (node.kind == ServiceTopologyNodeKind.relay) {
    final l10n = AppLocalizations.of(context)!;
    final method = node.method;
    if (method != null) return serviceRouteMethodUiLabel(l10n, method);
    final type = ServiceRouteHopType.values
        .where((value) => value.name == detail)
        .firstOrNull;
    if (type != null) return serviceHopTypeLabel(l10n, type);
  }
  return detail == null || detail.isEmpty ? null : detail;
}

/// Purpose: Return the short text a port chip shows.
/// Inputs: `node`.
/// Returns: `String` — at most five characters.
/// Side effects: None.
/// Notes: A remote entry shows the port after its last colon; any other node
/// the last port-like number in its label and detail; otherwise the label cut
/// to five characters.
String _compactTopologyLabel(ServiceTopologyNode node) {
  if (node.kind == ServiceTopologyNodeKind.remoteEntry) {
    final label = node.label.trim();
    final portMatch = RegExp(r':(\d{1,5}(?:-\d{1,5})?)$').firstMatch(label);
    if (portMatch != null) return portMatch.group(1)!;
    if (label.length <= 5) return label;
    return label.substring(0, 5);
  }
  final source = [node.label, node.detail].whereType<String>().join(' ');
  final matches = RegExp(r'\d{1,5}(?:-\d{1,5})?').allMatches(source).toList();
  if (matches.isNotEmpty) return matches.last.group(0)!;
  final label = node.label.trim();
  if (label.length <= 5) return label;
  return label.substring(0, 5);
}

/// Purpose: Return the icon a topology node shows.
/// Inputs: `node`; `services`, `devices` — to look up the node's own icon.
/// Returns: `IconData`.
/// Side effects: None.
/// Notes: Devices use their category icon, services their service icon,
/// endpoints, remote entries and domains a fixed icon, relays their method's.
IconData iconForTopologyNode(
  ServiceTopologyNode node,
  List<ServiceNode> services,
  List<Device> devices,
) {
  if (node.kind == ServiceTopologyNodeKind.device && node.deviceId != null) {
    final device = devices
        .where((device) => device.id == node.deviceId)
        .firstOrNull;
    return device == null
        ? Icons.devices_other_outlined
        : deviceCategoryIcon(device.category);
  }
  if (node.kind == ServiceTopologyNodeKind.service) {
    final service = services
        .where((service) => service.id == node.serviceId)
        .firstOrNull;
    return service == null ? Icons.dns_outlined : iconForService(service);
  }
  if (node.kind == ServiceTopologyNodeKind.endpoint) {
    return Icons.settings_ethernet;
  }
  if (node.kind == ServiceTopologyNodeKind.remoteEntry) return Icons.public;
  if (node.kind == ServiceTopologyNodeKind.domain) return Icons.language;
  return iconForRouteMethod(node.method);
}

/// Purpose: Return the icon of a route method.
/// Inputs: `method` — null for a route without one.
/// Returns: `IconData`.
/// Side effects: None.
/// Notes: The guided page's pattern cards use the same icons.
IconData iconForRouteMethod(ServiceRouteMethod? method) => switch (method) {
  ServiceRouteMethod.caddy => Icons.alt_route,
  ServiceRouteMethod.nginx => Icons.account_tree_outlined,
  ServiceRouteMethod.traefik => Icons.hub_outlined,
  ServiceRouteMethod.frp => Icons.swap_horiz,
  ServiceRouteMethod.cloudflareTunnel => Icons.cloud_sync,
  ServiceRouteMethod.pangolin => Icons.hub,
  ServiceRouteMethod.tailscaleFunnel => Icons.vpn_lock,
  ServiceRouteMethod.routerPortForward => Icons.router,
  ServiceRouteMethod.direct => Icons.near_me_outlined,
  ServiceRouteMethod.custom => Icons.route,
  null => Icons.route,
};

/// Purpose: Return the first method a route's hops name.
/// Inputs: `route`.
/// Returns: `ServiceRouteMethod?` — null when no hop has a method.
/// Side effects: None.
/// Notes: None.
ServiceRouteMethod? primaryRouteMethod(ServiceRoute route) => route.hops
    .map((hop) => hop.method)
    .whereType<ServiceRouteMethod>()
    .firstOrNull;

/// Purpose: Return the label of an access lane.
/// Inputs: `lane`.
/// Returns: `String` — English.
/// Side effects: None.
/// Notes: None.
String topologyLaneLabel(ServiceAccessLane lane) => switch (lane) {
  ServiceAccessLane.local => 'LAN / WiFi',
  ServiceAccessLane.vpn => 'VPN / Tailscale',
  ServiceAccessLane.public => 'Public / VPS',
};

/// Purpose: Return the label of a node's topology role.
/// Inputs: `role`.
/// Returns: `String` — English.
/// Side effects: None.
/// Notes: None.
String topologyRoleLabel(ServiceTopologyNodeRole role) => switch (role) {
  ServiceTopologyNodeRole.localDevice => 'Local device',
  ServiceTopologyNodeRole.remoteDevice => 'Remote / VPS device',
  ServiceTopologyNodeRole.localService => 'Local service',
  ServiceTopologyNodeRole.remoteService => 'Remote service',
  ServiceTopologyNodeRole.localEndpoint => 'Local endpoint',
  ServiceTopologyNodeRole.lanAccess => 'LAN / WiFi access',
  ServiceTopologyNodeRole.vpnAccess => 'VPN / Tailscale access',
  ServiceTopologyNodeRole.publicRelay => 'Public relay',
  ServiceTopologyNodeRole.remotePublicEntry => 'Remote public entry',
  ServiceTopologyNodeRole.domain => 'Domain / URL',
};

/// Purpose: Return a node card's fill colour for its role.
/// Inputs: `context`, `node`.
/// Returns: `Color` — a translucent container colour.
/// Side effects: None.
/// Notes: Local roles use primary, secondary and tertiary containers, remote
/// roles the error container.
Color _nodeFill(BuildContext context, ServiceTopologyNode node) {
  final cs = Theme.of(context).colorScheme;
  return switch (node.role) {
    ServiceTopologyNodeRole.localDevice => cs.primaryContainer.withValues(
      alpha: 0.74,
    ),
    ServiceTopologyNodeRole.remoteDevice => cs.errorContainer.withValues(
      alpha: 0.55,
    ),
    ServiceTopologyNodeRole.localService => cs.secondaryContainer.withValues(
      alpha: 0.74,
    ),
    ServiceTopologyNodeRole.remoteService => cs.errorContainer.withValues(
      alpha: 0.42,
    ),
    ServiceTopologyNodeRole.localEndpoint => cs.tertiaryContainer.withValues(
      alpha: 0.72,
    ),
    ServiceTopologyNodeRole.lanAccess => cs.tertiary.withValues(alpha: 0.14),
    ServiceTopologyNodeRole.vpnAccess => cs.secondary.withValues(alpha: 0.14),
    ServiceTopologyNodeRole.publicRelay => cs.primary.withValues(alpha: 0.13),
    ServiceTopologyNodeRole.remotePublicEntry => cs.errorContainer.withValues(
      alpha: 0.62,
    ),
    ServiceTopologyNodeRole.domain => cs.primaryContainer.withValues(
      alpha: 0.42,
    ),
  };
}

/// Purpose: Return a node card's border and icon colour for its role.
/// Inputs: `context`, `node`.
/// Returns: `Color`.
/// Side effects: None.
/// Notes: Pairs with `_nodeFill`.
Color _nodeBorder(BuildContext context, ServiceTopologyNode node) {
  final cs = Theme.of(context).colorScheme;
  return switch (node.role) {
    ServiceTopologyNodeRole.localDevice => cs.primary,
    ServiceTopologyNodeRole.remoteDevice => cs.error,
    ServiceTopologyNodeRole.localService => cs.secondary,
    ServiceTopologyNodeRole.remoteService => cs.error,
    ServiceTopologyNodeRole.localEndpoint => cs.tertiary,
    ServiceTopologyNodeRole.lanAccess => cs.tertiary,
    ServiceTopologyNodeRole.vpnAccess => cs.secondary,
    ServiceTopologyNodeRole.publicRelay => cs.primary,
    ServiceTopologyNodeRole.remotePublicEntry => cs.error,
    ServiceTopologyNodeRole.domain => cs.primary,
  };
}

/// Purpose: Map a stored service icon name to its Material icon.
/// Inputs: `icon` — the `ServiceNode.icon` or template icon name.
/// Returns: `IconData` — `Icons.dns` for an unknown or missing name.
/// Side effects: None.
/// Notes: Shared by the service list, the service editor and its template
/// picker, the guided access-path page and the topology.
IconData iconForServiceIcon(String? icon) => switch (icon) {
  'code' => Icons.code,
  'terminal' => Icons.terminal,
  'sports_esports' => Icons.sports_esports,
  'edit_document' => Icons.edit_document,
  'source' => Icons.source,
  'folder' => Icons.folder,
  'keyboard_alt' => Icons.keyboard_alt,
  'cloud' => Icons.cloud,
  'password' => Icons.password,
  'smart_toy' => Icons.smart_toy,
  'theaters' => Icons.theaters,
  'article' => Icons.article,
  'hub' => Icons.hub,
  'download' => Icons.download,
  'router' => Icons.router,
  'shield' => Icons.shield,
  'alt_route' => Icons.alt_route,
  'swap_horiz' => Icons.swap_horiz,
  'cloud_sync' => Icons.cloud_sync,
  'deployed_code' => Icons.inventory_2,
  'home' => Icons.home,
  'photo_library' => Icons.photo_library,
  'movie' => Icons.movie,
  'sync' => Icons.sync,
  'inventory_2' => Icons.inventory_2,
  'database' => Icons.storage,
  'monitoring' => Icons.analytics,
  'monitor_heart' => Icons.monitor_heart,
  'memory' => Icons.memory,
  'science' => Icons.science,
  'desktop_windows' => Icons.desktop_windows,
  'vpn_lock' => Icons.vpn_lock,
  'folder_shared' => Icons.folder_shared,
  'music_note' => Icons.music_note,
  'search' => Icons.search,
  'menu_book' => Icons.menu_book,
  'payments' => Icons.payments,
  'sticky_note_2' => Icons.sticky_note_2,
  'precision_manufacturing' => Icons.precision_manufacturing,
  'rss_feed' => Icons.rss_feed,
  'fact_check' => Icons.fact_check,
  'view_kanban' => Icons.view_kanban,
  _ => Icons.dns,
};

/// Purpose: Return a service's icon.
/// Inputs: `service`.
/// Returns: `IconData`.
/// Side effects: None.
/// Notes: `iconForServiceIcon` of the service's icon name.
IconData iconForService(ServiceNode service) =>
    iconForServiceIcon(service.icon);
