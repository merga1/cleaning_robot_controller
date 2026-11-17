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
  final String zoneId;
  final String zoneName;
  final String jobId;
  final DetectionClass detectionClass;
  final double confidence; // validated to 0.0 - 1.0
  final DateTime timestamp;
  final String? imageUrl;
  final bool isSimulated;

  const GarbageDetectionModel({
    required this.id,
    required this.robotId,
    required this.zoneName,
    required this.detectionClass,
    required this.confidence,
    required this.timestamp,
    this.zoneId = '',
    this.jobId = '',
    this.imageUrl,
    this.isSimulated = false,
  });

  factory GarbageDetectionModel.fromJson(Map<String, dynamic> json) {
    final rawConfidence = (json['confidence'] as num?)?.toDouble();
    final confidence = (rawConfidence != null &&
            rawConfidence >= 0 &&
            rawConfidence <= 1)
        ? rawConfidence
        : 0.0;
    return GarbageDetectionModel(
      id: json['id'] as String? ?? '',
      robotId: json['robot_id'] as String? ?? '',
      zoneId: json['zone_id'] as String? ?? '',
      zoneName: json['zone_name'] as String? ?? 'Unknown zone',
      jobId: json['job_id'] as String? ?? '',
      detectionClass: DetectionClass.fromString(json['class'] as String?),
      confidence: confidence,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now().toUtc(),
      imageUrl: json['image_url'] as String?,
      isSimulated: json['is_simulated'] as bool? ?? false,
    );
  }

  bool get isUncertain => confidence < 0.65; // MOB-DET-003

  @override
  List<Object?> get props => [
        id,
        robotId,
        zoneId,
        zoneName,
        jobId,
        detectionClass,
        confidence,
        timestamp,
        imageUrl,
        isSimulated,
      ];
}

