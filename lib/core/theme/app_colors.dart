import 'package:flutter/material.dart';

/// CleanBot visual identity.
///
/// The palette intentionally uses only three families: a single blue brand
/// colour (with light/dark shades for hover and depth) and white. Every legacy
/// accent name is kept as an alias so the rest of the app automatically
/// resolves to the reduced blue/white palette.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Core brand blues
  // ---------------------------------------------------------------------------

  /// Primary blue used for app bars, primary actions and strong text.
  static const Color primaryNavy = Color(0xFF0B3B8F);

  /// Deep blue used for dark-mode app bars and pressed states.
  static const Color deepNavy = Color(0xFF062052);

  /// Secondary blue used for surfaces and dark-mode elevation.
  static const Color secondaryBlue = Color(0xFF103768);

  /// Hover / focus blue. This replaces every previous orange accent.
  static const Color accentBlue = Color(0xFF1565D8);

  /// Pressed state for blue actions.
  static const Color accentBluePressed = Color(0xFF0F4CA8);

  /// Pale blue tint for chips, badges and icon wells.
  static const Color softBlue = Color(0xFFEAF2FF);

  /// Slightly stronger pale blue for selected rows.
  static const Color paleBlue = Color(0xFFD8E7FF);

  /// Blue-tinted border colour that keeps the UI on-palette.
  static const Color borderBlue = Color(0xFFC9DBF7);

  /// Muted blue for secondary text and inactive icons.
  static const Color mutedBlue = Color(0xFF5A719B);

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  static const Color white = Color(0xFFFFFFFF);

  // Light theme: full white background as requested.
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = borderBlue;

  // Dark theme: deep blue surfaces with white text.
  static const Color darkBackground = Color(0xFF06142B);
  static const Color darkSurface = Color(0xFF0A2242);
  static const Color darkElevated = Color(0xFF10305C);
  static const Color darkBorder = Color(0xFF1D4B87);

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------

  static const Color primaryText = primaryNavy;
  static const Color secondaryText = mutedBlue;
  static const Color textLight = white;

  // ---------------------------------------------------------------------------
  // Status & severity (blue-only, differentiated by depth)
  // ---------------------------------------------------------------------------

  static const Color severityInfo = primaryNavy;
  static const Color severityWarning = accentBlue;
  static const Color severityCritical = deepNavy;
  static const Color successGreen = primaryNavy;

  static const Color statusIdle = mutedBlue;
  static const Color statusNavigating = primaryNavy;
  static const Color statusCleaning = accentBlue;
  static const Color statusPaused = accentBluePressed;
  static const Color statusReturning = deepNavy;
  static const Color statusCharging = accentBlue;
  static const Color statusFault = deepNavy;

  static const Color levelNormal = primaryNavy;
  static const Color levelWarning = accentBlue;
  static const Color levelCritical = deepNavy;

  // ---------------------------------------------------------------------------
  // Badges
  // ---------------------------------------------------------------------------

  static const Color simulatedBadgeBackground = softBlue;
  static const Color simulatedBadgeText = primaryNavy;

  static const Color staleBadgeBackground = softBlue;
  static const Color staleBadgeText = mutedBlue;

  // ---------------------------------------------------------------------------
  // Compatibility aliases
  // ---------------------------------------------------------------------------

  static const Color techOrange = accentBlue;
  static const Color orangeHover = accentBluePressed;

  static const Color primaryBlue = primaryNavy;
  static const Color primaryDark = deepNavy;
  static const Color primaryLight = softBlue;

  // Hover / overlay helpers used by the theme and custom painters.
  static const Color hoverOverlay = Color(0x141565D8);
  static const Color pressedOverlay = Color(0x241565D8);
  static const Color darkHoverOverlay = Color(0x33A8C7FF);
  static const Color darkPressedOverlay = Color(0x4DA8C7FF);

  /// Text colour that follows the active brightness.
  static Color textPrimaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? white : primaryNavy;

  /// Secondary text colour that follows the active brightness.
  static Color textSecondaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFFB9CCEB) : mutedBlue;

  /// Surface colour that follows the active brightness.
  static Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : white;

  /// Border colour that follows the active brightness.
  static Color borderFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorder : borderBlue;
}
