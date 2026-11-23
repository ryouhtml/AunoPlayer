/// Actual listened time and metadata for one deduplicated play session.
class ListeningSessionSnapshot {
  const ListeningSessionSnapshot({
    required this.songId,
    required this.sessionId,
    required this.startedAt,
    required this.listenedMs,
    required this.completedRatio,
    required this.title,
    required this.artist,
    required this.album,
  });

  final String songId;
  final String sessionId;
  final DateTime startedAt;
  final int listenedMs;
  final double completedRatio;
  final String title;
  final String artist;
  final String album;
}

class ReplayPlayTracker {
  ReplayPlayTracker({
    this.minimumPlayDuration = const Duration(seconds: 30),
    this.maxContinuousProgressGap = const Duration(seconds: 3),
    this.maxRealtimeDrift = const Duration(seconds: 2),
    DateTime Function()? now,
    String Function()? sessionIdFactory,
  })  : _now = now ?? DateTime.now,
        _sessionIdFactory = sessionIdFactory ?? _defaultSessionIdFactory;

  final DateTime Function() _now;
  final String Function() _sessionIdFactory;
  final Duration maxRealtimeDrift;

  final Duration minimumPlayDuration;
  final Duration maxContinuousProgressGap;

  String? _songId;
  String? _sessionId;
  DateTime? _startedAt;
  int _totalDurationMs = 0;
  int _lastPositionMs = 0;
  int _listenedMs = 0;
  bool _hasCountedCurrentTrack = false;
  DateTime? _lastProgressAt;

  /// Stable id for the current session. Pause/resume reuses it.
  String? get sessionId => _sessionId;

  /// Actual heard time accumulated for the current session.
  Duration get listenedDuration => Duration(milliseconds: _listenedMs);

  static String _defaultSessionIdFactory() {
    final counter = DateTime.now().microsecondsSinceEpoch;
    return 'auno-$counter-${_nextCounter()}';
  }

  static int _staticCounter = 0;
  static int _nextCounter() => ++_staticCounter;

  void startTrack(
    String songId, {
    Duration initialPosition = Duration.zero,
    Duration totalDuration = Duration.zero,
  }) {
    _songId = songId;
    _sessionId = _sessionIdFactory();
    _startedAt = _now();
    _totalDurationMs = totalDuration.inMilliseconds;
    _lastPositionMs = initialPosition.inMilliseconds;
    _listenedMs = 0;
    _hasCountedCurrentTrack = false;
    _lastProgressAt = _now();
  }

  void clear() {
    _songId = null;
    _sessionId = null;
    _startedAt = null;
    _totalDurationMs = 0;
    _lastPositionMs = 0;
    _listenedMs = 0;
    _hasCountedCurrentTrack = false;
    _lastProgressAt = null;
  }

  void syncPosition({required String songId, required Duration position}) {
    if (_songId != songId) {
      startTrack(songId, initialPosition: position);
      return;
    }

    _lastPositionMs = position.inMilliseconds;
    _lastProgressAt = _now();
  }

  bool onPositionChanged({required String songId, required Duration position}) {
    if (_songId != songId) {
      startTrack(songId, initialPosition: position);
      return false;
    }

    final now = _now();
    final positionMs = position.inMilliseconds;
    final deltaMs = positionMs - _lastPositionMs;
    final wallDeltaMs = _lastProgressAt == null
        ? deltaMs
        : now.difference(_lastProgressAt!).inMilliseconds;

    _lastPositionMs = positionMs;
    _lastProgressAt = now;

    if (_hasCountedCurrentTrack || deltaMs <= 0) {
      return false;
    }

    if (deltaMs > maxContinuousProgressGap.inMilliseconds) {
      final driftMs = (deltaMs - wallDeltaMs).abs();
      if (wallDeltaMs <= 0 || driftMs > maxRealtimeDrift.inMilliseconds) {
        return false;
      }
    }

    _listenedMs += deltaMs;
    if (_listenedMs < minimumPlayDuration.inMilliseconds) {
      return false;
    }

    _hasCountedCurrentTrack = true;
    return true;
  }

  /// Builds the event to persist after [onPositionChanged] returns true.
  /// The session id and start time do not change on pause/resume.
  ListeningSessionSnapshot? consumeEvent({
    required String title,
    required String artist,
    required String album,
  }) {
    if (!_hasCountedCurrentTrack || _songId == null) return null;
    final ratio = _totalDurationMs > 0
        ? (_listenedMs / _totalDurationMs).clamp(0.0, 1.0)
        : 0.0;
    return ListeningSessionSnapshot(
      songId: _songId!,
      sessionId: _sessionId ?? _defaultSessionIdFactory(),
      startedAt: _startedAt ?? _now(),
      listenedMs: _listenedMs,
      completedRatio: ratio,
      title: title,
      artist: artist,
      album: album,
    );
  }
}
