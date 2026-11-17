import 'package:equatable/equatable.dart';

/// A completed (or interrupted) cleaning job as shown in the history list.
///
/// All figures are supplied by the backend (or by the mock backend in the
/// frontend-only demo). The app never derives them from other fields.
class CleaningJobHistoryItem extends Equatable {
  final String id;
  final String robotId;
  final String robotName;
  final String zones;
  final List<String> zoneIds;
  final String outcome;
  final Duration duration;
  final double coverageM2;
  final double coveragePercentage;
  final int detectionCount;
  final DateTime date;

  const CleaningJobHistoryItem({
    required this.id,
    required this.robotId,
    required this.robotName,
    required this.zones,
    required this.zoneIds,
    required this.outcome,
    required this.duration,
    required this.coverageM2,
    required this.coveragePercentage,
    required this.detectionCount,
    required this.date,
  });

  bool get isSuccessful => outcome.toLowerCase() == 'completed';

  @override
  List<Object?> get props => [
        id,
        robotId,
        robotName,
        zones,
        zoneIds,
        outcome,
        duration,
        coverageM2,
        coveragePercentage,
        detectionCount,
        date,
      ];
}
