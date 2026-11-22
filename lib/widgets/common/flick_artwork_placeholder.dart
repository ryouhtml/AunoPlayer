import 'package:flutter/material.dart';

/// Centered Auno logo used when album art is missing.
///
/// Used as placeholder/errorWidget inside [CachedImageWidget] fallbacks.
/// The master square logo is rendered with `BoxFit.contain` and can be tinted
/// via [color] and dimmed via [opacity] to match the surrounding surface.
class FlickArtworkPlaceholder extends StatelessWidget {
  const FlickArtworkPlaceholder({
    super.key,
    this.size = 48,
    this.opacity = 1.0,
    this.color,
  });

  final double size;
  final double opacity;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // SVG viewBox is 606×734 (0.826 ratio). Constrain both axes so layout
    // stays square and centered regardless of parent constraints.
    final logo = Image.asset(
      'assets/icons/auno_logo_square.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: BlendMode.srcIn,
    );

    if (opacity >= 1.0) {
      return Center(child: logo);
    }
    return Center(
      child: Opacity(opacity: opacity, child: logo),
    );
  }
}
