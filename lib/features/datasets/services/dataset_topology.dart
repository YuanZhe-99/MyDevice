import 'dart:math' as math;
import 'dart:ui';

import '../../devices/models/device.dart';
import '../models/dataset.dart';
import 'dataset_placement.dart';

/// What a box on the data set topology stands for.
enum DataSetTopologyNodeKind { device, storage, copy }

/// One placed box of the data set topology: a device (large), a storage
/// slot inside it (medium) or one copy of a data set on that slot (small).
class DataSetTopologyNode {
  /// `device:<deviceId>`, `storage:<deviceId>:<index>` or
  /// `copy:<dataSetId>@<deviceId>:<index>`.
  final String id;
  final DataSetTopologyNodeKind kind;
  final Rect rect;
  final Device device;

  /// The slot, for storage and copy boxes.
  final int? storageIndex;

  /// The data set, for copy boxes.
  final DataSet? dataSet;

  /// How many copies the copy box's data set has in the whole inventory,
  /// counting devices a filter hides; 0 for other boxes.
  final int copyCount;

  /// Purpose: Create a placed box.
  /// Inputs: Every field; see their comments.
  /// Returns: A new `DataSetTopologyNode`.
  /// Side effects: None.
  /// Notes: Built only by [DataSetTopologyLayout.build].
  const DataSetTopologyNode({
    required this.id,
    required this.kind,
    required this.rect,
    required this.device,
    this.storageIndex,
    this.dataSet,
    this.copyCount = 0,
  });
}

/// One sync line: two copies of the same data set, consecutive in the
/// copies' drawing order.
class DataSetTopologyLink {
  final String dataSetId;
  final String fromId;
  final String toId;

  /// Purpose: Create a link.
  /// Inputs: `dataSetId`; `fromId`, `toId` — copy node ids.
  /// Returns: A new `DataSetTopologyLink`.
  /// Side effects: None.
  /// Notes: None.
  const DataSetTopologyLink({
    required this.dataSetId,
    required this.fromId,
    required this.toId,
  });
}

/// The boxes and lines a selection lights.
class DataSetTopologyHighlight {
  final String selectedId;
  final Set<String> nodeIds;
  final Set<String> dataSetIds;

  /// Purpose: Create a highlight.
  /// Inputs: `selectedId`; `nodeIds` — lit boxes; `dataSetIds` — data sets
  /// whose copies and links are lit.
  /// Returns: A new `DataSetTopologyHighlight`.
  /// Side effects: None.
  /// Notes: Built by [DataSetTopologyLayout.highlightFor].
  const DataSetTopologyHighlight({
    required this.selectedId,
    required this.nodeIds,
    required this.dataSetIds,
  });
}

/// The pure, deterministic layout of the data set topology: devices as
/// large boxes packed into columns of a square-to-16:10 canvas, their storage slots stacked inside, each
/// slot's data set copies wrapped inside the slot, and one chain of sync
/// lines per data set with more than one copy.
class DataSetTopologyLayout {
  final Size size;

  /// Every box, devices first, then storages, then copies.
  final List<DataSetTopologyNode> nodes;
  final List<DataSetTopologyLink> links;

  /// Purpose: Create a layout result.
  /// Inputs: `size`, `nodes`, `links`.
  /// Returns: A new `DataSetTopologyLayout`.
  /// Side effects: None.
  /// Notes: Use [DataSetTopologyLayout.build].
  DataSetTopologyLayout({
    required this.size,
    required this.nodes,
    required this.links,
  }) : _byId = {for (final node in nodes) node.id: node};

  final Map<String, DataSetTopologyNode> _byId;

  static const padding = 24.0;
  static const deviceGap = 32.0;
  static const deviceHeader = 44.0;
  static const devicePadding = 12.0;
  static const storageHeader = 34.0;
  static const storagePadding = 8.0;
  static const storageGap = 10.0;
  static const copyWidth = 140.0;
  static const copyHeight = 36.0;
  static const copyGap = 8.0;
  static const copiesPerRow = 2;
  static const emptyStorageBody = 24.0;

  /// The canvas aspect ratios (width / height) the device columns aim for:
  /// square up to 16:10.
  static const targetMinAspect = 1.0;
  static const targetMaxAspect = 1.6;

  /// Width of a storage box: two copy boxes and their margins.
  static const storageWidth =
      2 * storagePadding +
      copiesPerRow * copyWidth +
      (copiesPerRow - 1) * copyGap;

  /// Width of a device box.
  static const deviceWidth = storageWidth + 2 * devicePadding;

  /// Purpose: Look a box up by id.
  /// Inputs: `id`.
  /// Returns: The node, or null.
  /// Side effects: None.
  /// Notes: None.
  DataSetTopologyNode? node(String id) => _byId[id];

  /// Purpose: Tell whether the layout has nothing to draw.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isEmpty => nodes.isEmpty;

  /// Purpose: Lay the topology out.
  /// Inputs: `devices` — the device list, whose order breaks ties;
  /// `dataSets` — in display order; `deviceIds` — when non-empty, only these
  /// devices are drawn; `showEmptyDevices` — also draw devices with storage
  /// but no copy.
  /// Returns: The layout.
  /// Side effects: None.
  /// Notes: Devices with no storage slot are never drawn. Device order:
  /// the device with the most copies first, then repeatedly the device that
  /// shares the most data sets with those already placed, so devices that
  /// sync sit side by side; ties keep the device-list order. Devices are
  /// packed into columns (each into the currently shortest one), with the
  /// column count chosen by [_columnCount] so the canvas is as close as
  /// possible to square-to-16:10; the window size plays no part. Copy count
  /// counts every copy, drawn or not.
  static DataSetTopologyLayout build({
    required List<Device> devices,
    required List<DataSet> dataSets,
    Set<String> deviceIds = const {},
    bool showEmptyDevices = false,
  }) {
    final replicasByDataSet = <String, List<DataSetReplica>>{
      for (final ds in dataSets) ds.id: resolveReplicas(ds, devices),
    };
    final onSlot = <String, List<DataSetReplica>>{};
    final dataSetsOnDevice = <String, Set<String>>{};
    for (final ds in dataSets) {
      for (final r in replicasByDataSet[ds.id]!) {
        onSlot.putIfAbsent('${r.device.id}:${r.storageIndex}', () => []).add(r);
        dataSetsOnDevice.putIfAbsent(r.device.id, () => {}).add(ds.id);
      }
    }
    final candidates = [
      for (final device in devices)
        if (device.storage.isNotEmpty &&
            (deviceIds.isEmpty || deviceIds.contains(device.id)) &&
            (showEmptyDevices || dataSetsOnDevice.containsKey(device.id)))
          device,
    ];
    final ordered = _orderByAffinity(candidates, dataSetsOnDevice);
    if (ordered.isEmpty) {
      return DataSetTopologyLayout(size: Size.zero, nodes: [], links: []);
    }

    /// Purpose: Return the height of one storage box.
    /// Inputs: `copies` — how many copies the slot holds.
    /// Returns: `double`.
    /// Side effects: None.
    /// Notes: Local helper of [build].
    double storageHeight(int copies) {
      final rows = (copies / copiesPerRow).ceil();
      final body = copies == 0
          ? emptyStorageBody
          : rows * copyHeight + (rows - 1) * copyGap;
      return storageHeader + body + storagePadding;
    }

    final heights = [
      for (final device in ordered)
        deviceHeader +
            devicePadding +
            [
              for (var i = 0; i < device.storage.length; i++)
                storageHeight(onSlot['${device.id}:$i']?.length ?? 0),
            ].reduce((a, b) => a + b) +
            (device.storage.length - 1) * storageGap,
    ];
    final columns = _columnCount(heights);
    final tops = _packColumns(heights, columns);

    final deviceNodes = <DataSetTopologyNode>[];
    final storageNodes = <DataSetTopologyNode>[];
    final copyNodes = <DataSetTopologyNode>[];
    var maxRight = padding;
    var maxBottom = padding;
    for (var d = 0; d < ordered.length; d++) {
      final device = ordered[d];
      final left = padding + tops[d].column * (deviceWidth + deviceGap);
      final y = tops[d].top;
      var sy = y + deviceHeader;
      for (var i = 0; i < device.storage.length; i++) {
        final copies = onSlot['${device.id}:$i'] ?? const [];
        final storageRect = Rect.fromLTWH(
          left + devicePadding,
          sy,
          storageWidth,
          storageHeight(copies.length),
        );
        storageNodes.add(
          DataSetTopologyNode(
            id: 'storage:${device.id}:$i',
            kind: DataSetTopologyNodeKind.storage,
            rect: storageRect,
            device: device,
            storageIndex: i,
          ),
        );
        for (var c = 0; c < copies.length; c++) {
          final r = copies[c];
          copyNodes.add(
            DataSetTopologyNode(
              id: copyNodeId(r.dataSet.id, device.id, i),
              kind: DataSetTopologyNodeKind.copy,
              rect: Rect.fromLTWH(
                storageRect.left +
                    storagePadding +
                    (c % copiesPerRow) * (copyWidth + copyGap),
                storageRect.top +
                    storageHeader +
                    (c ~/ copiesPerRow) * (copyHeight + copyGap),
                copyWidth,
                copyHeight,
              ),
              device: device,
              storageIndex: i,
              dataSet: r.dataSet,
              copyCount: replicasByDataSet[r.dataSet.id]!.length,
            ),
          );
        }
        sy = storageRect.bottom + storageGap;
      }
      final deviceRect = Rect.fromLTWH(left, y, deviceWidth, heights[d]);
      deviceNodes.add(
        DataSetTopologyNode(
          id: 'device:${device.id}',
          kind: DataSetTopologyNodeKind.device,
          rect: deviceRect,
          device: device,
        ),
      );
      maxRight = math.max(maxRight, deviceRect.right);
      maxBottom = math.max(maxBottom, deviceRect.bottom);
    }

    // Copy boxes were placed device by device in affinity order, slot by
    // slot, so this order chains each data set's copies along the canvas.
    final copiesOf = <String, List<DataSetTopologyNode>>{};
    for (final node in copyNodes) {
      copiesOf.putIfAbsent(node.dataSet!.id, () => []).add(node);
    }
    final links = <DataSetTopologyLink>[];
    for (final ds in dataSets) {
      final placed = copiesOf[ds.id] ?? const [];
      for (var i = 1; i < placed.length; i++) {
        links.add(
          DataSetTopologyLink(
            dataSetId: ds.id,
            fromId: placed[i - 1].id,
            toId: placed[i].id,
          ),
        );
      }
    }

    return DataSetTopologyLayout(
      size: Size(maxRight + padding, maxBottom + padding),
      nodes: [...deviceNodes, ...storageNodes, ...copyNodes],
      links: links,
    );
  }

  /// Purpose: Place device boxes into columns, each into the shortest.
  /// Inputs: `heights` — device heights in placement order; `columns`.
  /// Returns: Per device, its column and top edge.
  /// Side effects: None.
  /// Notes: Ties go to the leftmost column, so the result is deterministic;
  /// a tall device simply makes its column longer while the next devices
  /// fill the others.
  static List<({int column, double top})> _packColumns(
    List<double> heights,
    int columns,
  ) {
    final bottoms = List<double>.filled(columns, padding);
    final placed = <({int column, double top})>[];
    for (final h in heights) {
      var best = 0;
      for (var c = 1; c < columns; c++) {
        if (bottoms[c] < bottoms[best]) best = c;
      }
      placed.add((column: best, top: bottoms[best]));
      bottoms[best] += h + deviceGap;
    }
    return placed;
  }

  /// Purpose: Choose how many device columns make the canvas closest to
  /// square-to-16:10.
  /// Inputs: `heights` — device heights in placement order.
  /// Returns: A column count between 1 and the number of devices.
  /// Side effects: None.
  /// Notes: Each count is packed with [_packColumns]; its aspect ratio
  /// (width / height) scores by how far, on a log scale, it falls outside
  /// [targetMinAspect, targetMaxAspect]. Ties — several counts inside the
  /// range — go to the smaller canvas area, then to fewer columns.
  static int _columnCount(List<double> heights) {
    var best = 1;
    var bestScore = double.infinity;
    var bestArea = double.infinity;
    for (var k = 1; k <= heights.length; k++) {
      final placed = _packColumns(heights, k);
      var bottom = 0.0;
      var used = 0;
      for (var d = 0; d < heights.length; d++) {
        bottom = math.max(bottom, placed[d].top + heights[d]);
        used = math.max(used, placed[d].column + 1);
      }
      final w = 2 * padding + used * deviceWidth + (used - 1) * deviceGap;
      final h = bottom + padding;
      final aspect = w / h;
      final score = aspect < targetMinAspect
          ? math.log(targetMinAspect / aspect)
          : aspect > targetMaxAspect
          ? math.log(aspect / targetMaxAspect)
          : 0.0;
      final area = w * h;
      if (score < bestScore - 1e-9 ||
          ((score - bestScore).abs() <= 1e-9 && area < bestArea - 1e-6)) {
        best = k;
        bestScore = score;
        bestArea = area;
      }
    }
    return best;
  }

  /// Purpose: Build the id of a copy box.
  /// Inputs: `dataSetId`, `deviceId`, `storageIndex`.
  /// Returns: `copy:<dataSetId>@<deviceId>:<index>`.
  /// Side effects: None.
  /// Notes: Widget keys use `dataset-topology-node-<id>`.
  static String copyNodeId(
    String dataSetId,
    String deviceId,
    int storageIndex,
  ) => 'copy:$dataSetId@$deviceId:$storageIndex';

  /// Purpose: Order devices so that devices sharing data sets are adjacent.
  /// Inputs: `devices` — candidates in device-list order; `onDevice` —
  /// device id → ids of the data sets it holds.
  /// Returns: The devices, reordered.
  /// Side effects: None.
  /// Notes: Greedy and deterministic: the device holding the most data sets
  /// first, then each step the device sharing the most with the placed ones
  /// (ties: more data sets, then list order).
  static List<Device> _orderByAffinity(
    List<Device> devices,
    Map<String, Set<String>> onDevice,
  ) {
    final rest = List<Device>.of(devices);
    final placed = <Device>[];
    final placedSets = <String>{};
    while (rest.isNotEmpty) {
      var best = 0;
      var bestShared = -1;
      var bestOwn = -1;
      for (var i = 0; i < rest.length; i++) {
        final own = onDevice[rest[i].id] ?? const <String>{};
        final shared = own.where(placedSets.contains).length;
        if (shared > bestShared ||
            (shared == bestShared && own.length > bestOwn)) {
          best = i;
          bestShared = shared;
          bestOwn = own.length;
        }
      }
      final device = rest.removeAt(best);
      placed.add(device);
      placedSets.addAll(onDevice[device.id] ?? const <String>{});
    }
    return placed;
  }

  /// Purpose: Resolve which boxes and data sets a selection lights.
  /// Inputs: `selectedId` — a node id.
  /// Returns: The highlight; null when the id is not in this layout.
  /// Side effects: None.
  /// Notes: A copy lights its data set; a storage or device lights every
  /// data set it holds. Each lit data set lights all of its drawn copies and
  /// their storages and devices, so a selection shows where everything on
  /// it is mirrored. The selected box itself is always lit.
  DataSetTopologyHighlight? highlightFor(String selectedId) {
    final selected = node(selectedId);
    if (selected == null) return null;
    final dataSetIds = <String>{
      for (final n in nodes)
        if (n.kind == DataSetTopologyNodeKind.copy &&
            switch (selected.kind) {
              DataSetTopologyNodeKind.copy =>
                n.dataSet!.id == selected.dataSet!.id,
              DataSetTopologyNodeKind.storage =>
                n.device.id == selected.device.id &&
                    n.storageIndex == selected.storageIndex,
              DataSetTopologyNodeKind.device =>
                n.device.id == selected.device.id,
            })
          n.dataSet!.id,
    };
    final lit = <String>{selectedId};
    for (final n in nodes) {
      if (n.kind != DataSetTopologyNodeKind.copy ||
          !dataSetIds.contains(n.dataSet!.id)) {
        continue;
      }
      lit
        ..add(n.id)
        ..add('storage:${n.device.id}:${n.storageIndex}')
        ..add('device:${n.device.id}');
    }
    return DataSetTopologyHighlight(
      selectedId: selectedId,
      nodeIds: lit,
      dataSetIds: dataSetIds,
    );
  }
}
