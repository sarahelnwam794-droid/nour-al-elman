import 'package:flutter/material.dart';

/// أنيميشن انتقال خفيف بين الصفحات: fade بسيط + انزلاق خفيف جدًا (4% من
/// عرض الشاشة). مبني على FadeTransition/SlideTransition بس (بدون أي
/// مكتبات خارجية أو حسابات تقيلة)، فمفيش أي تأثير ملموس على أداء التطبيق.
///
/// بيتفعّل تلقائيًا على *كل* الشاشات في التطبيق لأنه متسجل مركزيًا في
/// [ThemeData.pageTransitionsTheme] في main.dart — مفيش داعي تعدّل أي
/// Navigator.push في أي شاشة تانية.
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// PageTransitionsTheme جاهز يستخدم نفس الأنيميشن على كل المنصات
/// (أندرويد و iOS)، عشان يبقى شكل الانتقال موحّد في كل مكان.
const PageTransitionsTheme smoothPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: SmoothPageTransitionsBuilder(),
    TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
    TargetPlatform.windows: SmoothPageTransitionsBuilder(),
    TargetPlatform.macOS: SmoothPageTransitionsBuilder(),
    TargetPlatform.linux: SmoothPageTransitionsBuilder(),
  },
);
