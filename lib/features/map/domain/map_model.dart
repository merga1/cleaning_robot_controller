import 'package:equatable/equatable.dart';

class RobotPose extends Equatable {
  final double x;
  final double y;
  final double heading; // Radians
  final DateTime timestamp;
  final bool isStale;

  const RobotPose({
    required this.x,
    required this.y,
    required this.heading,
    required this.timestamp,
    this.isStale = false,
  });

  @override
  List<Object?> get props => [x, y, heading, timestamp, isStale];
}

class MapZonePolygon extends Equatable {
  final String id;
  final String name;
  final List<OffsetPoint> points;
  final bool isSelected;

  const MapZonePolygon({
    required this.id,
    required this.name,
    required this.points,
    this.isSelected = false,
  });

  @override
  List<Object?> get props => [id, name, points, isSelected];
}

/// Plain serialisable point (avoids importing Flutter into the domain layer).
class OffsetPoint extends Equatable {
  final double dx;
  final double dy;

  const OffsetPoint(this.dx, this.dy);

  @override
  List<Object?> get props => [dx, dy];
}

class ObstacleMarker extends Equatable {
  final OffsetPoint position;
  final String label;

  const ObstacleMarker({required this.position, required this.label});

  @override
  List<Object?> get props => [position, label];
}

class MapDataModel extends Equatable {
  final String mapId;
  /// Backend-provided reference; fetched on demand and cached by the app.
  final String mapImageUrl;
  final RobotPose currentPose;
  final List<List<double>> plannedPath;
  final OffsetPoint dockLocation;
  final List<MapZonePolygon> zones;
  final List<ObstacleMarker> obstacles;
  final bool isSimulated;
  final DateTime loadedAt;

  const MapDataModel({
    required this.mapId,
    required this.mapImageUrl,
    required this.currentPose,
    required this.plannedPath,
    this.dockLocation = const OffsetPoint(60, 460),
    this.zones = const [],
    this.obstacles = const [],
    this.isSimulated = false,
    required this.loadedAt,
  });

  MapDataModel copyWithPose(RobotPose pose) => MapDataModel(
        mapId: mapId,
        mapImageUrl: mapImageUrl,
        currentPose: pose,
        plannedPath: plannedPath,
        dockLocation: dockLocation,
        zones: zones,
        obstacles: obstacles,
        isSimulated: isSimulated,
        loadedAt: loadedAt,
      );

  @override
  List<Object?> get props => [
        mapId,
        mapImageUrl,
        currentPose,
        plannedPath,
        dockLocation,
        zones,
        obstacles,
        isSimulated,
        loadedAt,
      ];
}
