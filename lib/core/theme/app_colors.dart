import 'package:flutter/material.dart';

/// Official Brand Colors for Ethiopian Artificial Intelligence Institute (EAII)
/// Cleaning Robot Controller.
class AppColors {
  AppColors._();

  // Official Brand Color Palette
  static const Color primaryNavy = Color(0xFF03204E);
  static const Color deepNavy = Color(0xFF031C48);
  static const Color secondaryBlue = Color(0xFF102952);
  static const Color techOrange = Color(0xFFF67B05);
  static const Color orangeHover = Color(0xFFDB6800);

  // Backgrounds & Surfaces
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Dark Theme Surfaces
  static const Color darkBackground = Color(0xFF021636);
  static const Color darkSurface = Color(0xFF03204E);
  static const Color darkBorder = Color(0xFF102952);

  // Typography
  static const Color primaryText = Color(0xFF03204E);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color textLight = Color(0xFFFFFFFF);

  // Alert & Severity Colors
  static const Color severityInfo = Color(0xFF102952);
  static const Color severityWarning = Color(0xFFF67B05);
  static const Color severityCritical = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF16A34A);

  // Operational Status Colors
  static const Color statusIdle = Color(0xFF64748B);
  static const Color statusNavigating = Color(0xFF102952);
  static const Color statusCleaning = Color(0xFFF67B05); // Active cleaning
  static const Color statusPaused = Color(0xFFD97706);
  static const Color statusReturning = Color(0xFF03204E);
  static const Color statusCharging = Color(0xFF16A34A);
  static const Color statusFault = Color(0xFFDC2626);

  // Battery & Container Levels
  static const Color levelNormal = Color(0xFF16A34A);
  static const Color levelWarning = Color(0xFFF67B05);
  static const Color levelCritical = Color(0xFFDC2626);

  // Badges
  static const Color simulatedBadgeBackground = Color(0xFFFFF7ED);
  static const Color simulatedBadgeText = Color(0xFFC2410C);

  static const Color staleBadgeBackground = Color(0xFFF1F5F9);
  static const Color staleBadgeText = Color(0xFF475569);

  // Compatibility Aliases
  static const Color primaryBlue = primaryNavy;
  static const Color primaryDark = deepNavy;
  static const Color primaryLight = Color(0xFFEBF3FC);
}
