// Device-image processing shared by the in-app image editor and the
// thumbnail tooling (`tool/prepare_device_image.dart`,
// `tool/validate_json.dart`).
//
// Pure Dart on `package:image` with no Flutter imports, so it runs inside an
// isolate and from `dart run`. The rules for bundled thumbnails (square,
// transparent, everything inside the avatar circle) live here too, so the
// app, the tools and the tests share one definition.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Edge length every thumbnail is written at.
const deviceImageSize = 256;

/// Fraction of the diameter the content is fitted into. A square this size has
/// its corners inside the circle (0.64 * sqrt(2) < 1), the same safe box
/// `TemplateIcon` uses for brand logos.
const deviceImageSafeFraction = 0.64;

/// Alpha at or below which a pixel counts as invisible.
const deviceImageAlphaThreshold = 8;

/// Purpose: Check a decoded thumbnail against the device-image rules.
/// Inputs: `image` — the decoded PNG.
/// Returns: A list of human-readable problems; empty when the image passes.
/// Side effects: None.
/// Notes: Rules: square; at least 128 px; has an alpha channel; all four
/// corners fully transparent (background removed); and no pixel with alpha
/// above [deviceImageAlphaThreshold] outside the inscribed circle, because
/// every avatar that shows the image clips it to that circle.
List<String> checkDeviceImage(img.Image image) {
  final problems = <String>[];
  if (image.width != image.height) {
    problems.add('not square (${image.width}x${image.height})');
    return problems;
  }
  if (image.width < 128) {
    problems.add('smaller than 128 px (${image.width})');
  }
  if (image.numChannels < 4) {
    problems.add('no alpha channel; background was not removed');
    return problems;
  }

  final last = image.width - 1;
  for (final (x, y) in [(0, 0), (last, 0), (0, last), (last, last)]) {
    if (image.getPixel(x, y).a != 0) {
      problems.add('corner ($x,$y) is not transparent; background remains');
      break;
    }
  }

  final centre = image.width / 2;
  final radius = image.width / 2 - 1;
  var outside = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a <= deviceImageAlphaThreshold) continue;
      final dx = x + 0.5 - centre;
      final dy = y + 0.5 - centre;
      if (dx * dx + dy * dy > radius * radius) outside++;
    }
  }
  if (outside > 0) {
    problems.add('$outside visible pixel(s) fall outside the avatar circle');
  }
  return problems;
}

/// Purpose: Run the whole thumbnail pipeline on a decoded image.
/// Inputs: `source`; `tolerance` for background colour matching;
/// `roundRect` — when set, the corner-radius fraction for
/// [applyRoundRectMask], used instead of background removal.
/// `removeBackground` — false keeps every pixel (no flood fill);
/// `maxSource` — longest side processed; `size` and `safeFraction` are
/// passed to [fitIntoCircle].
/// Returns: A new `size` square RGBA image.
/// Side effects: None.
/// Notes: Large sources are first reduced to `maxSource` px so the flood fill stays
/// fast; the output is far smaller than that anyway. The mask suits a phone
/// or tablet photographed straight on against a busy surface (wood, cloth),
/// where a flood fill cannot tell the background from the device.
img.Image prepareDeviceImage(
  img.Image source, {
  int tolerance = 28,
  double? roundRect,
  bool removeBackground = true,
  int maxSource = 1024,
  int size = deviceImageSize,
  double safeFraction = deviceImageSafeFraction,
}) {
  var work = source.convert(format: img.Format.uint8, numChannels: 4);
  final longest = math.max(work.width, work.height);
  if (longest > maxSource) {
    work = img.copyResize(
      work,
      width: work.width >= work.height ? maxSource : null,
      height: work.height > work.width ? maxSource : null,
      interpolation: img.Interpolation.average,
    );
  }
  if (roundRect != null) {
    applyRoundRectMask(work, roundRect);
  } else if (removeBackground) {
    if (!_edgesTransparent(work)) removeEdgeBackground(work, tolerance);
    removeSpecks(work);
  }
  return fitIntoCircle(work, size: size, safeFraction: safeFraction);
}

/// Purpose: Keep only a rounded rectangle filling the image.
/// Inputs: `image` (RGBA, modified in place); `radiusFraction` — the corner
/// radius as a fraction of the shorter side.
/// Returns: None.
/// Side effects: Scales alpha down outside the rounded rectangle.
/// Notes: Coverage is sampled 4×4 per pixel, so the edge is antialiased
/// rather than stair-stepped. The caller crops tightly to the device first.
void applyRoundRectMask(img.Image image, double radiusFraction) {
  final w = image.width, h = image.height;
  final r = math.min(w, h) * radiusFraction;
  double inside(double x, double y) {
    final cx = x < r ? r : (x > w - r ? w - r : x);
    final cy = y < r ? r : (y > h - r ? h - r : y);
    final dx = x - cx, dy = y - cy;
    return dx * dx + dy * dy <= r * r ? 1 : 0;
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Only pixels near a corner can be partly outside.
      if ((x >= r && x < w - r) || (y >= r && y < h - r)) continue;
      var cover = 0.0;
      for (var sy = 0; sy < 4; sy++) {
        for (var sx = 0; sx < 4; sx++) {
          cover += inside(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4);
        }
      }
      final p = image.getPixel(x, y);
      p.a = (p.a * cover / 16).round();
    }
  }
}

/// Purpose: Clear small opaque islands left behind by background removal.
/// Inputs: `image` (RGBA, modified in place); `minFraction` of the largest
/// island's area below which an island is cleared.
/// Returns: None.
/// Side effects: Sets alpha 0 on the pixels of small islands.
/// Notes: Shadow fragments and noise otherwise stretch the trim box and
/// shrink the device. 8-connected, so a thin cable stays attached.
void removeSpecks(img.Image image, {double minFraction = 0.02}) {
  final w = image.width, h = image.height;
  final label = List<int>.filled(w * h, -1);
  final sizes = <int>[];
  for (var start = 0; start < w * h; start++) {
    if (label[start] != -1) continue;
    if (image.getPixel(start % w, start ~/ w).a <= deviceImageAlphaThreshold) {
      continue;
    }
    final id = sizes.length;
    var size = 0;
    final stack = [start];
    label[start] = id;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      size++;
      final x = i % w, y = i ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final n = ny * w + nx;
          if (label[n] != -1) continue;
          if (image.getPixel(nx, ny).a <= deviceImageAlphaThreshold) continue;
          label[n] = id;
          stack.add(n);
        }
      }
    }
    sizes.add(size);
  }
  if (sizes.length < 2) return;
  final largest = sizes.reduce(math.max);
  for (var i = 0; i < w * h; i++) {
    final id = label[i];
    if (id >= 0 && sizes[id] < largest * minFraction) {
      image.getPixel(i % w, i ~/ w).a = 0;
    }
  }
}

/// Purpose: Tell whether the image border is already fully transparent.
/// Inputs: `image`.
/// Returns: True when every border pixel has alpha 0.
/// Side effects: None.
/// Notes: A transparent render needs no background removal. Internal helper
/// used within this library only.
bool _edgesTransparent(img.Image image) {
  for (final (x, y) in _borderPixels(image)) {
    if (image.getPixel(x, y).a > deviceImageAlphaThreshold) return false;
  }
  return true;
}

/// Purpose: Enumerate the coordinates on an image's outer border.
/// Inputs: `image`.
/// Returns: Every border `(x, y)`, corners included once or twice.
/// Side effects: None.
/// Notes: Internal helper used within this library only.
Iterable<(int, int)> _borderPixels(img.Image image) sync* {
  final w = image.width, h = image.height;
  for (var x = 0; x < w; x++) {
    yield (x, 0);
    yield (x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    yield (0, y);
    yield (w - 1, y);
  }
}

/// Purpose: Make a plain background transparent by flooding in from the edges.
/// Inputs: `image` (RGBA uint8, modified in place); `tolerance`.
/// Returns: None.
/// Side effects: Rewrites alpha of background pixels in `image`.
/// Notes: The reference colour is the median border colour, so a vignette or
/// a stray corner does not throw it off. Only pixels connected to the border
/// are cleared, so a white screen or logo inside the device survives. Pixels
/// touching the cleared area within twice the tolerance get half alpha as a
/// one-pixel feather.
void removeEdgeBackground(img.Image image, int tolerance) {
  final w = image.width, h = image.height;
  final border = _borderPixels(image).map((p) => image.getPixel(p.$1, p.$2));
  final rs = border.map((p) => p.r.toInt()).toList()..sort();
  final gs = border.map((p) => p.g.toInt()).toList()..sort();
  final bs = border.map((p) => p.b.toInt()).toList()..sort();
  final ref = (rs[rs.length ~/ 2], gs[gs.length ~/ 2], bs[bs.length ~/ 2]);

  double distance(int x, int y) {
    final p = image.getPixel(x, y);
    final dr = p.r - ref.$1, dg = p.g - ref.$2, db = p.b - ref.$3;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  final background = List<bool>.filled(w * h, false);
  final queue = Queue<int>();
  for (final (x, y) in _borderPixels(image)) {
    final i = y * w + x;
    if (!background[i] && distance(x, y) <= tolerance) {
      background[i] = true;
      queue.add(i);
    }
  }
  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    final x = i % w, y = i ~/ w;
    for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      final n = ny * w + nx;
      if (background[n] || distance(nx, ny) > tolerance) continue;
      background[n] = true;
      queue.add(n);
    }
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final p = image.getPixel(x, y);
      if (background[i]) {
        p.a = 0;
        continue;
      }
      final touches =
          (x > 0 && background[i - 1]) ||
          (x < w - 1 && background[i + 1]) ||
          (y > 0 && background[i - w]) ||
          (y < h - 1 && background[i + w]);
      if (touches && distance(x, y) <= tolerance * 2) p.a = p.a ~/ 2;
    }
  }
}

/// Purpose: Trim to visible content and centre it inside the circle-safe box.
/// Inputs: `image` with transparency; `size` — output edge length;
/// `safeFraction` — fraction of the edge the content's longer side fills.
/// Returns: A new `size` square RGBA image.
/// Side effects: None.
/// Notes: Aspect ratio is preserved. With the default
/// [deviceImageSafeFraction] the content's bounding box (and therefore every
/// visible pixel) lies inside the inscribed circle. Larger fractions are
/// allowed for a user's own photo, where the avatar clipping the corners is
/// the user's choice.
img.Image fitIntoCircle(
  img.Image image, {
  int size = deviceImageSize,
  double safeFraction = deviceImageSafeFraction,
}) {
  var minX = image.width, minY = image.height, maxX = -1, maxY = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a <= deviceImageAlphaThreshold) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  if (maxX < 0) return canvas;

  final content = img.copyCrop(
    image,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
  final box = (size * safeFraction).floor();
  final scale = box / math.max(content.width, content.height);
  // Resample premultiplied so the removed background's colour cannot bleed
  // into the edge as a halo (white on a dark theme).
  _premultiply(content, true);
  final resized = img.copyResize(
    content,
    width: math.max(1, (content.width * scale).round()),
    height: math.max(1, (content.height * scale).round()),
    interpolation: img.Interpolation.average,
  );
  _premultiply(resized, false);
  return img.compositeImage(
    canvas,
    resized,
    dstX: (size - resized.width) ~/ 2,
    dstY: (size - resized.height) ~/ 2,
  );
}

/// Purpose: Convert an RGBA image between straight and premultiplied alpha.
/// Inputs: `image` (modified in place); `forward` — true to premultiply,
/// false to undo it.
/// Returns: None.
/// Side effects: Rewrites the colour channels of `image`.
/// Notes: Internal helper used within this library only.
void _premultiply(img.Image image, bool forward) {
  for (final p in image) {
    final a = p.a.toInt();
    if (forward) {
      p
        ..r = p.r * a ~/ 255
        ..g = p.g * a ~/ 255
        ..b = p.b * a ~/ 255;
    } else if (a > 0) {
      p
        ..r = math.min(255, p.r * 255 ~/ a)
        ..g = math.min(255, p.g * 255 ~/ a)
        ..b = math.min(255, p.b * 255 ~/ a);
    }
  }
}

/// One run of the image editor: the source pixels plus the user's settings.
class DeviceImageEditRequest {
  /// Straight-alpha RGBA bytes, `width * height * 4` long.
  final Uint8List rgba;
  final int width;
  final int height;

  /// Region to keep, as fractions of the source (`left, top, width,
  /// height`). Clamped to the image; null keeps everything.
  final (double, double, double, double)? crop;

  /// Clear a plain background by flooding in from the edges.
  final bool removeBackground;

  /// Colour distance counted as background.
  final int tolerance;

  /// Corner-radius fraction for a rounded-rectangle mask, used instead of
  /// background removal; null for none.
  final double? roundRect;

  /// Fraction of the output edge the device's longer side fills. Lower
  /// values leave more margin around it.
  final double scale;

  /// Output edge length in pixels.
  final int outputSize;

  /// Longest source side processed; larger crops are reduced first.
  final int maxSource;

  /// Purpose: Create an image edit request.
  /// Inputs: The source pixels and dimensions plus the edit settings.
  /// Returns: A new `DeviceImageEditRequest` instance.
  /// Side effects: None.
  /// Notes: Plain data, so it can be sent to an isolate.
  const DeviceImageEditRequest({
    required this.rgba,
    required this.width,
    required this.height,
    this.crop,
    this.removeBackground = true,
    this.tolerance = 28,
    this.roundRect,
    this.scale = deviceImageSafeFraction,
    this.outputSize = 512,
    this.maxSource = 1024,
  });

  /// Purpose: Copy this request with some settings changed.
  /// Inputs: Any setting to replace; `clearCrop` / `clearRoundRect` reset
  /// those to null.
  /// Returns: A new `DeviceImageEditRequest`.
  /// Side effects: None.
  /// Notes: The source pixels are shared, not copied.
  DeviceImageEditRequest copyWith({
    (double, double, double, double)? crop,
    bool clearCrop = false,
    bool? removeBackground,
    int? tolerance,
    double? roundRect,
    bool clearRoundRect = false,
    double? scale,
    int? outputSize,
    int? maxSource,
  }) => DeviceImageEditRequest(
    rgba: rgba,
    width: width,
    height: height,
    crop: clearCrop ? null : (crop ?? this.crop),
    removeBackground: removeBackground ?? this.removeBackground,
    tolerance: tolerance ?? this.tolerance,
    roundRect: clearRoundRect ? null : (roundRect ?? this.roundRect),
    scale: scale ?? this.scale,
    outputSize: outputSize ?? this.outputSize,
    maxSource: maxSource ?? this.maxSource,
  );
}

/// Purpose: Turn the region a request keeps into source pixels.
/// Inputs: `request`.
/// Returns: `(x, y, width, height)` inside the source, at least 1×1.
/// Side effects: None.
/// Notes: A crop reaching past the image (the user zoomed out beyond it) is
/// clamped to the image; margin comes from `scale` instead.
(int, int, int, int) cropRectOf(DeviceImageEditRequest request) {
  final c = request.crop;
  if (c == null) return (0, 0, request.width, request.height);
  final left = math.min(
    (c.$1.clamp(0.0, 1.0) * request.width).floor(),
    request.width - 1,
  );
  final top = math.min(
    (c.$2.clamp(0.0, 1.0) * request.height).floor(),
    request.height - 1,
  );
  final right = ((c.$1 + c.$3).clamp(0.0, 1.0) * request.width).ceil();
  final bottom = ((c.$2 + c.$4).clamp(0.0, 1.0) * request.height).ceil();
  return (
    left,
    top,
    math.max(1, math.min(request.width, right) - left),
    math.max(1, math.min(request.height, bottom) - top),
  );
}

/// Purpose: Run the editor's pipeline and encode the result.
/// Inputs: `request`.
/// Returns: PNG bytes of a transparent `outputSize` square.
/// Side effects: None.
/// Notes: Top-level so `Isolate.run` can call it. Order: crop, reduce to
/// `maxSource`, remove the background (or apply the rounded mask), trim to
/// what is left, and fit it at `scale` into the centre of the square.
Uint8List processDeviceImage(DeviceImageEditRequest request) {
  final source = img.Image.fromBytes(
    width: request.width,
    height: request.height,
    bytes: request.rgba.buffer,
    bytesOffset: request.rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  final (x, y, w, h) = cropRectOf(request);
  final cropped = img.copyCrop(source, x: x, y: y, width: w, height: h);
  final result = prepareDeviceImage(
    cropped,
    tolerance: request.tolerance,
    roundRect: request.roundRect,
    removeBackground: request.removeBackground,
    maxSource: request.maxSource,
    size: request.outputSize,
    safeFraction: request.scale,
  );
  return img.encodePng(result, level: 6);
}
