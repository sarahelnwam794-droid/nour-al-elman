import 'package:flutter/material.dart';
import 'skeleton_shimmer.dart';

/// Wireframe for a dashboard/home/report screen: a row of small stat cards
/// up top, then a list block underneath — matches employee/teacher home
/// screens, group dashboards, and report screens.
class DashboardSkeleton extends StatelessWidget {
  final int statCards;
  final int listRows;
  final EdgeInsetsGeometry padding;

  const DashboardSkeleton({
    super.key,
    this.statCards = 3,
    this.listRows = 4,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: List.generate(statCards, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == statCards - 1 ? 0 : 10),
                    child: Container(
                      height: 84,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Bone.circle(size: 22),
                          Bone(width: 40, height: 14),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),
            Bone(width: 130, height: 14),
            const SizedBox(height: 14),
            for (int i = 0; i < listRows; i++) ...[
              Container(
                padding: const EdgeInsets.all(14),
                margin: EdgeInsets.only(bottom: i == listRows - 1 ? 0 : 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Bone(width: 160, height: 12),
                          const SizedBox(height: 8),
                          Bone(width: 100, height: 10),
                        ],
                      ),
                    ),
                    const Bone(width: 44, height: 20, radius: 6),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
