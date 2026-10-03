import 'package:flutter/material.dart';
import 'skeleton_shimmer.dart';

/// Wireframe for a form/edit screen: a stack of label + input-box
/// placeholders, matching screens like "edit student/teacher/employee".
class FormSkeleton extends StatelessWidget {
  final int fieldCount;
  final EdgeInsetsGeometry padding;

  const FormSkeleton({
    super.key,
    this.fieldCount = 5,
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
            for (int i = 0; i < fieldCount; i++) ...[
              Bone(width: 90, height: 11),
              const SizedBox(height: 8),
              const Bone(height: 46, radius: 10),
              if (i != fieldCount - 1) const SizedBox(height: 20),
            ],
            const SizedBox(height: 28),
            const Bone(height: 48, radius: 12),
          ],
        ),
      ),
    );
  }
}
