import 'package:equatable/equatable.dart';

enum RobotConnectionState {
  online,
  offline,
  degraded;

  static RobotConnectionState fromString(String? state) {
    switch (state?.toLowerCase()) {
      case 'online':
        return RobotConnectionState.online;
      case 'degraded':
        return RobotConnectionState.degraded;
      case 'offline':
      default:
        return RobotConnectionState.offline;
    }
  }

  String get displayName {
    switch (this) {
      case RobotConnectionState.online:
        return 'Online';
      case RobotConnectionState.offline:
        return 'Offline';
      case RobotConnectionState.degraded:
        return 'Degraded';
    }
  }
}

enum RobotOperationalStatus {
  idle,
  navigating,
  cleaning,
  paused,
  returning,
  charging,
  fault;

  static RobotOperationalStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'navigating':
        return RobotOperationalStatus.navigating;
      case 'cleaning':
        return RobotOperationalStatus.cleaning;
      case 'paused':
        return RobotOperationalStatus.paused;
      case 'returning':
        return RobotOperationalStatus.returning;
      case 'charging':
        return RobotOperationalStatus.charging;
      case 'fault':
        return RobotOperationalStatus.fault;
      case 'idle':
      default:
        return RobotOperationalStatus.idle;
    }
  }

  String get displayName {
    switch (this) {
      case RobotOperationalStatus.idle:
        return 'Idle';
      case RobotOperationalStatus.navigating:
        return 'Navigating';
      case RobotOperationalStatus.cleaning:
        return 'Cleaning';
      case RobotOperationalStatus.paused:
        return 'Paused';
      case RobotOperationalStatus.returning:
        return 'Returning to Dock';
      case RobotOperationalStatus.charging:
        return 'Charging';
      case RobotOperationalStatus.fault:
        return 'Fault Triggered';
    }
  }
}

class RobotCapabilities extends Equatable {
  final bool canCall;
  final bool canClean;
  final bool canPause;
  final bool canResume;
  final bool canCancel;
  final bool canInspect;
  final bool canDock;

  const RobotCapabilities({
    this.canCall = true,
    this.canClean = true,
    this.canPause = true,
    this.canResume = true,
    this.canCancel = true,
    this.canInspect = true,
    this.canDock = true,
  });

  factory RobotCapabilities.fromJson(Map<String, dynamic> json) {
    return RobotCapabilities(
      canCall: json['can_call'] as bool? ?? true,
      canClean: json['can_clean'] as bool? ?? true,
      canPause: json['can_pause'] as bool? ?? true,
      canResume: json['can_resume'] as bool? ?? true,
      canCancel: json['can_cancel'] as bool? ?? true,
      canInspect: json['can_inspect'] as bool? ?? true,
      canDock: json['can_dock'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
        canCall,
        canClean,
        canPause,
        canResume,
        canCancel,
        canInspect,
        canDock,
      ];
}

class RobotModel extends Equatable {
  final String id;
  final String name;
  final int batteryLevel;
  final bool isCharging;
  final RobotConnectionState connectionState;
  final RobotOperationalStatus status;
  final RobotCapabilities capabilities;
  final bool isSimulated;
  final DateTime lastUpdatedAt;
  final String firmwareVersion;

  const RobotModel({
    required this.id,
    required this.name,
    required this.batteryLevel,
    required this.isCharging,
    required this.connectionState,
    required this.status,
    required this.capabilities,
    required this.isSimulated,
    required this.lastUpdatedAt,
    required this.firmwareVersion,
  });

  factory RobotModel.fromJson(Map<String, dynamic> json) {
    return RobotModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'CleanBot',
      batteryLevel: ((json['battery_level'] as num?)?.toInt() ?? 0).clamp(0, 100),
      isCharging: json['is_charging'] as bool? ?? false,
      connectionState:
          RobotConnectionState.fromString(json['connection_state'] as String?),
      status:
          RobotOperationalStatus.fromString(json['status'] as String?),
      capabilities: json['capabilities'] != null
          ? RobotCapabilities.fromJson(json['capabilities'] as Map<String, dynamic>)
          : const RobotCapabilities(),
      isSimulated: json['is_simulated'] as bool? ?? false,
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.tryParse(json['last_updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      firmwareVersion: json['firmware_version'] as String? ?? 'v1.0.0',
    );
  }

  RobotModel copyWith({
    String? id,
    String? name,
    int? batteryLevel,
    bool? isCharging,
    RobotConnectionState? connectionState,
    RobotOperationalStatus? status,
    RobotCapabilities? capabilities,
    bool? isSimulated,
    DateTime? lastUpdatedAt,
    String? firmwareVersion,
  }) {
    return RobotModel(
      id: id ?? this.id,
      name: name ?? this.name,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      connectionState: connectionState ?? this.connectionState,
      status: status ?? this.status,
      capabilities: capabilities ?? this.capabilities,
      isSimulated: isSimulated ?? this.isSimulated,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        batteryLevel,
        isCharging,
        connectionState,
        status,
        capabilities,
        isSimulated,
        lastUpdatedAt,
        firmwareVersion,
      ];
}

