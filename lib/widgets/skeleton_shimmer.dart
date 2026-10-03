import 'package:flutter/material.dart';

/// A single, cheap shimmer sweep applied over its [child]. Uses one
/// [AnimationController] and a [ShaderMask], so no matter how many bone
/// shapes are inside `child`, only one animation drives the whole thing —
/// this is what keeps it light on performance even on a big wireframe.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const SkeletonShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE6E9EF),
    this.highlightColor = const Color(0xFFF6F7F9),
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final double slide = _controller.value;
            return LinearGradient(
              colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1.5 + slide * 3, 0),
              end: Alignment(0.5 + slide * 3, 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single rounded placeholder "bone" — the building block every skeleton
/// layout is composed from. Colored plain white here; [SkeletonShimmer]
/// above is what makes it shimmer, applied once over the whole layout.
class Bone extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final BoxShape shape;

  const Bone({
    super.key,
    this.width = double.infinity,
    this.height = 12,
    this.radius = 6,
    this.shape = BoxShape.rectangle,
  });

  const Bone.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}
