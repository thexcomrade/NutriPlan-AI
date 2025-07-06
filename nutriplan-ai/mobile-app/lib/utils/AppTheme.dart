// 📄 D:\nutriplan-ai\mobile-app\lib\utils\AppTheme.dart

import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF00C853); // Vibrant green
  static const Color secondary = Color(0xFF1DE9B6); // Aqua
  static const Color accent = Color(0xFFFFC107); // Amber
  static const Color error = Color(0xFFD32F2F); // Red
  static const Color background = Color(0xFFF7F9FC); // Off-white
  static const Color card = Color(0xFFFFFFFF); // White
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color disabled = Color(0xFFBDBDBD);
  static const Color border = Color(0xFFEEEEEE);
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
}

class AppFonts {
  static const String primaryFont = 'Montserrat';
}

class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.bold,
    fontFamily: AppFonts.primaryFont,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontFamily: AppFonts.primaryFont,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    fontFamily: AppFonts.primaryFont,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    fontFamily: AppFonts.primaryFont,
    color: AppColors.textPrimary,
  );

  static const TextStyle hint = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: AppFonts.primaryFont,
    color: AppColors.textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFamily: AppFonts.primaryFont,
    color: Colors.white,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppFonts.primaryFont,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTextStyles.headline2.copyWith(color: Colors.white),
      ),
      cardColor: AppColors.card,
      iconTheme: const IconThemeData(color: AppColors.primary),
      textTheme: const TextTheme(
        headline1: AppTextStyles.headline1,
        headline2: AppTextStyles.headline2,
        subtitle1: AppTextStyles.subtitle,
        bodyText1: AppTextStyles.body,
        bodyText2: AppTextStyles.hint,
        button: AppTextStyles.button,
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        filled: true,
        fillColor: Colors.white,
        hintStyle: AppTextStyles.hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          primary: AppColors.primary,
          textStyle: AppTextStyles.button,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          primary: AppColors.primary,
          textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.all(AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.all(AppColors.primary),
        trackColor: MaterialStateProperty.all(AppColors.secondary.withOpacity(0.4)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }
}
