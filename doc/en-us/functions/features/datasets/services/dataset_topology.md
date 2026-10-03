# lib/features/datasets/services/dataset_topology.dart

The pure, deterministic layout of the data set topology (since 1.8.0), drawn by
[`dataset_topology_page.md`](../views/dataset_topology_page.md). It nests three kinds of box —
devices (large), their storage slots (medium) and the data set copies on each slot (small) — and
joins the copies of each data set with sync lines. See
[Datasets](../../../../features/datasets.md#data-set-topology) for the feature.

`enum DataSetTopologyNodeKind { device, storage, copy }` is not listed. The size constants of
`DataSetTopologyLayout` are documented in source and not listed: `padding` 24, `deviceGap` 32,
`deviceHeader` 44, `devicePadding` 12, `storageHeader` 34, `storagePadding` 8, `storageGap` 10,
`copyWidth` 140, `copyHeight` 36, `copyGap` 8, `copiesPerRow` 2, `emptyStorageBody` 24, and the
derived `storageWidth` (304) and `deviceWidth` (328).

Node ids: `device:<deviceId>`, `storage:<deviceId>:<index>`,
`copy:<dataSetId>@<deviceId>:<index>`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DataSetTopologyNode` (constructor) | constructor | B | One placed box: id, kind, rect, device, slot, data set, copy count. |
| `DataSetTopologyLink` (constructor) | constructor | B | One sync line between two copy boxes of a data set. |
| `DataSetTopologyHighlight` (constructor) | constructor | B | The boxes and data sets a selection lights. |
| `DataSetTopologyLayout` (constructor) | constructor | B | The result: size, nodes, links, with an id index. |
| `node` | method (`DataSetTopologyLayout`) | B | Look a box up by id. |
| `isEmpty` | getter (`DataSetTopologyLayout`) | B | Whether nothing is drawn. |
| [`build`](#build) | static method (`DataSetTopologyLayout`) | A | Lay the topology out for a viewport width, filter and empty-device switch. |
| `copyNodeId` | static method (`DataSetTopologyLayout`) | B | The id of a copy box. |
| [`_orderByAffinity`](#orderbyaffinity) | static method (`DataSetTopologyLayout`) | A | Order devices so devices sharing data sets are adjacent. |
| [`highlightFor`](#highlightfor) | method (`DataSetTopologyLayout`) | A | Which boxes and data sets a selected box lights. |

Row count (10) matches `grep -c 'Purpose:' dataset_topology.dart` (10) exactly.

## Documentation

### `static DataSetTopologyLayout build({required List<Device> devices, required List<DataSet> dataSets, required double viewportWidth, Set<String> deviceIds = const {}, bool showEmptyDevices = false})` <a id="build"></a>
- **Kind:** static method of `DataSetTopologyLayout`.
- **Source:** `lib/features/datasets/services/dataset_topology.dart` (line 157).
- **Purpose:** Lay the topology out.
- **Inputs:** `devices` — order breaks ties; `dataSets` — display order; `viewportWidth`;
  `deviceIds` — non-empty ⇒ only these devices; `showEmptyDevices` — also draw devices with
  storage but no copy.
- **Returns:** The layout; `Size.zero` and no nodes when nothing qualifies.
- **Side effects:** None.
- **Algorithm:** 1. Resolve every data set's copies
  ([`resolveReplicas`](dataset_placement.md#resolvereplicas)) and bucket them per slot. 2. Take
  the devices with storage that pass the filter and (unless `showEmptyDevices`) hold a copy;
  order them with `_orderByAffinity`. 3. Fit `floor((width − 2·padding + gap) / (deviceWidth +
  gap))` devices per row, at least one. 4. In each device, stack its slots under the 44 px
  header; a slot's body holds its copies two per row (or a 24 px empty body). The device's height
  follows its slots; a row is as tall as its tallest device. 5. For each data set, chain its copy
  boxes in placement order (row by row, device by device, slot by slot) with one link per
  consecutive pair.
- **Usage:** `_layoutFor` of the topology page, cached by data identity, filter, switch and
  rounded width.
- **Notes:** A copy's `copyCount` counts every copy of its data set, including those on devices
  the filter hides, while links are only drawn between drawn copies. `test/dataset_topology_test.dart`
  pins nesting, links, ordering, wrapping, the filter and the empty case.

### `static List<Device> _orderByAffinity(List<Device> devices, Map<String, Set<String>> onDevice)` <a id="orderbyaffinity"></a>
- **Kind:** static method of `DataSetTopologyLayout`.
- **Source:** `lib/features/datasets/services/dataset_topology.dart` (line 314).
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
- **Source:** `lib/features/datasets/services/dataset_topology.dart` (line 350).
- **Purpose:** Resolve which boxes and data sets a selection lights.
- **Inputs:** `selectedId` — a node id.
- **Returns:** The highlight; null when the id is not in this layout.
- **Side effects:** None.
- **Algorithm:** 1. The lit data sets: a copy's own; for a storage or device, every data set with
  a copy on it. 2. Lit boxes: the selected box, plus every drawn copy of a lit data set with its
  storage and device.
- **Usage:** The topology page's canvas, per build.
- **Notes:** Selecting a box therefore shows where everything on it is mirrored.
