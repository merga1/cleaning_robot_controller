import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../robots/presentation/robots_controller.dart';
import '../data/zones_repository_impl.dart';
import '../domain/zone_model.dart';
import '../domain/zones_repository.dart';

final zonesRepositoryProvider = Provider<ZonesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final config = ref.watch(appConfigProvider);
  return ZonesRepositoryImpl(dio: dio, config: config);
});

/// Zones for the active robot, fetched from the Raspberry Pi backend.
final zonesListProvider = FutureProvider<List<ZoneModel>>((ref) async {
  final robotId =
      ref.watch(robotsControllerProvider).activeRobot?.id ?? 'robot-alpha-01';
  return ref.watch(zonesRepositoryProvider).getZones(robotId);
});
