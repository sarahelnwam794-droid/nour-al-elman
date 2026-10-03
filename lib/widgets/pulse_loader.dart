import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A single, clear, unmistakably "loading" animation: a rotating arc with
/// rounded ends, in the app's brand color. Replaces the old skeleton/shimmer
/// bars — the same widget name is used everywhere `PulseLoader` was already
/// referenced, so no call sites needed to change, only what it draws.
class PulseLoader extends StatefulWidget {
  final Color? color;
  final Color? backgroundColor;
  final double? strokeWidth;
  final double? value;
  final String? semanticsLabel;

  const PulseLoader({
    super.key,
    this.color,
    this.backgroundColor,
    this.strokeWidth,
    this.value,
    this.semanticsLabel,
  });

  @override
  State<PulseLoader> createState() => _PulseLoaderState();
}

class _PulseLoaderState extends State<PulseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Color _brand = Color(0xFFFF8A00);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? _brand;
    final Color track = widget.backgroundColor ?? color.withOpacity(0.15);

    return Semantics(
      label: widget.semanticsLabel ?? 'جاري التحميل',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double boundedSide = math.min(
            constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity,
            constraints.maxHeight.isFinite ? constraints.maxHeight : double.infinity,
          );
          final double size = boundedSide.isFinite && boundedSide > 0
              ? boundedSide.clamp(18.0, 56.0)
              : 40.0;
          final double stroke = widget.strokeWidth ?? (size * 0.11).clamp(2.5, 5.0);

          return Center(
            child: SizedBox(
              width: size,
              height: size,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SpinnerPainter(
                      progress: _controller.value,
                      value: widget.value,
                      color: color,
                      track: track,
                      strokeWidth: stroke,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final double progress;
  final double? value;
  final Color color;
  final Color track;
  final double strokeWidth;

  _SpinnerPainter({
    required this.progress,
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Offset center = rect.center;
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final Paint trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final Paint arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);

    if (value != null) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        2 * math.pi * value!.clamp(0.0, 1.0),
        false,
        arcPaint,
      );
    } else {
      final double start = progress * 2 * math.pi - math.pi / 2;
      const double sweep = math.pi * 1.5;
      canvas.drawArc(arcRect, start, sweep, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.value != value ||
        oldDelegate.color != color ||
        oldDelegate.track != track ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
