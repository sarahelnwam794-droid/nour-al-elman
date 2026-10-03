import 'package:flutter/material.dart';

/// Shown when a network request actually failed (timeout, no internet,
/// server error) — distinct from "no data yet". Gives the user a clear
/// reason and a one-tap way to try again, instead of silently looking
/// like an empty list.
class ErrorStateWidget extends StatefulWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    this.message = "حصل خطأ أثناء الاتصال بالسيرفر. تأكد من اتصالك بالإنترنت وحاول مرة أخرى.",
    required this.onRetry,
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  State<ErrorStateWidget> createState() => _ErrorStateWidgetState();
}

class _ErrorStateWidgetState extends State<ErrorStateWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 44, color: const Color(0xFFDC2626)),
                const SizedBox(height: 14),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475467), height: 1.5),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text("إعادة المحاولة"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF07427C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
