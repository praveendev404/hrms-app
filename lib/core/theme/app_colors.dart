import 'package:flutter/material.dart';

/// Application color palette with modern, enterprise-grade design
class AppColors {
  AppColors._();

  // Primary Colors - Purple
  static const Color primary = Color(0xFF846CF9);
  static const Color primaryLight = Color(0xFFB5A4FF);
  static const Color primaryDark = Color(0xFF5C3FC6);
  static const Color primaryContainer = Color(0xFFF3F0FF);

  // Secondary Colors - Coral Accent
  static const Color secondary = Color(0xFFFF6B6B);
  static const Color secondaryLight = Color(0xFFFF9E9E);
  static const Color secondaryDark = Color(0xFFC73E3E);
  static const Color secondaryContainer = Color(0xFFFFE8E8);

  // Tertiary Colors - Teal
  static const Color tertiary = Color(0xFF00BFA5);
  static const Color tertiaryLight = Color(0xFF5DF2D6);
  static const Color tertiaryDark = Color(0xFF008E76);
  static const Color tertiaryContainer = Color(0xFFE0F7F4);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFE53935);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);

  // Verification Status Colors
  static const Color statusPending = Color(0xFFFF9800);
  static const Color statusSubmitted = Color(0xFF2196F3);
  static const Color statusNeedInfo = Color(0xFFE91E63);
  static const Color statusApproved = Color(0xFF4CAF50);
  static const Color statusRejected = Color(0xFFF44336);

  // Neutral Colors - Light Theme
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color dividerLight = Color(0xFFE2E8F0);

  // Neutral Colors - Dark Theme
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariantDark = Color(0xFF334155);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color dividerDark = Color(0xFF475569);

  // Text Colors - Light Theme
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  static const Color textDisabledLight = Color(0xFFCBD5E1);

  // Text Colors - Dark Theme
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF94A3B8);
  static const Color textDisabledDark = Color(0xFF64748B);

  // Shadow Colors
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowDark = Color(0x40000000);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8EAFF), Color(0xFFF8FAFC)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, tertiaryLight],
  );
}

