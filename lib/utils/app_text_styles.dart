import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized typography scale so text sizes/weights are consistent across
/// the whole app instead of ad-hoc `fontSize: 13/14/15/16/18/22/24/28`
/// scattered per screen. All sizes are on an 8-step scale for visual rhythm.
///
/// Usage: `Text('عنوان', style: AppTextStyles.h1)`
/// Need a color/weight tweak on top of a style? Use `.copyWith(...)`.
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Almarai';

  // Headings
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  // Body text
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // Supporting text
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  // Buttons / interactive
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.2,
  );

  static const TextStyle link = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    height: 1.3,
  );

  static const TextStyle errorText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.error,
    height: 1.2,
  );
}

/// 8pt spacing scale so gaps between elements follow one consistent rhythm
/// instead of random `SizedBox(height: 10/12/14/18/...)` values.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const SizedBox vXs = SizedBox(height: xs);
  static const SizedBox vSm = SizedBox(height: sm);
  static const SizedBox vMd = SizedBox(height: md);
  static const SizedBox vLg = SizedBox(height: lg);
  static const SizedBox vXl = SizedBox(height: xl);

  static const SizedBox hXs = SizedBox(width: xs);
  static const SizedBox hSm = SizedBox(width: sm);
  static const SizedBox hMd = SizedBox(width: md);
  static const SizedBox hLg = SizedBox(width: lg);
  static const SizedBox hXl = SizedBox(width: xl);

  /// Standard screen edge padding used across list/form screens.
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: md, vertical: md);
}
