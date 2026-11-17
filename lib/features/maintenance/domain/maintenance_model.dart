import 'package:equatable/equatable.dart';

enum HealthState { nominal, warning, fault }

extension HealthStateX on HealthState {
  String get displayName {
    switch (this) {
      case HealthState.nominal:
        return 'Nominal';
      case HealthState.warning:
        return 'Warning';
      case HealthState.fault:
        return 'Fault';
    }
  }
}

class SensorHealthItem extends Equatable {
  final String name;
  final HealthState state;
  final String detail;

  const SensorHealthItem({
    required this.name,
    required this.state,
    required this.detail,
  });

  @override
  List<Object?> get props => [name, state, detail];
}

class ActiveFaultItem extends Equatable {
  final String id;
  final String title;
  final String robotId;
  final HealthState severity;
  final DateTime detectedAt;
  final bool blocksCommands;

  const ActiveFaultItem({
    required this.id,
    required this.title,
    required this.robotId,
    required this.severity,
    required this.detectedAt,
    required this.blocksCommands,
  });

  @override
  List<Object?> get props =>
      [id, title, robotId, severity, detectedAt, blocksCommands];
}

class MaintenanceRecordItem extends Equatable {
  final String id;
  final String title;
  final DateTime? completedAt;
  final DateTime dueAt;
  final String? notes;

  const MaintenanceRecordItem({
    required this.id,
    required this.title,
    required this.dueAt,
    this.completedAt,
    this.notes,
  });

  bool get isOverdue => completedAt == null && DateTime.now().isAfter(dueAt);

  @override
  List<Object?> get props => [id, title, completedAt, dueAt, notes];
}

class RobotHealthReport extends Equatable {
  final String robotId;
  final String connectionState;
  final String firmwareVersion;
  final List<SensorHealthItem> sensors;
  final List<ActiveFaultItem> activeFaults;
  final List<MaintenanceRecordItem> maintenanceRecords;
  final List<CommandHistoryItem> commandHistory;
  final DateTime lastDiagnosticAt;

  const RobotHealthReport({
    required this.robotId,
    required this.connectionState,
    required this.firmwareVersion,
    required this.sensors,
    required this.activeFaults,
    required this.maintenanceRecords,
    required this.commandHistory,
    required this.lastDiagnosticAt,
  });

  @override
  List<Object?> get props => [
        robotId,
        connectionState,
        firmwareVersion,
        sensors,
        activeFaults,
        maintenanceRecords,
        commandHistory,
        lastDiagnosticAt,
      ];
}

class CommandHistoryItem extends Equatable {
  final String id;
  final String commandType;
  final String state;
  final DateTime timestamp;
  final String? reason;

  const CommandHistoryItem({
    required this.id,
    required this.commandType,
    required this.state,
    required this.timestamp,
    this.reason,
  });

  @override
  List<Object?> get props => [id, commandType, state, timestamp, reason];
}
