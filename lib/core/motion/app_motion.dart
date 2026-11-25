import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Central home for every duration, curve and spring used by the UI.
///
/// Screens import this instead of inventing their own constants so that
/// disabling animations ([AppConstants.setAnimationsEnabled]) and reduced
/// motion settings keep the whole app consistent.
class AppMotionCurves {
  AppMotionCurves._();

  /// Fluid deceleration: fast take-off, long calm settle.
  /// The workhorse for page transitions, sheets and element entrance.
  static const Cubic fluidDeceleration = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Symmetric ease used when an element leaves the screen.
  static const Cubic entrance = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Cubic exit = Cubic(0.7, 0.0, 0.84, 0.0);

  /// Standard material emphasis curves for in-place state changes.
  static const Cubic emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Cubic standard = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Slight overshoot for playful but short interactions (badges, bubbles).
  static const Cubic springy = Curves.easeOutBack;

  /// Cross-fade between two full screens (splash -> library).
  static const Cubic crossFade = Curves.easeInOutCubic;

  /// Scroll-linked bell mapping. 0 at the viewport edges, 1 in the centre.
  static const Cubic centerFocus = Curves.easeInOutCubic;
}

/// Named durations so call sites read as intent, not magic numbers.
class AppMotionDurations {
  AppMotionDurations._();

  static const Duration micro = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration splash = Duration(milliseconds: 1350);
}

/// Calibrated spring descriptions for interactive gestures.
///
/// A [SpringDescription] is just data; use [simulation] when a widget needs a
/// [SpringSimulation] to hand to an [AnimationController.animateWith].
class AppMotionSprings {
  AppMotionSprings._();

  /// Swipe-to-dismiss / hero morph: tracks the finger, never overshoots far.
  static const SpringDescription interactive = SpringDescription(
    mass: 1.0,
    stiffness: 320.0,
    damping: 28.0,
  );

  /// Softer spring for auto-scrolling lyrics.
  static const SpringDescription gentle = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 26.0,
  );

  /// Snappy spring for expanding bubbles and small cards.
  static const SpringDescription snappy = SpringDescription(
    mass: 0.8,
    stiffness: 420.0,
    damping: 30.0,
  );

  static SpringSimulation simulation({
    required SpringDescription spring,
    required double start,
    required double end,
    double velocity = 0.0,
  }) {
    return SpringSimulation(spring, start, end, velocity);
  }
}

/// Viewport driven focus maths shared by the carousel and any scroll-linked
/// effect: 1 in the exact centre, falling to 0 at the edge in a smooth cosine.
class AppMotionMath {
  AppMotionMath._();

  /// [normalizedDistance] is 0 at centre and 1 at the viewport edge.
  static double bell(double normalizedDistance) {
    final t = normalizedDistance.clamp(0.0, 1.0);
    return 0.5 * (1.0 + math.cos(math.pi * t));
  }

  /// Maps a bell value into a min..max range.
  static double lerpBell(double bell, double min, double max) {
    return min + (max - min) * bell.clamp(0.0, 1.0);
  }

  /// Frame-rate independent exponential approach factor.
  ///
  /// [timeConstant] is the seconds needed to close ~63% of the remaining gap.
  static double smoothingAlpha(double dtSeconds, double timeConstant) {
    if (dtSeconds <= 0) return 0.0;
    if (timeConstant <= 0) return 1.0;
    return 1.0 - math.exp(-dtSeconds / timeConstant);
  }

  static double lerpTrack(double current, double target, double alpha) {
    return current + (target - current) * alpha.clamp(0.0, 1.0);
  }
}

/// Smooths a noisy stream (playback position, visualizer samples) without
/// introducing a timer. Call [update] from the animation tick.
class ExponentialSmoother {
  ExponentialSmoother({
    required this.timeConstant,
    double initialValue = 0.0,
    this.snapThreshold = 0.0005,
  }) : _value = initialValue;

  /// Seconds to close ~63% of the remaining gap.
  double timeConstant;

  /// Gaps below this snap to the target, avoiding endless sub-pixel ticks.
  final double snapThreshold;

  double _value;

  double get value => _value;

  double update(double target, double dtSeconds) {
    final alpha = AppMotionMath.smoothingAlpha(dtSeconds, timeConstant);
    _value = AppMotionMath.lerpTrack(_value, target, alpha);
    if ((_value - target).abs() <= snapThreshold) _value = target;
    return _value;
  }

  void reset(double value) => _value = value;
}

/// Refresh-rate helpers. Everything animated by Flutter already runs on the
/// vsync ticker, so this exists to size fixed-duration work (sample windows,
/// debounce) to the actual panel instead of assuming 60Hz.
class AppMotionRefresh {
  AppMotionRefresh._();

  static const double fallbackHz = 60.0;
  static const double _minHz = 24.0;
  static const double _maxHz = 240.0;

  /// Panel refresh rate for [context], clamped to a sane range.
  static double refreshRateOf(BuildContext context) {
    final raw = View.maybeOf(context)?.display.refreshRate;
    if (raw == null || raw.isNaN || raw <= 0) return fallbackHz;
    return raw.clamp(_minHz, _maxHz);
  }

  static Duration frameBudget(BuildContext context) {
    final hz = refreshRateOf(context);
    return Duration(microseconds: (1000000 / hz).round());
  }

  /// How many frames fit in [duration] at this panel's rate.
  static int framesIn(BuildContext context, Duration duration) {
    final budget = frameBudget(context).inMicroseconds;
    if (budget <= 0) return 0;
    return duration.inMicroseconds ~/ budget;
  }
}
