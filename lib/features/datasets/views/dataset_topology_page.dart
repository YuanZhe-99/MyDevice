import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_share_service.dart';
import '../../../shared/utils/detail_layout.dart';
import '../../../shared/widgets/topology_canvas_viewer.dart';
import '../../devices/models/device.dart';
import '../../devices/widgets/device_category_icon.dart';
import '../../services/views/service_topology_widgets.dart'
    show topologyDimmedEdgeAlpha, topologyDimmedNodeOpacity;
import '../models/dataset.dart';
import '../services/dataset_placement.dart';
import '../services/dataset_topology.dart';

/// The data sets and devices the topology draws; what `reload` returns.
typedef DataSetTopologyInventory = ({
  List<DataSet> dataSets,
  List<Device> devices,
});

/// Purpose: Pick the colour of a data set's copies and sync lines.
/// Inputs: `cs`; `dataSetId`.
/// Returns: `Color` — one of a fixed palette, chosen by a stable hash of the
/// id, so a data set keeps its colour across launches and devices.
/// Side effects: None.
/// Notes: The palette avoids the error colour, which marks single copies.
Color dataSetTopologyColor(ColorScheme cs, String dataSetId) {
  final palette = [
    cs.primary,
    cs.tertiary,
    Colors.teal,
    Colors.indigo,
    Colors.orange.shade700,
    Colors.pink,
    Colors.green.shade700,
    Colors.purple,
  ];
  var hash = 0;
  for (final unit in dataSetId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

/// The full-screen data set topology: devices as large boxes, their
/// storages inside, and each data set's copies inside the storages, with a
/// sync line between copies of the same data set.
class DataSetTopologyPage extends StatefulWidget {
  final List<DataSet> dataSets;
  final List<Device> devices;
  final Future<void> Function(DataSet dataSet) onEditDataSet;

  /// Reads the data again after the editor has closed; null keeps the data
  /// the page was opened with.
  final Future<DataSetTopologyInventory> Function()? reload;

  /// Purpose: Create the page.
  /// Inputs: `dataSets`, `devices`; `onEditDataSet` — opens the data set
  /// editor, completing when it has closed; `reload` — the current data.
  /// Returns: A new `DataSetTopologyPage`.
  /// Side effects: None.
  /// Notes: The page never writes storage itself.
  const DataSetTopologyPage({
    super.key,
    required this.dataSets,
    required this.devices,
    required this.onEditDataSet,
    this.reload,
  });

  /// Purpose: Create the mutable state object.
  /// Inputs: None.
  /// Returns: A new `_DataSetTopologyPageState`.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<DataSetTopologyPage> createState() => _DataSetTopologyPageState();
}

class _DataSetTopologyPageState extends State<DataSetTopologyPage> {
  late List<DataSet> _dataSets = widget.dataSets;
  late List<Device> _devices = widget.devices;
  final _transform = TransformationController();
  final _viewerKey = GlobalKey<TopologyCanvasViewerState>();
  final _captureKey = GlobalKey();
  Set<String> _deviceFilter = const {};
  bool _showEmpty = false;

  /// Whether the sync lines are drawn; off by default so the boxes read
  /// cleanly, and only a repaint when toggled.
  bool _showLinks = false;
  bool _legendOpen = false;
  bool _exporting = false;
  String? _selectedId;

  /// The last layout and the inputs it was built for.
  ({
    List<DataSet> dataSets,
    List<Device> devices,
    Set<String> filter,
    bool showEmpty,
    DataSetTopologyLayout layout,
  })?
  _cache;

  /// Purpose: Release the transformation controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controller.
  /// Notes: None.
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Purpose: Return the layout, reusing the last one.
  /// Inputs: None.
  /// Returns: `DataSetTopologyLayout`.
  /// Side effects: Caches the layout in `_cache`.
  /// Notes: Keyed by data identity, the filter and the empty-device switch,
  /// so a selection, the line switch or a window resize only repaints — the
  /// layout aims at a square-to-16:10 canvas, not the window width.
  DataSetTopologyLayout _layout() {
    final c = _cache;
    if (c != null &&
        identical(c.dataSets, _dataSets) &&
        identical(c.devices, _devices) &&
        identical(c.filter, _deviceFilter) &&
        c.showEmpty == _showEmpty) {
      return c.layout;
    }
    final layout = DataSetTopologyLayout.build(
      devices: _devices,
      dataSets: _dataSets,
      deviceIds: _deviceFilter,
      showEmptyDevices: _showEmpty,
    );
    _cache = (
      dataSets: _dataSets,
      devices: _devices,
      filter: _deviceFilter,
      showEmpty: _showEmpty,
      layout: layout,
    );
    return layout;
  }

  /// Purpose: Select a tapped box.
  /// Inputs: `node`.
  /// Returns: `void`.
  /// Side effects: Updates the selection; without a details pane, opens the
  /// details sheet.
  /// Notes: The selection lives in the page, so the highlight stays after the
  /// sheet closes.
  void _select(DataSetTopologyNode node) {
    setState(() => _selectedId = node.id);
    final size = MediaQuery.sizeOf(context);
    if (!useDetailTwoPane(size.width, size.height)) _showDetailsSheet(node);
  }

  /// Purpose: Clear the selection.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Updates widget state.
  /// Notes: Called from a tap on empty canvas, the chip and the pane's close
  /// button.
  void _clearSelection() {
    if (_selectedId == null) return;
    setState(() => _selectedId = null);
  }

  /// Purpose: Open the editor for a data set, then refresh.
  /// Inputs: `ds`.
  /// Returns: `Future<void>`.
  /// Side effects: Awaits `onEditDataSet`; then `reload`, replacing the data.
  /// Notes: A box the edit removed is simply no longer selected.
  Future<void> _edit(DataSet ds) async {
    await widget.onEditDataSet(ds);
    final reload = widget.reload;
    if (reload == null) return;
    final data = await reload();
    if (!mounted) return;
    setState(() {
      _dataSets = data.dataSets;
      _devices = data.devices;
    });
  }

  /// Purpose: Show a box's details in a bottom sheet.
  /// Inputs: `node`.
  /// Returns: `void`.
  /// Side effects: Shows a modal bottom sheet.
  /// Notes: Used where the window has no room for the details pane.
  void _showDetailsSheet(DataSetTopologyNode node) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: _DataSetTopologyDetails(
          key: const Key('dataset-topology-details-sheet'),
          node: node,
          dataSets: _dataSets,
          devices: _devices,
          shrinkWrap: true,
          onEdit: (ds) {
            Navigator.pop(sheetContext);
            _edit(ds);
          },
        ),
      ),
    );
  }

  /// Purpose: Open the device filter sheet.
  /// Inputs: None.
  /// Returns: `Future<void>` that completes when the sheet closes.
  /// Side effects: Shows a modal bottom sheet whose changes apply live.
  /// Notes: Lists the devices with at least one storage slot.
  Future<void> _openFilters() {
    final l10n = AppLocalizations.of(context)!;
    final candidates = [
      for (final device in _devices)
        if (device.storage.isNotEmpty) device,
    ];
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          /// Purpose: Apply a new device filter to the page and the sheet.
          /// Inputs: `ids`.
          /// Returns: `void`.
          /// Side effects: Updates page and sheet state; resets the transform.
          /// Notes: Local helper of [_openFilters].
          void apply(Set<String> ids) {
            setState(() => _deviceFilter = ids);
            setSheet(() {});
            _transform.value = Matrix4.identity();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.serviceTopologyFilterDevices,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        key: const Key('dataset-topology-filter-all'),
                        label: Text(l10n.serviceTopologyFilterAllDevices),
                        selected: _deviceFilter.isEmpty,
                        onSelected: (_) => apply(const {}),
                      ),
                      for (final device in candidates)
                        FilterChip(
                          key: ValueKey(
                            'dataset-topology-filter-device-${device.id}',
                          ),
                          avatar: Icon(deviceCategoryIcon(device.category)),
                          label: Text(device.name),
                          selected: _deviceFilter.contains(device.id),
                          onSelected: (on) {
                            final next = {..._deviceFilter};
                            on ? next.add(device.id) : next.remove(device.id);
                            apply(next);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Purpose: Export the canvas as a PNG through the platform share flow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Renders the repaint boundary; shares the PNG; shows a
  /// snackbar on failure.
  /// Notes: The capture includes the highlight, not the legend or the pane.
  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('No topology boundary.');
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data?.buffer.asUint8List();
      if (bytes == null) throw StateError('PNG encoding failed.');
      if (!mounted) return;
      await ImageShareService.sharePngBytes(
        context,
        bytes,
        fileName: 'mydevice_dataset_topology.png',
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

  /// Purpose: Build the page.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: Fills the layout cache.
  /// Notes: App bar: filter (badge with the device count), the sync-line toggle
  /// (off by default), the "show
  /// devices without data sets" toggle, export. Body: view controls, legend
  /// strip, canvas; the details pane on split windows, always present so a
  /// selection never changes the canvas width.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final twoPane = useDetailTwoPane(size.width, size.height);
    final canvas = Builder(
      builder: (context) {
        final layout = _layout();
        if (layout.isEmpty) {
          return Center(
            key: const Key('dataset-topology-empty'),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.dataSetTopologyEmpty,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final selected = _selectedId == null ? null : layout.node(_selectedId!);
        final highlight = selected == null
            ? null
            : layout.highlightFor(selected.id);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: TopologyCanvasViewer(
              key: _viewerKey,
              canvasSize: layout.size,
              controller: _transform,
              onBackgroundTap: _clearSelection,
              child: RepaintBoundary(
                key: _captureKey,
                child: _DataSetTopologyCanvas(
                  layout: layout,
                  highlight: highlight,
                  showLinks: _showLinks,
                  onTap: _select,
                ),
              ),
            ),
          ),
        );
      },
    );
    final selectedNode = _selectedId == null
        ? null
        : _cache?.layout.node(_selectedId!);
    final column = Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
          child: TopologyViewControls(
            onZoomOut: () =>
                _viewerKey.currentState?.zoomBy(1 / topologyZoomStep),
            onZoomIn: () => _viewerKey.currentState?.zoomBy(topologyZoomStep),
            onFit: () => _viewerKey.currentState?.fit(),
            onReset: () => _transform.value = Matrix4.identity(),
          ),
        ),
        _buildLegendStrip(l10n, selectedNode),
        Expanded(
          child: Padding(padding: const EdgeInsets.all(12), child: canvas),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dataSetTopology),
        actions: [
          IconButton(
            key: const Key('dataset-topology-filter'),
            tooltip: l10n.serviceTopologyFilters,
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _deviceFilter.isNotEmpty,
              label: Text('${_deviceFilter.length}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
          IconButton(
            key: const Key('dataset-topology-links'),
            tooltip: l10n.dataSetTopologyShowLinks,
            isSelected: _showLinks,
            onPressed: () => setState(() => _showLinks = !_showLinks),
            icon: const Icon(Icons.timeline_outlined),
            selectedIcon: const Icon(Icons.timeline),
          ),
          IconButton(
            key: const Key('dataset-topology-show-empty'),
            tooltip: l10n.dataSetTopologyShowEmpty,
            isSelected: _showEmpty,
            onPressed: () {
              setState(() => _showEmpty = !_showEmpty);
              _transform.value = Matrix4.identity();
            },
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
          ),
          IconButton(
            key: const Key('dataset-topology-export'),
            tooltip: l10n.serviceExportTopologyImage,
            onPressed: _exporting || (_cache?.layout.isEmpty ?? true)
                ? null
                : _export,
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
          ),
        ],
      ),
      body: twoPane
          ? LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: column),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: topologyDetailPaneWidth(constraints.maxWidth),
                    child: selectedNode == null
                        ? Center(
                            key: const Key('dataset-topology-details-empty'),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                l10n.dataSetTopologySelectHint,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _DataSetTopologyDetails(
                            key: const Key('dataset-topology-details-pane'),
                            node: selectedNode,
                            dataSets: _dataSets,
                            devices: _devices,
                            onEdit: _edit,
                            onClose: _clearSelection,
                          ),
                  ),
                ],
              ),
            )
          : column,
    );
  }

  /// Purpose: Build the legend toggle, the legend and the selection chip.
  /// Inputs: `l10n`; `selected` — the selected box, if any.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Outside the canvas, so never exported.
  Widget _buildLegendStrip(
    AppLocalizations l10n,
    DataSetTopologyNode? selected,
  ) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.bodySmall;

    /// Purpose: Build one legend entry.
    /// Inputs: `swatch`, `label`.
    /// Returns: `Widget`.
    /// Side effects: None.
    /// Notes: Local helper of [_buildLegendStrip].
    Widget entry(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(label, style: text),
      ],
    );

    /// Purpose: Build a box swatch.
    /// Inputs: `fill`, `border`, `radius`.
    /// Returns: `Widget`.
    /// Side effects: None.
    /// Notes: Local helper of [_buildLegendStrip].
    Widget box(Color fill, Color border, double radius) => Container(
      width: 16,
      height: 14,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: 1.4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: const Key('dataset-topology-legend-toggle'),
                onPressed: () => setState(() => _legendOpen = !_legendOpen),
                icon: Icon(_legendOpen ? Icons.expand_less : Icons.expand_more),
                label: Text(l10n.serviceTopologyLegend),
              ),
              if (selected != null)
                InputChip(
                  key: const Key('dataset-topology-selection-chip'),
                  avatar: const Icon(Icons.filter_center_focus, size: 18),
                  label: Text(
                    l10n.serviceTopologySelected(_nodeLabel(selected, l10n)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onDeleted: _clearSelection,
                  deleteButtonTooltipMessage:
                      l10n.serviceTopologyClearSelection,
                ),
            ],
          ),
          if (_legendOpen)
            Padding(
              key: const Key('dataset-topology-legend'),
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  entry(
                    box(cs.surfaceContainerLow, cs.outline, 6),
                    l10n.dataSetTopologyLegendDevice,
                  ),
                  entry(
                    box(cs.surfaceContainerHighest, cs.outlineVariant, 4),
                    l10n.dataSetTopologyLegendStorage,
                  ),
                  entry(
                    box(cs.primaryContainer, cs.primary, 8),
                    l10n.dataSetTopologyLegendDataSet,
                  ),
                  if (_showLinks)
                    entry(
                      Container(width: 22, height: 3, color: cs.primary),
                      l10n.dataSetTopologyLegendSync,
                    ),
                  entry(
                    box(cs.errorContainer, cs.error, 8),
                    l10n.dataSetSingleCopy,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Purpose: Name a topology box.
/// Inputs: `node`, `l10n`.
/// Returns: The device name, the storage label, or the data set's emoji and
/// name.
/// Side effects: None.
/// Notes: Shared by the canvas, the chip and the details.
String _nodeLabel(DataSetTopologyNode node, AppLocalizations l10n) =>
    switch (node.kind) {
      DataSetTopologyNodeKind.device => node.device.name,
      DataSetTopologyNodeKind.storage => storageSlotLabel(
        node.device,
        node.storageIndex!,
        l10n.dataSetStorageFallback,
      ),
      DataSetTopologyNodeKind.copy =>
        '${node.dataSet!.emoji} ${node.dataSet!.name}',
    };

/// The canvas: device, storage and copy boxes, and the sync lines.
class _DataSetTopologyCanvas extends StatelessWidget {
  final DataSetTopologyLayout layout;
  final DataSetTopologyHighlight? highlight;
  final bool showLinks;
  final ValueChanged<DataSetTopologyNode> onTap;

  /// Purpose: Create the canvas.
  /// Inputs: `layout`; `highlight` — dims what it leaves out; `showLinks` —
  /// draw the sync lines; `onTap`.
  /// Returns: A new `_DataSetTopologyCanvas`.
  /// Side effects: None.
  /// Notes: None.
  const _DataSetTopologyCanvas({
    required this.layout,
    required this.highlight,
    required this.showLinks,
    required this.onTap,
  });

  /// Purpose: Build the stacked boxes with the line painter on top of the
  /// storages and under the copies.
  /// Inputs: `context`.
  /// Returns: The widget tree, sized to `layout.size`.
  /// Side effects: None.
  /// Notes: Device and storage boxes are drawn first, then the lines, then
  /// the copy boxes, so a line never hides a copy. Without `showLinks` the
  /// painter layer is left out. Every box is keyed
  /// `dataset-topology-node-<id>`.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final lit = highlight;

    /// Purpose: Position one box at its laid-out rect.
    /// Inputs: `node`.
    /// Returns: `Widget`.
    /// Side effects: None.
    /// Notes: Local helper of [build].
    Widget place(DataSetTopologyNode node) => Positioned.fromRect(
      rect: node.rect,
      child: _DataSetTopologyBox(
        key: ValueKey('dataset-topology-node-${node.id}'),
        node: node,
        label: _nodeLabel(node, l10n),
        selected: lit?.selectedId == node.id,
        dimmed: lit != null && !lit.nodeIds.contains(node.id),
        onTap: () => onTap(node),
      ),
    );
    return SizedBox.fromSize(
      size: layout.size,
      child: Stack(
        children: [
          for (final node in layout.nodes)
            if (node.kind != DataSetTopologyNodeKind.copy) place(node),
          if (showLinks)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const Key('dataset-topology-links-layer'),
                  painter: _DataSetLinkPainter(
                    layout: layout,
                    highlight: lit,
                    colorScheme: cs,
                  ),
                ),
              ),
            ),
          for (final node in layout.nodes)
            if (node.kind == DataSetTopologyNodeKind.copy) place(node),
        ],
      ),
    );
  }
}

/// One box of the canvas.
class _DataSetTopologyBox extends StatelessWidget {
  final DataSetTopologyNode node;
  final String label;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  /// Purpose: Create a box.
  /// Inputs: `node`, `label`, `selected`, `dimmed`, `onTap`.
  /// Returns: A new `_DataSetTopologyBox`.
  /// Side effects: None.
  /// Notes: The selection and dimming are read by tests.
  const _DataSetTopologyBox({
    super.key,
    required this.node,
    required this.label,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  /// Purpose: Build the box: a framed area with a header for a device or a
  /// storage, a filled chip for a copy.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Device and storage boxes take taps only on their header strip,
  /// so a tap on a copy inside always reaches the copy. A copy of a data
  /// set with a single copy uses the error colours. Screen readers hear the
  /// label, the kind and, for a copy, the copy count.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final width = selected ? 2.6 : 1.2;
    final Widget child;
    final String kind;
    switch (node.kind) {
      case DataSetTopologyNodeKind.device:
        kind = l10n.dataSetTopologyLegendDevice;
        child = _frame(
          cs.surfaceContainerLow,
          BorderSide(color: selected ? cs.primary : cs.outline, width: width),
          12,
          DataSetTopologyLayout.deviceHeader,
          Icon(deviceCategoryIcon(node.device.category), size: 20),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall,
          ),
        );
      case DataSetTopologyNodeKind.storage:
        kind = l10n.dataSetTopologyLegendStorage;
        child = _frame(
          cs.surfaceContainerHighest,
          BorderSide(
            color: selected ? cs.primary : cs.outlineVariant,
            width: width,
          ),
          8,
          DataSetTopologyLayout.storageHeader,
          const Icon(Icons.storage, size: 16),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelMedium,
          ),
        );
      case DataSetTopologyNodeKind.copy:
        kind = l10n.dataSetCopies(node.copyCount);
        final single = node.copyCount <= 1;
        final accent = single
            ? cs.error
            : dataSetTopologyColor(cs, node.dataSet!.id);
        child = Material(
          color: single
              ? cs.errorContainer
              : Color.alphaBlend(accent.withValues(alpha: 0.16), cs.surface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: accent, width: selected ? 2.6 : 1.4),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge,
                    ),
                  ),
                  Text(
                    '×${node.copyCount}',
                    style: text.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
    return Semantics(
      container: true,
      label: '$label, $kind',
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: dimmed ? topologyDimmedNodeOpacity : 1,
        child: Tooltip(message: label, child: child),
      ),
    );
  }

  /// Purpose: Build a framed container whose header strip takes the tap.
  /// Inputs: `fill`, `side`, `radius`, `header` — the strip height; `icon`,
  /// `title`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: The body below the header is not tappable, so its children win.
  Widget _frame(
    Color fill,
    BorderSide side,
    double radius,
    double header,
    Widget icon,
    Widget title,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: Border.fromBorderSide(side),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: header,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    Expanded(child: title),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the sync lines between copies of the same data set.
class _DataSetLinkPainter extends CustomPainter {
  final DataSetTopologyLayout layout;
  final DataSetTopologyHighlight? highlight;
  final ColorScheme colorScheme;

  /// Purpose: Create the painter.
  /// Inputs: `layout`, `highlight`, `colorScheme`.
  /// Returns: A new `_DataSetLinkPainter`.
  /// Side effects: None.
  /// Notes: None.
  const _DataSetLinkPainter({
    required this.layout,
    required this.highlight,
    required this.colorScheme,
  });

  /// Purpose: Paint every link as a soft curve.
  /// Inputs: `canvas`, `size`.
  /// Returns: None.
  /// Side effects: Draws on the canvas.
  /// Notes: The curve leaves and enters through the copies' nearest sides
  /// and bows sideways between copies stacked in one column. Links of
  /// data sets a highlight leaves out are faded; lit ones are drawn last
  /// and thicker. A small dot marks each end.
  @override
  void paint(Canvas canvas, Size size) {
    final lit = highlight;
    final ordered = [
      for (final link in layout.links)
        if (lit != null && !lit.dataSetIds.contains(link.dataSetId)) link,
      for (final link in layout.links)
        if (lit == null || lit.dataSetIds.contains(link.dataSetId)) link,
    ];
    for (final link in ordered) {
      final a = layout.node(link.fromId)?.rect;
      final b = layout.node(link.toId)?.rect;
      if (a == null || b == null) continue;
      final on = lit != null && lit.dataSetIds.contains(link.dataSetId);
      final off = lit != null && !on;
      final color = dataSetTopologyColor(colorScheme, link.dataSetId);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = on ? 3.2 : 2.2
        ..color = color.withValues(
          alpha: off ? topologyDimmedEdgeAlpha : (on ? 1 : 0.7),
        );
      final Offset start;
      final Offset end;
      final Offset c1;
      final Offset c2;
      final dx = b.center.dx - a.center.dx;
      if (dx.abs() > a.width / 2) {
        start = Offset(dx > 0 ? a.right : a.left, a.center.dy);
        end = Offset(dx > 0 ? b.left : b.right, b.center.dy);
        final bend = (end.dx - start.dx) * 0.5;
        c1 = start + Offset(bend, 0);
        c2 = end - Offset(bend, 0);
      } else {
        start = Offset(a.right, a.center.dy);
        end = Offset(b.right, b.center.dy);
        final bow = 28 + (end.dy - start.dy).abs() * 0.1;
        c1 = start + Offset(bow, 0);
        c2 = end + Offset(bow, 0);
      }
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
      canvas.drawPath(path, paint);
      final dot = Paint()..color = paint.color;
      canvas.drawCircle(start, 3.5, dot);
      canvas.drawCircle(end, 3.5, dot);
    }
  }

  /// Purpose: Tell whether the lines must be repainted.
  /// Inputs: `oldDelegate`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Identity checks; the page reuses the layout and builds a new
  /// highlight only when the selection changes.
  @override
  bool shouldRepaint(_DataSetLinkPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.highlight?.selectedId != highlight?.selectedId ||
      oldDelegate.colorScheme != colorScheme;
}

/// The details of a selected box: what it is and where every data set on it
/// has copies.
class _DataSetTopologyDetails extends StatelessWidget {
  final DataSetTopologyNode node;
  final List<DataSet> dataSets;
  final List<Device> devices;
  final bool shrinkWrap;
  final ValueChanged<DataSet> onEdit;
  final VoidCallback? onClose;

  /// Purpose: Create the details.
  /// Inputs: `node`; `dataSets`, `devices` — the inventory; `shrinkWrap` —
  /// for the sheet; `onEdit` — opens a data set's editor; `onClose` — adds a
  /// close button (pane only).
  /// Returns: A new `_DataSetTopologyDetails`.
  /// Side effects: None.
  /// Notes: None.
  const _DataSetTopologyDetails({
    super.key,
    required this.node,
    required this.dataSets,
    required this.devices,
    required this.onEdit,
    this.shrinkWrap = false,
    this.onClose,
  });

  /// Purpose: Build the details list.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: The header names the box; then one card per data set on it —
  /// just the one for a copy — listing every copy as "device – storage",
  /// with an edit button keyed `dataset-topology-edit-<id>`. Copies on the
  /// selected device or storage are marked with a check.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final onThis = <DataSet>[
      for (final ds in dataSets)
        if (resolveReplicas(ds, devices).any(
          (r) => switch (node.kind) {
            DataSetTopologyNodeKind.copy => ds.id == node.dataSet!.id,
            DataSetTopologyNodeKind.storage =>
              r.device.id == node.device.id &&
                  r.storageIndex == node.storageIndex,
            DataSetTopologyNodeKind.device => r.device.id == node.device.id,
          },
        ))
          ds,
    ];
    return ListView(
      shrinkWrap: shrinkWrap,
      padding: EdgeInsets.fromLTRB(16, onClose == null ? 0 : 8, 16, 16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: switch (node.kind) {
              DataSetTopologyNodeKind.device => Icon(
                deviceCategoryIcon(node.device.category),
              ),
              DataSetTopologyNodeKind.storage => const Icon(Icons.storage),
              DataSetTopologyNodeKind.copy => Text(node.dataSet!.emoji),
            },
          ),
          title: Text(switch (node.kind) {
            DataSetTopologyNodeKind.copy => node.dataSet!.name,
            _ => _nodeLabel(node, l10n),
          }),
          subtitle: Text(switch (node.kind) {
            DataSetTopologyNodeKind.device => deviceCategoryLabel(
              l10n,
              node.device.category,
            ),
            DataSetTopologyNodeKind.storage => node.device.name,
            DataSetTopologyNodeKind.copy => l10n.dataSetCopies(node.copyCount),
          }),
          trailing: onClose == null
              ? null
              : IconButton(
                  key: const Key('dataset-topology-details-close'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
        ),
        if (onThis.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.dataSetTopologyNoDataSets,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final ds in onThis) _buildDataSetCard(context, l10n, ds),
      ],
    );
  }

  /// Purpose: Build one data set's card of copies.
  /// Inputs: `context`, `l10n`, `ds`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper of [build].
  Widget _buildDataSetCard(
    BuildContext context,
    AppLocalizations l10n,
    DataSet ds,
  ) {
    final theme = Theme.of(context);
    final replicas = resolveReplicas(ds, devices);
    final single = replicas.length <= 1;
    return Card(
      key: ValueKey('dataset-topology-card-${ds.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(ds.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ds.name, style: theme.textTheme.titleSmall),
                ),
                IconButton(
                  key: ValueKey('dataset-topology-edit-${ds.id}'),
                  tooltip: l10n.editDataSet,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(ds),
                ),
              ],
            ),
            Text(
              single
                  ? l10n.dataSetSingleCopy
                  : '${l10n.dataSetTopologyCopiesTitle} · ${l10n.dataSetCopies(replicas.length)}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: single
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final r in replicas)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Row(
                  children: [
                    Icon(
                      _isHere(r) ? Icons.check_circle : Icons.circle_outlined,
                      size: 16,
                      color: _isHere(r)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${r.device.name} – ${storageSlotLabel(r.device, r.storageIndex, l10n.dataSetStorageFallback)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Purpose: Tell whether a copy lies on the selected box.
  /// Inputs: `r`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper of [_buildDataSetCard].
  bool _isHere(DataSetReplica r) => switch (node.kind) {
    DataSetTopologyNodeKind.device => r.device.id == node.device.id,
    _ => r.device.id == node.device.id && r.storageIndex == node.storageIndex,
  };
}
