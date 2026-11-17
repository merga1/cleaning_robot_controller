import 'package:equatable/equatable.dart';

class WasteReadingPoint extends Equatable {
  final DateTime timestamp;
  final double fillPercentage;

  const WasteReadingPoint({
    required this.timestamp,
    required this.fillPercentage,
  });

  @override
  List<Object?> get props => [timestamp, fillPercentage];
}

/// Current waste-container status plus the thresholds supplied by the backend.
class WasteStatusModel extends Equatable {
  final String robotId;
  final double fillPercentage;
  final double warningThreshold;
  final double fullThreshold;
  final bool hasSensorFault;
  final bool isSimulated;
  final DateTime timestamp;
  final List<WasteReadingPoint> history;

  const WasteStatusModel({
    required this.robotId,
    required this.fillPercentage,
    required this.warningThreshold,
    required this.fullThreshold,
    required this.hasSensorFault,
    required this.isSimulated,
    required this.timestamp,
    required this.history,
  });

  bool get isValidFill =>
      fillPercentage >= 0 && fillPercentage <= 100;

  bool get isFull => isValidFill && fillPercentage >= fullThreshold;
  bool get isWarning =>
      isValidFill &&
      fillPercentage >= warningThreshold &&
      fillPercentage < fullThreshold;

  String get stateLabel {
    if (hasSensorFault) return 'Sensor fault';
    if (!isValidFill) return 'No valid reading';
    if (isFull) return 'Full';
    if (isWarning) return 'Warning';
    return 'Normal';
  }

  @override
  List<Object?> get props => [
        robotId,
        fillPercentage,
        warningThreshold,
        fullThreshold,
        hasSensorFault,
        isSimulated,
        timestamp,
        history,
      ];
}
