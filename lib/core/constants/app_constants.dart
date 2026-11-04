class AppConstants {
  AppConstants._();

  // Storage Keys
  static const String keyAccessToken = 'cleanbot_access_token';
  static const String keyRefreshToken = 'cleanbot_refresh_token';
  static const String keySelectedRobotId = 'cleanbot_selected_robot_id';
  static const String keyOnboardingComplete = 'cleanbot_onboarding_complete';
  static const String keyThemeMode = 'cleanbot_theme_mode';
  static const String keyLanguage = 'cleanbot_language_code';

  // Freshness & Performance
  static const int staleThresholdSeconds = 20;
  static const int commandAckTimeoutSeconds = 10;
  static const int maxRetryAttempts = 3;

  // Accessibility & UI standards
  static const double minTouchTargetSize = 48.0;
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;

  // Safety Disclaimers
  static const String safetyNoticeText =
      'NOTICE: This mobile application is for monitoring and operational commands only. '
      'It is NOT an emergency stop system. Physical emergency stops and motion safety '
      'are governed solely by the robot\'s local hardware safety controller.';
}

