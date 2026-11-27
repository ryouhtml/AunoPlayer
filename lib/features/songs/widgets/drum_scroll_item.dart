import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Applies the 3D cylindrical drum transform to one fixed-extent list row.
///
/// The row nearest the viewport centre stays flat and fully opaque; rows that
/// scroll away rotate on X, scale down to [minScale] and fade to [minOpacity].
/// The scroll offset is shared through one [ValueListenable] so the whole list
/// uses a single scroll listener instead of one per row.
class DrumScrollItem extends StatelessWidget {
  const DrumScrollItem({
    super.key,
    required this.index,
    required this.itemExtent,
    required this.viewportHeight,
    required this.scrollOffset,
    required this.child,
    this.maxRotationRadians = 0.30,
    this.minScale = 0.88,
    this.minOpacity = 0.25,
  });

  final int index;
  final double itemExtent;
  final double viewportHeight;
  final ValueListenable<double> scrollOffset;
  final Widget child;
  final double maxRotationRadians;
  final double minScale;
  final double minOpacity;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: scrollOffset,
        child: child,
        builder: (context, offset, child) {
          final halfViewport = math.max(viewportHeight / 2, 1.0);
          final itemCenter = index * itemExtent + itemExtent / 2;
          final delta = itemCenter - (offset + halfViewport);
          final normalized = (delta / halfViewport).clamp(-1.0, 1.0);
          final distance = normalized.abs();

          final angle = normalized * maxRotationRadians;
          final scale = 1.0 - (1.0 - minScale) * distance;
          final opacity =
              (1.0 - (1.0 - minOpacity) * distance).clamp(0.0, 1.0);

          return Opacity(
            opacity: opacity,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(angle)
                ..scale(scale),
              child: child!,
            ),
          );
        },
      ),
    );
  }
}
