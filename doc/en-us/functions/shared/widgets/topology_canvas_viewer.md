# lib/shared/widgets/topology_canvas_viewer.dart

The one pan-and-zoom surface both full-screen topologies draw on (since 1.8.0):
[`service_topology_page.md`](../../features/services/views/service_topology_page.md) and
[`dataset_topology_page.md`](../../features/datasets/views/dataset_topology_page.md). Before
1.8.0 the service topology had two modes — a scroll view that took taps and an
`InteractiveViewer` that dropped them. A tap and a drag never compete for the same gesture, so
`TopologyCanvasViewer` does both in one mode:

- a **tap** reaches the node under it, or `onBackgroundTap` on empty canvas;
- a **drag** pans and a **pinch** (touch or trackpad) zooms about the fingers;
- the **mouse wheel** pans (Shift turns a vertical wheel sideways), **Ctrl or Cmd + wheel** zooms
  about the cursor, and a platform `PointerScaleEvent` zooms by its scale.

The viewer is built directly on a `GestureDetector` and a `Transform`, not on `InteractiveViewer`,
because `InteractiveViewer` always zooms on the mouse wheel. Every input goes through
`_apply`, which clamps the scale to 0.35–2.4 and the translation with
`clampTopologyTranslation`. `TopologyViewControls` is the row of zoom out, zoom in, Fit and
Reset icon buttons plus a gesture-hint tooltip, so keyboard and screen-reader users can zoom
without a gesture. `fitTransform` moved here from `service_topology_widgets.dart`, which still
re-exports it.

Public constants (documented in source, not listed): `topologyMinScale` (0.35),
`topologyMaxScale` (2.4), `topologyBoundaryMargin` (180), `topologyZoomStep` (1.25); private
`_wheelZoomDivisor` (200, the same wheel-to-zoom ratio `InteractiveViewer` uses).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`fitTransform`](#fittransform) | top-level function | A | The transform that fits a canvas into a viewer within its zoom limits and pan margin. |
| `offset` | nested function (`fitTransform`) | B | The scaled canvas's offset on one axis: centred when it keeps the viewer in bounds, else 0. |
| `topologyTransform` | top-level function | B | The matrix for a uniform scale and a translation. |
| [`clampTopologyTranslation`](#clamptopologytranslation) | top-level function | A | Keep a translation inside the pan limits. |
| `axis` | nested function (`clampTopologyTranslation`) | B | Clamp one axis. |
| `TopologyCanvasViewer` (constructor) | constructor | B | Create the viewer: canvas size, child, controller, background tap, limits. |
| `createState` | method (`TopologyCanvasViewer`) | B | Create the public `TopologyCanvasViewerState`, so a page can call `fit`/`zoomBy`/`reset` through a key. |
| `_controller` | getter (`TopologyCanvasViewerState`) | B | The widget's controller, or a private one created on first use. |
| `dispose` | method (`TopologyCanvasViewerState`) | B | Dispose the private controller only. |
| `_scale` | getter (`TopologyCanvasViewerState`) | B | The current scale. |
| `_translation` | getter (`TopologyCanvasViewerState`) | B | The current translation. |
| `_apply` | method (`TopologyCanvasViewerState`) | B | Write a clamped transform; every input goes through it. |
| [`zoomBy`](#zoomby) | method (`TopologyCanvasViewerState`) | A | Zoom about a viewport point, the centre by default. |
| `fit` | method (`TopologyCanvasViewerState`) | B | Set `fitTransform` for the canvas and viewport. |
| `reset` | method (`TopologyCanvasViewerState`) | B | Return to the identity: 1:1 at the canvas's top-left. |
| `_onScaleStart` | method (`TopologyCanvasViewerState`) | B | Remember the transform and focal point a gesture starts from. |
| [`_onScaleUpdate`](#onscaleupdate) | method (`TopologyCanvasViewerState`) | A | Pan and zoom with a drag or pinch, keeping the canvas point under the focal point. |
| `_onScaleEnd` | method (`TopologyCanvasViewerState`) | B | Forget the gesture; no fling. |
| [`_onPointerSignal`](#onpointersignal) | method (`TopologyCanvasViewerState`) | A | Wheel pans, Shift + wheel pans sideways, Ctrl/Cmd + wheel zooms. |
| [`build`](#build) | method (widget, `TopologyCanvasViewerState`) | A | The `Listener` → `GestureDetector` → `ClipRect` → `OverflowBox` → `Transform` stack. |
| `TopologyViewControls` (constructor) | constructor | B | Create the control row from four callbacks. |
| `build` | method (widget, `TopologyViewControls`) | B | Zoom out, zoom in, Fit, Reset and the gesture hint (keys `topology-zoom-out`, `topology-zoom-in`, `topology-fit`, `topology-reset`, `topology-gesture-hint`). |

Row count (22) matches `grep -c 'Purpose:' topology_canvas_viewer.dart` (22) exactly.

## Documentation

### `Matrix4 fitTransform(Size canvas, Size viewport, {required double minScale, required double maxScale, double boundaryMargin = 0})` <a id="fittransform"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/widgets/topology_canvas_viewer.dart` (line 38).
- **Purpose:** Compute the transform that fits a canvas into the viewer.
- **Inputs:** `canvas` — the child as the viewer lays it out (turned when the canvas is rotated);
  `viewport` — the viewer's size; `minScale`, `maxScale` — the zoom limits; `boundaryMargin` —
  the margin around the child.
- **Returns:** `Matrix4` — a uniform scale on all three axes and a translation; the identity for
  an empty canvas or viewport.
- **Side effects:** None.
- **Algorithm:** 1. `scale = min(viewport.width / canvas.width, viewport.height /
  canvas.height)`, clamped to the limits. 2. Per axis (`offset`): no room ⇒ 0; room ⇒ centred
  when half the room is at most `boundaryMargin × scale`, else 0. 3.
  `Matrix4.diagonal3Values(scale, scale, scale)` with that translation.
- **Usage:** `TopologyCanvasViewerState.fit`.
- **Notes:** Moved from `service_topology_widgets.dart` in 1.8.0, unchanged; that file
  re-exports it. The scale goes on the z axis too because the viewer reads its zoom back with
  `getMaxScaleOnAxis`. `test/service_topology_page_test.dart` pins the tighter axis, both limits,
  the margin rule and the empty cases.

### `Offset clampTopologyTranslation(double scale, Offset translation, {required Size canvas, required Size viewport, double margin})` <a id="clamptopologytranslation"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/widgets/topology_canvas_viewer.dart` (line 88).
- **Purpose:** Keep a transform's translation inside the pan limits.
- **Inputs:** `scale`, `translation` — the candidate; `canvas`, `viewport`; `margin` — defaults
  to `topologyBoundaryMargin`.
- **Returns:** The clamped translation.
- **Side effects:** None.
- **Algorithm:** Per axis, `lo = min(view − (child + margin) × scale, 0)` and
  `hi = max(margin × scale, view − child × scale)`; clamp to `[lo, hi]`.
- **Usage:** `_apply`.
- **Notes:** A canvas larger than the viewport may be panned until the margin beyond its edge
  reaches the viewport's edge, as `InteractiveViewer` allows; a smaller one may sit anywhere it is
  fully visible. The canvas can never be panned out of sight. `test/topology_canvas_viewer_test.dart`
  pins both cases.

### `void zoomBy(double factor, {Offset? focal})` <a id="zoomby"></a>
- **Kind:** method of `TopologyCanvasViewerState`.
- **Source:** `lib/shared/widgets/topology_canvas_viewer.dart` (line 226).
- **Purpose:** Zoom about a point of the viewport.
- **Inputs:** `factor` — multiplies the scale; `focal` — the viewport point that stays put, the
  viewport centre when null.
- **Returns:** `void`.
- **Side effects:** Sets the controller's value.
- **Algorithm:** `scene = (focal − t) / s0`; `s1 = clamp(s0 × factor)`; apply
  `(s1, focal − scene × s1)`.
- **Usage:** The zoom buttons (through the page's view key, with `topologyZoomStep` or its
  inverse) and Ctrl + wheel.
- **Notes:** None.

### `void _onScaleUpdate(ScaleUpdateDetails details)` <a id="onscaleupdate"></a>
- **Kind:** method of `TopologyCanvasViewerState`.
- **Source:** `lib/shared/widgets/topology_canvas_viewer.dart` (line 273).
- **Purpose:** Pan and zoom with a drag or a pinch.
- **Inputs:** `details`.
- **Returns:** `void`.
- **Side effects:** Sets the controller's value.
- **Algorithm:** From the transform saved at the gesture's start: `s1 = clamp(s0 ×
  details.scale)`; the scene point under the starting focal point is placed under the current
  focal point.
- **Usage:** The `GestureDetector`'s `onScaleUpdate`; a one-finger drag reports scale 1, so it
  only pans.
- **Notes:** Computed from the start rather than incrementally, so rounding never drifts. A
  trackpad pinch arrives as a pan-zoom gesture and goes through here too. The recognizer claims a
  drag only after the touch slop, so the first few pixels of a drag do not move the canvas, and a
  short tap still reaches the node.

### `void _onPointerSignal(PointerSignalEvent event)` <a id="onpointersignal"></a>
- **Kind:** method of `TopologyCanvasViewerState`.
- **Source:** `lib/shared/widgets/topology_canvas_viewer.dart` (line 298).
- **Purpose:** Handle the mouse wheel and platform zoom signals.
- **Inputs:** `event`.
- **Returns:** `void`.
- **Side effects:** Registers with `GestureBinding.instance.pointerSignalResolver`; pans or zooms.
- **Algorithm:** A `PointerScaleEvent` zooms by `event.scale` at the pointer. A
  `PointerScrollEvent` with Ctrl or Cmd held zooms by `exp(−dy / 200)` at the pointer; otherwise
  it pans by `−scrollDelta`, with a vertical-only delta turned sideways while Shift is held.
- **Usage:** The outer `Listener`'s `onPointerSignal`.
- **Notes:** Going through the resolver means an enclosing scrollable does not also scroll.
  `test/topology_canvas_viewer_test.dart` pins the wheel pan, Shift, and Ctrl zooming about the
  cursor.

### `Widget build(BuildContext context)` (`TopologyCanvasViewerState`) <a id="build"></a>
- **Kind:** method (widget build) of `TopologyCanvasViewerState`.
- **Source:** `lib/shared/widgets/topology_canvas_viewer.dart` (line 326).
- **Purpose:** Build the viewer.
- **Inputs:** `context`.
- **Returns:** The widget tree.
- **Side effects:** Remembers the viewport size for `fit`, `zoomBy` and clamping.
- **Algorithm:** `LayoutBuilder` → `Listener(onPointerSignal)` → an opaque `GestureDetector`
  (`onTap: onBackgroundTap` and the scale callbacks) → `ClipRect` → a top-left, unconstrained
  `OverflowBox` → an `AnimatedBuilder` on the controller with a `Transform` → the child at
  `canvasSize`.
- **Usage:** Both topology pages.
- **Notes:** Node cards' own tap recognizers win the arena over the background tap, so only taps
  that miss every card reach `onBackgroundTap`. Hit testing follows the `Transform`, so a node
  is tappable wherever it is drawn.
