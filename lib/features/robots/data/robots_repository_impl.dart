import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/preferences_service.dart';
import '../../../mock/mock_catalog.dart';
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
      return MockCatalog.robots;
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

