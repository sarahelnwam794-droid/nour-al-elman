import 'package:flutter/material.dart';
import 'skeleton_shimmer.dart';

/// Wireframe for a table/list screen: a header bar (optional) followed by
/// [rowCount] placeholder rows split into columns by [columnFlex] — mirrors
/// the real header/rows shape of screens like attendance or test lists, so
/// while data is loading (or the connection is slow) the user sees the
/// outline of the screen that's about to appear instead of a blank body.
///
/// Pass [headerLabels] with the screen's real, static column titles (e.g.
/// "الاسم", "حذف") so the header reads exactly like the real table instead
/// of generic shimmer bars — headers never come from the server, so there's
/// no reason to fake-load them. Set [wrapInCard] to true to match the
/// common white rounded-card-with-shadow container most list screens use,
/// so the whole placeholder looks like the real screen, not a generic box.
class ListSkeletonLoader extends StatelessWidget {
  final List<int> columnFlex;
  final bool showHeader;
  final int rowCount;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final List<String>? headerLabels;
  final bool wrapInCard;
  final List<TextAlign>? headerAlign;

  const ListSkeletonLoader({
    super.key,
    this.columnFlex = const [2, 1, 2, 2, 2],
    this.showHeader = true,
    this.rowCount = 6,
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.headerLabels,
    this.wrapInCard = false,
    this.headerAlign,
  });

  @override
  Widget build(BuildContext context) {
    Widget cell({double heightFactor = 1}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Bone(height: 12 * heightFactor),
    );

    Widget rowOf({double heightFactor = 1}) => Row(
      children: columnFlex
          .map((flex) => Expanded(flex: flex, child: cell(heightFactor: heightFactor)))
          .toList(),
    );

    Widget realHeaderRow() => Row(
      children: [
        for (int i = 0; i < columnFlex.length; i++)
          Expanded(
            flex: columnFlex[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
              child: Text(
                i < (headerLabels?.length ?? 0) ? headerLabels![i] : "",
                textAlign: headerAlign != null && i < headerAlign!.length
                    ? headerAlign![i]
                    : TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontFamily: 'Almarai'),
              ),
            ),
          ),
      ],
    );

    final bool useRealHeader = headerLabels != null && headerLabels!.isNotEmpty;

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader && useRealHeader) ...[
          Container(color: Colors.grey[100], child: realHeaderRow()),
        ] else if (showHeader) ...[
          Padding(
            padding: padding,
            child: SizedBox(height: 34, child: rowOf(heightFactor: 0.9)),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: useRealHeader ? EdgeInsets.zero : padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < rowCount; i++) ...[
                SizedBox(
                  height: useRealHeader ? 48 : 30,
                  child: useRealHeader
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: rowOf(),
                        )
                      : rowOf(),
                ),
                if (i != rowCount - 1 && !useRealHeader) const SizedBox(height: 18),
                if (i != rowCount - 1 && useRealHeader)
                  Divider(height: 1, color: Colors.grey[200]),
              ],
            ],
          ),
        ),
      ],
    );

    final Widget shimmered = SkeletonShimmer(
      baseColor: color?.withOpacity(0.16) ?? const Color(0xFFE6E9EF),
      child: body,
    );

    if (!wrapInCard) return shimmered;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: shimmered,
        ),
      ),
    );
  }
}
