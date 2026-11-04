import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
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
              side: const BorderSide(color: AppColors.lightBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      user?.fullName.isNotEmpty == true
                          ? user!.fullName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'operator@cleanbot.io',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user?.role.displayName ?? 'Operator',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
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
          const Text(
            'Language & Localization',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('English (Default)'),
                  value: 'en',
                  groupValue: currentLocale.languageCode,
                  onChanged: (code) {
                    if (code != null) {
                      ref.read(appLocaleProvider.notifier).setLocale(code);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('አማርኛ (Amharic)'),
                  value: 'am',
                  groupValue: currentLocale.languageCode,
                  onChanged: (code) {
                    if (code != null) {
                      ref.read(appLocaleProvider.notifier).setLocale(code);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Afaan Oromoo (Oromo)'),
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
          const Text(
            'Appearance & Theme',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('System Default'),
                  value: ThemeMode.system,
                  groupValue: currentTheme,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Light Theme'),
                  value: ThemeMode.light,
                  groupValue: currentTheme,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark Theme'),
                  value: ThemeMode.dark,
                  groupValue: currentTheme,
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // System & Backend Environment Info (MOB-SET-003, MOB-SET-004)
          const Text(
            'Application & Backend Environment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _infoRow('App Version', '1.0.0 (Build 1)'),
                  const Divider(height: 16),
                  _infoRow('Target Architecture', 'Feature-First Riverpod'),
                  const Divider(height: 16),
                  _infoRow(
                    'Backend Env',
                    config.environmentLabel,
                    badgeColor: config.isProduction
                        ? AppColors.statusCleaning
                        : AppColors.severityWarning,
                  ),
                  const Divider(height: 16),
                  _infoRow('REST Base URL', config.apiBaseUrl),
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

  Widget _infoRow(String label, String value, {Color? badgeColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        if (badgeColor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor),
            ),
          )
        else
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
