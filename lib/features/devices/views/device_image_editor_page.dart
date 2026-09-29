import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/utils/device_image_processing.dart';

/// Runs one edit and returns the encoded PNG.
typedef DeviceImageProcessor =
    Future<Uint8List> Function(DeviceImageEditRequest request);

/// Purpose: Run [processDeviceImage] off the UI isolate.
/// Inputs: `request`.
/// Returns: The PNG bytes.
/// Side effects: Spawns a short-lived isolate.
/// Notes: The default [DeviceImageProcessor]; tests pass a synchronous one.
Future<Uint8List> processDeviceImageInIsolate(DeviceImageEditRequest request) =>
    Isolate.run(() => processDeviceImage(request));

/// What the image editor hands back.
class DeviceImageEditorResult {
  /// The edited PNG, or null when the user chose to keep the original.
  final Uint8List? png;

  /// Purpose: Create an image editor result instance.
  /// Inputs: `png` — the edited image, or null for "use the original".
  /// Returns: A new `DeviceImageEditorResult` instance.
  /// Side effects: None.
  /// Notes: A cancelled editor returns null instead of a result.
  const DeviceImageEditorResult(this.png);

  /// Purpose: Tell whether the user chose to keep the original file.
  /// Inputs: None.
  /// Returns: True when no edited PNG was produced.
  /// Side effects: None.
  /// Notes: Only offered when adding a newly picked photo.
  bool get keepOriginal => png == null;
}

/// Purpose: Open the image editor on a file and wait for the user.
/// Inputs: `context`; `file` — the image to edit; `allowOriginal` — offer
/// "Use original" (true when adding a newly picked photo).
/// Returns: The result, or null when cancelled or when the file cannot be
/// decoded and `allowOriginal` is false.
/// Side effects: Decodes the file; pushes a full-screen route; may show a
/// snack bar.
/// Notes: A file the decoders refuse is returned as "keep original" when
/// that is allowed, so a format the editor cannot read never blocks adding
/// the photo.
Future<DeviceImageEditorResult?> showDeviceImageEditor(
  BuildContext context,
  File file, {
  bool allowOriginal = false,
  DeviceImageProcessor processor = processDeviceImageInIsolate,
}) async {
  final request = await ImageService.loadEditableImage(file);
  if (!context.mounted) return null;
  if (request == null) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(l10n.imageEditorDecodeFailed)));
    return allowOriginal ? const DeviceImageEditorResult(null) : null;
  }
  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => DeviceImageEditorPage(
        source: request,
        displayBytes: bytes,
        allowOriginal: allowOriginal,
        processor: processor,
      ),
    ),
  );
}

/// Full-screen editor that crops a photo, removes a plain background and
/// fits the device into the avatar circle.
class DeviceImageEditorPage extends StatefulWidget {
  /// Decoded source pixels with default settings.
  final DeviceImageEditRequest source;

  /// Encoded bytes shown in the crop area (same pixels as [source]).
  final Uint8List displayBytes;
  final bool allowOriginal;
  final DeviceImageProcessor processor;

  /// Purpose: Create a device image editor page instance.
  /// Inputs: `source`, `displayBytes`, `allowOriginal` and `processor`.
  /// Returns: A new `DeviceImageEditorPage` instance.
  /// Side effects: None.
  /// Notes: Pops with a [DeviceImageEditorResult], or null on cancel.
  const DeviceImageEditorPage({
    super.key,
    required this.source,
    required this.displayBytes,
    this.allowOriginal = false,
    this.processor = processDeviceImageInIsolate,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<DeviceImageEditorPage> createState() => DeviceImageEditorPageState();
}

/// State of [DeviceImageEditorPage]; public so tests can read the request.
class DeviceImageEditorPageState extends State<DeviceImageEditorPage> {
  /// Longest source side and output size used for the live preview; the
  /// final image is made at the request's own (larger) sizes.
  static const previewMaxSource = 384;
  static const previewOutputSize = 256;
  static const roundRectFraction = 0.12;

  final _transform = TransformationController();
  late DeviceImageEditRequest _request;
  Uint8List? _preview;
  bool _processing = false;
  bool _saving = false;
  Timer? _debounce;
  int _generation = 0;
  double _cropSide = 0;

  /// Purpose: Expose the settings the editor would apply now.
  /// Inputs: None.
  /// Returns: The current `DeviceImageEditRequest`.
  /// Side effects: None.
  /// Notes: Read by widget tests.
  DeviceImageEditRequest get request => _request;

  /// Purpose: Start from the source's defaults and render a first preview.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Schedules processing.
  /// Notes: None.
  @override
  void initState() {
    super.initState();
    _request = widget.source;
    _schedulePreview(immediate: true);
  }

  /// Purpose: Release the debounce timer and transform controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels pending work.
  /// Notes: A preview finishing after dispose is ignored.
  @override
  void dispose() {
    _debounce?.cancel();
    _transform.dispose();
    super.dispose();
  }

  /// Purpose: Change the settings and refresh the preview.
  /// Inputs: `next` — the new request.
  /// Returns: None.
  /// Side effects: Rebuilds; schedules processing.
  /// Notes: Internal helper used within this file only.
  void _update(DeviceImageEditRequest next) {
    setState(() => _request = next);
    _schedulePreview();
  }

  /// Purpose: Debounce and run a small preview of the current settings.
  /// Inputs: `immediate` — skip the debounce.
  /// Returns: None.
  /// Side effects: Runs the processor; updates the preview.
  /// Notes: A generation counter drops results that a newer change has
  /// already superseded. Internal helper used within this file only.
  void _schedulePreview({bool immediate = false}) {
    _debounce?.cancel();
    Future<void> run() async {
      final generation = ++_generation;
      setState(() => _processing = true);
      try {
        final png = await widget.processor(
          _request.copyWith(
            maxSource: previewMaxSource,
            outputSize: previewOutputSize,
          ),
        );
        if (!mounted || generation != _generation) return;
        setState(() {
          _preview = png;
          _processing = false;
        });
      } catch (_) {
        if (mounted && generation == _generation) {
          setState(() => _processing = false);
        }
      }
    }

    if (immediate) {
      run();
    } else {
      _debounce = Timer(const Duration(milliseconds: 150), run);
    }
  }

  /// Purpose: Read the crop area's pan and zoom into a source region.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Updates the request.
  /// Notes: The image is shown `contain`-fitted in a square of side
  /// `_cropSide`; the visible part of that square becomes the crop, as
  /// fractions of the image. An untouched view keeps the whole image.
  /// Internal helper used within this file only.
  void _onCropChanged() {
    final side = _cropSide;
    if (side <= 0) return;
    final m = _transform.value;
    if (m.isIdentity()) {
      _update(_request.copyWith(clearCrop: true));
      return;
    }
    final k = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final iw = _request.width.toDouble(), ih = _request.height.toDouble();
    final f = side / math.max(iw, ih);
    final dw = iw * f, dh = ih * f;
    final ox = (side - dw) / 2, oy = (side - dh) / 2;
    final left = -t.x / k, top = -t.y / k, visible = side / k;
    _update(
      _request.copyWith(
        crop: ((left - ox) / dw, (top - oy) / dh, visible / dw, visible / dh),
      ),
    );
  }

  /// Purpose: Put every setting and the crop back to the defaults.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Resets the transform and the request.
  /// Notes: Internal helper used within this file only.
  void _reset() {
    _transform.value = Matrix4.identity();
    _update(widget.source);
  }

  /// Purpose: Make the full-size image and close the editor with it.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Runs the processor; pops the route.
  /// Notes: Internal helper used within this file only.
  Future<void> _use() async {
    setState(() => _saving = true);
    try {
      final png = await widget.processor(_request);
      if (!mounted) return;
      Navigator.of(context).pop(DeviceImageEditorResult(png));
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Purpose: Build the editor.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: Wide windows put the crop area beside the preview and controls;
  /// narrow ones stack them.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.imageEditorTitle),
        actions: [
          if (widget.allowOriginal)
            TextButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(const DeviceImageEditorResult(null)),
              child: Text(l10n.imageEditorUseOriginal),
            ),
          TextButton(
            key: const ValueKey('imageEditorUse'),
            onPressed: _saving ? null : _use,
            child: Text(l10n.imageEditorUse),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final crop = _buildCropArea(
            context,
            math.min(
              wide ? constraints.maxWidth / 2 - 32 : constraints.maxWidth - 32,
              420,
            ),
          );
          final side = Column(
            children: [
              _buildPreview(context),
              const SizedBox(height: 8),
              _buildControls(context, l10n),
            ],
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: crop),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: side,
                  ),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPreview(context),
                const SizedBox(height: 12),
                Center(child: crop),
                const SizedBox(height: 8),
                _buildControls(context, l10n),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Purpose: Build the pan-and-zoom crop area.
  /// Inputs: `context`; `side` — the square's edge length.
  /// Returns: `Widget`.
  /// Side effects: Records the edge length for crop maths.
  /// Notes: A circle outline shows where the avatar will clip. Internal
  /// helper used within this file only.
  Widget _buildCropArea(BuildContext context, double side) {
    _cropSide = side;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: side,
          height: side,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: cs.surfaceContainerHighest),
                ),
                InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 8,
                  boundaryMargin: EdgeInsets.all(side / 2),
                  onInteractionEnd: (_) => _onCropChanged(),
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: Image.memory(
                      widget.displayBytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    size: Size.square(side),
                    painter: _CircleGuidePainter(cs.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context)!.imageEditorCropHint,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Purpose: Show the result the way the device list will.
  /// Inputs: `context`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: A large circle and a list-sized one, on the avatar's own fill
  /// colour. Internal helper used within this file only.
  Widget _buildPreview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget circle(double size) => SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant.withAlpha(140)),
        ),
        child: ClipOval(
          child: _preview == null
              ? const SizedBox.shrink()
              : Image.memory(
                  _preview!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
        ),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            circle(160),
            if (_processing || _saving)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
          ],
        ),
        const SizedBox(width: 16),
        circle(48),
      ],
    );
  }

  /// Purpose: Build the setting controls.
  /// Inputs: `context`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: Controls update the request.
  /// Notes: The rounded-corner mask replaces background removal, so the
  /// background switch is disabled while it is on. Internal helper used
  /// within this file only.
  Widget _buildControls(BuildContext context, AppLocalizations l10n) {
    final rounded = _request.roundRect != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('imageEditorRemoveBackground'),
          title: Text(l10n.imageEditorRemoveBackground),
          subtitle: Text(l10n.imageEditorRemoveBackgroundDesc),
          value: _request.removeBackground && !rounded,
          onChanged: rounded
              ? null
              : (v) => _update(_request.copyWith(removeBackground: v)),
        ),
        if (_request.removeBackground && !rounded)
          _labeledSlider(
            label: l10n.imageEditorTolerance,
            value: _request.tolerance.toDouble(),
            min: 4,
            max: 96,
            divisions: 23,
            display: '${_request.tolerance}',
            onChanged: (v) => _update(_request.copyWith(tolerance: v.round())),
          ),
        SwitchListTile(
          key: const ValueKey('imageEditorRoundedCorners'),
          title: Text(l10n.imageEditorRoundedCorners),
          subtitle: Text(l10n.imageEditorRoundedCornersDesc),
          value: rounded,
          onChanged: (v) => _update(
            v
                ? _request.copyWith(roundRect: roundRectFraction)
                : _request.copyWith(clearRoundRect: true),
          ),
        ),
        _labeledSlider(
          key: const ValueKey('imageEditorScale'),
          label: l10n.imageEditorSizeInCircle,
          value: _request.scale,
          min: 0.4,
          max: 1.0,
          divisions: 12,
          display: '${(_request.scale * 100).round()}%',
          onChanged: (v) => _update(_request.copyWith(scale: v)),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.imageEditorReset),
          ),
        ),
      ],
    );
  }

  /// Purpose: Build a slider row with a label and its current value.
  /// Inputs: The slider's `label`, `value`, range, `divisions`, the
  /// `display` text and `onChanged`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _labeledSlider({
    Key? key,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            flex: 5,
            child: Slider(
              key: key,
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              label: display,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 48, child: Text(display, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _CircleGuidePainter extends CustomPainter {
  final Color color;

  /// Purpose: Create a circle guide painter instance.
  /// Inputs: `color` of the outline.
  /// Returns: A new `_CircleGuidePainter` instance.
  /// Side effects: None.
  /// Notes: None.
  _CircleGuidePainter(this.color);

  /// Purpose: Dim the corners and outline the avatar circle.
  /// Inputs: `canvas`, `size`.
  /// Returns: None.
  /// Side effects: Paints on the canvas.
  /// Notes: None.
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = Path()..addOval(rect.deflate(1));
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      circle,
    );
    canvas.drawPath(outside, Paint()..color = Colors.black.withAlpha(60));
    canvas.drawPath(
      circle,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Purpose: Repaint only when the outline colour changes.
  /// Inputs: `oldDelegate`.
  /// Returns: Whether to repaint.
  /// Side effects: None.
  /// Notes: None.
  @override
  bool shouldRepaint(_CircleGuidePainter oldDelegate) =>
      oldDelegate.color != color;
}
