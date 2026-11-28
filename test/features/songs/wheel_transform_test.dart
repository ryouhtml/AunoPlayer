import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auno_player/features/songs/widgets/wheel_transform.dart';

void main() {
  group('wheel distance curves', () {
    test('scale matches the reference at each focal step', () {
      expect(wheelScale(0), closeTo(1.04, 1e-6));
      expect(wheelScale(1), closeTo(0.96, 1e-6));
      expect(wheelScale(2), closeTo(0.90, 1e-6));
      expect(wheelScale(3), closeTo(0.84, 1e-6));
      expect(wheelScale(10), closeTo(0.72, 1e-6));
    });

    test('scale is symmetric and bounded for invalid input', () {
      expect(wheelScale(-2), closeTo(wheelScale(2), 1e-6));
      expect(wheelScale(double.nan), closeTo(1.04, 1e-6));
      expect(wheelScale(double.infinity), closeTo(0.72, 1e-6));
    });

    test('opacity fades through the reference stops', () {
      expect(wheelOpacity(0), closeTo(1.0, 1e-6));
      expect(wheelOpacity(1), closeTo(0.85, 1e-6));
      expect(wheelOpacity(2), closeTo(0.55, 1e-6));
      expect(wheelOpacity(3), closeTo(0.25, 1e-6));
      expect(wheelOpacity(4), closeTo(0.04, 1e-6));
      expect(wheelOpacity(5), closeTo(0.0, 1e-6));
    });

    test('angle is signed, continuous and clamped', () {
      expect(wheelAngle(0), 0);
      expect(wheelAngle(-1), closeTo(-WheelTransform.thetaStep, 1e-6));
      expect(wheelAngle(1), closeTo(WheelTransform.thetaStep, 1e-6));
      expect(wheelAngle(100), closeTo(WheelTransform.maxTheta, 1e-6));
      expect(wheelAngle(-100), closeTo(-WheelTransform.maxTheta, 1e-6));
    });
  });

  group('wheel matrix', () {
    test('focused card has no rotation or depth offset', () {
      final matrix = wheelMatrix(0);
      expect(matrix.storage, orderedEquals(Matrix4.identity().storage));
    });

    test('neighbouring cards get a finite bounded 3D transform', () {
      for (final distance in [-3.0, -1.0, 0.5, 1.0, 2.5, 4.0]) {
        final matrix = wheelMatrix(distance);
        expect(matrix.storage.every((value) => value.isFinite), isTrue);
        expect(matrix.storage, isNot(orderedEquals(Matrix4.identity().storage)));
        expect(wheelAngle(distance).abs(),
            lessThanOrEqualTo(WheelTransform.maxTheta));
      }
    });

    test('reduce motion removes rotation and perspective', () {
      final matrix = wheelMatrix(2, reduceMotion: true);
      expect(matrix.storage, orderedEquals(Matrix4.identity().storage));
    });
  });
}
