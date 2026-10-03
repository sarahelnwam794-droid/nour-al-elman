import 'dart:async';
import 'package:flutter/material.dart';

/// بيعرض [skeleton] بس لو التحميل فعلاً واخد وقت ملحوظ (نت ضعيف، مفيش نت،
/// أو الداتا بطيئة من السيرفر) — مش أي مرة [isLoading] بيبقى true للحظة
/// بسيطة. لو الداتا وصلت قبل ما مدة [showDelay] تخلص، السكيلتون ميتعرضش
/// خالص والمستخدم يشوف المحتوى على طول.
///
/// وبيعمل كروس-فيد (fade) خفيف بين الحالتين (سكيلتون <-> محتوى) بدل
/// التبديل المفاجئ، من غير أي تأثير على أداء التطبيق.
///
/// الاستخدام:
/// ```dart
/// SmartLoadingSwitcher(
///   isLoading: _isLoading,
///   skeleton: _buildSkeleton(),
///   child: _buildRealContent(),
/// )
/// ```
class SmartLoadingSwitcher extends StatefulWidget {
  final bool isLoading;
  final Widget skeleton;
  final Widget child;

  /// أد إيه ننتظر قبل ما نعرض السكيلتون. لو التحميل خلص قبلها، السكيلتون
  /// ميتعرضش خالص.
  final Duration showDelay;

  /// مدة الكروس-فيد بين السكيلتون والمحتوى.
  final Duration transitionDuration;

  const SmartLoadingSwitcher({
    super.key,
    required this.isLoading,
    required this.skeleton,
    required this.child,
    this.showDelay = const Duration(milliseconds: 800),
    this.transitionDuration = const Duration(milliseconds: 180),
  });

  @override
  State<SmartLoadingSwitcher> createState() => _SmartLoadingSwitcherState();
}

class _SmartLoadingSwitcherState extends State<SmartLoadingSwitcher> {
  bool _showSkeleton = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant SmartLoadingSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) _sync();
  }

  void _sync() {
    _delayTimer?.cancel();
    if (widget.isLoading) {
      _delayTimer = Timer(widget.showDelay, () {
        if (mounted && widget.isLoading) {
          setState(() => _showSkeleton = true);
        }
      });
    } else {
      if (_showSkeleton) setState(() => _showSkeleton = false);
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool showSkeleton = widget.isLoading && _showSkeleton;
    return AnimatedSwitcher(
      duration: widget.transitionDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      child: showSkeleton
          ? KeyedSubtree(key: const ValueKey('skeleton'), child: widget.skeleton)
          : KeyedSubtree(key: const ValueKey('content'), child: widget.child),
    );
  }
}
