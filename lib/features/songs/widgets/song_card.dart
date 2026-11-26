import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:auno_player/core/theme/app_colors.dart';
import 'package:auno_player/core/theme/app_theme.dart';
import 'package:auno_player/core/constants/app_constants.dart';
import 'package:auno_player/core/utils/app_haptics.dart';
import 'package:auno_player/models/orbit_card_background_style.dart';
import 'package:auno_player/models/song.dart';
import 'package:auno_player/features/player/widgets/album_color_helpers.dart';
import 'package:auno_player/features/songs/widgets/orbit_card_blur.dart';
import 'package:auno_player/services/album_art_service.dart';
import 'package:auno_player/services/color_extraction_service.dart';
import 'package:auno_player/widgets/common/cached_image_widget.dart';
import 'package:auno_player/widgets/common/flick_artwork_placeholder.dart';
import 'package:auno_player/l10n/l10n.dart';

/// Song card widget for displaying in the orbit scroll.
class SongCard extends StatefulWidget {
  /// Song data to display
  final Song song;

  /// Scale factor based on position in orbit (0.0 - 1.0)
  final double scale;

  /// Opacity based on position in orbit (0.0 - 1.0)
  final double opacity;

  /// Whether this song is currently selected
  final bool isSelected;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  /// Callback when the card is swiped left.
  final VoidCallback? onSwipeLeft;

  /// Callback when the card is swiped right.
  final VoidCallback? onSwipeRight;

  /// Whether swipe-to-queue and swipe-to-favorite gestures are enabled.
  final bool swipeActionsEnabled;

  /// Whether multiselect mode is active.
  final bool isSelectionMode;

  /// Whether this song is selected in multiselect mode.
  final bool isMultiSelected;

  /// Base album-art size for non-selected cards (overrides default).
  final double artSizeBase;

  /// Album-art size for the selected card (overrides default).
  final double artSizeLarge;

  /// Card width as a fraction of screen width (overrides default).
  final double cardWidthRatio;

  /// Decode-resolution multiplier applied to art size (higher = sharper, heavier).
  final double artResolutionMultiplier;
  final double? width;
  final double? height;
  final bool artworkAbove;

  /// Background treatment used by the portrait card face.
  final OrbitCardBackgroundStyle backgroundStyle;

  /// Opens the song action sheet from the artwork overflow button. When null
  /// the affordance is hidden (e.g. selection mode or compact previews).
  final VoidCallback? onOpenActions;

  const SongCard({
    super.key,
    required this.song,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.isSelected = false,
    this.onTap,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.swipeActionsEnabled = false,
    this.isSelectionMode = false,
    this.isMultiSelected = false,
    this.artSizeBase = AppConstants.songCardArtSize,
    this.artSizeLarge = AppConstants.songCardArtSizeLarge,
    this.cardWidthRatio = 0.68,
    this.artResolutionMultiplier = 2.0,
    this.width,
    this.height,
    this.artworkAbove = false,
    this.backgroundStyle = OrbitCardBackgroundStyle.blackGradient,
    this.onOpenActions,
  });

  @override
  State<SongCard> createState() => _SongCardState();
}

class _SongCardState extends State<SongCard> {
  double _dragDx = 0;
  bool _queuedFlash = false;
  bool _favoriteFlash = false;

  /// Retained card face. Orbit motion changes only scale/opacity, so keeping
  /// this subtree identical between animation ticks avoids rebuilding the
  /// artwork, gradients and text on every frame.
  Widget? _cardFace;

  /// Resolves the per-card tint for [OrbitCardBackgroundStyle.albumColorGradient].
  /// The future is rebuilt only when the song or background style changes; the
  /// service caches extracted colors, so later resolutions are instant.
  late Future<Color?> _albumColorFuture;

  @override
  void initState() {
    super.initState();
    _albumColorFuture = _resolveAlbumColor();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited widgets may have changed (theme, media query, etc.).
    _cardFace = null;
  }

  @override
  void didUpdateWidget(covariant SongCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Song equality compares only the id, so use identity here: metadata or
    // artwork for the same id must refresh the retained face.
    final songChanged = !identical(oldWidget.song, widget.song);
    if (songChanged ||
        oldWidget.isSelected != widget.isSelected ||
        oldWidget.isSelectionMode != widget.isSelectionMode ||
        oldWidget.isMultiSelected != widget.isMultiSelected ||
        oldWidget.artSizeBase != widget.artSizeBase ||
        oldWidget.artSizeLarge != widget.artSizeLarge ||
        oldWidget.artResolutionMultiplier != widget.artResolutionMultiplier ||
        oldWidget.artworkAbove != widget.artworkAbove ||
        oldWidget.backgroundStyle != widget.backgroundStyle ||
        (oldWidget.onOpenActions == null) != (widget.onOpenActions == null)) {
      _cardFace = null;
    }
    if (songChanged ||
        oldWidget.artworkAbove != widget.artworkAbove ||
        oldWidget.backgroundStyle != widget.backgroundStyle) {
      _albumColorFuture = _resolveAlbumColor();
    }
  }

  Future<Color?> _resolveAlbumColor() {
    if (widget.artworkAbove ||
        widget.backgroundStyle != OrbitCardBackgroundStyle.albumColorGradient) {
      return Future<Color?>.value(null);
    }
    final song = widget.song;
    return () async {
      // Resolve embedded or folder artwork before sampling; the service keeps
      // the expensive extraction off the layout path and caches the result.
      final path = await AlbumArtService.instance.resolveArtworkPath(
        existingPath: song.albumArt,
        audioSourcePath: song.filePath ?? '',
      );
      if (path == null) return null;
      return ColorExtractionService().extractDominantColor(path);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final artSize =
        widget.isSelected ? widget.artSizeLarge : widget.artSizeBase;
    final cardFace = _cardFace ??= _buildCardFace(artSize);

    final cardWidth = widget.width ??
        MediaQuery.sizeOf(context).width * widget.cardWidthRatio;
    final cardHeight = widget.height ?? 130.0;

    final isSwiping = _dragDx.abs() > 0.001;
    final isFlashing = _queuedFlash || _favoriteFlash;
    final showSwipeOverlay = isSwiping || isFlashing;

    GestureDragUpdateCallback? dragUpdate;
    GestureDragEndCallback? dragEnd;
    GestureDragCancelCallback? dragCancel;
    if (widget.swipeActionsEnabled) {
      dragUpdate = (details) {
        final nextDx = (_dragDx + details.delta.dx).clamp(-120.0, 120.0);
        if (nextDx != _dragDx) {
          setState(() {
            _dragDx = nextDx;
          });
        }
      };
      dragEnd = (details) {
        unawaited(() async {
          final shouldFavorite =
              _dragDx >= 80 ||
              (details.primaryVelocity != null &&
                  details.primaryVelocity! > 400);
          final shouldQueue =
              _dragDx <= -80 ||
              (details.primaryVelocity != null &&
                  details.primaryVelocity! < -400);
          if (shouldFavorite) {
            AppHaptics.confirm();
            setState(() {
              _dragDx = 0;
              _favoriteFlash = true;
            });
            widget.onSwipeRight?.call();
            await Future<void>.delayed(const Duration(milliseconds: 180));
            if (!mounted) return;
            setState(() {
              _favoriteFlash = false;
            });
            return;
          }
          if (shouldQueue) {
            AppHaptics.confirm();
            setState(() {
              _dragDx = 0;
              _queuedFlash = true;
            });
            widget.onSwipeLeft?.call();
            await Future<void>.delayed(const Duration(milliseconds: 180));
            if (!mounted) return;
            setState(() {
              _queuedFlash = false;
            });
            return;
          }
          setState(() {
            _dragDx = 0;
          });
        }());
      };
      dragCancel = () {
        if (_dragDx != 0) {
          setState(() {
            _dragDx = 0;
          });
        }
      };
    }

    return GestureDetector(
      onTap: () {
        AppHaptics.tap();
        widget.onTap?.call();
      },
      onHorizontalDragUpdate: dragUpdate,
      onHorizontalDragEnd: dragEnd,
      onHorizontalDragCancel: dragCancel,
      // Keep the changing scale/opacity outside the retained artwork: the
      // RepaintBoundary caches the card face while the motion above it moves.
      child: Transform.scale(
        scale: widget.scale.isFinite ? widget.scale : 1.0,
        child: Opacity(
          opacity: widget.opacity.isFinite ? widget.opacity.clamp(0.0, 1.0) : 1.0,
          child: RepaintBoundary(
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: showSwipeOverlay
                  ? _buildSwipeStack(cardWidth, cardFace)
                  : cardFace,
            ),
          ),
        ),
      ),
    );
  }

  /// Inner padding of the portrait banner face.
  static const double _cardInset = 10.0;

  Widget _buildCardFace(double artSize) {
    if (widget.artworkAbove) return _buildArtworkCard(artSize);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(AppConstants.radiusLg)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Banner layout: a framed cover anchored on the right, metadata on
          // the left over a scrimmed backdrop. The cover is clamped to the card
          // height so a large art preference cannot overflow a short card.
          final available = constraints.maxHeight.isFinite
              ? constraints.maxHeight - _cardInset * 2
              : artSize;
          final coverSide =
              artSize.clamp(40.0, math.max(40.0, available)).toDouble();
          return Stack(
            children: [
              Positioned.fill(child: _buildPortraitBackground()),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(_cardInset),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _buildSongInfo(
                          context,
                          isSelected: widget.isSelected,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingSm),
                      _buildCoverTile(coverSide),
                    ],
                  ),
                ),
              ),
              if (widget.isSelectionMode)
                Positioned(
                  top: AppConstants.spacingXs,
                  right: AppConstants.spacingXs,
                  child: Icon(
                    widget.isMultiSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: widget.isMultiSelected
                        ? AppColors.accent
                        : Colors.white54,
                    size: 22,
                  ),
                )
              else if (widget.onOpenActions != null)
                Positioned(
                  top: AppConstants.spacingXs,
                  right: AppConstants.spacingXs,
                  child: _buildOverflowButton(),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Sharp, framed cover tile used by the portrait banner face. Decoding stays
  /// tied to [artSizeBase]/[artSizeLarge] so the orbit's memory budget is
  /// unchanged even though the tile is painted on its own.
  Widget _buildCoverTile(double side) {
    final radius = BorderRadius.circular(AppConstants.radiusMd);
    return SizedBox(
      width: side,
      height: side,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildRawImage(
                widget.song.albumArt ?? '',
                audioSourcePath: widget.song.filePath,
                artSize:
                    widget.isSelected ? widget.artSizeLarge : widget.artSizeBase,
              ),
              // Hairline frame keeps the cover edge visible on bright artwork.
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkCard(double artSize) {
    return Semantics(
      selected: widget.isSelected || widget.isMultiSelected,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: AppColors.glassBorder),
        ),
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Short stages keep the artwork instead of collapsing to a text
            // overlay. The footer stays one line per field and scrolls only
            // when enlarged text needs more room than the card can give it.
            final footerMaxHeight = constraints.maxHeight * 0.45;
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                        child: _buildRawImage(
                          widget.song.albumArt ?? '',
                          audioSourcePath: widget.song.filePath,
                          artSize: math.max(
                            artSize,
                            constraints.maxWidth,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: footerMaxHeight),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'GoogleSansFlex',
                                fontFamilyFallback: AppTheme.fontFamilyFallback,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                                letterSpacing: -0.1,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'GoogleSansFlex',
                                fontFamilyFallback: AppTheme.fontFamilyFallback,
                                fontSize: 12,
                                height: 1.2,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.isSelectionMode)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isMultiSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: widget.isMultiSelected
                            ? AppColors.accent
                            : AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  )
                else if (widget.onOpenActions != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _buildOverflowButton(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverflowButton() {
    return Semantics(
      button: true,
      label: l10n.more,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => widget.onOpenActions?.call(),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeStack(double cardWidth, Widget cardFace) {
    final queueProgress = (-_dragDx / 110).clamp(0.0, 1.0);
    final favoriteProgress = (_dragDx / 110).clamp(0.0, 1.0);
    final isFlashing = _queuedFlash || _favoriteFlash;

    final glowColor = (_favoriteFlash ? Colors.redAccent : AppColors.accent)
        .withValues(alpha: 0.25);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.all(Radius.circular(AppConstants.radiusLg)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.redAccent
                      .withValues(alpha: 0.14 + (favoriteProgress * 0.14)),
                  AppColors.surface,
                  AppColors.accent
                      .withValues(alpha: 0.14 + (queueProgress * 0.14)),
                ],
              ),
              border: Border.all(
                color: Color.lerp(
                  AppColors.accent
                      .withValues(alpha: 0.18 + (queueProgress * 0.26)),
                  Colors.redAccent
                      .withValues(alpha: 0.18 + (favoriteProgress * 0.26)),
                  favoriteProgress,
                )!,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLg),
              child: Row(
                children: [
                  Opacity(
                    opacity: favoriteProgress,
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.redAccent, size: 22),
                  ),
                  const Spacer(),
                  Opacity(
                    opacity: queueProgress,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music_rounded,
                            color: AppColors.accent, size: 20),
                        SizedBox(width: 8),
                        Text(l10n.addToQueue2,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSlide(
          duration: AppConstants.animationFast,
          curve: Curves.easeOutCubic,
          offset: Offset(_dragDx / cardWidth, 0),
          child: AnimatedScale(
            duration: AppConstants.animationFast,
            scale: isFlashing ? 0.98 : 1,
            child: AnimatedContainer(
              duration: AppConstants.animationFast,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.all(Radius.circular(AppConstants.radiusLg)),
                boxShadow: isFlashing
                    ? [
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: cardFace,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitBackground() {
    switch (widget.backgroundStyle) {
      case OrbitCardBackgroundStyle.blurGradient:
        return _buildBlurPortraitBackground();
      case OrbitCardBackgroundStyle.albumColorGradient:
        return FutureBuilder<Color?>(
          future: _albumColorFuture,
          builder: (context, snapshot) {
            return _buildAlbumColorPortraitBackground(snapshot.data);
          },
        );
      case OrbitCardBackgroundStyle.blackGradient:
        return _buildBlackPortraitBackground();
    }
  }

  Widget _buildBlackPortraitBackground() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1C1E), Color(0xFF0B0B0C)],
        ),
      ),
    );
  }

  Widget _buildBlurPortraitBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1D), Color(0xFF0A0A0B)],
            ),
          ),
        ),
        // The blur is baked once into a small cached texture, so orbit motion
        // draws a plain image instead of rerunning a live filter. It supplies
        // ambience behind the sharp framed cover.
        OrbitCardBlur(
          imagePath: widget.song.albumArt,
          audioSourcePath: widget.song.filePath,
        ),
        // Readability scrim for the metadata column; the cover tile is painted
        // above this layer, so it stays crisp.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withValues(alpha: 0.74),
                Colors.black.withValues(alpha: 0.34),
                Colors.black.withValues(alpha: 0.58),
              ],
              stops: const [0.0, 0.62, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumColorPortraitBackground(Color? albumColor) {
    if (albumColor == null) return _buildBlackPortraitBackground();

    final tint = albumSurface(albumColor, 0.55);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, Color.lerp(tint, Colors.black, 0.72)!],
        ),
      ),
    );
  }

  Widget _buildRawImage(
    String path, {
    String? audioSourcePath,
    BoxFit fit = BoxFit.cover,
    required double artSize,
  }) {
    // ponytail: cap decode at artSize * multiplier. Selected card used to decode
    // full-res, OOM'ing during fast orbit fling. Multiplier is now user-tunable;
    // default 2x stays soft on >2x DPR — scale up if it shows.
    final decodeDim = (artSize * widget.artResolutionMultiplier).toInt();

    return CachedImageWidget(
      imagePath: path,
      audioSourcePath: audioSourcePath,
      fit: fit,
      placeholder: _buildPlaceholderArt(),
      errorWidget: _buildPlaceholderArt(),
      useThumbnail: true,
      thumbnailWidth: decodeDim,
      thumbnailHeight: decodeDim,
    );
  }

  Widget _buildPlaceholderArt() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceLight, AppColors.surface],
        ),
      ),
      child: const Center(
        child: FlickArtworkPlaceholder(size: 36, opacity: 0.9),
      ),
    );
  }

  Widget _buildSongInfo(BuildContext context, {bool isSelected = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected)
          SizedBox(
            height: 24,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.song.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
          )
        else
          Text(
            widget.song.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 3),
        Text(
          widget.song.artist,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xB8FFFFFF),
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Row(
          children: [
            _buildMetadataBadge(widget.song.fileType),
            const SizedBox(width: AppConstants.spacingXs),
            _buildMetadataText(widget.song.formattedDuration),
            if (widget.song.resolution != null &&
                widget.song.resolution != 'Unknown') ...[
              const SizedBox(width: AppConstants.spacingXs),
              _buildMetadataText('•'),
              const SizedBox(width: AppConstants.spacingXs),
              Flexible(child: _buildMetadataText(widget.song.resolution!)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMetadataBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingXs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(AppConstants.radiusXs),
        border: Border.all(color: Colors.white30, width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMetadataText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: Colors.white70,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
