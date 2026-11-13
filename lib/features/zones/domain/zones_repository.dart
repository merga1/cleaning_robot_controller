import 'zone_model.dart';

abstract class ZonesRepository {
  Future<List<ZoneModel>> getZones(String robotId);
}
