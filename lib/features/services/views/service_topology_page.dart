import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_share_service.dart';
import '../../devices/models/device.dart';
import '../../devices/widgets/device_category_icon.dart';
import '../models/service.dart';
import '../services/service_access_patterns.dart';
import '../services/service_analysis.dart';
import '../services/service_labels.dart';
import '../services/service_topology_layout.dart';
import 'service_topology_widgets.dart';

enum _TopologyInteractionMode { select, move }

class _ServiceTopologyView extends StatefulWidget {
  final ServiceTopologyGraph graph;
  final List<ServiceNode> services;
  final List<Device> devices;
  final List<ServiceRoute> routes;
  final ValueChanged<ServiceNode> onEditService;
  final ValueChanged<ServiceRoute> onEditRoute;
  final Future<void> Function({ServiceAccessDraft? draft}) onAddAccess;
  final _TopologyInteractionMode mode;
  final int quarterTurns;
  final GlobalKey? repaintBoundaryKey;
  final ValueChanged<bool>? onLayoutReadyChanged;

  /// Purpose: Create a service topology view instance.
  /// Inputs: `graph`, service data, callbacks, `mode`, rotation, and optional capture/layout callbacks.
  /// Returns: A new `_ServiceTopologyView` instance.
  /// Side effects: None.
  /// Notes: The associated state object caches expensive topology layouts.
  const _ServiceTopologyView({
    required this.graph,
    required this.services,
    required this.devices,
    required this.routes,
    required this.onEditService,
    required this.onEditRoute,
    required this.onAddAccess,
    this.mode = _TopologyInteractionMode.select,
    this.quarterTurns = 0,
    this.repaintBoundaryKey,
    this.onLayoutReadyChanged,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `_ServiceTopologyViewState` instance.
  /// Side effects: None.
  /// Notes: The state defers layout work until after the route can paint.
  @override
  State<_ServiceTopologyView> createState() => _ServiceTopologyViewState();
}

class _ServiceTopologyViewState extends State<_ServiceTopologyView> {
  ServiceTopologyLayout? _layout;
  _TopologyLayoutRequest? _completedRequest;
  _TopologyLayoutRequest? _pendingRequest;
  bool? _reportedLayoutReady;
  int _layoutGeneration = 0;

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Schedules asynchronous layout work when viewport inputs change.
  /// Notes: Keeps expensive topology layout out of the first synchronous page build.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final turns = widget.quarterTurns % 4;
        final viewportWidth = turns.isOdd && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : constraints.maxWidth;
        final request = _TopologyLayoutRequest(
          graph: widget.graph,
          routes: widget.routes,
          viewportWidth: viewportWidth.round(),
        );
        final ready = _completedRequest == request && _layout != null;
        if (!ready) _ensureLayout(request);
        _reportLayoutReady(ready);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: ready
                ? _buildViewer(context, _layout!, turns)
                : _buildLoading(),
          ),
        );
      },
    );
  }

  /// Purpose: Schedule layout computation for the requested topology inputs.
  /// Inputs: `request`.
  /// Returns: None.
  /// Side effects: Updates cached layout state after asynchronous computation finishes.
  /// Notes: Multiple rebuilds for the same request share one pending computation.
  void _ensureLayout(_TopologyLayoutRequest request) {
    if (_pendingRequest == request) return;
    _pendingRequest = request;
    final generation = ++_layoutGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateLayout(request, generation);
    });
  }

  /// Purpose: Calculate and cache a topology layout for one request.
  /// Inputs: `request`, `generation`.
  /// Returns: None.
  /// Side effects: Updates widget state and triggers a rebuild when still current.
  /// Notes: Runs after the first frame so the topology page can show immediately.
  Future<void> _calculateLayout(
    _TopologyLayoutRequest request,
    int generation,
  ) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted ||
        generation != _layoutGeneration ||
        _pendingRequest != request) {
      return;
    }
    final layout = ServiceTopologyLayout.build(
      request.graph,
      request.routes,
      request.viewportWidth.toDouble(),
    );
    if (!mounted ||
        generation != _layoutGeneration ||
        _pendingRequest != request) {
      return;
    }
    setState(() {
      _layout = layout;
      _completedRequest = request;
      _pendingRequest = null;
    });
  }

  /// Purpose: Build the loading placeholder shown while topology layout is calculated.
  /// Inputs: None.
  /// Returns: A lightweight loading widget.
  /// Side effects: None.
  /// Notes: Avoids heavy work in the first route transition frame.
  Widget _buildLoading() {
    return const Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.6),
      ),
    );
  }

  /// Purpose: Report whether the current topology layout can be captured or exported.
  /// Inputs: `ready`.
  /// Returns: None.
  /// Side effects: Calls the parent readiness callback after the current frame.
  /// Notes: The callback is deferred so build remains side-effect-free.
  void _reportLayoutReady(bool ready) {
    if (_reportedLayoutReady == ready) return;
    _reportedLayoutReady = ready;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onLayoutReadyChanged?.call(ready);
    });
  }

  /// Purpose: Build and return viewer for the current context.
  /// Inputs: `context`, `layout`, `turns`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildViewer(
    BuildContext context,
    ServiceTopologyLayout layout,
    int turns,
  ) {
    Widget canvas = SizedBox.fromSize(
      size: layout.size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: ServiceTopologyEdgePainter(
                graph: widget.graph,
                layout: layout,
                colorScheme: Theme.of(context).colorScheme,
              ),
            ),
          ),
          for (final node in widget.graph.nodes)
            if (layout.nodeRects[node.id] != null)
              Positioned.fromRect(
                rect: layout.nodeRects[node.id]!,
                child: ServiceTopologyNodeCard(
                  node: node,
                  icon: iconForTopologyNode(
                    node,
                    widget.services,
                    widget.devices,
                  ),
                  onTap: widget.mode == _TopologyInteractionMode.select
                      ? () => _showNodeDetails(context, node)
                      : null,
                ),
              ),
        ],
      ),
    );
    if (turns != 0) {
      canvas = RotatedBox(quarterTurns: turns, child: canvas);
    }
    if (widget.repaintBoundaryKey != null) {
      canvas = RepaintBoundary(key: widget.repaintBoundaryKey, child: canvas);
    }
    if (widget.mode == _TopologyInteractionMode.select) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(child: canvas),
      );
    }
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(180),
      minScale: 0.35,
      maxScale: 2.4,
      child: canvas,
    );
  }

  /// Purpose: Show node details in the current UI flow.
  /// Inputs: `context`, `node`.
  /// Returns: `void`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  void _showNodeDetails(BuildContext context, ServiceTopologyNode node) {
    final device = node.deviceId == null
        ? null
        : widget.devices
              .where((device) => device.id == node.deviceId)
              .firstOrNull;
    final service = node.serviceId == null
        ? null
        : widget.services
              .where((service) => service.id == node.serviceId)
              .firstOrNull;
    final relatedRoutes = relatedRoutesForNode(
      node,
      widget.routes,
      services: widget.services,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Icon(
                    iconForTopologyNode(node, widget.services, widget.devices),
                  ),
                ),
                title: Text(node.label),
                subtitle: Text(
                  [
                    topologyRoleLabel(node.role),
                    if (node.detail?.trim().isNotEmpty == true) node.detail,
                    if (node.lane != null) topologyLaneLabel(node.lane!),
                  ].whereType<String>().join(' · '),
                ),
              ),
              if (device != null)
                ListTile(
                  leading: Icon(deviceCategoryIcon(device.category)),
                  title: Text(device.name),
                  subtitle: Text(device.category.name),
                ),
              if (service != null) ...[
                ListTile(
                  leading: Icon(iconForService(service)),
                  title: Text(service.name),
                  subtitle: Text(
                    service.endpoints
                        .map(
                          (endpoint) =>
                              '${endpoint.protocol.name}/${endpoint.portText}',
                        )
                        .join(', '),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.onEditService(service);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(AppLocalizations.of(context)!.editService),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        widget.onAddAccess(
                          draft: ServiceAccessDraft(
                            sourceServiceId: service.id,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_link),
                      label: Text(
                        AppLocalizations.of(context)!.serviceAddAccess,
                      ),
                    ),
                  ],
                ),
              ],
              if (relatedRoutes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.serviceRoutes,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final route in relatedRoutes)
                  ListTile(
                    leading: Icon(
                      iconForRouteMethod(primaryRouteMethod(route)),
                    ),
                    title: Text(serviceRouteDisplayTarget(route)),
                    subtitle: Text(
                      [
                        serviceRouteTargetsSummary(route),
                        serviceAccessLevelLabel(
                          AppLocalizations.of(context)!,
                          route.accessLevel,
                        ),
                        topologyLaneLabel(serviceAccessLaneForRoute(route)),
                      ].where((part) => part.isNotEmpty).join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      widget.onEditRoute(route);
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TopologyLayoutRequest {
  final ServiceTopologyGraph graph;
  final List<ServiceRoute> routes;
  final int viewportWidth;

  /// Purpose: Create a topology layout request cache key.
  /// Inputs: `graph`, `routes`, `viewportWidth`.
  /// Returns: A new `_TopologyLayoutRequest` instance.
  /// Side effects: None.
  /// Notes: Uses graph and route list identity so mode-only rebuilds reuse the cached layout.
  const _TopologyLayoutRequest({
    required this.graph,
    required this.routes,
    required this.viewportWidth,
  });

  /// Purpose: Compare layout request keys for cache reuse.
  /// Inputs: `other`.
  /// Returns: Whether both requests describe the same layout inputs.
  /// Side effects: None.
  /// Notes: Viewport width is rounded to avoid tiny constraint jitter causing re-layout.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TopologyLayoutRequest &&
          identical(other.graph, graph) &&
          identical(other.routes, routes) &&
          other.viewportWidth == viewportWidth;

  /// Purpose: Produce a hash for the layout request cache key.
  /// Inputs: None.
  /// Returns: An integer hash code.
  /// Side effects: None.
  /// Notes: Matches the equality contract for graph identity, route identity, and viewport width.
  @override
  int get hashCode => Object.hash(
    identityHashCode(graph),
    identityHashCode(routes),
    viewportWidth,
  );
}

/// The full-screen service topology: the graph with a select and a move
/// mode, rotation, and PNG export.
///
/// Pushed on the root navigator by the Services overview's topology card with
/// a graph built from the current inventory.
class ServiceTopologyPage extends StatefulWidget {
  final ServiceTopologyGraph graph;
  final List<ServiceNode> services;
  final List<Device> devices;
  final List<ServiceRoute> routes;
  final ValueChanged<ServiceNode> onEditService;
  final ValueChanged<ServiceRoute> onEditRoute;
  final Future<void> Function({ServiceAccessDraft? draft}) onAddAccess;

  /// Purpose: Create the full-screen topology page.
  /// Inputs: `graph` — the topology of `services`, `routes` and `devices`;
  /// `onEditService`, `onEditRoute`, `onAddAccess` — the Services page's editors,
  /// offered from the node details.
  /// Returns: A new `ServiceTopologyPage`.
  /// Side effects: None.
  /// Notes: The page never writes storage itself; the callbacks do.
  const ServiceTopologyPage({
    super.key,
    required this.graph,
    required this.services,
    required this.devices,
    required this.routes,
    required this.onEditService,
    required this.onEditRoute,
    required this.onAddAccess,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `_ServiceTopologyPageState`.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<ServiceTopologyPage> createState() => _ServiceTopologyPageState();
}

class _ServiceTopologyPageState extends State<ServiceTopologyPage> {
  _TopologyInteractionMode _mode = _TopologyInteractionMode.select;
  final _captureKey = GlobalKey();
  int _quarterTurns = 0;
  bool _exporting = false;
  bool _layoutReady = false;

  /// Purpose: Export topology image to an external representation.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _exportTopologyImage() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_layoutReady) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.serviceTopology)));
      return;
    }
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Topology image boundary is not available.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        throw StateError('Topology image encoding failed.');
      }
      if (!mounted) return;
      await ImageShareService.sharePngBytes(
        context,
        bytes,
        fileName: 'mydevice_topology.png',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state. Updates widget state and triggers a rebuild.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serviceTopology),
        actions: [
          IconButton(
            tooltip: l10n.serviceRotateTopology,
            onPressed: () {
              setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
            },
            icon: const Icon(Icons.screen_rotation_alt),
          ),
          IconButton(
            tooltip: l10n.serviceExportTopologyImage,
            onPressed: _exporting || !_layoutReady
                ? null
                : _exportTopologyImage,
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<_TopologyInteractionMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _TopologyInteractionMode.select,
                  icon: const Icon(Icons.touch_app),
                  label: Text(l10n.serviceTopologySelectMode),
                ),
                ButtonSegment(
                  value: _TopologyInteractionMode.move,
                  icon: const Icon(Icons.open_with),
                  label: Text(l10n.serviceTopologyMoveMode),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selected) {
                setState(() => _mode = selected.single);
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _ServiceTopologyView(
                graph: widget.graph,
                services: widget.services,
                devices: widget.devices,
                routes: widget.routes,
                onEditService: widget.onEditService,
                onEditRoute: widget.onEditRoute,
                onAddAccess: widget.onAddAccess,
                mode: _mode,
                quarterTurns: _quarterTurns,
                repaintBoundaryKey: _captureKey,
                onLayoutReadyChanged: (ready) {
                  if (_layoutReady == ready) return;
                  setState(() => _layoutReady = ready);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
