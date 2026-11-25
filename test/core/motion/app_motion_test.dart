import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auno_player/core/motion/app_motion.dart';

void main() {
  group('AppMotionMath.bell', () {
    test('peaks at the centre and falls to zero at the edges', () {
      expect(AppMotionMath.bell(0.0), closeTo(1.0, 1e-9));
      expect(AppMotionMath.bell(0.5), closeTo(0.5, 1e-9));
      expect(AppMotionMath.bell(1.0), closeTo(0.0, 1e-9));
    });

    test('is monotonically decreasing on the way out of focus', () {
      var previous = double.infinity;
      for (var i = 0; i <= 20; i++) {
        final value = AppMotionMath.bell(i / 20);
        expect(value, lessThanOrEqualTo(previous + 1e-9));
        previous = value;
      }
    });

    test('clamps out-of-range distances', () {
      expect(AppMotionMath.bell(-2.0), closeTo(1.0, 1e-9));
      expect(AppMotionMath.bell(2.0), closeTo(0.0, 1e-9));
    });

    test('maps bell values into a range', () {
      expect(AppMotionMath.lerpBell(1.0, 0.92, 1.04), closeTo(1.04, 1e-9));
      expect(AppMotionMath.lerpBell(0.0, 0.55, 1.0), closeTo(0.55, 1e-9));
      expect(AppMotionMath.lerpBell(0.5, 1.0, 2.0), closeTo(1.5, 1e-9));
    });
  });

  group('ExponentialSmoother', () {
    test('converges towards a static target', () {
      final smoother = ExponentialSmoother(
        timeConstant: 0.05,
        snapThreshold: 0.000001,
      );
      for (var i = 0; i < 300; i++) {
        smoother.update(10.0, 1 / 60);
      }
      expect(smoother.value, closeTo(10.0, 1e-3));
    });

    test('moves at least partially in a single frame', () {
      final smoother = ExponentialSmoother(timeConstant: 0.05);
      final next = smoother.update(1.0, 1 / 60);
      expect(next, greaterThan(0.0));
      expect(next, lessThan(1.0));
    });

    test('is frame-rate independent over the same elapsed time', () {
      final at60 = ExponentialSmoother(timeConstant: 0.1);
      for (var i = 0; i < 60; i++) {
        at60.update(1.0, 1 / 60);
      }
      final at120 = ExponentialSmoother(timeConstant: 0.1);
      for (var i = 0; i < 120; i++) {
        at120.update(1.0, 1 / 120);
      }
      expect(at60.value, closeTo(at120.value, 1e-9));
    });

    test('snaps to the target inside the threshold', () {
      final smoother = ExponentialSmoother(
        timeConstant: 0.05,
        initialValue: 0.9999,
        snapThreshold: 0.01,
      );
      expect(smoother.update(1.0, 1 / 60), 1.0);
    });

    test('reset jumps immediately', () {
      final smoother = ExponentialSmoother(timeConstant: 0.2);
      smoother.update(5.0, 1 / 60);
      smoother.reset(2.5);
      expect(smoother.value, 2.5);
    });
  });

  group('AppMotionSprings', () {
    test('interactive spring settles towards its target', () {
      final simulation = AppMotionSprings.simulation(
        spring: AppMotionSprings.interactive,
        start: 0.0,
        end: 1.0,
        velocity: 2.0,
      );
      var position = 0.0;
      var t = 0.0;
      while (!simulation.isDone(t) && t < 10.0) {
        t += 1 / 120;
        position = simulation.x(t);
      }
      expect(simulation.isDone(t), isTrue);
      expect(position, closeTo(1.0, 1e-3));
    });

    test('every preset is a stable under-damped spring', () {
      for (final spring in [
        AppMotionSprings.interactive,
        AppMotionSprings.gentle,
        AppMotionSprings.snappy,
      ]) {
        final dampingRatio =
            spring.damping / (2 * math.sqrt(spring.stiffness * spring.mass));
        expect(dampingRatio, greaterThan(0.5));
        expect(dampingRatio, lessThan(1.0));
      }
    });
  });

  group('AppMotionRefresh', () {
    test('frame budget matches the fallback rate without a view', () {
      expect(AppMotionRefresh.fallbackHz, 60.0);
    });

    test('smoothing alpha is bounded and grows with dt', () {
      expect(AppMotionMath.smoothingAlpha(0, 0.1), 0.0);
      expect(AppMotionMath.smoothingAlpha(1, 0.0), 1.0);
      final short = AppMotionMath.smoothingAlpha(1 / 120, 0.1);
      final long = AppMotionMath.smoothingAlpha(1 / 30, 0.1);
      expect(short, lessThan(long));
      expect(long, lessThanOrEqualTo(1.0));
    });
  });
}
