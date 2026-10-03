import 'package:flutter/material.dart';

/// A single, unambiguous control that expands/collapses the note panel.
/// Only the arrow icon does this job — no duplicate "إخفاء" text link next
/// to it — and it's a bit larger so it's easy to tap.
class ExpandToggleIcon extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;
  final Color collapsedColor;
  final Color expandedColor;

  const ExpandToggleIcon({
    super.key,
    required this.isExpanded,
    required this.onTap,
    this.collapsedColor = const Color(0xFF07427C),
    this.expandedColor = const Color(0xFFDC2626),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Icon(
            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.chat_bubble_outline_rounded,
            key: ValueKey(isExpanded),
            size: isExpanded ? 30 : 24,
            color: isExpanded ? expandedColor : collapsedColor,
          ),
        ),
      ),
    );
  }
}

/// The expanded content itself: the rating sits alone on its own line, the
/// teacher's comment sits alone on the line below it and wraps normally, and
/// the whole panel hugs its content height (no fixed/clipped height), so a
/// long comment never gets cramped or cut off.
class ExpandableNoteContent extends StatelessWidget {
  final String points;
  final String note;
  final Color accentColor;
  final Color noteColor;
  final String pointsLabel;
  final String noteLabel;

  const ExpandableNoteContent({
    super.key,
    required this.points,
    required this.note,
    this.accentColor = const Color(0xFF16A34A),
    this.noteColor = const Color(0xFF2E3542),
    this.pointsLabel = "التقييم",
    this.noteLabel = "تعليق المعلم",
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$pointsLabel: $points",
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Text(
          "$noteLabel:",
          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          note,
          softWrap: true,
          style: TextStyle(color: noteColor, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }
}
