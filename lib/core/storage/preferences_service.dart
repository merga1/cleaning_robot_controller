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

  // ---------------------------------------------------------------------------
  // Raspberry Pi backend connection
  // ---------------------------------------------------------------------------

  Future<void> setBackendHost(String host) async {
    await _prefs.setString(AppConstants.keyBackendHost, host);
  }

  String getBackendHost() {
    return _prefs.getString(AppConstants.keyBackendHost) ??
        AppConstants.defaultBackendHost;
  }

  Future<void> setBackendPort(int port) async {
    await _prefs.setInt(AppConstants.keyBackendPort, port);
  }

  int getBackendPort() {
    return _prefs.getInt(AppConstants.keyBackendPort) ??
        AppConstants.defaultBackendPort;
  }

  Future<void> setBackendUseTls(bool useTls) async {
    await _prefs.setBool(AppConstants.keyBackendUseTls, useTls);
  }

  bool getBackendUseTls() {
    return _prefs.getBool(AppConstants.keyBackendUseTls) ?? false;
  }

  Future<void> setBackendUseMock(bool useMock) async {
    await _prefs.setBool(AppConstants.keyBackendUseMock, useMock);
  }

  bool getBackendUseMock() {
    return _prefs.getBool(AppConstants.keyBackendUseMock) ?? false;
  }

  Future<void> clearAll() async {
    await _prefs.remove(AppConstants.keySelectedRobotId);
    await _prefs.remove(AppConstants.keyBackendHost);
    await _prefs.remove(AppConstants.keyBackendPort);
    await _prefs.remove(AppConstants.keyBackendUseTls);
    await _prefs.remove(AppConstants.keyBackendUseMock);
  }
}

