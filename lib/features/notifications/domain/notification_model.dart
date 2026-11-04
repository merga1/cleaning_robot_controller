import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum AlertSeverity {
  info,
  warning,
  critical;

  String get displayName {
    switch (this) {
      case AlertSeverity.info:
        return 'Information';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.critical:
        return 'Critical Fault';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverity.info:
        return AppColors.severityInfo;
      case AlertSeverity.warning:
        return AppColors.severityWarning;
      case AlertSeverity.critical:
        return AppColors.severityCritical;
    }
  }

  IconData get icon {
    switch (this) {
      case AlertSeverity.info:
        return Icons.info_outline;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }
}

class AlertNotificationModel extends Equatable {
  final String id;
  final String robotId;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  final bool isRead;

  const AlertNotificationModel({
    required this.id,
    required this.robotId,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.isRead = false,
  });

  AlertNotificationModel copyWith({bool? isRead}) {
    return AlertNotificationModel(
      id: id,
      robotId: robotId,
      title: title,
      message: message,
      severity: severity,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  List<Object?> get props => [
        id,
        robotId,
        title,
        message,
        severity,
        timestamp,
        isRead,
      ];
}

