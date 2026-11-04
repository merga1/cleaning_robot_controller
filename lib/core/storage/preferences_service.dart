import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main()');
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PreferencesService(prefs);
});

class PreferencesService {
  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  Future<void> setSelectedRobotId(String robotId) async {
    await _prefs.setString(AppConstants.keySelectedRobotId, robotId);
  }

  String? getSelectedRobotId() {
    return _prefs.getString(AppConstants.keySelectedRobotId);
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(AppConstants.keyOnboardingComplete, completed);
  }

  bool isOnboardingCompleted() {
    return _prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(AppConstants.keyThemeMode, mode);
  }

  String getThemeMode() {
    return _prefs.getString(AppConstants.keyThemeMode) ?? 'system';
  }

  Future<void> setLanguage(String languageCode) async {
    await _prefs.setString(AppConstants.keyLanguage, languageCode);
  }

  String getLanguage() {
    return _prefs.getString(AppConstants.keyLanguage) ?? 'en';
  }

  Future<void> clearAll() async {
    await _prefs.remove(AppConstants.keySelectedRobotId);
  }
}

