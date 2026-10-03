import 'package:flutter/material.dart';
import 'skeleton_shimmer.dart';

/// Wireframe for a profile/details screen: a big avatar with name and
/// subtitle underneath, then a handful of labeled detail rows — matches
/// staff/employee/student "details" screens.
class ProfileHeaderSkeleton extends StatelessWidget {
  final int detailRows;
  final EdgeInsetsGeometry padding;

  const ProfileHeaderSkeleton({
    super.key,
    this.detailRows = 4,
    this.padding = const EdgeInsets.all(20),
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
            Center(
              child: Column(
                children: [
                  const Bone.circle(size: 84),
                  const SizedBox(height: 14),
                  Bone(width: 150, height: 15),
                  const SizedBox(height: 8),
                  Bone(width: 100, height: 11),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < detailRows; i++) ...[
                    Row(
                      children: [
                        Bone(width: 80, height: 11),
                        const Spacer(),
                        Bone(width: 110, height: 11),
                      ],
                    ),
                    if (i != detailRows - 1) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
