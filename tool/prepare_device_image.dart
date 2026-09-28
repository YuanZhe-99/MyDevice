// Turns a product photo into a bundled device thumbnail.
//
// Run with:
//   dart run tool/prepare_device_image.dart <input> <output.png> [...]
//       [--tolerance=N] [--crop=x,y,w,h] [--roundrect=R]
//
// Steps: optionally crop to one region of the source (a sheet of several
// views, or a group shot), remove a plain background (flood fill from the
// edges) unless the image is already transparent, trim to the visible
// content (or, with --roundrect, cut a tightly cropped phone or tablet out
// with a rounded-rectangle mask instead), fit it into the
// circle-safe square, centre it on a transparent 256 px canvas, and verify
// the result with `checkDeviceImage`. Exit code 1 when the result fails.

import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'device_image_check.dart';

/// Purpose: Convert photos into checked, circle-safe thumbnails.
/// Inputs: Command-line `args`: one or more `<input> <output.png>` pairs and
/// an optional `--tolerance=N` (colour distance counted as background,
/// default 28) and an optional `--crop=x,y,w,h` (a source-pixel rectangle
/// applied to every input before anything else) and an optional
/// `--roundrect=R` (mask the cropped image with a rounded rectangle whose
/// corner radius is R times its shorter side, instead of removing the
/// background).
/// Returns: None.
/// Side effects: Reads the inputs, writes the output PNGs, prints one result
/// line per pair and sets `exitCode`.
/// Notes: Pairs let a batch run in one process instead of one `dart run`
/// each. Primarily intended for local validation or one-off tooling.
void main(List<String> args) {
  final positional = args.where((a) => !a.startsWith('--')).toList();
  if (positional.isEmpty || positional.length.isOdd) {
    stderr.writeln(
      'usage: dart run tool/prepare_device_image.dart <input> <output.png> '
      '[<input> <output.png> ...] [--tolerance=N] [--crop=x,y,w,h] '
      '[--roundrect=R]',
    );
    exitCode = 2;
    return;
  }
  var tolerance = 28;
  for (final a in args.where((a) => a.startsWith('--tolerance='))) {
    tolerance = int.parse(a.split('=').last);
  }
  (int, int, int, int)? crop;
  for (final a in args.where((a) => a.startsWith('--crop='))) {
    final v = a.split('=').last.split(',').map(int.parse).toList();
    if (v.length != 4) {
      stderr.writeln('--crop needs x,y,w,h');
      exitCode = 2;
      return;
    }
    crop = (v[0], v[1], v[2], v[3]);
  }

  double? roundRect;
  for (final a in args.where((a) => a.startsWith('--roundrect='))) {
    roundRect = double.parse(a.split('=').last);
  }

  for (var i = 0; i < positional.length; i += 2) {
    final input = positional[i], output = positional[i + 1];
    img.Image? decoded;
    try {
      decoded = img.decodeImage(File(input).readAsBytesSync());
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      stdout.writeln('$output: $input is not a decodable image');
      exitCode = 1;
      continue;
    }
    if (crop != null) {
      decoded = img.copyCrop(
        decoded,
        x: crop.$1,
        y: crop.$2,
        width: crop.$3,
        height: crop.$4,
      );
    }
    final result = prepareDeviceImage(
      decoded,
      tolerance: tolerance,
      roundRect: roundRect,
    );
    File(output).writeAsBytesSync(img.encodePng(result, level: 9));

    final problems = checkDeviceImage(result);
    if (problems.isEmpty) {
      stdout.writeln('$output: OK');
    } else {
      stdout.writeln('$output: ${problems.join('; ')}');
      exitCode = 1;
    }
  }
}

/// Purpose: Run the whole thumbnail pipeline on a decoded image.
/// Inputs: `source`; `tolerance` for background colour matching;
/// `roundRect` — when set, the corner-radius fraction for
/// [applyRoundRectMask], used instead of background removal.
/// Returns: A new [deviceImageSize] square RGBA image.
/// Side effects: None.
/// Notes: Large sources are first reduced to 1024 px so the flood fill stays
/// fast; the output is far smaller than that anyway. The mask suits a phone
/// or tablet photographed straight on against a busy surface (wood, cloth),
/// where a flood fill cannot tell the background from the device.
img.Image prepareDeviceImage(
  img.Image source, {
  int tolerance = 28,
  double? roundRect,
}) {
  var work = source.convert(format: img.Format.uint8, numChannels: 4);
  final longest = math.max(work.width, work.height);
  if (longest > 1024) {
    work = img.copyResize(
      work,
      width: work.width >= work.height ? 1024 : null,
      height: work.height > work.width ? 1024 : null,
      interpolation: img.Interpolation.average,
    );
  }
  if (roundRect != null) {
    applyRoundRectMask(work, roundRect);
  } else {
    if (!_edgesTransparent(work)) removeEdgeBackground(work, tolerance);
    removeSpecks(work);
  }
  return fitIntoCircle(work);
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
/// used within this file only.
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
/// Notes: Internal helper used within this file only.
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
/// Inputs: `image` with transparency.
/// Returns: A new [deviceImageSize] square RGBA image.
/// Side effects: None.
/// Notes: Content is scaled to fit a square of [deviceImageSafeFraction] of
/// the canvas, preserving aspect ratio, so its bounding box (and therefore
/// every visible pixel) lies inside the inscribed circle.
img.Image fitIntoCircle(img.Image image) {
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
  final canvas = img.Image(
    width: deviceImageSize,
    height: deviceImageSize,
    numChannels: 4,
  );
  if (maxX < 0) return canvas;

  final content = img.copyCrop(
    image,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
  final box = (deviceImageSize * deviceImageSafeFraction).floor();
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
    dstX: (deviceImageSize - resized.width) ~/ 2,
    dstY: (deviceImageSize - resized.height) ~/ 2,
  );
}

/// Purpose: Convert an RGBA image between straight and premultiplied alpha.
/// Inputs: `image` (modified in place); `forward` — true to premultiply,
/// false to undo it.
/// Returns: None.
/// Side effects: Rewrites the colour channels of `image`.
/// Notes: Internal helper used within this file only.
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
