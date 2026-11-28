import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auno_player/services/performance_tier_service.dart';

const _graphicsModeKey = 'graphics_performance_mode_v1';
const _blurOverrideKey = 'blur_effects_override_v1';

/// Persisted graphics mode (Auto / Lite / High-End).
class GraphicsPerformanceModeNotifier extends Notifier<GraphicsPerformanceMode> {
  bool _initialized = false;

  @override
  GraphicsPerformanceMode build() {
    if (!_initialized) {
      _initialized = true;
      Future<void>.microtask(_load);
    }
    return GraphicsPerformanceMode.auto;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_graphicsModeKey);
    final mode = GraphicsPerformanceMode.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => GraphicsPerformanceMode.auto,
    );
    if (ref.mounted && state != mode) state = mode;
  }

  Future<void> setMode(GraphicsPerformanceMode mode) async {
    if (state == mode) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_graphicsModeKey, mode.name);
  }
}

final graphicsPerformanceModeProvider =
    NotifierProvider<GraphicsPerformanceModeNotifier, GraphicsPerformanceMode>(
      GraphicsPerformanceModeNotifier.new,
    );

/// Resolved device profile for the active mode.
///
/// Falls back to [DevicePerformanceProfile.fallback] while detection is in
/// flight so first frames never wait on the platform channel.
final performanceProfileProvider = FutureProvider<DevicePerformanceProfile>((
  ref,
) async {
  final mode = ref.watch(graphicsPerformanceModeProvider);
  return PerformanceTierService().resolve(mode);
});

/// Explicit user choice for lyric/glass blur. `null` means "follow the
/// resolved device tier", which keeps the toggle off on entry-level hardware
/// without ever writing a preference the user did not set.
class BlurEffectsOverrideNotifier extends Notifier<bool?> {
  bool _initialized = false;

  @override
  bool? build() {
    if (!_initialized) {
      _initialized = true;
      Future<void>.microtask(_load);
    }
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_blurOverrideKey)) return;
    final stored = prefs.getBool(_blurOverrideKey);
    if (ref.mounted && stored != null && state != stored) state = stored;
  }

  Future<void> setOverride(bool? value) async {
    if (state == value) return;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_blurOverrideKey);
    } else {
      await prefs.setBool(_blurOverrideKey, value);
    }
  }
}

final blurEffectsOverrideProvider =
    NotifierProvider<BlurEffectsOverrideNotifier, bool?>(
      BlurEffectsOverrideNotifier.new,
    );

/// Master blur switch for lyrics depth-of-field and glass panels.
///
/// Defaults to on everywhere except entry-level devices (≤4 GB RAM or a
/// low-end SoC), where a full-screen blur layer costs whole frames.
final blurEffectsEnabledProvider = Provider<bool>((ref) {
  final override = ref.watch(blurEffectsOverrideProvider);
  if (override != null) return override;
  final profile = ref.watch(performanceProfileProvider).value;
  if (profile == null) return false;
  return !profile.isEntryLevel;
});

/// Convenience selector for lyric depth-of-field.
final lyricsBlurEnabledProvider = Provider<bool>((ref) {
  return ref.watch(blurEffectsEnabledProvider);
});
