import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auno_player/services/performance_tier_service.dart';

const _graphicsModeKey = 'graphics_performance_mode_v1';

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

/// Convenience selector for lyric depth-of-field.
final lyricsBlurEnabledProvider = Provider<bool>((ref) {
  return ref.watch(performanceProfileProvider).value?.blurEnabled ?? false;
});
