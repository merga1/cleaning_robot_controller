import 'package:equatable/equatable.dart';

/// Reporting periods supported by the backend-computed report endpoint.
enum ReportPeriod {
  last7Days('Last 7 days', 7),
  last30Days('Last 30 days', 30),
  last90Days('Last 90 days', 90);

  const ReportPeriod(this.displayName, this.days);

  final String displayName;
  final int days;
}

/// One point in a backend-supplied trend series.
class ReportTrendPoint extends Equatable {
  final String label;
  final double cleanlinessScore;
  final int detections;
  final int containerEvents;

  const ReportTrendPoint({
    required this.label,
    required this.cleanlinessScore,
    required this.detections,
    required this.containerEvents,
  });

  @override
  List<Object?> get props =>
      [label, cleanlinessScore, detections, containerEvents];
}

/// The full report payload. Every figure comes from the backend (or its mock
/// equivalent) - the app does not calculate metrics itself (MOB-REP-003).
class CleaningReport extends Equatable {
  final ReportPeriod period;
  final CleaningReportMetrics metrics;
  final List<ReportTrendPoint> trends;
  final Map<DetectionSummaryClass, int> detectionsByClass;
  final DateTime generatedAt;
  final bool isSimulated;

  const CleaningReport({
    required this.period,
    required this.metrics,
    required this.trends,
    required this.detectionsByClass,
    required this.generatedAt,
    required this.isSimulated,
  });

  @override
  List<Object?> get props =>
      [period, metrics, trends, detectionsByClass, generatedAt, isSimulated];
}

enum DetectionSummaryClass { wet, dry, mixed, unknown }

class CleaningReportMetrics extends Equatable {
  final int jobsCompleted;
  final int jobsFailed;
  final Duration totalCleaningTime;
  final double averageCoveragePercentage;
  final int totalGarbageDetections;

  const CleaningReportMetrics({
    required this.jobsCompleted,
    required this.jobsFailed,
    required this.totalCleaningTime,
    required this.averageCoveragePercentage,
    required this.totalGarbageDetections,
  });

  @override
  List<Object?> get props => [
        jobsCompleted,
        jobsFailed,
        totalCleaningTime,
        averageCoveragePercentage,
        totalGarbageDetections,
      ];
}

