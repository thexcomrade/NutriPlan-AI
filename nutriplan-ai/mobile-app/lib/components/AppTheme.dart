import 'package:flutter/material.dart';

class AppTheme {
  // Primary colors
  static const Color primaryColor = Color(0xFF4CAF50); // Green shade
  static const Color primaryLightColor = Color(0xFFC8E6C9);
  static const Color primaryDarkColor = Color(0xFF388E3C);

  // Accent colors
  static const Color accentColor = Color(0xFFFFC107); // Amber shade

  // Backgrounds
  static const Color scaffoldBackgroundColor = Color(0xFFF5F5F5);

  // Text colors
  static const Color primaryTextColor = Color(0xFF212121);
  static const Color secondaryTextColor = Color(0xFF757575);
  static const Color disabledTextColor = Color(0xFFBDBDBD);

  // Fonts - assuming Google Fonts are added in pubspec.yaml (Roboto)
  static const String fontFamily = 'Roboto';

  // Text styles
  static TextTheme textTheme = TextTheme(
    headline1: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: primaryTextColor,
      fontFamily: fontFamily,
    ),
    headline2: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: primaryTextColor,
      fontFamily: fontFamily,
    ),
    headline3: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: primaryTextColor,
      fontFamily: fontFamily,
    ),
    bodyText1: TextStyle(
      fontSize: 16,
      color: primaryTextColor,
      fontFamily: fontFamily,
    ),
    bodyText2: TextStyle(
      fontSize: 14,
      color: secondaryTextColor,
      fontFamily: fontFamily,
    ),
    caption: TextStyle(
      fontSize: 12,
      color: disabledTextColor,
      fontFamily: fontFamily,
    ),
    button: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      fontFamily: fontFamily,
    ),
  );

  // ThemeData
  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    accentColor: accentColor,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    fontFamily: fontFamily,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      color: primaryColor,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: textTheme.headline6?.copyWith(color: Colors.white),
      elevation: 2,
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      textTheme: ButtonTextTheme.primary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryLightColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryLightColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red),
      ),
      errorStyle: TextStyle(color: Colors.redAccent),
      hintStyle: TextStyle(color: secondaryTextColor),
    ),
  );
}
