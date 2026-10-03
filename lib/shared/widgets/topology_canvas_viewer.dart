import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// Smallest zoom a topology canvas allows.
const topologyMinScale = 0.35;

/// Largest zoom a topology canvas allows.
const topologyMaxScale = 2.4;

/// How far, in canvas pixels, a topology canvas can be panned past its edges.
const topologyBoundaryMargin = 180.0;

/// Zoom factor of one press of a zoom button.
const topologyZoomStep = 1.25;

/// Mouse-wheel delta that zooms by a factor of e with Ctrl held; the same
/// ratio `InteractiveViewer` uses.
const _wheelZoomDivisor = 200.0;

/// Purpose: Compute a transform that fits a canvas into a viewport.
/// Inputs: `canvas` — the canvas size as the viewer sees it (swapped if the
/// canvas is rotated); `viewport` — the viewer's size; `minScale`,
/// `maxScale` — the viewer's zoom limits; `boundaryMargin` — the viewer's
/// margin around the child.
/// Returns: `Matrix4` — a uniform scale (on all three axes, so
/// `getMaxScaleOnAxis` reads it back) and a translation for the viewer's
/// `TransformationController`; the identity for an empty canvas or viewport.
/// Side effects: None.
/// Notes: The scale is the smaller of the two axis ratios clamped to the
/// limits, so the whole graph shows whenever the limits allow. On an axis the
/// scaled canvas leaves room on, it is centred if that keeps the viewport
/// inside the child plus `boundaryMargin`, and placed at the start otherwise.
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

/// Purpose: Build the transform for a scale and a translation.
/// Inputs: `scale`, `translation`.
/// Returns: `Matrix4` — uniform scale on all three axes plus the translation.
/// Side effects: None.
/// Notes: The one matrix shape the topology viewer writes and reads.
Matrix4 topologyTransform(double scale, Offset translation) =>
    Matrix4.diagonal3Values(scale, scale, scale)
      ..setTranslationRaw(translation.dx, translation.dy, 0);

/// Purpose: Keep a transform's translation inside the pan limits.
/// Inputs: `scale`, `translation` — the candidate transform; `canvas`,
/// `viewport` — sizes in logical pixels; `margin` — `boundaryMargin`.
/// Returns: The clamped translation.
/// Side effects: None.
/// Notes: A canvas larger than the viewport may be panned until the margin
/// beyond its edge reaches the viewport's edge, as `InteractiveViewer`
/// allows; a smaller one may sit anywhere it is fully visible. Either way the
/// canvas can never be panned out of sight.
Offset clampTopologyTranslation(
  double scale,
  Offset translation, {
  required Size canvas,
  required Size viewport,
  double margin = topologyBoundaryMargin,
}) {
  /// Purpose: Clamp one axis.
  /// Inputs: `t` — the offset; `view` — viewport extent; `child` — canvas extent.
  /// Returns: `double`.
  /// Side effects: None.
  /// Notes: Local helper of [clampTopologyTranslation].
  double axis(double t, double view, double child) {
    final lo = math.min(view - (child + margin) * scale, 0.0);
    final hi = math.max(margin * scale, view - child * scale);
    return t.clamp(lo, hi).toDouble();
  }

  return Offset(
    axis(translation.dx, viewport.width, canvas.width),
    axis(translation.dy, viewport.height, canvas.height),
  );
}

/// The pan-and-zoom surface both topology pages draw their canvas on.
///
/// One mode for everything: a tap reaches the node under it (or
/// [onBackgroundTap] on empty canvas), a drag pans, a pinch — touch or
/// trackpad — zooms about the fingers, the mouse wheel pans (Shift for
/// sideways) and Ctrl + wheel zooms about the cursor.
class TopologyCanvasViewer extends StatefulWidget {
  final Size canvasSize;
  final Widget child;
  final TransformationController? controller;
  final VoidCallback? onBackgroundTap;
  final double minScale;
  final double maxScale;
  final double boundaryMargin;

  /// Purpose: Create the viewer.
  /// Inputs: `canvasSize` — the child's size as drawn (rotated if rotated);
  /// `child` — the canvas, laid out at `canvasSize`; `controller` — the
  /// transform, owned by the page so it can reset it (a private one when
  /// null); `onBackgroundTap` — a tap that hits no node; `minScale`,
  /// `maxScale`, `boundaryMargin` — the limits.
  /// Returns: A new `TopologyCanvasViewer`.
  /// Side effects: None.
  /// Notes: The identity transform shows the canvas at 1:1 from its top-left.
  const TopologyCanvasViewer({
    super.key,
    required this.canvasSize,
    required this.child,
    this.controller,
    this.onBackgroundTap,
    this.minScale = topologyMinScale,
    this.maxScale = topologyMaxScale,
    this.boundaryMargin = topologyBoundaryMargin,
  });

  /// Purpose: Create the mutable state object.
  /// Inputs: None.
  /// Returns: A new `TopologyCanvasViewerState`.
  /// Side effects: None.
  /// Notes: Public so a page can call `fit`, `zoomBy` and `reset` through a
  /// `GlobalKey`.
  @override
  State<TopologyCanvasViewer> createState() => TopologyCanvasViewerState();
}

class TopologyCanvasViewerState extends State<TopologyCanvasViewer> {
  TransformationController? _own;
  Size _viewport = Size.zero;

  /// The transform and focal point a pinch or drag started from.
  Matrix4? _gestureStart;
  Offset _gestureFocal = Offset.zero;

  /// Purpose: Return the controller in use.
  /// Inputs: None.
  /// Returns: The widget's controller, or a private one.
  /// Side effects: Creates the private controller on first use.
  /// Notes: None.
  TransformationController get _controller =>
      widget.controller ?? (_own ??= TransformationController());

  /// Purpose: Release the private controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes `_own`.
  /// Notes: A page-owned controller is the page's to dispose.
  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  /// Purpose: Read the current scale.
  /// Inputs: None.
  /// Returns: `double`.
  /// Side effects: None.
  /// Notes: The viewer only writes uniform scales.
  double get _scale => _controller.value.getMaxScaleOnAxis();

  /// Purpose: Read the current translation.
  /// Inputs: None.
  /// Returns: `Offset`.
  /// Side effects: None.
  /// Notes: None.
  Offset get _translation {
    final t = _controller.value.getTranslation();
    return Offset(t.x, t.y);
  }

  /// Purpose: Write a clamped transform.
  /// Inputs: `scale`, `translation`.
  /// Returns: `void`.
  /// Side effects: Sets the controller's value.
  /// Notes: Every gesture, wheel event and button goes through here.
  void _apply(double scale, Offset translation) {
    final s = scale.clamp(widget.minScale, widget.maxScale).toDouble();
    _controller.value = topologyTransform(
      s,
      clampTopologyTranslation(
        s,
        translation,
        canvas: widget.canvasSize,
        viewport: _viewport,
        margin: widget.boundaryMargin,
      ),
    );
  }

  /// Purpose: Zoom about a point of the viewport.
  /// Inputs: `factor` — multiplies the scale; `focal` — the viewport point
  /// that stays put; the viewport centre when null.
  /// Returns: `void`.
  /// Side effects: Sets the controller's value.
  /// Notes: Called by the zoom buttons and Ctrl + wheel.
  void zoomBy(double factor, {Offset? focal}) {
    final at = focal ?? _viewport.center(Offset.zero);
    final s0 = _scale;
    final s1 = (s0 * factor).clamp(widget.minScale, widget.maxScale).toDouble();
    final scene = (at - _translation) / s0;
    _apply(s1, at - scene * s1);
  }

  /// Purpose: Fit the whole canvas into the viewport.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Sets the controller's value.
  /// Notes: Uses [fitTransform] with the viewer's limits.
  void fit() {
    _controller.value = fitTransform(
      widget.canvasSize,
      _viewport,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      boundaryMargin: widget.boundaryMargin,
    );
  }

  /// Purpose: Return to 1:1 at the canvas's top-left.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Sets the controller's value to the identity.
  /// Notes: None.
  void reset() => _controller.value = Matrix4.identity();

  /// Purpose: Remember where a drag or pinch began.
  /// Inputs: `details`.
  /// Returns: `void`.
  /// Side effects: Stores the starting transform and focal point.
  /// Notes: Updates are computed from the start, not incrementally, so
  /// rounding never drifts.
  void _onScaleStart(ScaleStartDetails details) {
    _gestureStart = _controller.value.clone();
    _gestureFocal = details.localFocalPoint;
  }

  /// Purpose: Pan and zoom with a drag or pinch.
  /// Inputs: `details`.
  /// Returns: `void`.
  /// Side effects: Sets the controller's value.
  /// Notes: The canvas point that was under the starting focal point stays
  /// under the current one.
  void _onScaleUpdate(ScaleUpdateDetails details) {
    final start = _gestureStart;
    if (start == null) return;
    final s0 = start.getMaxScaleOnAxis();
    final t0 = start.getTranslation();
    final s1 = (s0 * details.scale)
        .clamp(widget.minScale, widget.maxScale)
        .toDouble();
    final scene = (_gestureFocal - Offset(t0.x, t0.y)) / s0;
    _apply(s1, details.localFocalPoint - scene * s1);
  }

  /// Purpose: Forget the finished gesture.
  /// Inputs: `details`.
  /// Returns: `void`.
  /// Side effects: Clears `_gestureStart`.
  /// Notes: No fling; the canvas stops where the finger left it.
  void _onScaleEnd(ScaleEndDetails details) => _gestureStart = null;

  /// Purpose: Handle the mouse wheel and platform zoom signals.
  /// Inputs: `event`.
  /// Returns: `void`.
  /// Side effects: Registers with the pointer-signal resolver; pans or zooms.
  /// Notes: Wheel pans (Shift turns a vertical wheel sideways); Ctrl or Cmd +
  /// wheel zooms about the cursor. A `PointerScaleEvent` zooms by its scale.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent && event is! PointerScaleEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      if (event is PointerScaleEvent) {
        zoomBy(event.scale, focal: event.localPosition);
        return;
      }
      if (event is! PointerScrollEvent) return;
      final keys = HardwareKeyboard.instance;
      if (keys.isControlPressed || keys.isMetaPressed) {
        final dy = event.scrollDelta.dy;
        if (dy == 0) return;
        zoomBy(math.exp(-dy / _wheelZoomDivisor), focal: event.localPosition);
        return;
      }
      var delta = event.scrollDelta;
      if (keys.isShiftPressed && delta.dx == 0) delta = Offset(delta.dy, 0);
      _apply(_scale, _translation - delta);
    });
  }

  /// Purpose: Build the viewer.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: Remembers the viewport size.
  /// Notes: The transform sits inside an unconstrained `OverflowBox`, as in
  /// `InteractiveViewer`, so hit testing follows the transformed canvas.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        return Listener(
          onPointerSignal: _onPointerSignal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onBackgroundTap,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onScaleEnd: _onScaleEnd,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) =>
                      Transform(transform: _controller.value, child: child),
                  child: SizedBox.fromSize(
                    size: widget.canvasSize,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The topology view controls: zoom out, zoom in, fit, reset and a gesture
/// hint.
class TopologyViewControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;
  final VoidCallback onReset;

  /// Purpose: Create the control row.
  /// Inputs: The four button callbacks.
  /// Returns: A new `TopologyViewControls`.
  /// Side effects: None.
  /// Notes: Keys `topology-zoom-out`, `topology-zoom-in`, `topology-fit`,
  /// `topology-reset`, `topology-gesture-hint`.
  const TopologyViewControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
    required this.onReset,
  });

  /// Purpose: Build the row of icon buttons.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Icon buttons with tooltips, so keyboard and screen-reader users
  /// can zoom without a gesture.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('topology-zoom-out'),
          tooltip: l10n.topologyZoomOut,
          onPressed: onZoomOut,
          icon: const Icon(Icons.zoom_out),
        ),
        IconButton(
          key: const Key('topology-zoom-in'),
          tooltip: l10n.topologyZoomIn,
          onPressed: onZoomIn,
          icon: const Icon(Icons.zoom_in),
        ),
        IconButton(
          key: const Key('topology-fit'),
          tooltip: l10n.serviceTopologyFit,
          onPressed: onFit,
          icon: const Icon(Icons.fit_screen),
        ),
        IconButton(
          key: const Key('topology-reset'),
          tooltip: l10n.serviceTopologyReset,
          onPressed: onReset,
          icon: const Icon(Icons.restart_alt),
        ),
        Tooltip(
          key: const Key('topology-gesture-hint'),
          message: l10n.topologyGestureHint,
          triggerMode: TooltipTriggerMode.tap,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.info_outline, size: 20),
          ),
        ),
      ],
    );
  }
}
