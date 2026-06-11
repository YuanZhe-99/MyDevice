import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

const _sourceIcons = <String>[
  'assets/icon/app_icon_ios.png',
  'assets/icon/app_icon_ios_dark.png',
  'assets/icon/app_icon_ios_tinted.png',
];

const _appIconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _contentsPath = '$_appIconDir/Contents.json';

/// Purpose: Decode a PNG file for validation.
/// Inputs: `path`.
/// Returns: The decoded image.
/// Side effects: Reads a file and throws if decoding fails.
/// Notes: Keeps validation failures explicit instead of silently skipping files.
img.Image _readPng(String path) {
  final image = img.decodePng(File(path).readAsBytesSync());
  if (image == null) {
    throw StateError('Could not decode PNG: $path');
  }
  return image;
}

/// Purpose: Fail validation when a required condition is false.
/// Inputs: `condition` and failure `message`.
/// Returns: None.
/// Side effects: Throws `StateError` on failure.
/// Notes: Used instead of `assert` so checks run in normal command-line mode.
void _check(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

/// Purpose: Check whether an image has at least one transparent pixel.
/// Inputs: `image`.
/// Returns: True when any pixel alpha is below 255.
/// Side effects: None.
/// Notes: Dark and tinted iOS sources must remain transparent-background art.
bool _hasTransparentPixel(img.Image image) {
  for (final pixel in image) {
    if (pixel.a < 255) {
      return true;
    }
  }
  return false;
}

/// Purpose: Check whether all image pixels are fully opaque.
/// Inputs: `image`.
/// Returns: True when every pixel alpha is 255.
/// Side effects: None.
/// Notes: Default iOS and marketing icons must not contain transparent pixels.
bool _isOpaque(img.Image image) {
  for (final pixel in image) {
    if (pixel.a < 255) {
      return false;
    }
  }
  return true;
}

/// Purpose: Check whether visible pixels are grayscale.
/// Inputs: `image`.
/// Returns: True when every visible pixel has equal RGB channels.
/// Side effects: None.
/// Notes: Alpha-zero pixels are ignored because their RGB values are irrelevant.
bool _isVisibleGrayscale(img.Image image) {
  for (final pixel in image) {
    if (pixel.a == 0) {
      continue;
    }
    if (pixel.r != pixel.g || pixel.g != pixel.b) {
      return false;
    }
  }
  return true;
}

/// Purpose: Extract a plain filename from a path.
/// Inputs: `path`.
/// Returns: The final path component.
/// Side effects: None.
/// Notes: Avoids adding a package dependency just for basename handling.
String _basename(String path) => path.split(Platform.pathSeparator).last;

/// Purpose: Return the luminosity appearance value for a Contents entry.
/// Inputs: JSON `entry`.
/// Returns: `dark`, `tinted`, or null.
/// Side effects: None.
/// Notes: flutter_launcher_icons stores iOS mode variants under appearances.
String? _luminosityAppearance(Map<String, Object?> entry) {
  final appearances = entry['appearances'];
  if (appearances is! List) {
    return null;
  }
  for (final appearance in appearances) {
    if (appearance is Map &&
        appearance['appearance'] == 'luminosity' &&
        appearance['value'] is String) {
      return appearance['value'] as String;
    }
  }
  return null;
}

/// Purpose: Calculate the expected pixel side for a Contents entry.
/// Inputs: JSON `entry`.
/// Returns: Expected square image side in pixels.
/// Side effects: Throws if size or scale are malformed.
/// Notes: Handles fractional iPad sizes such as 83.5x83.5.
int _expectedPixelSide(Map<String, Object?> entry) {
  final size = entry['size'];
  final scale = entry['scale'];
  if (size is! String || scale is! String) {
    throw StateError('Contents entry is missing size or scale: $entry');
  }
  final logicalSize = double.parse(size.split('x').first);
  final scaleFactor = int.parse(scale.replaceAll('x', ''));
  return (logicalSize * scaleFactor).round();
}

/// Purpose: Validate the three generated iOS source icons.
/// Inputs: None.
/// Returns: None.
/// Side effects: Reads PNG files and throws on invalid output.
/// Notes: Source icons are intentionally 2560px so launcher generation has room.
void _validateSourceIcons() {
  for (final path in _sourceIcons) {
    _check(File(path).existsSync(), 'Missing source icon: $path');
    final image = _readPng(path);
    _check(image.width == 2560 && image.height == 2560, '$path is not 2560px');
  }

  final defaultIcon = _readPng(_sourceIcons[0]);
  final darkIcon = _readPng(_sourceIcons[1]);
  final tintedIcon = _readPng(_sourceIcons[2]);
  _check(_isOpaque(defaultIcon), 'Default iOS source contains transparency');
  _check(_hasTransparentPixel(darkIcon), 'Dark iOS source is not transparent');
  _check(
    _hasTransparentPixel(tintedIcon),
    'Tinted iOS source is not transparent',
  );
  _check(_isVisibleGrayscale(tintedIcon), 'Tinted iOS source is not grayscale');
}

/// Purpose: Delete PNGs in AppIcon.appiconset that Contents.json no longer uses.
/// Inputs: Referenced `filenames`.
/// Returns: None.
/// Side effects: Deletes unreferenced PNG files when present.
/// Notes: This keeps generated asset folders from carrying stale icon sizes.
void _cleanUnreferencedPngs(Set<String> filenames) {
  final dir = Directory(_appIconDir);
  for (final entity in dir.listSync()) {
    if (entity is! File || !entity.path.endsWith('.png')) {
      continue;
    }
    final name = _basename(entity.path);
    if (!filenames.contains(name)) {
      entity.deleteSync();
      stdout.writeln('deleted_unreferenced=$name');
    }
  }
}

/// Purpose: Validate generated iOS AppIcon.appiconset contents.
/// Inputs: Whether to `clean` unreferenced PNG files first.
/// Returns: None.
/// Side effects: Reads Contents.json and PNGs, optionally deletes stale PNGs.
/// Notes: Checks dimensions, transparency policy, mode entries, and references.
void _validateAppIconSet({required bool clean}) {
  final contents = jsonDecode(File(_contentsPath).readAsStringSync());
  if (contents is! Map || contents['images'] is! List) {
    throw StateError('Invalid Contents.json images array');
  }
  final entries = (contents['images'] as List).cast<Map<String, Object?>>();
  final referenced = <String>{};
  var defaultCount = 0;
  var darkCount = 0;
  var tintedCount = 0;

  for (final entry in entries) {
    final filename = entry['filename'];
    if (filename is! String || filename.isEmpty) {
      throw StateError('Contents entry is missing filename: $entry');
    }
    referenced.add(filename);
  }

  if (clean) {
    _cleanUnreferencedPngs(referenced);
  }

  for (final entry in entries) {
    final filename = entry['filename'] as String;
    final path = '$_appIconDir/$filename';
    _check(File(path).existsSync(), 'Contents references missing PNG: $path');

    final image = _readPng(path);
    final expectedSide = _expectedPixelSide(entry);
    _check(
      image.width == expectedSide && image.height == expectedSide,
      '$filename is ${image.width}x${image.height}, expected $expectedSide',
    );

    final appearance = _luminosityAppearance(entry);
    if (appearance == 'dark') {
      darkCount++;
      _check(_hasTransparentPixel(image), '$filename dark icon is not alpha');
    } else if (appearance == 'tinted') {
      tintedCount++;
      _check(_hasTransparentPixel(image), '$filename tinted icon is not alpha');
      _check(_isVisibleGrayscale(image), '$filename tinted icon is not gray');
    } else {
      defaultCount++;
      _check(_isOpaque(image), '$filename default icon contains alpha');
    }
  }

  _check(defaultCount > 0, 'Contents.json has no default iOS icons');
  _check(darkCount > 0, 'Contents.json has no dark iOS icons');
  _check(tintedCount > 0, 'Contents.json has no tinted iOS icons');

  final unreferenced =
      Directory(_appIconDir)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .map((file) => _basename(file.path))
          .where((name) => !referenced.contains(name))
          .toList()
        ..sort();
  _check(
    unreferenced.isEmpty,
    'Unreferenced PNGs remain in AppIcon.appiconset: $unreferenced',
  );

  stdout.writeln('source_icons=${_sourceIcons.length}');
  stdout.writeln('appicon_entries=${entries.length}');
  stdout.writeln('default_entries=$defaultCount');
  stdout.writeln('dark_entries=$darkCount');
  stdout.writeln('tinted_entries=$tintedCount');
}

/// Purpose: Validate generated iOS source and AppIcon assets.
/// Inputs: Optional `--clean` argument.
/// Returns: None.
/// Side effects: Reads icon assets and may delete stale AppIcon PNGs.
/// Notes: Run after `dart run flutter_launcher_icons`.
void main(List<String> args) {
  final clean = args.contains('--clean');
  _validateSourceIcons();
  _validateAppIconSet(clean: clean);
}
