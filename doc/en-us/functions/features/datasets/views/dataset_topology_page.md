# lib/features/datasets/views/dataset_topology_page.dart

The full-screen data set topology (since 1.8.0), pushed on the root navigator from the data set
list's app bar ([`dataset_list_page.md`](dataset_list_page.md), `_openTopology`). Devices are
large boxes, their storage slots medium boxes inside them, and each data set copy a small box
inside its slot; copies of the same data set are joined by sync lines. The layout comes from
[`../services/dataset_topology.md`](../services/dataset_topology.md); the canvas is the shared
[`TopologyCanvasViewer`](../../../shared/widgets/topology_canvas_viewer.md) — tap to select, drag
or wheel to pan, pinch or Ctrl + wheel to zoom. See
[Datasets](../../../../features/datasets.md#data-set-topology).

The typedef `DataSetTopologyInventory` (the `dataSets`, `devices` record `reload` returns) is not
listed. Keys: boxes `dataset-topology-node-<id>`; app bar `dataset-topology-filter`,
`dataset-topology-show-empty`, `dataset-topology-export`; `dataset-topology-legend-toggle`,
`dataset-topology-legend`, `dataset-topology-selection-chip`, `dataset-topology-empty`; details
`dataset-topology-details-sheet`, `dataset-topology-details-pane`,
`dataset-topology-details-empty`, `dataset-topology-details-close`,
`dataset-topology-card-<id>`, `dataset-topology-edit-<id>`; filter chips
`dataset-topology-filter-all`, `dataset-topology-filter-device-<id>`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`dataSetTopologyColor`](#datasettopologycolor) | top-level function | A | A data set's stable colour for its copies and lines. |
| `DataSetTopologyPage` (constructor) | constructor | B | Create the page: data sets, devices, editor callback, optional `reload`. |
| `createState` | method (`DataSetTopologyPage`) | B | Create the page's state. |
| `dispose` | method (`_DataSetTopologyPageState`) | B | Dispose the transformation controller. |
| [`_layoutFor`](#layoutfor) | method (`_DataSetTopologyPageState`) | A | The layout for a width, cached. |
| `_select` | method (`_DataSetTopologyPageState`) | B | Select a tapped box; on phones open the details sheet. |
| `_clearSelection` | method (`_DataSetTopologyPageState`) | B | Clear the selection. |
| `_edit` | method (`_DataSetTopologyPageState`) | B | Await the editor, then `reload` and replace the data. |
| `_showDetailsSheet` | method (`_DataSetTopologyPageState`) | B | The details in a bottom sheet. |
| `_openFilters` | method (`_DataSetTopologyPageState`) | B | A sheet of device chips that applies live. |
| `apply` | nested function (`_openFilters`) | B | Apply a filter to page and sheet, resetting the transform. |
| `_export` | method (`_DataSetTopologyPageState`) | B | Capture the canvas with its highlight as `mydevice_dataset_topology.png` and share it. |
| [`build`](#build) | method (widget, `_DataSetTopologyPageState`) | A | App bar, view controls, legend strip, canvas, details pane. |
| `_buildLegendStrip` | method (widget helper) | B | Legend toggle, the legend, the selection chip. |
| `entry` | nested function (`_buildLegendStrip`) | B | One legend entry. |
| `box` | nested function (`_buildLegendStrip`) | B | One box swatch. |
| `_nodeLabel` | top-level function | B | Device name, storage label or "emoji name". |
| `_DataSetTopologyCanvas` (constructor) | constructor | B | Create the canvas from a layout, a highlight and a tap callback. |
| [`build`](#canvasbuild) | method (widget, `_DataSetTopologyCanvas`) | A | Device and storage boxes, the line painter, then copy boxes. |
| `place` | nested function (`_DataSetTopologyCanvas.build`) | B | Position one box at its rect. |
| `_DataSetTopologyBox` (constructor) | constructor | B | Create one box: node, label, selected, dimmed, tap. |
| [`build`](#boxbuild) | method (widget, `_DataSetTopologyBox`) | A | A framed device/storage box or a filled copy chip, with semantics and dimming. |
| `_frame` | method (widget helper, `_DataSetTopologyBox`) | B | A framed container whose header strip alone takes the tap. |
| `_DataSetLinkPainter` (constructor) | constructor | B | Create the painter. |
| [`paint`](#paint) | method (`_DataSetLinkPainter`) | A | Draw each link as a soft curve with end dots, the lit ones last. |
| `shouldRepaint` | method (`_DataSetLinkPainter`) | B | Repaint when the layout, the selection or the scheme changed. |
| `_DataSetTopologyDetails` (constructor) | constructor | B | Create the details for a box. |
| [`build`](#detailsbuild) | method (widget, `_DataSetTopologyDetails`) | A | The box's header, then one card per data set on it. |
| `_buildDataSetCard` | method (widget helper, `_DataSetTopologyDetails`) | B | A data set's copies as "device – storage", with an edit button. |
| `_isHere` | method (`_DataSetTopologyDetails`) | B | Whether a copy lies on the selected box. |

Row count (30) matches `grep -c 'Purpose:' dataset_topology_page.dart` (30) exactly.

## Documentation

### `Color dataSetTopologyColor(ColorScheme cs, String dataSetId)` <a id="datasettopologycolor"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/datasets/views/dataset_topology_page.dart` (line 30).
- **Purpose:** Pick the colour of a data set's copies and sync lines.
- **Inputs:** `cs`, `dataSetId`.
- **Returns:** One of eight palette colours (scheme primary and tertiary, teal, indigo, orange,
  pink, green, purple), indexed by a 31-multiplier hash of the id.
- **Side effects:** None.
- **Algorithm:** `hash = (hash × 31 + unit) & 0x7fffffff` over the code units; `palette[hash % 8]`.
- **Usage:** Copy boxes and `_DataSetLinkPainter`.
- **Notes:** Stable across launches and devices (unlike `String.hashCode`). The error colour is
  not in the palette; it marks single-copy data sets.

### `DataSetTopologyLayout _layoutFor(double width)` <a id="layoutfor"></a>
- **Kind:** method of `_DataSetTopologyPageState`.
- **Source:** `lib/features/datasets/views/dataset_topology_page.dart` (line 123).
- **Purpose:** Return the layout for the canvas width.
- **Inputs:** `width`.
- **Returns:** `DataSetTopologyLayout`.
- **Side effects:** Caches it in `_cache`.
- **Algorithm:** Reuse the cache when the data lists and the filter set are identical, the
  empty-device switch is equal and the rounded width matches; otherwise
  [`DataSetTopologyLayout.build`](../services/dataset_topology.md#build).
- **Usage:** The canvas `LayoutBuilder` in `build`.
- **Notes:** The layout is cheap (no routing), so it runs synchronously; the cache only keeps a
  selection, pan or zoom from rebuilding it.

### `Widget build(BuildContext context)` (`_DataSetTopologyPageState`) <a id="build"></a>
- **Kind:** method (widget build).
- **Source:** `lib/features/datasets/views/dataset_topology_page.dart` (line 339).
- **Purpose:** Build the page.
- **Inputs:** `context`.
- **Returns:** The widget tree.
- **Side effects:** Fills the layout cache.
- **Algorithm:** 1. App bar: the device filter with a badge counting chosen devices, the "Show
  devices without data sets" toggle (resets the transform), export (disabled while exporting or
  with nothing drawn). 2. A column of `TopologyViewControls`, the legend strip and the canvas: the
  empty message when the layout is empty, else a `TopologyCanvasViewer` with
  `onBackgroundTap: _clearSelection` around a `RepaintBoundary` (export) and the canvas. 3. On
  `useDetailTwoPane` windows a pane of `topologyDetailPaneWidth` on the right: a hint, or the
  selected box's details with a close button.
- **Usage:** Framework.
- **Notes:** The pane is always present, so a selection never changes the canvas width.

### `Widget build(BuildContext context)` (`_DataSetTopologyCanvas`) <a id="canvasbuild"></a>
- **Kind:** method (widget build).
- **Source:** `lib/features/datasets/views/dataset_topology_page.dart` (line 637).
- **Purpose:** Build the boxes and lines.
- **Inputs:** `context`.
- **Returns:** A `Stack` at `layout.size`.
- **Side effects:** None.
- **Algorithm:** Device and storage boxes, then an `IgnorePointer` `CustomPaint` with the link
  painter, then copy boxes — so a line never covers a copy. Each box is dimmed when a highlight
  leaves it out and selected when it is the highlight's box.
- **Usage:** Inside the viewer in [`build`](#build).
- **Notes:** None.

### `Widget build(BuildContext context)` (`_DataSetTopologyBox`) <a id="boxbuild"></a>
- **Kind:** method (widget build).
- **Source:** `lib/features/datasets/views/dataset_topology_page.dart` (line 715).
- **Purpose:** Render one box.
- **Inputs:** `context`.
- **Returns:** The widget tree.
- **Side effects:** None.
- **Algorithm:** Device: a framed box with a 44 px header (category icon, name). Storage: a
  framed, darker box with a 34 px header (storage icon, label). Copy: a filled chip in the data
  set's colour (error colours for a single copy) with the label and an `×n` badge. Wrapped in
  `Semantics` (label, kind or copy count, button, selected), `Opacity` for dimming and a
  `Tooltip`.
- **Usage:** `place` in the canvas.
- **Notes:** Device and storage boxes take taps only on their header (`_frame`), so a tap in a
  box's body reaches the copy there, or the background.

### `void paint(Canvas canvas, Size size)` (`_DataSetLinkPainter`) <a id="paint"></a>
- **Kind:** method of `_DataSetLinkPainter`.
- **Source:** `lib/features/datasets/views/dataset_topology_page.dart` (line 885).
- **Purpose:** Paint the sync lines.
- **Inputs:** `canvas`, `size`.
- **Returns:** None.
- **Side effects:** Draws.
- **Algorithm:** Unlit links first, lit ones last. Copies side by side: a horizontal cubic from
  the facing sides. Copies in one column: a cubic leaving and entering on the right, bowed out by
  `28 + 0.1 × Δy`. Lit lines 3.2 px at full alpha, others 2.2 px at 0.7, dimmed ones at
  `topologyDimmedEdgeAlpha`; a 3.5 px dot at each end.
- **Usage:** The canvas's `CustomPaint`.
- **Notes:** None.

### `Widget build(BuildContext context)` (`_DataSetTopologyDetails`) <a id="detailsbuild"></a>
- **Kind:** method (widget build).
- **Source:** `lib/features/datasets/views/dataset_topology_page.dart` (line 984).
- **Purpose:** Render the selected box's details.
- **Inputs:** `context`.
- **Returns:** A `ListView`.
- **Side effects:** None.
- **Algorithm:** A header tile (device icon / storage icon / emoji; the name; the category,
  device name or copy count; a close button in the pane). Then the data sets on the box — only
  its own for a copy — as cards: emoji, name, edit button, "Copies · n copies" (or *Only one
  copy* in the error colour) and one row per copy, ticked when on the selected box; *No data
  sets* when there are none.
- **Usage:** The sheet and the pane.
- **Notes:** None.
