import 'package:equatable/equatable.dart';

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

