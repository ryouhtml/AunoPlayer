import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:auno_player/services/player_service.dart';

/// Frame-accurate playback position driven by engine anchor ticks.
///
/// The Rust engine publishes its real playback position every 50 ms. Reading
/// that value directly gives a position that only moves twenty times a second,
/// which is visibly stepped on 90 Hz and 120 Hz displays. This clock keeps the
/// last engine value as an anchor and advances it with a monotonic stopwatch
/// every frame:
///
/// ```text
/// positionMs = anchorPositionMs + (nowUs - anchorTimestampUs) * playbackRate
/// ```
///
/// Engine ticks re-anchor the clock, so it never drifts. Only widgets that
/// actually move (progress bars, timestamps, karaoke fills, equalizer bars)
/// should listen to [position]; everything else should keep watching the
/// coarser Riverpod player state.
class PlaybackClock with WidgetsBindingObserver {
  PlaybackClock._();

  static final PlaybackClock instance = PlaybackClock._();

  /// Interpolated position, updated once per displayed frame while playing.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  /// Mirrors the engine's play/pause state without rebuilding on position.
  final ValueNotifier<bool> isPlaying = ValueNotifier(false);

  PlayerService? _service;
  Ticker? _ticker;
  final Stopwatch _clock = Stopwatch();

  int _anchorPositionMs = 0;
  int _anchorElapsedUs = 0;
  double _rate = 1.0;
  bool _attached = false;
  bool _lifecyclePaused = false;

  /// Pure interpolation step, exposed for tests.
  static int interpolatePositionMs({
    required int anchorPositionMs,
    required int elapsedMicros,
    required double playbackRate,
    required bool playing,
  }) {
    if (!playing || elapsedMicros <= 0 || playbackRate <= 0) {
      return anchorPositionMs;
    }
    final advanced = (elapsedMicros / 1000.0) * playbackRate;
    return anchorPositionMs + advanced.round();
  }

  bool get isAttached => _attached;

  /// Starts following [service]. Safe to call more than once.
  void attach(PlayerService service) {
    if (_attached) return;
    _attached = true;
    _service = service;
    _clock.start();
    _lifecyclePaused = false;

    service.positionNotifier.addListener(_onEnginePosition);
    service.isPlayingNotifier.addListener(_onEnginePlayState);
    service.playbackSpeedNotifier.addListener(_onEngineRate);
    WidgetsBinding.instance.addObserver(this);

    _rate = service.playbackSpeedNotifier.value;
    isPlaying.value = service.isPlayingNotifier.value;
    _anchor(service.positionNotifier.value);

    if (isPlaying.value) {
      _startTicker();
    }
  }

  /// Stops following the engine. Intended for tests and hot restart.
  void detach() {
    if (!_attached) return;
    _attached = false;
    _stopTicker();
    final service = _service;
    service?.positionNotifier.removeListener(_onEnginePosition);
    service?.isPlayingNotifier.removeListener(_onEnginePlayState);
    service?.playbackSpeedNotifier.removeListener(_onEngineRate);
    if (WidgetsBinding.instance.isRootWidgetAttached) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _service = null;
    _clock.stop();
  }

  /// Re-anchors to an explicit engine position. Used after a seek when the
  /// engine has not published its first tick yet.
  void syncFromEngine() {
    final service = _service;
    if (service == null) return;
    _rate = service.playbackSpeedNotifier.value;
    isPlaying.value = service.isPlayingNotifier.value;
    _anchor(service.positionNotifier.value);
  }

  void _anchor(Duration enginePosition) {
    _anchorPositionMs = enginePosition.inMilliseconds;
    _anchorElapsedUs = _clock.elapsedMicroseconds;
    position.value = enginePosition;
  }

  void _onEnginePosition() {
    final service = _service;
    if (service == null) return;
    _anchor(service.positionNotifier.value);
  }

  void _onEnginePlayState() {
    final service = _service;
    if (service == null) return;
    isPlaying.value = service.isPlayingNotifier.value;
    _anchor(service.positionNotifier.value);
    if (isPlaying.value && !_lifecyclePaused) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  void _onEngineRate() {
    final service = _service;
    if (service == null) return;
    _rate = service.playbackSpeedNotifier.value;
    _anchor(service.positionNotifier.value);
  }

  void _startTicker() {
    if (_ticker != null) return;
    _ticker = Ticker(_onTick, debugLabel: 'PlaybackClock');
    _ticker!.start();
  }

  void _stopTicker() {
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration _) {
    if (!_attached) return;
    final elapsedUs = _clock.elapsedMicroseconds - _anchorElapsedUs;
    final nextMs = interpolatePositionMs(
      anchorPositionMs: _anchorPositionMs,
      elapsedMicros: elapsedUs,
      playbackRate: _rate,
      playing: isPlaying.value,
    );
    final duration = Duration(milliseconds: nextMs);
    if (position.value != duration) {
      position.value = duration;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _lifecyclePaused = false;
        syncFromEngine();
        if (isPlaying.value) _startTicker();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _lifecyclePaused = true;
        _stopTicker();
        syncFromEngine();
    }
  }
}
