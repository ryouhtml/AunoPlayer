import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show ScrollCacheExtent, ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:auno_player/core/motion/app_motion.dart';
import 'package:auno_player/core/theme/app_theme.dart';
import 'package:auno_player/features/player/widgets/album_color_helpers.dart';
import 'package:auno_player/features/player/widgets/karaoke_lyric_line.dart';
import 'package:auno_player/features/player/widgets/lyrics_alignment.dart';
import 'package:auno_player/l10n/l10n.dart';
import 'package:auno_player/providers/app_preferences_provider.dart';
import 'package:auno_player/providers/karaoke_provider.dart';
import 'package:auno_player/providers/performance_provider.dart';
import 'package:auno_player/services/karaoke_spans.dart';
import 'package:auno_player/services/lyrics_service.dart';
import 'package:auno_player/services/player_service.dart';

/// Synced lyrics list with a fixed focus anchor: the active line pins at
/// [_anchorFraction] of the viewport height, per-line geometry comes from a
/// measured-height registry (TextPainter estimates until real sizes arrive),
/// and animations are single-flight — a new target simply interrupts the
/// previous animateTo.
///
/// User drags suspend auto-following; it resumes after [_followResumeMs] of
/// idle, or immediately on a tap-to-seek or external seek.
class SyncedLyricsView extends ConsumerStatefulWidget {
  final PlayerService playerService;
  final LyricsService lyricsService;
  final LyricsData lyrics;
  final Color? albumColor;

  /// Playback clock to follow. Defaults to the player's own position, but
  /// carousel peek stages pass a static source so only the playing song's
  /// lyrics run.
  final ValueNotifier<Duration>? positionNotifier;

  /// False for peek stages: renders statically without following playback.
  final bool active;

  /// Compact one-line presentation under the transport controls. Reads the
  /// same [lyrics] and [positionNotifier] as the scrolling list — no second
  /// parser and no inferred timing.
  final bool strip;
  final VoidCallback? onStripTap;

  const SyncedLyricsView({
    super.key,
    required this.playerService,
    required this.lyricsService,
    required this.lyrics,
    this.albumColor,
    this.positionNotifier,
    this.active = true,
    this.strip = false,
    this.onStripTap,
  });

  @override
  ConsumerState<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<SyncedLyricsView>
    with SingleTickerProviderStateMixin {
  static const double _anchorFraction = 0.32;
  static const int _followResumeMs = 4000;
  static const int _seekBackThresholdMs = 1200;
  static const int _seekForwardThresholdMs = 3000;
  static const double _measureEpsilonPx = 0.5;
  static const double _correctionMinDeltaPx = 6;

  final ScrollController _scrollController = ScrollController();

  /// Drives the spring that carries the list to the active line. A spring
  /// (instead of animateTo) lets a new target interrupt mid-flight with
  /// velocity continuity and settles without a fixed duration.
  late final AnimationController _springController;
  double _springFrom = 0;
  double _springTo = 0;

  List<double> _inactiveEstimates = const [];
  List<double> _activeEstimates = const [];
  List<double?> _measuredHeights = const [];
  List<double> _lineTops = const [];
  double? _estimatesForWidth;
  LyricsData? _estimatesForLyrics;

  int _activeLineIndex = -1;
  Duration _lastTickPosition = Duration.zero;
  bool _following = true;
  Timer? _followResumeTimer;
  bool _needsInitialJump = true;

  ValueNotifier<Duration> get _positionNotifier =>
      widget.positionNotifier ?? widget.playerService.positionNotifier;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: AppMotionDurations.normal,
    )..addListener(_onSpringTick);
    _positionNotifier.addListener(_onPositionChanged);
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNotifier =
        oldWidget.positionNotifier ?? oldWidget.playerService.positionNotifier;
    if (!identical(oldNotifier, _positionNotifier)) {
      oldNotifier.removeListener(_onPositionChanged);
      _positionNotifier.addListener(_onPositionChanged);
    }
    if (!identical(oldWidget.lyrics, widget.lyrics)) {
      _estimatesForWidth = null;
      _needsInitialJump = true;
    }
    if (oldWidget.active != widget.active && widget.active) {
      _needsInitialJump = true;
    }
  }

  @override
  void dispose() {
    _followResumeTimer?.cancel();
    _positionNotifier.removeListener(_onPositionChanged);
    _springController
      ..removeListener(_onSpringTick)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPositionChanged() {
    // Strip mode drives its own ValueListenableBuilder; the full-list spring
    // state is never initialized there.
    if (widget.strip || !widget.active) return;
    final position = _positionNotifier.value;
    final deltaMs = position.inMilliseconds - _lastTickPosition.inMilliseconds;
    _lastTickPosition = position;
    final isSeekBack = deltaMs <= -_seekBackThresholdMs;
    final isSeek = isSeekBack || deltaMs >= _seekForwardThresholdMs;

    final newIndex = widget.lyricsService.findCurrentLineIndex(
      widget.lyrics,
      position,
    );
    if (newIndex == _activeLineIndex) {
      if (isSeek) _resumeFollow();
      return;
    }

    // Transient position dips from the audio engine must not scroll back.
    if (newIndex < _activeLineIndex && !isSeekBack) return;

    _setActiveIndex(newIndex);
    if (isSeek) _resumeFollow(animateNow: false);
    if (_following) {
      _animateToActiveLine(immediate: isSeek);
    }
  }

  void _syncToPosition() {
    final position = _positionNotifier.value;
    _lastTickPosition = position;
    final newIndex = widget.lyricsService.findCurrentLineIndex(
      widget.lyrics,
      position,
    );
    if (newIndex != _activeLineIndex) {
      _setActiveIndex(newIndex);
    }
    _jumpToActiveLine();
  }

  Future<void> _seekToLine(int index) async {
    if (index < 0 || index >= widget.lyrics.lines.length) return;
    final target = widget.lyrics.lines[index].timestamp;
    widget.playerService.positionNotifier.value = target;
    _lastTickPosition = target;
    _resumeFollow(animateNow: false);
    _setActiveIndex(index);
    _animateToActiveLine();
    await widget.playerService.seek(target);
  }

  // --- geometry ---------------------------------------------------------

  void _ensureEstimates(double listWidth) {
    if (_estimatesForWidth == listWidth &&
        identical(_estimatesForLyrics, widget.lyrics)) {
      return;
    }
    final lines = widget.lyrics.lines;
    final textWidth = listWidth - 44 > 24 ? listWidth - 44 : 24.0;
    final inactive = <double>[];
    final active = <double>[];
    for (final line in lines) {
      inactive.add(
        32 + _estimateTextHeight(line.text, 17, 1.24, 2, textWidth),
      );
      active.add(28 + _estimateTextHeight(line.text, 22, 1.18, 3, textWidth));
    }
    _inactiveEstimates = inactive;
    _activeEstimates = active;
    _measuredHeights = List<double?>.filled(lines.length, null);
    _lineTops = List<double>.filled(lines.length, 0);
    _estimatesForWidth = listWidth;
    _estimatesForLyrics = widget.lyrics;
    _recomputeTops();
  }

  double _estimateTextHeight(
    String text,
    double fontSize,
    double heightFactor,
    int maxLines,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'GoogleSansFlex',
          fontFamilyFallback: AppTheme.fontFamilyFallback,
          fontSize: fontSize,
          height: heightFactor,
          fontWeight: maxLines == 3 ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );
    painter.layout(maxWidth: maxWidth);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  double _heightOf(int index) {
    final measured = index < _measuredHeights.length
        ? _measuredHeights[index]
        : null;
    if (measured != null) return measured;
    return index == _activeLineIndex
        ? _activeEstimates[index]
        : _inactiveEstimates[index];
  }

  void _recomputeTops() {
    final count = widget.lyrics.lines.length;
    if (_lineTops.length != count) {
      _lineTops = List<double>.filled(count, 0);
    }
    var top = 0.0;
    for (var i = 0; i < count; i++) {
      _lineTops[i] = top;
      top += _heightOf(i);
    }
  }

  void _onLineMeasured(int index, double height) {
    if (index >= _measuredHeights.length) return;
    final current = _heightOf(index);
    if ((current - height).abs() <= _measureEpsilonPx) {
      _measuredHeights[index] = height;
      return;
    }
    _measuredHeights[index] = height;
    _recomputeTops();
    if (_following && _scrollController.hasClients) {
      final target = _targetFor(_activeLineIndex);
      if (target != null &&
          (target - _scrollController.offset).abs() >
              _correctionMinDeltaPx) {
        _animateToActiveLine();
      }
    }
  }

  void _setActiveIndex(int index) {
    if (index == _activeLineIndex) return;
    if (_activeLineIndex >= 0 && _activeLineIndex < _measuredHeights.length) {
      _measuredHeights[_activeLineIndex] = null;
    }
    _activeLineIndex = index;
    if (index >= 0 && index < _measuredHeights.length) {
      _measuredHeights[index] = null;
    }
    _recomputeTops();
    setState(() {});
  }

  // --- scrolling --------------------------------------------------------

  double? _targetFor(int index) {
    if (!_scrollController.hasClients) return null;
    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    final anchorPx = viewport * _anchorFraction;
    if (index < 0) return 0.0;
    if (index >= _lineTops.length) return null;
    final center =
        viewport * _anchorFraction + _lineTops[index] + _heightOf(index) / 2;
    return (center - anchorPx).clamp(0.0, position.maxScrollExtent);
  }

  void _onSpringTick() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    final t = _springController.value.clamp(0.0, 1.0);
    final target = _springFrom + (_springTo - _springFrom) * t;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((position.pixels - clamped).abs() > 0.01) {
      position.jumpTo(clamped);
    }
  }

  void _animateToActiveLine({bool immediate = false}) {
    if (!_scrollController.hasClients) return;
    final target = _targetFor(_activeLineIndex);
    if (target == null) return;
    _springController.stop();
    if (immediate || MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(target);
      return;
    }
    if ((target - _scrollController.offset).abs() < 1.0) return;
    _springFrom = _scrollController.offset;
    _springTo = target;
    _springController
      ..value = 0.0
      ..animateWith(
        AppMotionSprings.simulation(
          spring: AppMotionSprings.gentle,
          start: 0.0,
          end: 1.0,
        ),
      );
  }

  void _jumpToActiveLine() {
    if (!_scrollController.hasClients) return;
    final target = _targetFor(_activeLineIndex);
    if (target == null) return;
    _scrollController.jumpTo(target);
  }

  void _suspendFollow() {
    _followResumeTimer?.cancel();
    _springController.stop();
    _followResumeTimer = Timer(const Duration(milliseconds: _followResumeMs), () {
      if (!mounted) return;
      _setFollowing(true);
      _animateToActiveLine();
    });
    _setFollowing(false);
  }

  void _resumeFollow({bool animateNow = true}) {
    _followResumeTimer?.cancel();
    _setFollowing(true);
    if (animateNow) _animateToActiveLine();
  }

  void _setFollowing(bool value) {
    if (_following == value || !mounted) return;
    setState(() => _following = value);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final userDragging =
        (notification is ScrollStartNotification &&
            notification.dragDetails != null) ||
        (notification is ScrollUpdateNotification &&
            notification.dragDetails != null) ||
        (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle);
    if (userDragging) _suspendFollow();
    return false;
  }

  // --- rendering --------------------------------------------------------

  double _opacityForIndex(int index) {
    if (_activeLineIndex < 0) return 0.72;
    final distance = (index - _activeLineIndex).abs();
    switch (distance) {
      case 0:
        return 1;
      case 1:
        return 0.56;
      case 2:
        return 0.36;
      case 3:
        return 0.24;
      default:
        return 0.18;
    }
  }

  double _blurSigmaForIndex(int index) {
    if (_activeLineIndex < 0) return 0;
    final distance = (index - _activeLineIndex).abs();
    // Only the handful of lines around the focus get a filter; further lines
    // already fade with opacity, and bounding the range keeps the number of
    // saved layers per frame small.
    if (distance <= 1 || distance > 4) return 0;
    return math.min(1.2, 0.35 * (distance - 1));
  }

  TextStyle _textStyle(bool isActive, double opacity) {
    return TextStyle(
      fontFamily: 'GoogleSansFlex',
      fontSize: isActive ? 22 : 17,
      height: isActive ? 1.18 : 1.24,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      color: Colors.white.withValues(alpha: opacity),
      shadows: isActive
          ? null
          : const [
              Shadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 1)),
            ],
    );
  }

  StrutStyle _strutStyle(bool isActive) {
    return StrutStyle(
      fontFamily: 'GoogleSansFlex',
      fontSize: isActive ? 22 : 17,
      height: isActive ? 1.18 : 1.24,
      forceStrutHeight: true,
    );
  }

  Color get _sungColor {
    final albumColor = widget.albumColor;
    if (albumColor != null) {
      return albumAccent(albumColor, 0.7, lightness: 0.88);
    }
    return Colors.white;
  }

  Widget _buildLine(
    BuildContext context,
    int index,
    LyricsAlignment alignment, {
    required bool karaokeEnabled,
    required List<KaraokeLine> karaokeLines,
    required KaraokeSweepStyle sweepStyle,
  }) {
    final line = widget.lyrics.lines[index];
    final isActive = index == _activeLineIndex;

    final content = isActive && karaokeEnabled
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: KaraokeLyricLine(
              playerService: widget.playerService,
              lyricsService: widget.lyricsService,
              lyrics: widget.lyrics,
              lineIndex: index,
              textAlign: alignment.textAlign,
              style: _textStyle(true, 1),
              sungColor: _sungColor,
              unsungColor: Colors.white.withValues(alpha: 0.30),
              positionNotifier: _positionNotifier,
              active: widget.active,
              karaokeLine: index < karaokeLines.length
                  ? karaokeLines[index]
                  : null,
              sweepStyle: sweepStyle,
              onSeek: () => unawaited(_seekToLine(index)),
            ),
          )
        : Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: isActive ? 8 : 10),
            child: Text(
              line.text,
              maxLines: 2,
              overflow: TextOverflow.fade,
              textAlign: alignment.textAlign,
              style: _textStyle(isActive, isActive ? 1 : _opacityForIndex(index)),
              strutStyle: _strutStyle(isActive),
            ),
          );

    return Transform.scale(
      scale: isActive ? 1.05 : 0.94,
      alignment: Alignment.center,
      child: _MeasuredLine(
        index: index,
        onMeasured: _onLineMeasured,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => unawaited(_seekToLine(index)),
              child: _applyLineBlur(content, index),
            ),
          ),
        ),
      ),
    );
  }

  /// Progressive blur on lines further from the active one, on top of the
  /// opacity tiers, so focus reads instantly without a hard edge.
  Widget _applyLineBlur(Widget content, int index) {
    // Entry-level GPUs (Helio P35 / SD450) keep the depth illusion with
    // opacity and scale only. Blur is opt-in through the performance profile.
    if (!ref.watch(lyricsBlurEnabledProvider)) return content;
    final sigma = _blurSigmaForIndex(index);
    if (sigma <= 0 || MediaQuery.disableAnimationsOf(context)) return content;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: content,
    );
  }

  Widget _buildResumePill() {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.74),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _resumeFollow,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_upward_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.backToActiveLyrics,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrip(BuildContext context) {
    final alignment = resolveLyricsAlignment(
      ref.watch(appPreferencesProvider).lyricsTextAlign,
    );
    return ValueListenableBuilder<Duration>(
      valueListenable: _positionNotifier,
      builder: (context, position, _) {
        var index = widget.lyricsService.findCurrentLineIndex(
          widget.lyrics,
          position,
        );
        // Plain lyrics carry no timing. Showing the first line is display,
        // not an inferred timestamp — no line is ever auto-timed.
        if (index < 0 && widget.lyrics.lines.isNotEmpty) index = 0;
        final text = index >= 0 && index < widget.lyrics.lines.length
            ? widget.lyrics.lines[index].text
            : '';
        return Semantics(
          button: true,
          label: context.l10n.showLyrics,
          child: GestureDetector(
            onTap: widget.onStripTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: alignment.textAlign,
                      style: const TextStyle(
                        fontFamily: 'GoogleSansFlex',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.strip) return _buildStrip(context);
    final alignment = resolveLyricsAlignment(
      ref.watch(appPreferencesProvider).lyricsTextAlign,
    );
    final preferences = ref.watch(appPreferencesProvider);
    final karaokeEnabled = preferences.karaokeEnabled;
    final karaokeLines = ref
        .watch(karaokeNormalizerProvider)
        .fromLyricsData(widget.lyrics);
    final sweepStyle =
        karaokeSweepStyleFromString(preferences.karaokeSweepStyle);

    return LayoutBuilder(
      builder: (context, constraints) {
        _ensureEstimates(constraints.maxWidth);
        if (_needsInitialJump) {
          _needsInitialJump = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncToPosition();
          });
        }

        final anchorPx = constraints.maxHeight * _anchorFraction;
        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: ListView.builder(
                controller: _scrollController,
                scrollCacheExtent: ScrollCacheExtent.pixels(900),
                padding: EdgeInsets.only(
                  top: anchorPx,
                  bottom: constraints.maxHeight - anchorPx,
                  left: 10,
                  right: 10,
                ),
                itemCount: widget.lyrics.lines.length,
                itemBuilder: (context, index) => _buildLine(
                    context,
                    index,
                    alignment,
                    karaokeEnabled: karaokeEnabled,
                    karaokeLines: karaokeLines,
                    sweepStyle: sweepStyle,
                  ),
              ),
            ),
            // Visible while the reader is browsing away from the current line:
            // one tap restores auto-follow.
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: AnimatedSwitcher(
                duration: AppMotionDurations.fast,
                switchInCurve: AppMotionCurves.entrance,
                switchOutCurve: AppMotionCurves.exit,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: _following
                    ? const SizedBox.shrink()
                    : Center(child: _buildResumePill()),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Reports its rendered height after each frame so the parent can keep its
/// line geometry registry in sync with reality.
class _MeasuredLine extends StatefulWidget {
  final int index;
  final void Function(int index, double height) onMeasured;
  final Widget child;

  const _MeasuredLine({
    required this.index,
    required this.onMeasured,
    required this.child,
  });

  @override
  State<_MeasuredLine> createState() => _MeasuredLineState();
}

class _MeasuredLineState extends State<_MeasuredLine> {
  double? _reported;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return widget.child;
  }

  void _report() {
    if (!mounted) return;
    final size = context.size;
    if (size == null) return;
    if (_reported != null &&
        (_reported! - size.height).abs() <= 0.5) {
      return;
    }
    _reported = size.height;
    widget.onMeasured(widget.index, size.height);
  }
}
