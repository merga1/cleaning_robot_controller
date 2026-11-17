import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/failures.dart';
import '../../../mock/mock_catalog.dart';
import '../../robots/domain/robot_model.dart';
import '../domain/command_model.dart';
import '../domain/controls_repository.dart';

class ControlsRepositoryImpl implements ControlsRepository {
  final Dio _dio;
  final AppConfig _config;

  /// In-memory command registry for the frontend-only demo. Keyed by command
  /// id so "check status" and the lifecycle display stay consistent.
  static final Map<String, CommandModel> _mockCommands = {};

  ControlsRepositoryImpl({
    required Dio dio,
    required AppConfig config,
  })  : _dio = dio,
        _config = config;

  @override
  Future<CommandModel> submitCommand({
    required String robotId,
    required CommandType type,
    required String idempotencyKey,
    Map<String, dynamic>? parameters,
  }) async {
    if (_config.enableMockMode) {
      // Simulated submission latency keeps the "submitting" state observable.
      await Future.delayed(const Duration(milliseconds: 350));
      final robot = MockCatalog.robotFor(robotId);
      final CommandLifecycleState state;
      String? reason;
      if (robot.connectionState == RobotConnectionState.offline) {
        state = CommandLifecycleState.rejected;
        reason = 'The robot is offline and cannot accept commands.';
      } else if (robot.hasSafetyFault || robot.status == RobotOperationalStatus.fault) {
        state = CommandLifecycleState.rejected;
        reason = 'A safety fault is active. Commands are blocked until it is cleared.';
      } else {
        state = CommandLifecycleState.pending;
      }

      final command = MockCatalog.seedCommand(
        robotId: robotId,
        type: type,
        idempotencyKey: idempotencyKey,
        state: state,
        reason: reason,
      );
      _mockCommands[command.id] = command;
      return command;
    }

    try {
      final response = await _dio.post(
        '/robots/$robotId/commands',
        data: {
          'command': type.name,
          'idempotency_key': idempotencyKey,
          'parameters': parameters ?? {},
        },
      );

      final data = response.data as Map<String, dynamic>;
      // MOB-CTRL-007: an HTTP success is only "submitted"; physical effects
      // are never inferred from the response code.
      final command = CommandModel(
        id: data['command_id'] as String? ?? idempotencyKey,
        robotId: robotId,
        type: type,
        idempotencyKey: idempotencyKey,
        state: CommandLifecycleState.pending,
        createdAt: DateTime.now().toUtc(),
        parameters: parameters,
      );
      _mockCommands[command.id] = command;
      return command;
    } on DioException catch (e) {
      final data = e.response?.data;
      throw ServerFailure(
        message: data is Map
            ? (data['reason'] ?? data['detail'] ?? 'Failed to submit command.')
                .toString()
            : 'Failed to submit command.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<CommandModel> getCommandStatus(String commandId) async {
    if (_config.enableMockMode) {
      final stored = _mockCommands[commandId];
      if (stored == null) {
        return MockCatalog.seedCommand(
          robotId: MockCatalog.alphaRobotId,
          type: CommandType.requestStatusRefresh,
          idempotencyKey: commandId,
          state: CommandLifecycleState.expired,
          reason: 'Command not found in this demo session.',
        );
      }
      if (stored.state.isTerminal) return stored;

      final elapsed = MockCatalog.nowUtc.difference(stored.createdAt);
      final robot = MockCatalog.robotFor(stored.robotId);
      final isDegraded =
          robot.connectionState == RobotConnectionState.degraded;

      final state = _mockStateFor(elapsed, isDegraded);
      final updated = stored.copyWith(
        state: state,
        rejectionReason: state == CommandLifecycleState.expired
            ? 'No acknowledgement was received in time.'
            : null,
      );
      _mockCommands[commandId] = updated;
      return updated;
    }

    final response = await _dio.get('/commands/$commandId');
    final data = response.data as Map<String, dynamic>;
    return CommandModel(
      id: data['id'] as String,
      robotId: data['robot_id'] as String,
      type: CommandType.values.firstWhere(
        (t) => t.name == data['command_type'],
        orElse: () => CommandType.call,
      ),
      idempotencyKey: data['idempotency_key'] as String,
      state: CommandLifecycleState.fromString(data['state'] as String?),
      rejectionReason: data['rejection_reason'] as String?,
      createdAt: DateTime.parse(data['created_at'] as String).toUtc(),
    );
  }

  CommandLifecycleState _mockStateFor(Duration elapsed, bool isDegraded) {
    if (isDegraded && elapsed >= const Duration(seconds: 4)) {
      return CommandLifecycleState.expired;
    }
    if (elapsed < const Duration(milliseconds: 600)) {
      return CommandLifecycleState.pending;
    }
    if (elapsed < const Duration(milliseconds: 1200)) {
      return CommandLifecycleState.dispatched;
    }
    if (elapsed < const Duration(milliseconds: 2000)) {
      return CommandLifecycleState.accepted;
    }
    if (elapsed < const Duration(milliseconds: 3500)) {
      return CommandLifecycleState.executing;
    }
    return CommandLifecycleState.completed;
  }
}
