import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../devices/models/device.dart';
import '../../devices/widgets/device_category_icon.dart';
import '../models/service.dart';
import '../services/service_analysis.dart';
import '../services/service_labels.dart';
import '../services/service_topology_layout.dart';

/// Opacity of a node card a selection leaves out: low enough that the lit
/// route reads at a glance, high enough that the rest stays legible and
/// tappable.
const topologyDimmedNodeOpacity = 0.35;

/// Alpha of an edge a selection leaves out. Edges are drawn at 0.62 without a
/// selection and at full alpha when lit.
const topologyDimmedEdgeAlpha = 0.18;

/// One node of the topology canvas: a full card, or a small port chip for
/// compact nodes (endpoints and remote entries).
class ServiceTopologyNodeCard extends StatelessWidget {
  final ServiceTopologyNode node;
  final IconData icon;
  final VoidCallback? onTap;

  /// Whether this is the selected node, drawn with a heavier border.
  final bool selected;

  /// Whether a selection leaves this node out, drawn faded.
  final bool dimmed;

  /// Purpose: Create a topology node card.
  /// Inputs: `node`; `icon` — from `iconForTopologyNode`; `onTap` — null in move
  /// mode, so the card does not take the pan gesture; `selected`; `dimmed`.
  /// Returns: A new `ServiceTopologyNodeCard`.
  /// Side effects: None.
  /// Notes: The layout sizes the card; it fills the rect it is given.
  const ServiceTopologyNodeCard({
    super.key,
    required this.node,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.dimmed = false,
  });

  /// Purpose: Build the card or chip with its semantics and dimming.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Screen readers hear one label — the node's label, its localized
  /// role and, when it has one, its lane — plus its selected state and a tap
  /// action in select mode.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final lane = node.lane == null
        ? null
        : serviceAccessLaneLabel(l10n, node.lane!);
    final border = _roleBorder(cs, node.role);
    return Semantics(
      container: true,
      label: [
        node.label,
        serviceTopologyRoleLabel(l10n, node.role),
        lane,
      ].whereType<String>().join(', '),
      button: onTap != null,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: dimmed ? topologyDimmedNodeOpacity : 1,
        child: node.compact
            ? _buildChip(context, cs, border, lane)
            : _buildCard(context, cs, border, lane),
      ),
    );
  }

  /// Purpose: Build the small port chip of a compact node.
  /// Inputs: `context`, `cs`, `border` — the role colour, `lane` — the
  /// localized lane label or null.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Shows the icon over `_compactTopologyLabel`; the tooltip carries
  /// the full label, detail and lane.
  Widget _buildChip(
    BuildContext context,
    ColorScheme cs,
    Color border,
    String? lane,
  ) {
    return Tooltip(
      message: [node.label, node.detail, lane].whereType<String>().join('\n'),
      child: SizedBox.square(
        dimension: ServiceTopologyLayout.portChipSize,
        child: Card(
          margin: EdgeInsets.zero,
          color: _roleFill(cs, node.role),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: border, width: selected ? 2.4 : 1.2),
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

  /// Purpose: Build the full card of a regular node.
  /// Inputs: `context`, `cs`, `border` — the role colour, `lane` — the
  /// localized lane label or null.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Icon avatar, label, and a subtitle of `_nodeSubtitle` and the lane.
  Widget _buildCard(
    BuildContext context,
    ColorScheme cs,
    Color border,
    String? lane,
  ) {
    final subtitle = _nodeSubtitle(context, node);
    return Tooltip(
      message: [node.label, node.detail].whereType<String>().join('\n'),
      child: Card(
        margin: EdgeInsets.zero,
        color: _roleFill(cs, node.role),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: selected ? 3 : 1.4),
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
                      if (subtitle != null || lane != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [subtitle, lane].whereType<String>().join(' · '),
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

  /// What the current selection lights up; null when nothing is selected.
  final ServiceTopologyHighlight? highlight;

  /// Purpose: Create the edge painter.
  /// Inputs: `graph`; `layout` — supplies each edge's routed polyline;
  /// `colorScheme` — the lane colours; `highlight` — the selection's lit
  /// edges, or null.
  /// Returns: A new `ServiceTopologyEdgePainter`.
  /// Side effects: None.
  /// Notes: None.
  const ServiceTopologyEdgePainter({
    required this.graph,
    required this.layout,
    required this.colorScheme,
    this.highlight,
  });

  /// Purpose: Paint every edge that has a routed path.
  /// Inputs: `canvas`, `size`.
  /// Returns: None.
  /// Side effects: Draws on the canvas.
  /// Notes: Without a selection every edge is drawn at 0.62 alpha and 2.2
  /// wide. With one, the edges it leaves out are drawn first at
  /// [topologyDimmedEdgeAlpha], then the lit edges on top at full alpha and
  /// 3.0 wide, so a lit route is never hidden under a faded one.
  @override
  void paint(Canvas canvas, Size size) {
    final lit = highlight?.edges;
    if (lit == null) {
      for (final edge in graph.edges) {
        _paintEdge(canvas, edge, alpha: 0.62, width: 2.2);
      }
      return;
    }
    for (final edge in graph.edges) {
      if (!lit.contains(edge)) {
        _paintEdge(canvas, edge, alpha: topologyDimmedEdgeAlpha, width: 2.2);
      }
    }
    for (final edge in graph.edges) {
      if (lit.contains(edge)) _paintEdge(canvas, edge, alpha: 1, width: 3);
    }
  }

  /// Purpose: Paint one edge's routed path in its lane colour.
  /// Inputs: `canvas`, `edge`, `alpha`, `width`.
  /// Returns: `void`.
  /// Side effects: Draws on the canvas.
  /// Notes: Edges without a path of at least two points are skipped.
  void _paintEdge(
    Canvas canvas,
    ServiceTopologyEdge edge, {
    required double alpha,
    required double width,
  }) {
    final points = layout.edgePaths[edge];
    if (points == null || points.length < 2) return;
    final paint = Paint()
      ..color = _edgeColor(edge).withValues(alpha: alpha)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _drawPolyline(canvas, paint, points);
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
  /// Returns: `Color` — [serviceAccessLaneColor] of its lane, the outline
  /// colour for a structural edge without one.
  /// Side effects: None.
  /// Notes: The legend draws its lane samples with the same function.
  Color _edgeColor(ServiceTopologyEdge edge) {
    final lane = edge.lane;
    return lane == null
        ? colorScheme.outline
        : serviceAccessLaneColor(colorScheme, lane);
  }

  /// Purpose: Report whether the edges must be repainted.
  /// Inputs: `oldDelegate`.
  /// Returns: `bool` — true when the graph, layout, colour scheme or
  /// highlight changed.
  /// Side effects: None.
  /// Notes: The page memoizes the highlight, so an unchanged selection keeps
  /// its instance and does not repaint.
  @override
  bool shouldRepaint(covariant ServiceTopologyEdgePainter oldDelegate) =>
      oldDelegate.graph != graph ||
      oldDelegate.layout != layout ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.highlight != highlight;
}

/// Purpose: Return the colour the topology uses for an access lane.
/// Inputs: `cs` — the colour scheme; `lane`.
/// Returns: `Color` — local tertiary, VPN secondary, public primary.
/// Side effects: None.
/// Notes: Shared by the edge painter, the legend and the guided access-path
/// page's preview, so a lane looks the same everywhere.
Color serviceAccessLaneColor(ColorScheme cs, ServiceAccessLane lane) =>
    switch (lane) {
      ServiceAccessLane.local => cs.tertiary,
      ServiceAccessLane.vpn => cs.secondary,
      ServiceAccessLane.public => cs.primary,
    };

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

/// Purpose: Return the fill colour of a node role.
/// Inputs: `cs` — the colour scheme; `role`.
/// Returns: `Color` — a translucent container colour.
/// Side effects: None.
/// Notes: Local roles use primary, secondary and tertiary containers, remote
/// roles the error container. The node cards and the legend's swatches share
/// it.
Color _roleFill(ColorScheme cs, ServiceTopologyNodeRole role) {
  return switch (role) {
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

/// Purpose: Return the border and icon colour of a node role.
/// Inputs: `cs` — the colour scheme; `role`.
/// Returns: `Color`.
/// Side effects: None.
/// Notes: Pairs with `_roleFill`.
Color _roleBorder(ColorScheme cs, ServiceTopologyNodeRole role) {
  return switch (role) {
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

/// The key to the topology's colours: the three lanes' line samples and the
/// fill and border of the six node roles a reader meets most, drawn with the
/// same functions as the edges and cards.
///
/// Shown by the topology page in a collapsible strip outside the canvas, so
/// it is never part of the PNG export.
class ServiceTopologyLegend extends StatelessWidget {
  /// The roles the legend explains, in reading order: the local side, then
  /// the remote side, then the destination.
  static const roles = [
    ServiceTopologyNodeRole.localDevice,
    ServiceTopologyNodeRole.localService,
    ServiceTopologyNodeRole.localEndpoint,
    ServiceTopologyNodeRole.remoteDevice,
    ServiceTopologyNodeRole.remotePublicEntry,
    ServiceTopologyNodeRole.domain,
  ];

  /// Purpose: Create the legend.
  /// Inputs: None.
  /// Returns: A new `ServiceTopologyLegend`.
  /// Side effects: None.
  /// Notes: None.
  const ServiceTopologyLegend({super.key});

  /// Purpose: Build the legend as a wrap of lane samples and role swatches.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Port-chip roles get a squarer swatch than card roles, as on the
  /// canvas.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final lane in ServiceAccessLane.values)
          _entry(
            context,
            Container(
              width: 22,
              height: 3,
              decoration: BoxDecoration(
                color: serviceAccessLaneColor(cs, lane),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            serviceAccessLaneLabel(l10n, lane),
          ),
        for (final role in roles)
          _entry(
            context,
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _roleFill(cs, role),
                border: Border.all(color: _roleBorder(cs, role), width: 1.4),
                borderRadius: BorderRadius.circular(
                  role == ServiceTopologyNodeRole.localEndpoint ||
                          role == ServiceTopologyNodeRole.remotePublicEntry
                      ? 4
                      : 7,
                ),
              ),
            ),
            serviceTopologyRoleLabel(l10n, role),
          ),
      ],
    );
  }

  /// Purpose: Build one legend entry: a swatch and its label.
  /// Inputs: `context`, `swatch`, `label`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper of [build].
  Widget _entry(BuildContext context, Widget swatch, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      swatch,
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

/// Purpose: Compute the transform that fits a canvas into a viewer.
/// Inputs: `canvas` — the child as the viewer lays it out (turned when the
/// canvas is rotated); `viewport` — the viewer's size; `minScale`,
/// `maxScale` — the viewer's zoom limits; `boundaryMargin` — the viewer's
/// margin around the child.
/// Returns: `Matrix4` — a uniform scale (on all three axes, as the viewer's
/// own zoom writes it, so `getMaxScaleOnAxis` reads it back) and a
/// translation for the viewer's `TransformationController`; the identity for
/// an empty canvas or viewport.
/// Side effects: None.
/// Notes: The scale is the smaller of the two axis ratios clamped to the
/// limits, so the whole graph shows whenever the limits allow. On an axis the
/// scaled canvas leaves room on, it is centred if that keeps the viewport
/// inside the child plus `boundaryMargin`, and placed at the start otherwise
/// — an `InteractiveViewer` snaps an out-of-bounds offset back to the start
/// on the next pan, so centring there would only make the graph jump.
Matrix4 fitTransform(
  Size canvas,
  Size viewport, {
  required double minScale,
  required double maxScale,
  double boundaryMargin = 0,
}) {
  if (canvas.isEmpty || viewport.isEmpty) return Matrix4.identity();
  final scale = math
      .min(viewport.width / canvas.width, viewport.height / canvas.height)
      .clamp(minScale, maxScale)
      .toDouble();

  /// Purpose: Return the offset of the scaled canvas on one axis.
  /// Inputs: `view` — the viewport's extent; `child` — the canvas's extent.
  /// Returns: `double`.
  /// Side effects: None.
  /// Notes: Local helper of [fitTransform].
  double offset(double view, double child) {
    final free = view - child * scale;
    if (free <= 0) return 0;
    final centred = free / 2;
    return centred <= boundaryMargin * scale ? centred : 0;
  }

  return Matrix4.diagonal3Values(scale, scale, scale)..setTranslationRaw(
    offset(viewport.width, canvas.width),
    offset(viewport.height, canvas.height),
    0,
  );
}
