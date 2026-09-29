import 'dart:io';

import 'package:flutter/material.dart';

import '../../../shared/services/image_service.dart';
import '../models/device.dart';
import '../services/preset_service.dart';
import 'device_category_icon.dart';

class DeviceAvatar extends StatefulWidget {
  final DeviceCategory category;
  final String? emoji;
  final String? imagePath;

  /// Bundled thumbnail the user chose by hand; wins over matching.
  final String? templateImage;
  final double size;

  /// Identity used to look up a matching template thumbnail when the device
  /// has neither an emoji nor its own photo.
  final String? brand;
  final String? model;
  final String? name;

  /// Purpose: Create a device avatar instance.
  /// Inputs: `category`, optional `emoji` / `imagePath` / `templateImage`,
  /// the device identity (`brand`, `model`, `name`) for the template
  /// thumbnail, and `size`.
  /// Returns: A new `DeviceAvatar` instance.
  /// Side effects: None.
  /// Notes: Priority is emoji, then the user's photo, then the thumbnail
  /// chosen by hand, then the matching template thumbnail, then the
  /// category icon.
  const DeviceAvatar({
    super.key,
    required this.category,
    this.emoji,
    this.imagePath,
    this.templateImage,
    this.brand,
    this.model,
    this.name,
    this.size = 40,
  });

  /// Purpose: Create a from device instance.
  /// Inputs: `device`.
  /// Returns: A new `DeviceAvatar.fromDevice` instance.
  /// Side effects: None.
  /// Notes: Passes the identity fields so existing devices match templates.
  factory DeviceAvatar.fromDevice(Device device, {double size = 40}) {
    return DeviceAvatar(
      category: device.category,
      emoji: device.emoji,
      imagePath: device.imagePath,
      templateImage: device.templateImage,
      brand: device.brand,
      model: device.model,
      name: device.name,
      size: size,
    );
  }

  /// Purpose: Create the mutable state that caches the image lookup.
  /// Inputs: None.
  /// Returns: A new `_DeviceAvatarState`.
  /// Side effects: None.
  /// Notes: The state exists only so the resolved-file future is created once
  /// per image path instead of on every rebuild.
  @override
  State<DeviceAvatar> createState() => _DeviceAvatarState();
}

class _DeviceAvatarState extends State<DeviceAvatar> {
  Future<File>? _fileFuture;
  String? _fileFuturePath;

  DeviceCategory get category => widget.category;
  String? get emoji => widget.emoji;
  String? get imagePath => widget.imagePath;
  String? get templateImage => widget.templateImage;
  double get size => widget.size;
  String? get brand => widget.brand;
  String? get model => widget.model;
  String? get name => widget.name;

  /// Purpose: Return the (cached) future resolving [path] to a file.
  /// Inputs: `path` - the device's relative image path.
  /// Returns: `Future<File>`, the same instance until [path] changes.
  /// Side effects: Starts a storage-path lookup the first time a path is seen.
  /// Notes: Creating the future inside `build` restarted the lookup on every
  /// rebuild, so scrolling lists flashed the fallback icon.
  Future<File> _resolveFile(String path) {
    if (_fileFuturePath != path) {
      _fileFuturePath = path;
      _fileFuture = ImageService.resolve(path);
    }
    return _fileFuture!;
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (emoji != null) {
      return _AvatarFrame(
        size: size,
        backgroundColor: cs.primaryContainer,
        borderColor: cs.outlineVariant.withAlpha(120),
        child: Center(
          child: Text(emoji!, style: TextStyle(fontSize: size * 0.48)),
        ),
      );
    }

    if (imagePath != null) {
      final decodeSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
      return FutureBuilder<File>(
        future: _resolveFile(imagePath!),
        initialData: ImageService.cachedResolve(imagePath!),
        builder: (context, snap) {
          final file = snap.data;
          if (file != null && file.existsSync()) {
            return _AvatarFrame(
              size: size,
              backgroundColor: cs.surfaceContainerHighest,
              borderColor: cs.outlineVariant.withAlpha(140),
              child: ClipOval(
                child: Image.file(
                  file,
                  width: size,
                  height: size,
                  // Decode at avatar size, not at the photo's full resolution.
                  cacheWidth: decodeSize,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, _, _) => _fallbackIconContent(context),
                ),
              ),
            );
          }
          return _templateOrFallback(context);
        },
      );
    }

    return _templateOrFallback(context);
  }

  /// Purpose: Show the chosen or matching template thumbnail, or the icon.
  /// Inputs: `context`.
  /// Returns: `Widget`.
  /// Side effects: May load the template catalog once.
  /// Notes: Resolves synchronously once the catalog is cached, so rebuilds do
  /// not flash the fallback. A hand-picked [templateImage] that is no longer
  /// in the catalog is ignored in favour of matching. Internal helper used
  /// within this file only.
  Widget _templateOrFallback(BuildContext context) {
    if (templateImage == null &&
        brand == null &&
        model == null &&
        name == null) {
      return _fallbackIcon(context);
    }
    final cached = PresetService.cachedTemplates;
    if (cached != null) {
      final asset = _resolveTemplate(cached);
      return asset == null
          ? _fallbackIcon(context)
          : _templateImage(context, asset);
    }
    return FutureBuilder<String?>(
      future: PresetService.loadTemplates().then(_resolveTemplate),
      builder: (context, snap) {
        final asset = snap.data;
        return asset == null
            ? _fallbackIcon(context)
            : _templateImage(context, asset);
      },
    );
  }

  /// Purpose: Pick the thumbnail asset this avatar should show.
  /// Inputs: `templates` — the loaded catalog.
  /// Returns: The hand-picked asset when it is still bundled, otherwise the
  /// automatically matched one, or null.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String? _resolveTemplate(List<DeviceTemplate> templates) {
    final chosen = templateImage;
    if (chosen != null && PresetService.isTemplateImage(templates, chosen)) {
      return chosen;
    }
    if (brand == null && model == null && name == null) return null;
    return PresetService.matchTemplateImage(
      templates,
      brand: brand,
      model: model,
      name: name,
    );
  }

  /// Purpose: Render a bundled template thumbnail in the avatar circle.
  /// Inputs: `context`, `asset`.
  /// Returns: `Widget`.
  /// Side effects: Loads the bundled image.
  /// Notes: Thumbnails are transparent and already keep their content inside
  /// the circle, so the image fills the frame without cropping anything.
  /// Internal helper used within this file only.
  Widget _templateImage(BuildContext context, String asset) {
    final cs = Theme.of(context).colorScheme;
    return _AvatarFrame(
      size: size,
      backgroundColor: cs.surfaceContainerHighest,
      borderColor: cs.outlineVariant.withAlpha(140),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _fallbackIconContent(context),
      ),
    );
  }

  /// Purpose: Provide the internal fallback icon helper for this file.
  /// Inputs: `context`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _fallbackIcon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _AvatarFrame(
      size: size,
      backgroundColor: cs.primaryContainer,
      borderColor: cs.outlineVariant.withAlpha(120),
      child: Icon(
        deviceCategoryIcon(category),
        size: size * 0.5,
        color: cs.onPrimaryContainer,
      ),
    );
  }

  /// Purpose: Provide the internal fallback icon content helper for this file.
  /// Inputs: `context`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _fallbackIconContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(
      deviceCategoryIcon(category),
      size: size * 0.5,
      color: cs.onPrimaryContainer,
    );
  }
}

class _AvatarFrame extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final Color borderColor;
  final Widget child;

  /// Purpose: Create an avatar frame instance.
  /// Inputs: None.
  /// Returns: A new `_AvatarFrame` instance.
  /// Side effects: None.
  /// Notes: None.
  const _AvatarFrame({
    required this.size,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
  });

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor),
        ),
        child: ClipOval(child: child),
      ),
    );
  }
}
