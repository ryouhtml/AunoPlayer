import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:auno_player/core/theme/dynamic_palette.dart';
import 'package:auno_player/providers/dynamic_theme_provider.dart';

/// Exposes the currently animated palette to every descendant.
class DynamicThemeData extends InheritedWidget {
  const DynamicThemeData({
    super.key,
    required this.palette,
    required super.child,
  });

  final DynamicThemePalette palette;

  static DynamicThemePalette of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<DynamicThemeData>()
            ?.palette ??
        DynamicThemePalette.neutral;
  }

  static DynamicThemePalette? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DynamicThemeData>()
        ?.palette;
  }

  @override
  bool updateShouldNotify(DynamicThemeData oldWidget) {
    return !identical(palette, oldWidget.palette);
  }
}

/// Animates palette changes over 450 ms with [Curves.easeOutCubic].
///
/// Only widgets that call [DynamicThemeData.of] rebuild during the transition;
/// the app subtree itself is passed through unchanged.
class DynamicThemeScope extends ConsumerStatefulWidget {
  const DynamicThemeScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DynamicThemeScope> createState() => _DynamicThemeScopeState();
}

class _DynamicThemeScopeState extends ConsumerState<DynamicThemeScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  DynamicThemePalette _from = DynamicThemePalette.neutral;
  DynamicThemePalette _to = DynamicThemePalette.neutral;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: 1,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(DynamicThemePalette target) {
    if (identical(target, _to)) return;
    _from = _current;
    _to = target;
    _controller.forward(from: 0);
  }

  DynamicThemePalette get _current {
    if (_controller.value >= 1) return _to;
    final t = Curves.easeOutCubic.transform(
      _controller.value.clamp(0.0, 1.0),
    );
    return DynamicThemePalette.lerp(_from, _to, t);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DynamicThemePalette>>(dynamicPaletteProvider, (
      previous,
      next,
    ) {
      final palette = next.value;
      if (palette != null) _animateTo(palette);
    });

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return DynamicThemeData(palette: _current, child: widget.child);
      },
    );
  }
}

/// Small helpers for tinted surfaces that keep text legible.
extension DynamicPaletteSurfaces on DynamicThemePalette {
  Color get glassPill => Color.alphaBlend(
    dominant.withValues(alpha: 0.28),
    const Color(0x99101012),
  );

  Color get cardTint => Color.alphaBlend(
    dominant.withValues(alpha: 0.14),
    surface,
  );

  Color get activeGlow => accent.withValues(alpha: 0.55);
}
