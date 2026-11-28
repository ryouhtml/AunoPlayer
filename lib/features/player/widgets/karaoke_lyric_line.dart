import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:auno_player/services/karaoke_model.dart';
import 'package:auno_player/services/karaoke_spans.dart';
import 'package:auno_player/services/lyrics_service.dart';
import 'package:auno_player/services/player_service.dart';

/// Renders a single lyric line as karaoke-style text: a soft highlight
/// sweeps through the words in reading order based on playback position.
/// Real enhanced-LRC word timings drive the sweep; plain synced lines fall
/// back to a single whole-line window.
///
/// The widget subscribes to [PlayerService.positionNotifier] and
/// extrapolates between engine ticks with a frame ticker, so the sweep stays
/// smooth even when position updates arrive infrequently.
class KaraokeLyricLine extends StatefulWidget {
  final PlayerService playerService;
  final LyricsService lyricsService;
  final LyricsData lyrics;
  final int lineIndex;
  final TextAlign textAlign;
  final TextStyle style;
  final Color sungColor;
  final Color unsungColor;

  /// Position source to sweep against. Defaults to the player's own position;
  /// carousel peek stages pass a static source so their sweep stays put.
  final ValueNotifier<Duration>? positionNotifier;

  /// False for peek stages: no ticker, no sweep.
  final bool active;

  /// Normalized BitChord-style line. When supplied, its real spans drive the
  /// sweep; otherwise the legacy enhanced-LRC path is used unchanged.
  final KaraokeLine? karaokeLine;

  /// Granularity chosen in lyrics settings.
  final KaraokeSweepStyle sweepStyle;

  /// Optional callback so the widget itself can handle tap-to-seek.
  final VoidCallback? onSeek;

  /// Dims inactive carousel lines while keeping their text readable.
  final bool background;

  const KaraokeLyricLine({
    super.key,
    required this.playerService,
    required this.lyricsService,
    required this.lyrics,
    required this.lineIndex,
    required this.textAlign,
    required this.style,
    required this.sungColor,
    required this.unsungColor,
    this.positionNotifier,
    this.active = true,
    this.karaokeLine,
    this.sweepStyle = KaraokeSweepStyle.auto,
    this.onSeek,
    this.background = false,
  });

  @override
  State<KaraokeLyricLine> createState() => _KaraokeLyricLineState();
}

class _KaraokeLyricLineState extends State<KaraokeLyricLine>
    with SingleTickerProviderStateMixin {
  static const double _fillEpsilon = 0.0004;

  late List<LyricsWord> _segments;
  List<KaraokeSpan> _spans = const [];
  Duration _basePosition = Duration.zero;
  Duration _tickerElapsed = Duration.zero;
  Duration _baseTickerElapsed = Duration.zero;
  bool _isPlaying = false;
  Ticker? _ticker;
  List<double> _lastFills = const [];
  int _builtForLineIndex = -1;
  LyricsData? _builtForLyrics;
  KaraokeLine? _builtForKaraokeLine;
  KaraokeSweepStyle _builtForSweepStyle = KaraokeSweepStyle.auto;

  ValueNotifier<Duration> get _positionNotifier =>
      widget.positionNotifier ?? widget.playerService.positionNotifier;

  @override
  void initState() {
    super.initState();
    _basePosition = _positionNotifier.value;
    _isPlaying = widget.playerService.isPlayingNotifier.value;
    _positionNotifier.addListener(_onPositionTick);
    widget.playerService.isPlayingNotifier.addListener(_onPlayingChanged);
    _resolveWords();
    _updateTicker();
  }

  @override
  void didUpdateWidget(covariant KaraokeLyricLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNotifier =
        oldWidget.positionNotifier ?? oldWidget.playerService.positionNotifier;
    if (!identical(oldNotifier, _positionNotifier)) {
      oldNotifier.removeListener(_onPositionTick);
      _basePosition = _positionNotifier.value;
      _baseTickerElapsed = _tickerElapsed;
      _positionNotifier.addListener(_onPositionTick);
    }
    if (!identical(oldWidget.lyrics, widget.lyrics) ||
        oldWidget.lineIndex != widget.lineIndex ||
        oldWidget.karaokeLine != widget.karaokeLine ||
        oldWidget.sweepStyle != widget.sweepStyle) {
      _resolveWords();
      _onPositionTick();
      return;
    }
    if (oldWidget.active != widget.active) {
      _onPositionTick();
      return;
    }
    _updateTicker();
  }

  void _resolveWords() {
    _segments = [
      for (final word
          in widget.lyricsService.resolveWords(widget.lyrics, widget.lineIndex))
        ...LyricsService.splitKaraokeWord(word),
    ];
    _spans = widget.karaokeLine == null
        ? const []
        : wordSpans(widget.karaokeLine!, widget.sweepStyle);
    _builtForLineIndex = widget.lineIndex;
    _builtForLyrics = widget.lyrics;
    _builtForKaraokeLine = widget.karaokeLine;
    _builtForSweepStyle = widget.sweepStyle;
    _lastFills = const [];
  }

  void _onPositionTick() {
    _basePosition = _positionNotifier.value;
    _baseTickerElapsed = _tickerElapsed;
    _updateTicker();
  }

  void _onPlayingChanged() {
    // Freeze extrapolation at the exact current predicted position so
    // pausing does not jump the fill forward.
    _basePosition = _predictedPosition();
    _baseTickerElapsed = _tickerElapsed;
    _isPlaying = widget.playerService.isPlayingNotifier.value;
    _updateTicker();
  }

  void _updateTicker() {
    final shouldRun = widget.active &&
        _isPlaying &&
        (_segments.isNotEmpty || _spans.isNotEmpty) &&
        mounted;
    if (shouldRun && _ticker == null) {
      _tickerElapsed = Duration.zero;
      _baseTickerElapsed = Duration.zero;
      _ticker = createTicker(_onFrame);
      _ticker!.start();
    } else if (!shouldRun && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
      _rebuildIfFillsChanged();
    }
  }

  Duration _predictedPosition() {
    if (!_isPlaying) return _basePosition;
    final ahead = _tickerElapsed - _baseTickerElapsed;
    if (ahead < Duration.zero) return _basePosition;
    return _basePosition + ahead;
  }

  void _onFrame(Duration elapsed) {
    _tickerElapsed = elapsed;
    _rebuildIfFillsChanged();
  }

  void _rebuildIfFillsChanged() {
    if ((_segments.isEmpty && _spans.isEmpty) || !mounted) return;

    final position = _predictedPosition();
    final nextFills = _spans.isNotEmpty
        ? sweepSpans(
                widget.karaokeLine!,
                position.inMilliseconds,
                widget.sweepStyle,
              )
            .map((swept) => swept.fill)
            .toList(growable: false)
        : <double>[
            for (final segment in _segments)
              LyricsService.fillForWord(segment, position),
          ];

    final previous = _lastFills;
    var changed = previous.length != nextFills.length;
    if (!changed) {
      for (var i = 0; i < nextFills.length; i++) {
        if ((previous[i] - nextFills[i]).abs() > _fillEpsilon) {
          changed = true;
          break;
        }
      }
    }
    if (!changed) return;

    setState(() => _lastFills = nextFills);
  }

  WrapAlignment get _wrapAlignment {
    switch (widget.textAlign) {
      case TextAlign.left:
        return WrapAlignment.start;
      case TextAlign.right:
        return WrapAlignment.end;
      default:
        return WrapAlignment.center;
    }
  }

  Widget _buildWord(LyricsWord word, double fill) {
    final clamped = fill.clamp(0.0, 1.0);
    final durationMs = word.end.inMilliseconds - word.start.inMilliseconds;
    final edgeStart = clamped >= 1.0 || durationMs <= 0
        ? clamped
        : (clamped - 80 / durationMs).clamp(0.0, 1.0);

    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [widget.sungColor, widget.unsungColor],
          stops: [edgeStart, clamped],
        ).createShader(rect);
      },
      child: Text(word.text, style: widget.style),
    );
  }

  Widget _buildSpan(KaraokeSpan span, double fill) {
    final clamped = fill.clamp(0.0, 1.0);
    final durationMs = span.endMs - span.startMs;
    final edgeStart = clamped >= 1.0 || durationMs <= 0
        ? clamped
        : (clamped - 80 / durationMs).clamp(0.0, 1.0);

    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [widget.sungColor, widget.unsungColor],
          stops: [edgeStart, clamped],
        ).createShader(rect);
      },
      child: Text(span.text, style: widget.style),
    );
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _positionNotifier.removeListener(_onPositionTick);
    widget.playerService.isPlayingNotifier.removeListener(_onPlayingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_builtForLineIndex != widget.lineIndex ||
        !identical(_builtForLyrics, widget.lyrics) ||
        !identical(_builtForKaraokeLine, widget.karaokeLine) ||
        _builtForSweepStyle != widget.sweepStyle) {
      _resolveWords();
    }

    Widget content;
    if (_spans.isNotEmpty) {
      final fills = _lastFills.isEmpty
          ? List<double>.filled(_spans.length, 0.0)
          : _lastFills;
      content = SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: _wrapAlignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < _spans.length; i++)
              _buildSpan(_spans[i], i < fills.length ? fills[i] : 0.0),
          ],
        ),
      );
    } else if (_segments.isNotEmpty) {
      final fills = _lastFills.isEmpty
          ? List<double>.filled(_segments.length, 0.0)
          : _lastFills;
      content = SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: _wrapAlignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < _segments.length; i++)
              _buildWord(_segments[i], i < fills.length ? fills[i] : 0.0),
          ],
        ),
      );
    } else {
      content = Text(
        widget.karaokeLine?.text ?? widget.lyrics.lines[widget.lineIndex].text,
        textAlign: widget.textAlign,
        style: widget.style,
      );
    }

    if (widget.onSeek != null) {
      content = GestureDetector(
        onTap: widget.onSeek,
        child: content,
      );
    }
    if (widget.background) {
      content = Opacity(opacity: 0.45, child: content);
    }
    return content;
  }
}
