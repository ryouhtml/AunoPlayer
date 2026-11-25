import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:auno_player/core/motion/app_motion.dart';
import 'package:auno_player/core/theme/app_colors.dart';
import 'package:auno_player/l10n/l10n.dart';

/// Animated launch cover shown above [child] while the first frame settles.
///
/// The real app content is built underneath from the very first frame, so the
/// logo reveal is a decoration rather than a blocking gate: database, queue
/// restore and audio warm-up already run in `main()` / after the first frame.
///
/// Honors the system "remove animations" setting by rendering the child
/// immediately.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _visible = true;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotionDurations.splash,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (reducedMotion) {
      _visible = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;

    final l10n = AppLocalizations.of(context);
    final logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.45,
          curve: Cubic(0.34, 1.56, 0.64, 1.0),
        ),
      ),
    );
    final contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: AppMotionCurves.entrance),
    );
    final exitFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 1.0, curve: AppMotionCurves.crossFade),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final exit = exitFade.value.clamp(0.0, 1.0);
            final overlayOpacity = 1.0 - exit;
            // Ambient glow breathes once during the reveal and settles.
            final breathing =
                0.5 - 0.5 * math.cos(_controller.value * math.pi * 2.0);
            final glowStrength = breathing * (1.0 - exit);
            return IgnorePointer(
              ignoring: exit >= 0.999,
              child: Opacity(
                opacity: overlayOpacity,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.0, -0.12),
                      radius: 1.15,
                      colors: [Color(0xFF181818), AppColors.backgroundBlack],
                    ),
                  ),
                  child: RepaintBoundary(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FadeTransition(
                          opacity: contentFade,
                          child: ScaleTransition(
                            scale: logoScale,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(
                                      alpha: 0.10 * glowStrength,
                                    ),
                                    blurRadius: 64 * glowStrength + 12,
                                    spreadRadius: 6 * glowStrength,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/icons/auno_logo_square.png',
                                  width: 116,
                                  height: 116,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        FadeTransition(
                          opacity: contentFade,
                          child: Text(
                            l10n.appTitle,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FadeTransition(
                          opacity: contentFade,
                          child: Text(
                            l10n.splashTagline,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
