// 📄 D:\nutriplan-ai\mobile-app\lib\utils\Validators.dart

import 'package:flutter/material.dart';

/// Utility class for form field validation
class Validators {
  /// Validates if input is a non-empty name
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    } else if (value.trim().length < 2) {
      return 'Name is too short';
    }
    return null;
  }

  /// Validates email using RegExp
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final RegExp emailRegex = RegExp(
      r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }

  /// Validates password (min 8 chars, at least 1 digit, 1 uppercase)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    final RegExp strongPass = RegExp(
      r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9]).{8,}$',
    );

    if (!strongPass.hasMatch(value)) {
      return 'Password must be 8+ chars, include uppercase & number';
    }

    return null;
  }

  /// Confirm password match
  static String? validateConfirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Confirm password';
    }
    if (value != originalPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Validates age (must be number, 10-99)
  static String? validateAge(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Age is required';
    }
    final int? age = int.tryParse(value);
    if (age == null || age < 10 || age > 99) {
      return 'Enter a valid age (10–99)';
    }
    return null;
  }

  /// Validates if input is not empty
  static String? validateRequired(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates phone number (10 digits)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    final RegExp phoneRegex = RegExp(r'^\d{10}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid 10-digit phone number';
    }

    return null;
  }

  /// Validates if the given number is within a range
  static String? validateRange(String? value, int min, int max, {String fieldName = "Value"}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final int? num = int.tryParse(value);
    if (num == null || num < min || num > max) {
      return '$fieldName must be between $min and $max';
    }
    return null;
  }

  /// Shows validation error as an animated snackbar
  static void showValidationError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
