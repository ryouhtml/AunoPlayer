import 'package:flutter/material.dart';

/// Horizontal page gesture for the pinned full-player chrome only.
///
/// The old queue-chip left drag keeps priority when the gesture starts inside
/// [queueDragRegionKey]. All other horizontal chrome drags page between Now
/// Playing and the embedded queue panel.
class PlayerChromePageGesture extends StatefulWidget {
  static const double _velocityThreshold = 400.0;

  final Widget child;
  final bool pageSwipeEnabled;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final GlobalKey? queueDragRegionKey;
  final VoidCallback? onQueueDrag;

  const PlayerChromePageGesture({
    super.key,
    required this.child,
    this.pageSwipeEnabled = true,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.queueDragRegionKey,
    this.onQueueDrag,
  });

  @override
  State<PlayerChromePageGesture> createState() =>
      _PlayerChromePageGestureState();
}

class _PlayerChromePageGestureState extends State<PlayerChromePageGesture> {
  DragStartDetails? _dragStart;

  bool _startedInQueueRegion(DragStartDetails details) {
    final context = widget.queueDragRegionKey?.currentContext;
    if (context == null) return false;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return false;
    final local = renderObject.globalToLocal(details.globalPosition);
    return renderObject.size.contains(local);
  }

  void _handleDragStart(DragStartDetails details) {
    _dragStart = details;
  }

  void _handleDragEnd(DragEndDetails details) {
    final start = _dragStart;
    _dragStart = null;
    if (start == null) return;

    final velocity = details.primaryVelocity;
    if (velocity == null ||
        velocity.abs() < PlayerChromePageGesture._velocityThreshold) {
      return;
    }

    if (velocity < 0 &&
        widget.onQueueDrag != null &&
        _startedInQueueRegion(start)) {
      widget.onQueueDrag!.call();
      return;
    }

    if (!widget.pageSwipeEnabled) return;
    if (velocity < 0) {
      widget.onSwipeLeft?.call();
    } else {
      widget.onSwipeRight?.call();
    }
  }

  void _handleDragCancel() {
    _dragStart = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragEnd: _handleDragEnd,
      onHorizontalDragCancel: _handleDragCancel,
      child: widget.child,
    );
  }
}
