import 'package:equatable/equatable.dart';

class CleanlinessSummary extends Equatable {
  final double score; // 0.0 - 100.0
  final double confidence; // 0.0 - 1.0
  final DateTime timestamp;
  final bool isSimulated;
  final String zoneName;

  const CleanlinessSummary({
    required this.score,
    required this.confidence,
    required this.timestamp,
    required this.isSimulated,
    required this.zoneName,
  });

  bool get isInconclusive => confidence < 0.6;

  String get assessmentLabel {
    if (isInconclusive) return 'Inconclusive (Low Confidence)';
    if (score >= 80) return 'Optimal Clean';
    if (score >= 50) return 'Moderate Dust';
    return 'Requires Deep Clean';
  }

  @override
  List<Object?> get props => [score, confidence, timestamp, isSimulated, zoneName];
}

class ActiveJobSummary extends Equatable {
  final String jobId;
  final String zoneName;
  final double progressPercentage;
  final Duration elapsedTime;
  final double coverageAreaM2;

  const ActiveJobSummary({
    required this.jobId,
    required this.zoneName,
    required this.progressPercentage,
    required this.elapsedTime,
    required this.coverageAreaM2,
  });

  @override
  List<Object?> get props => [
        jobId,
        zoneName,
        progressPercentage,
        elapsedTime,
        coverageAreaM2,
      ];
}

class DashboardSummaryModel extends Equatable {
  final String robotId;
  final ActiveJobSummary? activeJob;
  final int wasteFillPercentage;
  final bool wasteSensorFault;
  final CleanlinessSummary? latestCleanliness;
  final int activeAlertCount;
  final DateTime lastDataReceivedAt;

  const DashboardSummaryModel({
    required this.robotId,
    this.activeJob,
    required this.wasteFillPercentage,
    this.wasteSensorFault = false,
    this.latestCleanliness,
    this.activeAlertCount = 0,
    required this.lastDataReceivedAt,
  });

  bool isStale(Duration threshold) {
    return DateTime.now().difference(lastDataReceivedAt) > threshold;
  }

  @override
  List<Object?> get props => [
        robotId,
        activeJob,
        wasteFillPercentage,
        wasteSensorFault,
        latestCleanliness,
        activeAlertCount,
        lastDataReceivedAt,
      ];
}

