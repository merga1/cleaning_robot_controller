import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/failures.dart';
import '../domain/command_model.dart';
import '../domain/controls_repository.dart';

class ControlsRepositoryImpl implements ControlsRepository {
  final Dio _dio;
  final AppConfig _config;

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
      // Mock mode simulates network latency & backend submission state (MOB-CTRL-007)
      await Future.delayed(const Duration(milliseconds: 400));
      return CommandModel(
        id: 'cmd-mock-${DateTime.now().millisecondsSinceEpoch}',
        robotId: robotId,
        type: type,
        idempotencyKey: idempotencyKey,
        state: CommandLifecycleState.pending, // Shows "Queued"
        createdAt: DateTime.now(),
        parameters: parameters,
      );
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
      return CommandModel(
        id: data['command_id'] as String? ?? idempotencyKey,
        robotId: robotId,
        type: type,
        idempotencyKey: idempotencyKey,
        state: CommandLifecycleState.fromString(data['state'] as String?),
        createdAt: DateTime.now(),
        parameters: parameters,
      );
    } on DioException catch (e) {
      throw ServerFailure(
        message: e.response?.data?['detail'] ?? 'Failed to submit command.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  @override
  Future<CommandModel> getCommandStatus(String commandId) async {
    if (_config.enableMockMode) {
      return CommandModel(
        id: commandId,
        robotId: 'robot-alpha-01',
        type: CommandType.call,
        idempotencyKey: 'mock-key',
        state: CommandLifecycleState.completed,
        createdAt: DateTime.now(),
      );
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
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}

