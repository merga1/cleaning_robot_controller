import 'package:equatable/equatable.dart';

enum DetectionClass {
  wet,
  dry,
  mixed,
  unknown;

  static DetectionClass fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'wet':
        return DetectionClass.wet;
      case 'dry':
        return DetectionClass.dry;
      case 'mixed':
        return DetectionClass.mixed;
      case 'unknown':
      default:
        return DetectionClass.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case DetectionClass.wet:
        return 'Wet Liquid';
      case DetectionClass.dry:
        return 'Dry Debris';
      case DetectionClass.mixed:
        return 'Mixed Waste';
      case DetectionClass.unknown:
        return 'Unclassified';
    }
  }
}

class GarbageDetectionModel extends Equatable {
  final String id;
  final String robotId;
  final String zoneName;
  final DetectionClass detectionClass;
  final double confidence; // 0.0 - 1.0
  final DateTime timestamp;
  final String? imageUrl;

  const GarbageDetectionModel({
    required this.id,
    required this.robotId,
    required this.zoneName,
    required this.detectionClass,
    required this.confidence,
    required this.timestamp,
    this.imageUrl,
  });

  bool get isUncertain => confidence < 0.65; // MOB-DET-003

  @override
  List<Object?> get props => [
        id,
        robotId,
        zoneName,
        detectionClass,
        confidence,
        timestamp,
        imageUrl,
      ];
}

