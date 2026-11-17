import 'package:cleanbot_app/core/config/app_config.dart';
import 'package:cleanbot_app/features/controls/data/controls_repository_impl.dart';
import 'package:cleanbot_app/features/controls/domain/command_model.dart';
import 'package:cleanbot_app/mock/mock_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

ControlsRepositoryImpl createRepository() => ControlsRepositoryImpl(
      dio: Dio(),
      config: AppConfig.dev(mock: true),
    );

void main() {
  test('mock submission is pending until the robot acknowledges', () async {
    final repository = createRepository();
    final command = await repository.submitCommand(
      robotId: MockCatalog.alphaRobotId,
      type: CommandType.startCleaning,
      idempotencyKey: 'test-key-online',
      parameters: {'zones': ['z-lobby']},
    );

    expect(command.state, CommandLifecycleState.pending);
    expect(command.idempotencyKey, 'test-key-online');

    final immediate = await repository.getCommandStatus(command.id);
    expect(immediate.id, command.id);
    expect(immediate.state, CommandLifecycleState.pending);

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final later = await repository.getCommandStatus(command.id);
    expect(later.state, isNot(CommandLifecycleState.pending));
    expect(
      later.state,
      isIn({
        CommandLifecycleState.dispatched,
        CommandLifecycleState.accepted,
        CommandLifecycleState.executing,
        CommandLifecycleState.completed,
      }),
    );
  });

  test('offline and safety-fault robots reject with an understandable reason',
      () async {
    final repository = createRepository();

    final offline = await repository.submitCommand(
      robotId: MockCatalog.deltaRobotId,
      type: CommandType.call,
      idempotencyKey: 'test-key-offline',
    );
    expect(offline.state, CommandLifecycleState.rejected);
    expect(offline.rejectionReason, contains('offline'));

    final faulty = await repository.submitCommand(
      robotId: MockCatalog.deltaRobotId,
      type: CommandType.inspectFloor,
      idempotencyKey: 'test-key-fault',
    );
    expect(faulty.state, CommandLifecycleState.rejected);
    // Delta is both offline and safety-faulted; either explicit reason is
    // understandable to the operator and blocks the command.
    expect(faulty.rejectionReason, isNotNull);
    expect(faulty.rejectionReason, isNotEmpty);
  });

  test('a degraded robot command expires without claiming execution', () async {
    final repository = createRepository();
    final command = await repository.submitCommand(
      robotId: MockCatalog.gammaRobotId,
      type: CommandType.call,
      idempotencyKey: 'test-key-degraded',
    );

    await Future<void>.delayed(const Duration(milliseconds: 4200));
    final status = await repository.getCommandStatus(command.id);
    expect(status.state, CommandLifecycleState.expired);
    expect(status.rejectionReason, contains('No acknowledgement'));
  });
}
