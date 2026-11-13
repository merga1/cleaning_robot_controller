import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Single source of truth for the CleanBot theme.
///
/// Only blue and white are used. All interactive states (hover, focus, press,
/// selection) resolve to a blue overlay, while the light theme keeps a full
/// white background and the dark theme uses deep blue surfaces.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryNavy,
      brightness: Brightness.light,
      primary: AppColors.primaryNavy,
      onPrimary: AppColors.white,
      secondary: AppColors.accentBlue,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.primaryNavy,
      error: AppColors.deepNavy,
      onError: AppColors.white,
    );

    return _buildBase(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.lightBackground,
      cardColor: AppColors.white,
      borderColor: AppColors.borderBlue,
      appBarColor: AppColors.primaryNavy,
      textPrimary: AppColors.primaryNavy,
      textSecondary: AppColors.mutedBlue,
      hoverOverlay: AppColors.hoverOverlay,
      pressedOverlay: AppColors.pressedOverlay,
      navBackground: AppColors.primaryNavy,
      navSelected: AppColors.white,
      navUnselected: const Color(0xFFB9CCEB),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accentBlue,
      brightness: Brightness.dark,
      primary: AppColors.accentBlue,
      onPrimary: AppColors.white,
      secondary: AppColors.accentBlue,
      onSecondary: AppColors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.white,
      error: AppColors.accentBlue,
      onError: AppColors.white,
    );

    return _buildBase(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.darkBackground,
      cardColor: AppColors.darkSurface,
      borderColor: AppColors.darkBorder,
      appBarColor: AppColors.deepNavy,
      textPrimary: AppColors.white,
      textSecondary: const Color(0xFFB9CCEB),
      hoverOverlay: AppColors.darkHoverOverlay,
      pressedOverlay: AppColors.darkPressedOverlay,
      navBackground: AppColors.deepNavy,
      navSelected: AppColors.white,
      navUnselected: const Color(0xFF9FBCE6),
    );
  }

  static ThemeData _buildBase({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color borderColor,
    required Color appBarColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color hoverOverlay,
    required Color pressedOverlay,
    required Color navBackground,
    required Color navSelected,
    required Color navUnselected,
  }) {
    final isDark = brightness == Brightness.dark;
    final fieldFill = isDark ? AppColors.darkElevated : AppColors.white;
    final disabledFill = isDark ? AppColors.darkBorder : AppColors.paleBlue;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: AppColors.primaryNavy,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: scaffoldBackground,
      cardColor: cardColor,
      dividerColor: borderColor,
      hoverColor: hoverOverlay,
      focusColor: hoverOverlay,
      splashColor: pressedOverlay,
      highlightColor: hoverOverlay,
      disabledColor: navUnselected,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: appBarColor,
        foregroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.white),
        actionsIconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: const TextStyle(
          color: AppColors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: AppColors.primaryNavy.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return disabledFill;
            if (states.contains(WidgetState.pressed)) {
              return AppColors.accentBluePressed;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return AppColors.accentBlue;
            }
            return AppColors.primaryNavy;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return isDark ? AppColors.white : AppColors.mutedBlue;
            }
            return AppColors.white;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.white.withValues(alpha: 0.16);
            }
            return AppColors.white.withValues(alpha: 0.08);
          }),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return navUnselected;
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)) {
              return isDark ? AppColors.white : AppColors.accentBlue;
            }
            return isDark ? AppColors.white : AppColors.primaryNavy;
          }),
          overlayColor: WidgetStatePropertyAll(hoverOverlay),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return navUnselected;
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)) {
              return isDark ? AppColors.white : AppColors.accentBlue;
            }
            return isDark ? AppColors.white : AppColors.primaryNavy;
          }),
          overlayColor: WidgetStatePropertyAll(hoverOverlay),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return isDark ? AppColors.darkElevated : AppColors.softBlue;
            }
            return Colors.transparent;
          }),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
          side: WidgetStatePropertyAll(
            BorderSide(color: borderColor, width: 1.5),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStatePropertyAll(hoverOverlay),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return navUnselected;
            return isDark ? AppColors.white : AppColors.primaryNavy;
          }),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentBlue,
        foregroundColor: AppColors.white,
        elevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBackground,
        selectedItemColor: navSelected,
        unselectedItemColor: navUnselected,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBackground,
        indicatorColor: AppColors.white.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? navSelected : navUnselected,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? navSelected : navUnselected,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.softBlue,
        selectedColor: AppColors.accentBlue,
        secondarySelectedColor: AppColors.primaryNavy,
        disabledColor: disabledFill,
        labelStyle: TextStyle(
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryNavy),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor),
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.primaryNavy,
        contentTextStyle: const TextStyle(color: AppColors.white),
        actionTextColor: AppColors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return navUnselected;
          return AppColors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return disabledFill;
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentBlue;
          }
          return isDark ? AppColors.darkBorder : AppColors.borderBlue;
        }),
        overlayColor: WidgetStatePropertyAll(hoverOverlay),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return navUnselected;
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentBlue;
          }
          return isDark ? navUnselected : AppColors.mutedBlue;
        }),
        overlayColor: WidgetStatePropertyAll(hoverOverlay),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentBlue;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.white),
        side: BorderSide(color: borderColor, width: 1.5),
        overlayColor: WidgetStatePropertyAll(hoverOverlay),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accentBlue,
        linearTrackColor: isDark ? AppColors.darkBorder : AppColors.softBlue,
        circularTrackColor: isDark ? AppColors.darkBorder : AppColors.softBlue,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? AppColors.white : AppColors.primaryNavy,
        textColor: textPrimary,
        tileColor: Colors.transparent,
        selectedTileColor: isDark ? AppColors.darkElevated : AppColors.softBlue,
        selectedColor: isDark ? AppColors.white : AppColors.primaryNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkElevated : AppColors.primaryNavy,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: AppColors.white, fontSize: 12),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accentBlue,
        selectionColor: AppColors.paleBlue,
        selectionHandleColor: AppColors.accentBlue,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
      ),
    );
  }
}
