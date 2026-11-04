import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/preferences_service.dart';
import '../domain/robot_model.dart';
import '../domain/robots_repository.dart';

class RobotsRepositoryImpl implements RobotsRepository {
  final Dio _dio;
  final PreferencesService _prefs;
  final AppConfig _config;

  RobotsRepositoryImpl({
    required Dio dio,
    required PreferencesService prefs,
    required AppConfig config,
  })  : _dio = dio,
        _prefs = prefs,
        _config = config;

  @override
  Future<List<RobotModel>> getAuthorizedRobots() async {
    if (_config.enableMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return [
        RobotModel(
          id: 'robot-alpha-01',
          name: 'CleanBot Pro (East Wing)',
          batteryLevel: 88,
          isCharging: false,
          connectionState: RobotConnectionState.online,
          status: RobotOperationalStatus.cleaning,
          capabilities: const RobotCapabilities(),
          isSimulated: false,
          lastUpdatedAt: DateTime.now().subtract(const Duration(seconds: 4)),
          firmwareVersion: 'v2.4.1',
        ),
        RobotModel(
          id: 'robot-sim-02',
          name: 'CleanBot Simulator-Beta',
          batteryLevel: 65,
          isCharging: true,
          connectionState: RobotConnectionState.online,
          status: RobotOperationalStatus.idle,
          capabilities: const RobotCapabilities(),
          isSimulated: true, // MOB-DASH-009
          lastUpdatedAt: DateTime.now().subtract(const Duration(seconds: 8)),
          firmwareVersion: 'v2.4.1-sim',
        ),
        RobotModel(
          id: 'robot-delta-03',
          name: 'CleanBot Yard Guard',
          batteryLevel: 14,
          isCharging: false,
          connectionState: RobotConnectionState.offline,
          status: RobotOperationalStatus.fault,
          capabilities: const RobotCapabilities(),
          isSimulated: false,
          lastUpdatedAt: DateTime.now().subtract(const Duration(minutes: 45)),
          firmwareVersion: 'v2.3.8',
        ),
      ];
    }

    final response = await _dio.get('/robots');
    final data = response.data as List;
    return data.map((json) => RobotModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<RobotModel> getRobotById(String id) async {
    final robots = await getAuthorizedRobots();
    return robots.firstWhere(
      (r) => r.id == id,
      orElse: () => robots.first,
    );
  }

  @override
  Future<void> saveActiveRobotId(String id) async {
    await _prefs.setSelectedRobotId(id);
  }

  @override
  String? getActiveRobotId() {
    return _prefs.getSelectedRobotId();
  }
}

