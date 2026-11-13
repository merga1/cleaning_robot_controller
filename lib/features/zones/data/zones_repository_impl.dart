import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
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
      return [
        ZoneModel(
          id: 'zone-101',
          name: 'Main Reception & Lobby',
          areaM2: 120.5,
          lastCleanedAt: DateTime.now().subtract(const Duration(hours: 4)),
          isAvailable: true,
        ),
        ZoneModel(
          id: 'zone-102',
          name: 'North Conference Hall',
          areaM2: 85.0,
          lastCleanedAt: DateTime.now().subtract(const Duration(hours: 18)),
          isAvailable: true,
        ),
        ZoneModel(
          id: 'zone-103',
          name: 'Executive Boardroom',
          areaM2: 64.2,
          lastCleanedAt: DateTime.now().subtract(const Duration(days: 1)),
          isAvailable: true,
        ),
        const ZoneModel(
          id: 'zone-104',
          name: 'Cafeteria & Dining Lounge',
          areaM2: 150.0,
          isAvailable: false,
          unavailabilityReason: 'Active human maintenance in progress',
        ),
        const ZoneModel(
          id: 'zone-105',
          name: 'Server Room Corridor',
          areaM2: 45.0,
          isAvailable: false,
          unavailabilityReason: 'Restricted high-security access',
        ),
      ];
    }

    final response = await _dio.get('/robots/$robotId/zones');
    final data = response.data as List;
    return data
        .map((json) => ZoneModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
