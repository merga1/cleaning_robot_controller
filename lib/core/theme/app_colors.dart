import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors (Clean, Modern Industrial Robotics)
  static const Color primaryBlue = Color(0xFF0284C7); // Sky 600
  static const Color primaryDark = Color(0xFF0369A1); // Sky 700
  static const Color primaryLight = Color(0xFFE0F2FE); // Sky 100

  static const Color secondaryTeal = Color(0xFF0D9488); // Teal 600
  static const Color accentCyan = Color(0xFF06B6D4); // Cyan 500

  // Alert & Severity Colors
  static const Color severityInfo = Color(0xFF2563EB); // Blue 600
  static const Color severityWarning = Color(0xFFD97706); // Amber 600
  static const Color severityCritical = Color(0xFFDC2626); // Red 600

  // Operational Status Colors
  static const Color statusIdle = Color(0xFF64748B); // Slate 500
  static const Color statusNavigating = Color(0xFF0284C7); // Sky 600
  static const Color statusCleaning = Color(0xFF16A34A); // Green 600
  static const Color statusPaused = Color(0xFFD97706); // Amber 600
  static const Color statusReturning = Color(0xFF7C3AED); // Violet 600
  static const Color statusCharging = Color(0xFF059669); // Emerald 600
  static const Color statusFault = Color(0xFFDC2626); // Red 600

  // Battery & Container Levels
  static const Color levelNormal = Color(0xFF16A34A);
  static const Color levelWarning = Color(0xFFD97706);
  static const Color levelCritical = Color(0xFFDC2626);

  // Background & Surfaces
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);

  // Simulation Badge
  static const Color simulatedBadgeBackground = Color(0xFFFEF3C7);
  static const Color simulatedBadgeText = Color(0xFFB45309);

  // Stale Data Badge
  static const Color staleBadgeBackground = Color(0xFFF1F5F9);
  static const Color staleBadgeText = Color(0xFF475569);
}

