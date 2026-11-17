import 'package:equatable/equatable.dart';

/// A floor cleanliness assessment. Scores are validated to 0-100 and
/// confidence to 0-1 before they are ever displayed.
class FloorAssessmentModel extends Equatable {
  final String id;
  final String robotId;
  final String zoneId;
  final String zoneName;
  final double score;
  final double confidence;
  final DateTime timestamp;
  final bool isSimulated;
  final String? sensorFault;

  const FloorAssessmentModel({
    required this.id,
    required this.robotId,
    required this.zoneId,
    required this.zoneName,
    required this.score,
    required this.confidence,
    required this.timestamp,
    required this.isSimulated,
    this.sensorFault,
  });

  /// Low confidence or a sensor fault is reported as inconclusive, never as
  /// clean or dirty (MOB-INSP-003).
  bool get isInconclusive => confidence < 0.6 || sensorFault != null;

  String get resultLabel {
    if (isInconclusive) return 'Inconclusive';
    if (score >= 80) return 'Clean';
    if (score >= 50) return 'Moderate dust';
    return 'Needs deep clean';
  }

  @override
  List<Object?> get props => [
        id,
        robotId,
        zoneId,
        zoneName,
        score,
        confidence,
        timestamp,
        isSimulated,
        sensorFault,
      ];
}
