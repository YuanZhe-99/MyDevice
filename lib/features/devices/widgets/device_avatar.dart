import 'dart:io';

import 'package:flutter/material.dart';

import '../../../shared/services/image_service.dart';
import '../models/device.dart';
import 'device_category_icon.dart';

class DeviceAvatar extends StatelessWidget {
  final DeviceCategory category;
  final String? emoji;
  final String? imagePath;
  final double size;

  const DeviceAvatar({
    super.key,
    required this.category,
    this.emoji,
    this.imagePath,
    this.size = 40,
  });

  factory DeviceAvatar.fromDevice(Device device, {double size = 40}) {
    return DeviceAvatar(
      category: device.category,
      emoji: device.emoji,
      imagePath: device.imagePath,
      size: size,
    );
  }

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
      return FutureBuilder<File>(
        future: ImageService.resolve(imagePath!),
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
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, _, _) => _fallbackIconContent(context),
                ),
              ),
            );
          }
          return _fallbackIcon(context);
        },
      );
    }

    return _fallbackIcon(context);
  }

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

  const _AvatarFrame({
    required this.size,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
  });

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
