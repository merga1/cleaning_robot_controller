import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/backend_config_dialog.dart';
import '../../auth/presentation/auth_controller.dart';

class AppLocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(preferencesServiceProvider);
    return Locale(prefs.getLanguage());
  }

  void setLocale(String languageCode) {
    ref.read(preferencesServiceProvider).setLanguage(languageCode);
    state = Locale(languageCode);
  }
}

final appLocaleProvider =
    NotifierProvider<AppLocaleNotifier, Locale>(AppLocaleNotifier.new);

class AppThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(preferencesServiceProvider);
    final mode = prefs.getThemeMode();
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode mode) {
    final modeStr = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    ref.read(preferencesServiceProvider).setThemeMode(modeStr);
    state = mode;
  }
}

final appThemeModeProvider =
    NotifierProvider<AppThemeModeNotifier, ThemeMode>(AppThemeModeNotifier.new);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final config = ref.watch(appConfigProvider);
    final currentLocale = ref.watch(appLocaleProvider);
    final currentTheme = ref.watch(appThemeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Signed-In User Profile Card (MOB-SET-003)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryNavy,
                    child: Text(
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.techOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Operator',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'operator@cleanbot.io',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.techOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user?.role.displayName ?? 'Operator',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.techOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Localization Selection (MOB-SET-001, MOB-SET-002)
          Text(
            'Language & Localization',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: Column(
              children: [
                RadioListTile<String>(
                  activeColor: AppColors.techOrange,
                  title: Text(
                    'English (Default)',
                    style: TextStyle(color: primaryTextColor),
                  ),
                  value: 'en',
                  groupValue: currentLocale.languageCode,
                  onChanged: (code) {
                    if (code != null) {
                      ref.read(appLocaleProvider.notifier).setLocale(code);
                    }
                  },
                ),
                RadioListTile<String>(
                  activeColor: AppColors.techOrange,
                  title: Text(
                    'አማርኛ (Amharic)',
                    style: TextStyle(color: primaryTextColor),
                  ),
                  value: 'am',
                  groupValue: currentLocale.languageCode,
                  onChanged: (code) {
                    if (code != null) {
                      ref.read(appLocaleProvider.notifier).setLocale(code);
                    }
                  },
                ),
                RadioListTile<String>(
                  activeColor: AppColors.techOrange,
                  title: Text(
                    'Afaan Oromoo (Oromo)',
                    style: TextStyle(color: primaryTextColor),
                  ),
                  value: 'om',
                  groupValue: currentLocale.languageCode,
                  onChanged: (code) {
                    if (code != null) {
                      ref.read(appLocaleProvider.notifier).setLocale(code);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Theme Selection (MOB-SET-001)
          Text(
            'Appearance & Theme',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  activeColor: AppColors.techOrange,
                  title: Text(
                    'System Default',
                    style: TextStyle(color: primaryTextColor),
                  ),
                  value: ThemeMode.system,
                  groupValue: currentTheme,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref
                          .read(appThemeModeProvider.notifier)
                          .setThemeMode(mode);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  activeColor: AppColors.techOrange,
                  title: Text(
                    'Light Theme',
                    style: TextStyle(color: primaryTextColor),
                  ),
                  value: ThemeMode.light,
                  groupValue: currentTheme,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref
                          .read(appThemeModeProvider.notifier)
                          .setThemeMode(mode);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  activeColor: AppColors.techOrange,
                  title: Text(
                    'Dark Theme',
                    style: TextStyle(color: primaryTextColor),
                  ),
                  value: ThemeMode.dark,
                  groupValue: currentTheme,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref
                          .read(appThemeModeProvider.notifier)
                          .setThemeMode(mode);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // System & Backend Environment Info (MOB-SET-003, MOB-SET-004)
          Text(
            'Application & Backend Environment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _infoRow(
                    'App Version',
                    '1.0.0 (Build 1)',
                    primaryTextColor,
                    secondaryTextColor,
                  ),
                  const Divider(height: 16),
                  _infoRow(
                    'Target Architecture',
                    'Feature-First Riverpod',
                    primaryTextColor,
                    secondaryTextColor,
                  ),
                  const Divider(height: 16),
                  _infoRow(
                    'Backend Mode',
                    config.enableMockMode ? 'Demo data' : 'Live robot',
                    primaryTextColor,
                    secondaryTextColor,
                    badgeColor: config.enableMockMode
                        ? AppColors.accentBlue
                        : AppColors.primaryNavy,
                  ),
                  const Divider(height: 16),
                  _infoRow(
                    'REST Base URL',
                    config.apiBaseUrl,
                    primaryTextColor,
                    secondaryTextColor,
                  ),
                  const Divider(height: 16),
                  _infoRow(
                    'WebSocket URL',
                    config.wsBaseUrl,
                    primaryTextColor,
                    secondaryTextColor,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => showBackendConfigDialog(context),
                    icon: const Icon(Icons.router_outlined, size: 18),
                    label: const Text('Configure Raspberry Pi Backend'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button (MOB-AUTH-006)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.severityCritical,
              side: const BorderSide(color: AppColors.severityCritical),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
    Color primaryTextColor,
    Color secondaryTextColor, {
    Color? badgeColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: secondaryTextColor),
        ),
        if (badgeColor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primaryTextColor,
            ),
          ),
      ],
    );
  }
}
