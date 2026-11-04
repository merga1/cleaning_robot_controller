import 'package:equatable/equatable.dart';

class RobotPose extends Equatable {
  final double x;
  final double y;
  final double heading; // Radians
  final DateTime timestamp;

  const RobotPose({
    required this.x,
    required this.y,
    required this.heading,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [x, y, heading, timestamp];
}

class MapDataModel extends Equatable {
  final String mapId;
  final String mapImageUrl;
  final RobotPose currentPose;
  final List<List<double>> plannedPath;

  const MapDataModel({
    required this.mapId,
    required this.mapImageUrl,
    required this.currentPose,
    required this.plannedPath,
  });

  @override
  List<Object?> get props => [mapId, mapImageUrl, currentPose, plannedPath];
}

