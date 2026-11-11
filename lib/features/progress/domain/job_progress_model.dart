import 'package:equatable/equatable.dart';

enum JobProgressStatus {
  pending,
  active,
  paused,
  faultInterrupted,
  completed,
  failed,
  cancelled;

  static JobProgressStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'active':
      case 'cleaning':
        return JobProgressStatus.active;
      case 'paused':
        return JobProgressStatus.paused;
      case 'fault_interrupted':
      case 'fault':
        return JobProgressStatus.faultInterrupted;
      case 'completed':
      case 'done':
        return JobProgressStatus.completed;
      case 'failed':
        return JobProgressStatus.failed;
      case 'cancelled':
        return JobProgressStatus.cancelled;
      case 'pending':
      default:
        return JobProgressStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case JobProgressStatus.pending:
        return 'Queued';
      case JobProgressStatus.active:
        return 'In Progress';
      case JobProgressStatus.paused:
        return 'Paused';
      case JobProgressStatus.faultInterrupted:
        return 'Fault Interrupted';
      case JobProgressStatus.completed:
        return 'Completed';
      case JobProgressStatus.failed:
        return 'Failed';
      case JobProgressStatus.cancelled:
        return 'Cancelled';
    }
  }

  bool get isTerminal =>
      this == JobProgressStatus.completed ||
      this == JobProgressStatus.failed ||
      this == JobProgressStatus.cancelled ||
      this == JobProgressStatus.faultInterrupted;
}

class ZoneCleaningProgress extends Equatable {
  final String zoneId;
  final String zoneName;
  final double progressPercentage;
  final double areaCleanedM2;
  final double totalAreaM2;
  final bool isCompleted;

  const ZoneCleaningProgress({
    required this.zoneId,
    required this.zoneName,
    required this.progressPercentage,
    required this.areaCleanedM2,
    required this.totalAreaM2,
    required this.isCompleted,
  });

  @override
  List<Object?> get props => [
        zoneId,
        zoneName,
        progressPercentage,
        areaCleanedM2,
        totalAreaM2,
        isCompleted,
      ];
}

class JobEventTimelineItem extends Equatable {
  final String id;
  final String eventType; // started, paused, resumed, obstacle, container_full, fault, completed
  final String title;
  final String description;
  final DateTime timestamp;

  const JobEventTimelineItem({
    required this.id,
    required this.eventType,
    required this.title,
    required this.description,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, eventType, title, description, timestamp];
}

class DetailedJobProgressModel extends Equatable {
  final String jobId;
  final String robotId;
  final String robotName;
  final JobProgressStatus status;
  final double overallProgress;
  final Duration elapsedTime;
  final double totalCoverageM2;
  final DateTime? estimatedFinishTime; // MOB-PROG-003: only shown if supplied
  final List<ZoneCleaningProgress> zones;
  final List<JobEventTimelineItem> timeline;

  const DetailedJobProgressModel({
    required this.jobId,
    required this.robotId,
    required this.robotName,
    required this.status,
    required this.overallProgress,
    required this.elapsedTime,
    required this.totalCoverageM2,
    this.estimatedFinishTime,
    required this.zones,
    required this.timeline,
  });

  @override
  List<Object?> get props => [
        jobId,
        robotId,
        robotName,
        status,
        overallProgress,
        elapsedTime,
        totalCoverageM2,
        estimatedFinishTime,
        zones,
        timeline,
      ];
}

