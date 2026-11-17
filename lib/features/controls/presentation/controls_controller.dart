import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/idempotency_util.dart';
import '../../../mock/mock_catalog.dart';
import '../../../mock/mock_telemetry.dart';
import '../data/controls_repository_impl.dart';
import '../domain/command_model.dart';
import '../domain/controls_repository.dart';

final controlsRepositoryProvider = Provider<ControlsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final config = ref.watch(appConfigProvider);
  return ControlsRepositoryImpl(dio: dio, config: config);
});

class ControlsState {
  final bool isInFlight;
  final CommandType? activeCommandType;
  final CommandModel? lastCommand;
  final String? activeIdempotencyKey;
  final String? errorMessage;
  final bool isTimedOut;

  const ControlsState({
    this.isInFlight = false,
    this.activeCommandType,
    this.lastCommand,
    this.activeIdempotencyKey,
    this.errorMessage,
    this.isTimedOut = false,
  });

  ControlsState copyWith({
    bool? isInFlight,
    CommandType? activeCommandType,
    CommandModel? lastCommand,
    String? activeIdempotencyKey,
    String? errorMessage,
    bool? isTimedOut,
  }) {
    return ControlsState(
      isInFlight: isInFlight ?? this.isInFlight,
      activeCommandType: activeCommandType ?? this.activeCommandType,
      lastCommand: lastCommand ?? this.lastCommand,
      activeIdempotencyKey: activeIdempotencyKey ?? this.activeIdempotencyKey,
      errorMessage: errorMessage,
      isTimedOut: isTimedOut ?? this.isTimedOut,
    );
  }
}

class ControlsController extends Notifier<ControlsState> {
  Timer? _ackTimer;
  Timer? _pollTimer;
  StreamSubscription? _telemetrySub;
  bool _applyingRemoteState = false;

  @override
  ControlsState build() {
    ref.onDispose(() {
      _ackTimer?.cancel();
      _pollTimer?.cancel();
      _telemetrySub?.cancel();
    });

    if (_config.enableMockMode) {
      // MOB-CTRL-006 / SRS 4.3: command state changes arrive as live events.
      _telemetrySub = ref
          .read(mockTelemetryProvider)
          .messageStream
          .where((msg) => msg.type == 'command_state_change')
          .listen((msg) {
            final current = state.lastCommand;
            if (current == null ||
                msg.payload['command_id'] != current.id) {
              return;
            }
            _applyingRemoteState = true;
            updateCommandState(
              current.copyWith(
                state: CommandLifecycleState.fromString(
                  msg.payload['state'] as String?,
                ),
                rejectionReason: msg.payload['reason'] as String?,
              ),
            );
            _applyingRemoteState = false;
          });
    }
    return const ControlsState();
  }

  ControlsRepository get _repository => ref.read(controlsRepositoryProvider);
  AppConfig get _config => ref.read(appConfigProvider);

  Future<void> executeCommand({
    required String robotId,
    required CommandType type,
    Map<String, dynamic>? parameters,
    bool isRetry = false,
  }) async {
    // MOB-CTRL-010: in-flight prevention.
    if (state.isInFlight) return;

    // MOB-CTRL-005: the same user action reuses its idempotency key on retry.
    final idempotencyKey = (isRetry && state.activeIdempotencyKey != null)
        ? state.activeIdempotencyKey!
        : IdempotencyUtil.generateKey();

    // MOB-CTRL-006: "Sending…" is visible before the network call completes.
    final submitting = MockCatalog.seedCommand(
      robotId: robotId,
      type: type,
      idempotencyKey: idempotencyKey,
      state: CommandLifecycleState.submitting,
    );
    state = state.copyWith(
      isInFlight: true,
      activeCommandType: type,
      activeIdempotencyKey: idempotencyKey,
      lastCommand: submitting,
      errorMessage: null,
      isTimedOut: false,
    );

    _ackTimer?.cancel();
    _ackTimer = Timer(_config.commandAckTimeout, () {
      if (state.isInFlight) {
        state = state.copyWith(
          isInFlight: false,
          isTimedOut: true,
          errorMessage: 'No response from robot. Retry or check status.',
        );
      }
    });

    try {
      final result = await _repository.submitCommand(
        robotId: robotId,
        type: type,
        idempotencyKey: idempotencyKey,
        parameters: parameters,
      );

      _ackTimer?.cancel();
      state = state.copyWith(
        isInFlight: false,
        lastCommand: result,
        errorMessage: result.state == CommandLifecycleState.rejected
            ? (result.rejectionReason ?? 'The robot rejected this command.')
            : null,
      );
      _publishCommandState(result);

      if (!result.state.isTerminal) {
        _startCommandPolling(result.id);
      }
    } catch (e) {
      _ackTimer?.cancel();
      state = state.copyWith(
        isInFlight: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// MOB-CTRL-009: retry the same action with the same idempotency key.
  Future<void> retryLastCommand({required String robotId}) async {
    final type = state.activeCommandType;
    final command = state.lastCommand;
    if (type == null || command == null) return;
    await executeCommand(
      robotId: robotId,
      type: type,
      parameters: command.parameters,
      isRetry: true,
    );
  }

  /// MOB-CTRL-009: ask the backend for the latest state without resubmitting.
  Future<void> checkStatus() async {
    final command = state.lastCommand;
    if (command == null) return;
    try {
      final updated = await _repository.getCommandStatus(command.id);
      updateCommandState(updated);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void _startCommandPolling(String commandId) {
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      attempts++;
      if (attempts > 30) {
        timer.cancel();
        return;
      }
      try {
        final updated = await _repository.getCommandStatus(commandId);
        updateCommandState(updated);
        if (updated.state.isTerminal) timer.cancel();
      } catch (_) {
        // Keep polling until the retry budget is exhausted.
      }
    });
  }

  void updateCommandState(CommandModel updated) {
    _ackTimer?.cancel();
    if (updated.state.isTerminal) _pollTimer?.cancel();
    state = state.copyWith(
      isInFlight: false,
      lastCommand: updated,
      isTimedOut: false,
      errorMessage: (updated.state == CommandLifecycleState.rejected ||
              updated.state == CommandLifecycleState.failed ||
              updated.state == CommandLifecycleState.expired)
          ? (updated.rejectionReason ?? updated.state.label)
          : null,
    );
    _publishCommandState(updated);
  }

  void _publishCommandState(CommandModel command) {
    if (_applyingRemoteState || !_config.enableMockMode) return;
    ref.read(mockTelemetryProvider).emitCommandStateChange(
          commandId: command.id,
          state: command.state.name,
          reason: command.rejectionReason,
        );
  }

  void clearActiveCommand() {
    _ackTimer?.cancel();
    _pollTimer?.cancel();
    state = const ControlsState();
  }
}

final controlsControllerProvider =
    NotifierProvider<ControlsController, ControlsState>(ControlsController.new);
