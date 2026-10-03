
import 'package:flutter/material.dart';
import 'package:project1/widgets/pulse_loader.dart';

class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int pageSize;
  final Widget? emptyState;
  final EdgeInsetsGeometry? padding;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.pageSize = 25,
    this.emptyState,
    this.padding,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final ScrollController _controller = ScrollController();
  int _visibleCount = 0;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.pageSize.clamp(0, widget.items.length);
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _visibleCount = widget.pageSize.clamp(0, widget.items.length);
    }
  }

  void _onScroll() {
    if (_controller.position.pixels >= _controller.position.maxScrollExtent - 200) {
      if (_visibleCount < widget.items.length) {
        setState(() {
          _visibleCount = (_visibleCount + widget.pageSize).clamp(0, widget.items.length);
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return widget.emptyState ?? const SizedBox.shrink();
    }

    final visibleItems = widget.items.take(_visibleCount).toList();
    final hasMore = _visibleCount < widget.items.length;

    return ListView.builder(
      controller: _controller,
      padding: widget.padding,
      itemCount: visibleItems.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= visibleItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: SizedBox(width: 28, height: 28, child: PulseLoader(strokeWidth: 2))),
          );
        }
        return widget.itemBuilder(context, visibleItems[index], index);
      },
    );
  }
}

