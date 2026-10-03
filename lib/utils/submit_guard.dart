
import 'package:flutter/widgets.dart';

mixin SubmitGuard<T extends StatefulWidget> on State<T> {
  bool _isSubmitting = false;

  bool get isSubmitting => _isSubmitting;

  Future<void> guardedSubmit(Future<void> Function() action) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

