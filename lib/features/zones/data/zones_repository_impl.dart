import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../mock/mock_catalog.dart';
import '../domain/zone_model.dart';
import '../domain/zones_repository.dart';

class ZonesRepositoryImpl implements ZonesRepository {
  final Dio _dio;
  final AppConfig _config;

  ZonesRepositoryImpl({required Dio dio, required AppConfig config})
      : _dio = dio,
        _config = config;

  @override
  Future<List<ZoneModel>> getZones(String robotId) async {
    if (_config.enableMockMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return MockCatalog.zonesFor(robotId);
    }

    final response = await _dio.get('/robots/$robotId/zones');
    final data = response.data as List;
    return data
        .map((json) => ZoneModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
