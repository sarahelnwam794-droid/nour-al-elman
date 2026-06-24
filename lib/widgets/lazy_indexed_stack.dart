import 'package:flutter/material.dart';

/// Builds tab children only after they are visited once, reducing startup API calls.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget Function()> itemBuilders;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.itemBuilders,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late List<bool> _built;

  @override
  void initState() {
    super.initState();
    _built = List<bool>.filled(widget.itemBuilders.length, false);
    _markBuilt(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemBuilders.length != widget.itemBuilders.length) {
      _built = List<bool>.filled(widget.itemBuilders.length, false);
    }
    _markBuilt(widget.index);
  }

  void _markBuilt(int index) {
    if (index < 0 || index >= _built.length) return;
    _built[index] = true;
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: List.generate(widget.itemBuilders.length, (i) {
        if (!_built[i]) {
          return const SizedBox.shrink();
        }
        return widget.itemBuilders[i]();
      }),
    );
  }
}
