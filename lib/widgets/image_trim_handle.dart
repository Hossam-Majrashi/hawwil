import 'package:flutter/material.dart';
import '../models/merge_media_item.dart';

class ImageTrimHandle extends StatefulWidget {
  final bool isLeft;
  final MergeMediaItem item;
  final double pixelsPerSecond;
  final ValueChanged<Duration> onDurationChanged;
  final Color color;
  final double handleWidth;

  const ImageTrimHandle({
    super.key,
    required this.isLeft,
    required this.item,
    required this.pixelsPerSecond,
    required this.onDurationChanged,
    required this.color,
    this.handleWidth = 14.0,
  });

  @override
  State<ImageTrimHandle> createState() => _ImageTrimHandleState();
}

class _ImageTrimHandleState extends State<ImageTrimHandle> {
  double? _startDurationSec;
  double _accumulatedDelta = 0.0;
  bool _isDragging = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) {
          _startDurationSec = widget.item.durationInSeconds;
          _accumulatedDelta = 0.0;
          setState(() => _isDragging = true);
        },
        onHorizontalDragUpdate: (details) {
          _startDurationSec ??= widget.item.durationInSeconds;
          _accumulatedDelta += details.delta.dx;
          final pps = widget.pixelsPerSecond > 0 ? widget.pixelsPerSecond : 50.0;
          final deltaSec = widget.isLeft ? (-_accumulatedDelta / pps) : (_accumulatedDelta / pps);
          final rawSec = _startDurationSec! + deltaSec;
          final clampedSec = rawSec.clamp(0.5, 3600.0);
          final newDuration = Duration(milliseconds: (clampedSec * 1000).round());
          widget.onDurationChanged(newDuration);
        },
        onHorizontalDragEnd: (_) {
          _startDurationSec = null;
          _accumulatedDelta = 0.0;
          setState(() => _isDragging = false);
        },
        onHorizontalDragCancel: () {
          _startDurationSec = null;
          _accumulatedDelta = 0.0;
          setState(() => _isDragging = false);
        },
        child: Container(
          width: widget.handleWidth,
          decoration: BoxDecoration(
            color: (_isDragging || _isHovered)
                ? widget.color.withOpacity(0.85)
                : widget.color.withOpacity(0.4),
            borderRadius: BorderRadius.horizontal(
              left: widget.isLeft ? const Radius.circular(5) : Radius.zero,
              right: !widget.isLeft ? const Radius.circular(5) : Radius.zero,
            ),
          ),
          child: Center(
            child: Container(
              width: 2,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
