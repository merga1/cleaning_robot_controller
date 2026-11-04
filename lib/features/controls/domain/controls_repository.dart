import 'command_model.dart';

abstract class ControlsRepository {
  Future<CommandModel> submitCommand({
    required String robotId,
    required CommandType type,
    required String idempotencyKey,
    Map<String, dynamic>? parameters,
  });

  Future<CommandModel> getCommandStatus(String commandId);
}

