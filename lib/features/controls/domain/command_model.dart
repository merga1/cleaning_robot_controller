import 'package:equatable/equatable.dart';

enum CommandType {
  call,
  startCleaning,
  pause,
  resume,
  cancel,
  inspectFloor,
  returnToDock,
  requestStatusRefresh;

  String get displayName {
    switch (this) {
      case CommandType.call:
        return 'Call Robot';
      case CommandType.startCleaning:
        return 'Start Cleaning';
      case CommandType.pause:
        return 'Pause';
      case CommandType.resume:
        return 'Resume';
      case CommandType.cancel:
        return 'Cancel Cleaning';
      case CommandType.inspectFloor:
        return 'Inspect Floor';
      case CommandType.returnToDock:
        return 'Return to Dock';
      case CommandType.requestStatusRefresh:
        return 'Refresh Status';
    }
  }

  bool get isDisruptive {
    return this == CommandType.cancel ||
        this == CommandType.returnToDock ||
        this == CommandType.startCleaning;
  }
}

enum CommandLifecycleState {
  submitting,
  pending,
  dispatched,
  accepted,
  executing,
  completed,
  rejected,
  failed,
  expired,
  cancelled;

  static CommandLifecycleState fromString(String? state) {
    switch (state?.toLowerCase()) {
      case 'pending':
        return CommandLifecycleState.pending;
      case 'dispatched':
        return CommandLifecycleState.dispatched;
      case 'accepted':
        return CommandLifecycleState.accepted;
      case 'executing':
        return CommandLifecycleState.executing;
      case 'completed':
        return CommandLifecycleState.completed;
      case 'rejected':
        return CommandLifecycleState.rejected;
      case 'failed':
        return CommandLifecycleState.failed;
      case 'expired':
        return CommandLifecycleState.expired;
      case 'cancelled':
        return CommandLifecycleState.cancelled;
      case 'submitting':
      default:
        return CommandLifecycleState.submitting;
    }
  }

  String get label {
    switch (this) {
      case CommandLifecycleState.submitting:
        return 'Sending…';
      case CommandLifecycleState.pending:
        return 'Queued';
      case CommandLifecycleState.dispatched:
        return 'Sent to robot';
      case CommandLifecycleState.accepted:
        return 'Robot accepted';
      case CommandLifecycleState.executing:
        return 'In progress';
      case CommandLifecycleState.completed:
        return 'Done';
      case CommandLifecycleState.rejected:
        return 'Robot rejected';
      case CommandLifecycleState.failed:
        return 'Failed';
      case CommandLifecycleState.expired:
        return 'Expired, not executed';
      case CommandLifecycleState.cancelled:
        return 'Cancelled';
    }
  }

  bool get isTerminal {
    return this == CommandLifecycleState.completed ||
        this == CommandLifecycleState.rejected ||
        this == CommandLifecycleState.failed ||
        this == CommandLifecycleState.expired ||
        this == CommandLifecycleState.cancelled;
  }

  bool get indicatesPhysicalAction => this == CommandLifecycleState.executing;
}

class CommandModel extends Equatable {
  final String id;
  final String robotId;
  final CommandType type;
  final String idempotencyKey;
  final CommandLifecycleState state;
  final String? rejectionReason;
  final DateTime createdAt;
  final Map<String, dynamic>? parameters;

  const CommandModel({
    required this.id,
    required this.robotId,
    required this.type,
    required this.idempotencyKey,
    required this.state,
    this.rejectionReason,
    required this.createdAt,
    this.parameters,
  });

  CommandModel copyWith({
    String? id,
    String? robotId,
    CommandType? type,
    String? idempotencyKey,
    CommandLifecycleState? state,
    String? rejectionReason,
    DateTime? createdAt,
    Map<String, dynamic>? parameters,
  }) {
    return CommandModel(
      id: id ?? this.id,
      robotId: robotId ?? this.robotId,
      type: type ?? this.type,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      state: state ?? this.state,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      parameters: parameters ?? this.parameters,
    );
  }

  @override
  List<Object?> get props => [
        id,
        robotId,
        type,
        idempotencyKey,
        state,
        rejectionReason,
        createdAt,
        parameters,
      ];
}

