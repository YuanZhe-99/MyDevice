// Turns a product photo into a bundled device thumbnail.
//
// Run with:
//   dart run tool/prepare_device_image.dart <input> <output.png> [...]
//       [--tolerance=N] [--crop=x,y,w,h] [--roundrect=R] [--keep-background]
//
// Steps: optionally crop to one region of the source (a sheet of several
// views, or a group shot), remove a plain background (flood fill from the
// edges) unless the image is already transparent, trim to the visible
// content (or, with --roundrect, cut a tightly cropped phone or tablet out
// with a rounded-rectangle mask instead; or, with --keep-background, skip
// removal for a transparent render cropped out of a line-up), fit it into the
// circle-safe square, centre it on a transparent 256 px canvas, and verify
// the result with `checkDeviceImage`. Exit code 1 when the result fails.
//
// The pipeline itself lives in
// `lib/shared/utils/device_image_processing.dart`, shared with the
// in-app image editor.

import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:my_device/shared/utils/device_image_processing.dart';

export 'package:my_device/shared/utils/device_image_processing.dart'
    show
        applyRoundRectMask,
        fitIntoCircle,
        prepareDeviceImage,
        removeEdgeBackground,
        removeSpecks;

/// Purpose: Convert photos into checked, circle-safe thumbnails.
/// Inputs: Command-line `args`: one or more `<input> <output.png>` pairs and
/// an optional `--tolerance=N` (colour distance counted as background,
/// default 28) and an optional `--crop=x,y,w,h` (a source-pixel rectangle
/// applied to every input before anything else) and an optional
/// `--roundrect=R` (mask the cropped image with a rounded rectangle whose
/// corner radius is R times its shorter side, instead of removing the
/// background) and an optional `--keep-background` (no flood fill: for a
/// transparent render whose crop cuts through a neighbouring device, where
/// the fill would compare the transparent pixels' colour to the device).
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
      '[--roundrect=R] [--keep-background]',
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

  final keepBackground = args.contains('--keep-background');
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
      removeBackground: !keepBackground,
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
