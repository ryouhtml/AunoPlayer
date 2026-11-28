import 'package:flutter/material.dart';
import 'package:auno_player/features/songs/widgets/orbit_scroll.dart';
import 'package:auno_player/features/songs/widgets/wheel_transform.dart';
import 'package:auno_player/l10n/l10n.dart';
import 'package:auno_player/models/orbit_card_background_style.dart';
import 'package:auno_player/models/song.dart';

/// Callable transform object so `OrbitScroll` can compare settings instead of
/// rebuilding a fresh closure on every parent build.
class WheelItemTransform {
  final double radius;
  final bool reduceMotion;

  const WheelItemTransform({
    this.radius = WheelTransform.defaultRadius,
    this.reduceMotion = false,
  });

  Matrix4 call(double distance) => wheelMatrix(
        distance,
        radius: radius,
        reduceMotion: reduceMotion,
      );

  @override
  bool operator ==(Object other) =>
      other is WheelItemTransform &&
      other.radius == radius &&
      other.reduceMotion == reduceMotion;

  @override
  int get hashCode => Object.hash(radius, reduceMotion);
}

/// Cylindrical wheel that replaces the default library view.
///
/// It reuses `OrbitScroll`'s proven fling, snap, artwork and state-retention
/// machinery; only the distance curves, 3D matrix and accessibility labels are
/// wheel-specific.
class WheelSongList extends StatelessWidget {
  static final double Function(double distance) _scale = wheelScale;
  static final double Function(double distance) _opacity = wheelOpacity;

  final List<Song> songs;
  final int selectedIndex;
  final OrbitScrollController? controller;

  final ValueChanged<int>? onSelectedIndexChanged;
  final ValueChanged<int>? onSongSelected;
  final ValueChanged<int>? onSongSwipedLeft;
  final ValueChanged<int>? onSongSwipedRight;
  final void Function(int index)? onSongActions;

  final bool swipeActionsEnabled;
  final bool isSelectionMode;
  final Set<String> selectedIds;

  final Axis scrollDirection;
  final double radiusRatio;
  final double centerOffsetRatio;
  final double centerYRatio;
  final double itemSpacing;
  final double selectedScale;
  final double depth;
  final int visibleItems;
  final double cardArtSize;
  final double cardWidthRatio;
  final double artResolutionMultiplier;
  final bool showPath;
  final bool showGlow;
  final OrbitCardBackgroundStyle cardBackgroundStyle;
  final double pathOverflowBottom;
  final double paintOverflowTop;
  final EdgeInsets horizontalPaintOverflow;

  /// Test hook. When null the widget follows `MediaQuery.disableAnimationsOf`.
  final bool? reduceMotion;

  const WheelSongList({
    super.key,
    required this.songs,
    this.selectedIndex = 0,
    this.controller,
    this.onSelectedIndexChanged,
    this.onSongSelected,
    this.onSongSwipedLeft,
    this.onSongSwipedRight,
    this.onSongActions,
    this.swipeActionsEnabled = false,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.scrollDirection = Axis.vertical,
    this.radiusRatio = 1.0,
    this.centerOffsetRatio = -0.5,
    this.centerYRatio = 0.42,
    this.itemSpacing = 0.28,
    this.selectedScale = 1.25,
    this.depth = 0.75,
    this.visibleItems = 5,
    this.cardArtSize = 64.0,
    this.cardWidthRatio = 0.68,
    this.artResolutionMultiplier = 2.0,
    this.showPath = true,
    this.showGlow = true,
    this.cardBackgroundStyle = OrbitCardBackgroundStyle.blackGradient,
    this.pathOverflowBottom = 0.0,
    this.paintOverflowTop = 0.0,
    this.horizontalPaintOverflow = EdgeInsets.zero,
    this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final reduced =
        reduceMotion ?? MediaQuery.disableAnimationsOf(context);
    final l10n = context.l10n;

    return OrbitScroll(
      songs: songs,
      selectedIndex: selectedIndex,
      controller: controller,
      scrollDirection: scrollDirection,
      radiusRatio: radiusRatio,
      centerOffsetRatio: centerOffsetRatio,
      centerYRatio: centerYRatio,
      itemSpacing: itemSpacing,
      selectedScale: selectedScale,
      depth: depth,
      visibleItems: visibleItems,
      cardArtSize: cardArtSize,
      cardWidthRatio: cardWidthRatio,
      artResolutionMultiplier: artResolutionMultiplier,
      showPath: showPath,
      showGlow: showGlow,
      cardBackgroundStyle: cardBackgroundStyle,
      pathOverflowBottom: pathOverflowBottom,
      paintOverflowTop: paintOverflowTop,
      horizontalPaintOverflow: horizontalPaintOverflow,
      swipeActionsEnabled: swipeActionsEnabled,
      isSelectionMode: isSelectionMode,
      selectedIds: selectedIds,
      onSelectedIndexChanged: onSelectedIndexChanged,
      onSongSelected: onSongSelected,
      onSongSwipedLeft: onSongSwipedLeft,
      onSongSwipedRight: onSongSwipedRight,
      onSongActions: onSongActions,
      scaleForDistance: _scale,
      opacityForDistance: _opacity,
      itemTransform: WheelItemTransform(reduceMotion: reduced),
      itemSemanticsLabel: (index) {
        final song = songs[index];
        return '${l10n.play}: ${song.title} — ${song.artist}';
      },
    );
  }
}
