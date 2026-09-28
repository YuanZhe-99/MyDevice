// Shared rules for bundled device thumbnails (`assets/device_images/*.png`).
//
// Used by `tool/validate_json.dart`, `tool/prepare_device_image.dart` and the
// unit tests, so the rule that "the background is gone and everything visible
// sits inside the avatar circle" is enforced in one place.

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
