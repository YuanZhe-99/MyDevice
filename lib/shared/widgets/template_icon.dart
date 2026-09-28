import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A transparent brand mark with enough space to fit inside a circular avatar.
class TemplateIcon extends StatelessWidget {
  final String? asset;
  final IconData fallback;
  final double size;
  final Color? foregroundColor;

  /// Purpose: Configure a circular template icon with a local image or fallback.
  /// Inputs: `asset`, `fallback`, `size`, optional monochrome `foregroundColor`.
  /// Returns: A new `TemplateIcon`.
  /// Side effects: None.
  /// Notes: Leave foregroundColor null to preserve a multicolour brand mark.
  const TemplateIcon({
    super.key,
    this.asset,
    required this.fallback,
    this.size = 40,
    this.foregroundColor,
  });

  /// Purpose: Keep the complete image within the avatar's circular boundary.
  /// Inputs: `context`.
  /// Returns: A circular avatar with a contained image or Material fallback.
  /// Side effects: Loads the bundled SVG or raster image when provided.
  /// Notes: A square of side 0.64 times the diameter has its corners inside
  /// the circle (0.64 * sqrt(2) < 1), including a margin for the entire mark.
  @override
  Widget build(BuildContext context) {
    final fallbackWidget = Icon(fallback, size: size * 0.55);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: asset == null
          ? null
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: asset == null
          ? fallbackWidget
          : SizedBox.square(
              dimension: size * 0.64,
              child: !asset!.endsWith('.svg')
                  ? Image.asset(
                      asset!,
                      fit: BoxFit.contain,
                      color: foregroundColor,
                      colorBlendMode: BlendMode.srcIn,
                      errorBuilder: (_, _, _) => fallbackWidget,
                    )
                  : SvgPicture.asset(
                      asset!,
                      fit: BoxFit.contain,
                      theme: SvgTheme(
                        currentColor: Theme.of(context).colorScheme.onSurface,
                      ),
                      colorFilter: foregroundColor == null
                          ? null
                          : ColorFilter.mode(foregroundColor!, BlendMode.srcIn),
                      placeholderBuilder: (_) => fallbackWidget,
                      errorBuilder: (_, _, _) => fallbackWidget,
                    ),
            ),
    );
  }
}
