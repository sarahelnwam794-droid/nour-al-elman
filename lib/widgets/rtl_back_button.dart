
import 'package:flutter/material.dart';

class RtlBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const RtlBackButton({super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return IconButton(
      icon: Icon(isRtl ? Icons.arrow_forward : Icons.arrow_back, color: color),
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

