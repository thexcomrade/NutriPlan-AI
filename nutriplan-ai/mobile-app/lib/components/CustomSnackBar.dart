// File: nutriplan-ai/mobile-app/lib/components/CustomSnackBar.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SnackBarType { success, error, info, warning }

class CustomSnackBar {
  static void show({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final backgroundColor = _getColor(type);
    final icon = _getIcon(type);

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      elevation: 10,
      duration: duration,
      backgroundColor: Colors.transparent,
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static IconData _getIcon(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return Icons.check_circle_outline;
      case SnackBarType.error:
        return Icons.error_outline;
      case SnackBarType.warning:
        return Icons.warning_amber_rounded;
      case SnackBarType.info:
      default:
        return Icons.info_outline;
    }
  }

  static Color _getColor(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return const Color(0xFF43A047); // Green
      case SnackBarType.error:
        return const Color(0xFFE53935); // Red
      case SnackBarType.warning:
        return const Color(0xFFFDD835); // Yellow
      case SnackBarType.info:
      default:
        return const Color(0xFF1E88E5); // Blue
    }
  }
}
