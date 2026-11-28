import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pure maths for the cylindrical song wheel.
///
/// The curves mirror the reference wheel: distance zero is the focused card,
/// and every neighbouring card eases away in scale, opacity and 3D rotation.
/// Keeping the maths free of `BuildContext` makes it directly unit-testable.
class WheelTransform {
  const WheelTransform._();

  /// One slot is 13.5 degrees around the drum, as in the reference.
  static const double thetaStep = 13.5 * math.pi / 180;

  /// Never rotate far enough for a card to turn edge-on or flip.
  static const double maxTheta = 1.05;

  /// Reference-like drum radius and depth, in density-independent pixels.
  static const double defaultRadius = 220.0;
  static const double defaultDepth = 120.0;

  /// Perspective factor applied to the card matrix.
  static const double perspective = 0.0012;

  /// Signed, bounded drum angle for [distance].
  static double angle(double distance) {
    final d = distance.isNaN ? 0.0 : distance;
    return (d * thetaStep).clamp(-maxTheta, maxTheta).toDouble();
  }

  /// C1-smooth scale falloff: 1.04, 0.96, 0.90, 0.84 ... minimum 0.72.
  static double scale(double distance) {
    final d = (distance.isNaN ? 0.0 : distance).abs();
    if (d <= 1.0) {
      return _hermite(d, 1.04, 0.96, 0.0, -0.06);
    }
    if (d <= 3.0) {
      return 0.96 - 0.06 * (d - 1.0);
    }
    return math.max(0.72, 0.84 - 0.06 * (d - 3.0));
  }

  /// Smooth opacity falloff: 1.0, 0.85, 0.55, 0.25 ... fading to zero.
  static double opacity(double distance) {
    final d = (distance.isNaN ? 0.0 : distance).abs();
    if (d <= 1.0) {
      return _hermite(d, 1.0, 0.85, 0.0, -0.25).clamp(0.0, 1.0).toDouble();
    }
    if (d <= 2.0) {
      return 0.85 - 0.30 * (d - 1.0);
    }
    if (d <= 3.0) {
      return 0.55 - 0.30 * (d - 2.0);
    }
    if (d <= 4.0) {
      return 0.25 - 0.21 * (d - 3.0);
    }
    return math.max(0.0, 0.04 - 0.04 * (d - 4.0));
  }

  /// Card matrix for [distance], with signed distance so cards above and
  /// below the focus tilt in opposite directions.
  ///
  /// With [reduceMotion] the matrix is identity: the caller's base layout
  /// still separates cards, but no depth/rotation is painted.
  static Matrix4 matrix(
    double distance, {
    double radius = defaultRadius,
    double depth = defaultDepth,
    bool reduceMotion = false,
  }) {
    final theta = angle(distance);
    if (reduceMotion || theta == 0.0) return Matrix4.identity();

    final y = radius * math.sin(theta);
    final z = depth * (math.cos(theta) - 1.0);
    return Matrix4.identity()
      ..setEntry(3, 2, perspective)
      ..translate(0.0, y, z)
      ..rotateX(-theta);
  }

  static double _hermite(
    double t,
    double from,
    double to,
    double slopeFrom,
    double slopeTo,
  ) {
    final t2 = t * t;
    final t3 = t2 * t;
    final h00 = 2 * t3 - 3 * t2 + 1;
    final h10 = t3 - 2 * t2 + t;
    final h01 = -2 * t3 + 3 * t2;
    final h11 = t3 - t2;
    return h00 * from + h10 * slopeFrom + h01 * to + h11 * slopeTo;
  }
}

double wheelScale(double distance) => WheelTransform.scale(distance);

double wheelOpacity(double distance) => WheelTransform.opacity(distance);

double wheelAngle(double distance) => WheelTransform.angle(distance);

Matrix4 wheelMatrix(
  double distance, {
  double radius = WheelTransform.defaultRadius,
  double depth = WheelTransform.defaultDepth,
  bool reduceMotion = false,
}) =>
    WheelTransform.matrix(
      distance,
      radius: radius,
      depth: depth,
      reduceMotion: reduceMotion,
    );
