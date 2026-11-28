import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// User-selectable graphics budget.
enum GraphicsPerformanceMode {
  /// Detect from RAM, core count and refresh rate.
  auto,

  /// Helio P35 / Snapdragon 450 class: no blur, smaller caches.
  lite,

  /// Flagship: depth-of-field blur and richer ambient layers.
  highEnd,
}

/// Resolved device class used by the rendering tier.
enum DevicePerformanceTier { lite, standard, highEnd }

/// Everything the UI needs to decide how expensive a frame may be.
@immutable
class DevicePerformanceProfile {
  const DevicePerformanceProfile({
    required this.mode,
    required this.tier,
    required this.blurEnabled,
    required this.isLowRamDevice,
    required this.totalRamMb,
    required this.processorCount,
    required this.refreshRateHz,
  });

  final GraphicsPerformanceMode mode;
  final DevicePerformanceTier tier;

  /// Whether expensive blur layers may be drawn at all.
  final bool blurEnabled;
  final bool isLowRamDevice;
  final int totalRamMb;
  final int processorCount;
  final double refreshRateHz;

  bool get isEntryLevel => tier == DevicePerformanceTier.lite;

  /// Inactive lyric lines keep the am-lyrics depth illusion with opacity and
  /// scale instead of a GPU blur on entry-level hardware.
  bool get lyricsDepthBlur => blurEnabled;

  static const DevicePerformanceProfile fallback = DevicePerformanceProfile(
    mode: GraphicsPerformanceMode.auto,
    tier: DevicePerformanceTier.standard,
    blurEnabled: false,
    isLowRamDevice: false,
    totalRamMb: 0,
    processorCount: 8,
    refreshRateHz: 60,
  );
}

/// Reads the device's memory class once and maps it to a render budget.
class PerformanceTierService {
  PerformanceTierService._();

  static final PerformanceTierService _instance =
      PerformanceTierService._();
  factory PerformanceTierService() => _instance;

  static const MethodChannel _channel = MethodChannel(
    'com.aunoplayer.auno/diagnostics',
  );

  ({int totalRamMb, bool lowRam})? _memory;
  double? _refreshRateHz;

  Future<({int totalRamMb, bool lowRam})> _readMemory() async {
    final cached = _memory;
    if (cached != null) return cached;
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'getDeviceMemoryInfo',
      );
      final total = (raw?['totalBytes'] as num?)?.toInt() ?? 0;
      final lowRam = raw?['isLowRamDevice'] as bool? ?? false;
      final result = (totalRamMb: total ~/ (1024 * 1024), lowRam: lowRam);
      _memory = result;
      return result;
    } on PlatformException {
      // Desktop/tests: fall through to a neutral profile.
    } on MissingPluginException {
      // Channel is Android-only.
    }
    final fallback = (totalRamMb: 0, lowRam: false);
    _memory = fallback;
    return fallback;
  }

  Future<double> _readRefreshRate() async {
    final cached = _refreshRateHz;
    if (cached != null) return cached;
    try {
      final active = await FlutterDisplayMode.active;
      final rate = active.refreshRate;
      _refreshRateHz = rate > 0 ? rate : 60;
    } catch (_) {
      _refreshRateHz = 60;
    }
    return _refreshRateHz!;
  }

  Future<DevicePerformanceProfile> resolve(GraphicsPerformanceMode mode) async {
    final memory = await _readMemory();
    final refreshRate = await _readRefreshRate();
    final cores = Platform.numberOfProcessors;

    final DevicePerformanceTier detected;
    if (memory.lowRam ||
        (memory.totalRamMb > 0 && memory.totalRamMb <= 4096) ||
        cores <= 4) {
      detected = DevicePerformanceTier.lite;
    } else if (memory.totalRamMb >= 7168 && cores >= 8) {
      detected = DevicePerformanceTier.highEnd;
    } else {
      detected = DevicePerformanceTier.standard;
    }

    final tier = switch (mode) {
      GraphicsPerformanceMode.auto => detected,
      GraphicsPerformanceMode.lite => DevicePerformanceTier.lite,
      GraphicsPerformanceMode.highEnd => DevicePerformanceTier.highEnd,
    };

    return DevicePerformanceProfile(
      mode: mode,
      tier: tier,
      blurEnabled: tier == DevicePerformanceTier.highEnd,
      isLowRamDevice: memory.lowRam,
      totalRamMb: memory.totalRamMb,
      processorCount: cores,
      refreshRateHz: refreshRate,
    );
  }
}
