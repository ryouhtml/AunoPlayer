import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/core/motion/app_motion.dart';
import 'package:auno_player/core/theme/adaptive_color_provider.dart';
import 'package:auno_player/core/theme/app_colors.dart';

typedef FastIndexSelectCallback = void Function(String token, bool animate);

class SongFastIndexOverlay extends StatefulWidget {
  static const List<String> defaultTokens = <String>[
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '0-9',
    '#',
  ];

  final Map<String, int> tokenToIndex;
  final FastIndexSelectCallback onSelect;
  final String? selectedToken;
  final List<String> tokens;

  const SongFastIndexOverlay({
    super.key,
    required this.tokenToIndex,
    required this.onSelect,
    this.selectedToken,
    this.tokens = defaultTokens,
  });

  @override
  State<SongFastIndexOverlay> createState() => _SongFastIndexOverlayState();
}

class _SongFastIndexOverlayState extends State<SongFastIndexOverlay> {
  String? _activeToken;
  String? _dragToken;
  bool _isDragging = false;

  int _lastSetStateMs = 0;
  static const int _minSetStateIntervalMs = 16; // ~60fps

  bool _shouldThrottleSetState() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSetStateMs < _minSetStateIntervalMs) {
      return true;
    }
    _lastSetStateMs = now;
    return false;
  }

  void _maybeSetState(VoidCallback callback) {
    if (_shouldThrottleSetState()) return;
    setState(callback);
  }

  @override
  void initState() {
    super.initState();
    _activeToken = widget.selectedToken ?? widget.tokens.first;
  }

  @override
  void didUpdateWidget(covariant SongFastIndexOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging &&
        widget.selectedToken != null &&
        widget.selectedToken != _activeToken) {
      _activeToken = widget.selectedToken;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens
        .where(widget.tokenToIndex.containsKey)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_activeToken == null || !tokens.contains(_activeToken)) {
      _activeToken = tokens.first;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const railPadding = AppConstants.spacingXs;
        final usableHeight = (constraints.maxHeight - (railPadding * 2)).clamp(
          0.0,
          double.infinity,
        );
        final spacing = (usableHeight / tokens.length).clamp(8.0, 18.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final token = _tokenFromOffset(
                  localDy: details.localPosition.dy,
                  tokens: tokens,
                  spacing: spacing,
                );
                if (token == null) return;
                _activeToken = token;
                widget.onSelect(token, true);
                _maybeSetState(() {});
              },
              onVerticalDragStart: (details) {
                _maybeSetState(() {
                  _isDragging = true;
                });
                final token = _tokenFromOffset(
                  localDy: details.localPosition.dy,
                  tokens: tokens,
                  spacing: spacing,
                );
                if (token == null) return;
                if (_dragToken != token) {
                  _dragToken = token;
                  widget.onSelect(token, false);
                }
                _maybeSetState(() {});
              },
              onVerticalDragUpdate: (details) {
                final token = _tokenFromOffset(
                  localDy: details.localPosition.dy,
                  tokens: tokens,
                  spacing: spacing,
                );
                if (token == null || _dragToken == token) return;
                _dragToken = token;
                widget.onSelect(token, false);
                _maybeSetState(() {});
              },
              onVerticalDragEnd: (_) {
                setState(() {
                  _isDragging = false;
                  if (_dragToken != null) {
                    _activeToken = _dragToken;
                  }
                });
              },
              onVerticalDragCancel: () {
                setState(() {
                  _isDragging = false;
                  if (_dragToken != null) {
                    _activeToken = _dragToken;
                  }
                });
              },
              child: Container(
                width: 26,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spacingSm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final token in tokens)
                      SizedBox(
                        height: spacing,
                        child: AnimatedDefaultTextStyle(
                          duration: AppConstants.animationFast,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: _colorForToken(context, token),
                                fontWeight: _isHighlighted(token)
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: _isDragging && _dragToken == token
                                    ? 11.5
                                    : 9.5,
                                height: 1,
                              ) ??
                              const TextStyle(),
                          child: Center(child: Text(token, maxLines: 1)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_isDragging && _dragToken != null)
              _buildDragBubble(tokens, spacing, constraints),
          ],
        );
      },
    );
  }

  /// Floating token bubble that tracks the current drag position on the rail
  /// and springs in when the scrub starts.
  Widget _buildDragBubble(
    List<String> tokens,
    double spacing,
    BoxConstraints constraints,
  ) {
    const bubbleWidth = 58.0;
    const bubbleHeight = 50.0;
    // Tokens live inside the rail's vertical padding, each in a `spacing`
    // slot; the bubble centers on the slot of the token being scrubbed.
    const railPadding = AppConstants.spacingSm;
    final index = tokens.indexOf(_dragToken!);
    final railTop = railPadding + (index + 0.5) * spacing - bubbleHeight / 2;
    final maxTop = math.max(0.0, constraints.maxHeight - bubbleHeight);
    final top = railTop.clamp(0.0, maxTop);

    return AnimatedPositioned(
      duration: AppConstants.animationFast,
      curve: AppMotionCurves.fluidDeceleration,
      right: 34,
      top: top,
      width: bubbleWidth,
      height: bubbleHeight,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.8, end: 1.0),
        duration: AppMotionDurations.fast,
        curve: AppMotionCurves.springy,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _dragToken!,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  bool _isHighlighted(String token) {
    return (_isDragging && _dragToken == token) ||
        (!_isDragging && _activeToken == token);
  }

  Color _colorForToken(BuildContext context, String token) {
    if (_isHighlighted(token)) {
      return AppColors.accent;
    }

    if (widget.tokenToIndex.containsKey(token)) {
      return context.adaptiveTextSecondary;
    }

    return context.adaptiveTextTertiary.withValues(alpha: 0.45);
  }

  String? _tokenFromOffset({
    required double localDy,
    required List<String> tokens,
    required double spacing,
  }) {
    if (tokens.isEmpty || spacing <= 0) return null;

    // Clip to the rail's padded content box, then map onto token slots.
    final contentDy = localDy - AppConstants.spacingSm;
    final adjusted = contentDy.clamp(0.0, spacing * tokens.length - 0.01);
    final tokenIndex = (adjusted / spacing).floor().clamp(0, tokens.length - 1);
    return tokens[tokenIndex];
  }
}
