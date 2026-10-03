import 'package:flutter/material.dart';
import 'skeleton_shimmer.dart';

/// Wireframe for a vertical list of cards, each with a leading icon/avatar
/// and a couple of text lines — matches screens like groups, sessions,
/// waiting lists, courses, or certificates where each row is its own card.
class CardListSkeleton extends StatelessWidget {
  final int itemCount;
  final bool leadingCircle;
  final bool showTrailingAction;
  final EdgeInsetsGeometry padding;

  const CardListSkeleton({
    super.key,
    this.itemCount = 5,
    this.leadingCircle = true,
    this.showTrailingAction = false,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                if (leadingCircle) ...[
                  const Bone.circle(size: 44),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Bone(width: 140, height: 13),
                      const SizedBox(height: 8),
                      Bone(width: 90, height: 11),
                    ],
                  ),
                ),
                if (showTrailingAction) ...[
                  const SizedBox(width: 12),
                  const Bone(width: 56, height: 26, radius: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
