# lib/features/datasets/services/dataset_topology.dart

The pure, deterministic layout of the data set topology (since 1.8.0), drawn by
[`dataset_topology_page.md`](../views/dataset_topology_page.md). It nests three kinds of box —
devices (large), their storage places — RAID arrays, then free slots, since 1.8.2 (medium) — and
the data set copies on each place (small) — and joins the copies of each data set with sync lines. See
[Datasets](../../../../features/datasets.md#data-set-topology) for the feature.

`enum DataSetTopologyNodeKind { device, storage, copy }` is not listed. The size constants of
`DataSetTopologyLayout` are documented in source and not listed: `padding` 24, `deviceGap` 32,
`deviceHeader` 44, `devicePadding` 12, `storageHeader` 34, `storagePadding` 8, `storageGap` 10,
`copyWidth` 140, `copyHeight` 36, `copyGap` 8, `copiesPerRow` 2, `emptyStorageBody` 24,
`targetMinAspect` 1.0 and `targetMaxAspect` 1.6 (since 1.8.1), and the derived `storageWidth` (304) and `deviceWidth` (328).

Node ids: `device:<deviceId>`, `storage:<deviceId>:<place key>`,
`copy:<dataSetId>@<deviceId>:<place key>`, where a slot's place key is its index (so slot ids are
unchanged from 1.8.0) and an array's is `a:<arrayId>` (see
[`StoragePlace.key`](dataset_placement.md#declarations)).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DataSetTopologyNode` (constructor) | constructor | B | One placed box: id, kind, rect, device, place, data set, copy and available counts. |
| `storageIndex` | getter (`DataSetTopologyNode`) | B | The slot of a slot or slot-copy box; null for devices and arrays. |
| `DataSetTopologyLink` (constructor) | constructor | B | One sync line between two copy boxes of a data set. |
| `DataSetTopologyHighlight` (constructor) | constructor | B | The boxes and data sets a selection lights. |
| `DataSetTopologyLayout` (constructor) | constructor | B | The result: size, nodes, links, with an id index. |
| `node` | method (`DataSetTopologyLayout`) | B | Look a box up by id. |
| `isEmpty` | getter (`DataSetTopologyLayout`) | B | Whether nothing is drawn. |
| [`build`](#build) | static method (`DataSetTopologyLayout`) | A | Lay the topology out for a filter and empty-device switch, packed into a square-to-16:10 canvas. |
| `storageHeight` | nested function (`build`) | B | One storage (place) box's height from its copy count. |
| [`_packColumns`](#packcolumns) | static method (`DataSetTopologyLayout`) | A | Place device boxes into columns, each into the shortest. |
| [`_columnCount`](#columncount) | static method (`DataSetTopologyLayout`) | A | The column count whose canvas is closest to square-to-16:10. |
| `copyNodeId` | static method (`DataSetTopologyLayout`) | B | The id of a copy box; `placeKey` is an `Object` (slot index or place key). |
| [`_orderByAffinity`](#orderbyaffinity) | static method (`DataSetTopologyLayout`) | A | Order devices so devices sharing data sets are adjacent. |
| [`highlightFor`](#highlightfor) | method (`DataSetTopologyLayout`) | A | Which boxes and data sets a selected box lights. |

Row count (14) matches `grep -c 'Purpose:' dataset_topology.dart` (14) exactly.

## Documentation

### `static DataSetTopologyLayout build({required List<Device> devices, required List<DataSet> dataSets, Set<String> deviceIds = const {}, bool showEmptyDevices = false})` <a id="build"></a>
- **Kind:** static method of `DataSetTopologyLayout`.
- **Source:** `lib/features/datasets/services/dataset_topology.dart` (line 180).
- **Purpose:** Lay the topology out.
- **Inputs:** `devices` — order breaks ties; `dataSets` — display order;
  `deviceIds` — non-empty ⇒ only these devices; `showEmptyDevices` — also draw devices with
  storage but no copy.
- **Returns:** The layout; `Size.zero` and no nodes when nothing qualifies.
- **Side effects:** None.
- **Algorithm:** 1. Resolve every data set's copies
  ([`resolveReplicas`](dataset_placement.md#resolvereplicas)) and bucket them per
  `<deviceId>:<place key>`. 2. Take the devices with storage that pass the filter and (unless
  `showEmptyDevices`) hold a copy; order them with `_orderByAffinity`. 3. Each device's places:
  [`devicePlaces`](dataset_placement.md#deviceplaces) (arrays, then free slots), plus any array
  member slot a link still names directly, so no copy is lost. 4. Each device's height: the 44 px
  header, its places (`storageHeight`: a 34 px header plus copies two per row, or a 24 px empty
  body) with 10 px gaps, and 12 px padding. 5. Pick the column count with `_columnCount` and place
  the devices with `_packColumns`. 6. Stack each device's place boxes and copies inside its box;
  each copy carries `copyCount` and `availableCount`
  ([`availableCopyCount`](dataset_placement.md#declarations)). 7. For each data set, chain its copy
  boxes in placement order (device by device in affinity order, place by place) with one link per
  consecutive pair.
- **Usage:** `_layout` of the topology page, cached by data identity, filter and switch.
  Before 1.8.1 it took a `viewportWidth` and flowed devices into rows of that width.
- **Notes:** A copy's `copyCount` counts every copy of its data set, including those on devices
  the filter hides and on unavailable places; `availableCount` counts those whose place is not
  `unavailable`. Links are only drawn between drawn copies. `test/dataset_topology_test.dart`
  pins nesting, links, ordering, the aspect ratio, tall-device packing, the filter and the empty
  case.

### `static List<({int column, double top})> _packColumns(List<double> heights, int columns)` <a id="packcolumns"></a>
- **Kind:** static method of `DataSetTopologyLayout`.
- **Source:** `lib/features/datasets/services/dataset_topology.dart` (line 352).
- **Purpose:** Place device boxes into columns.
- **Inputs:** `heights` — device heights in placement order; `columns`.
- **Returns:** Per device, its column and top edge.
- **Side effects:** None.
- **Algorithm:** Every column starts at `padding`; each device goes into the column whose bottom
  is lowest (leftmost on ties), which then grows by the height plus `deviceGap`.
- **Usage:** `build` and `_columnCount`.
- **Notes:** Deterministic. With a tall device first, the following devices stack in the other
  columns beside it.

### `static int _columnCount(List<double> heights)` <a id="columncount"></a>
- **Kind:** static method of `DataSetTopologyLayout`.
- **Source:** `lib/features/datasets/services/dataset_topology.dart` (line 378).
- **Purpose:** Choose the column count that brings the canvas closest to square-to-16:10.
- **Inputs:** `heights` — device heights in placement order.
- **Returns:** A count from 1 to the number of devices.
- **Side effects:** None.
- **Algorithm:** For every count, pack with `_packColumns` and measure the canvas (only used
  columns count towards the width). Score = 0 when `width / height` lies in
  [`targetMinAspect`, `targetMaxAspect`], else the log of how far outside it is. Lowest score
  wins; ties go to the smaller area, then fewer columns.
- **Usage:** `build`.
- **Notes:** O(n²) in devices — fine at inventory sizes. The window size plays no part.

### `static List<Device> _orderByAffinity(List<Device> devices, Map<String, Set<String>> onDevice)` <a id="orderbyaffinity"></a>
- **Kind:** static method of `DataSetTopologyLayout`.
- **Source:** `lib/features/datasets/services/dataset_topology.dart` (line 429).
- **Purpose:** Order devices so that devices sharing data sets are adjacent.
- **Inputs:** `devices` — in list order; `onDevice` — device id → data set ids it holds.
- **Returns:** The devices, reordered.
- **Side effects:** None.
- **Algorithm:** Greedy: repeatedly take the remaining device with the most data sets shared with
  those already placed, ties broken by more data sets, then list order. The first pick is
  therefore the device holding the most.
- **Usage:** `build`.
- **Notes:** Deterministic, O(n²) in devices — fine at inventory sizes.

### `DataSetTopologyHighlight? highlightFor(String selectedId)` <a id="highlightfor"></a>
- **Kind:** method of `DataSetTopologyLayout`.
- **Source:** `lib/features/datasets/services/dataset_topology.dart` (line 465).
- **Purpose:** Resolve which boxes and data sets a selection lights.
- **Inputs:** `selectedId` — a node id.
- **Returns:** The highlight; null when the id is not in this layout.
- **Side effects:** None.
- **Algorithm:** 1. The lit data sets: a copy's own; for a storage (place, matched by device and
  place key) or device, every data set with a copy on it. 2. Lit boxes: the selected box, plus every drawn copy of a lit data set with its
  storage and device.
- **Usage:** The topology page's canvas, per build.
- **Notes:** Selecting a box therefore shows where everything on it is mirrored.
