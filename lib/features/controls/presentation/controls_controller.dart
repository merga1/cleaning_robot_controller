import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/idempotency_util.dart';
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
      activeCommandType: activeCommandType,
      lastCommand: lastCommand ?? this.lastCommand,
      activeIdempotencyKey: activeIdempotencyKey ?? this.activeIdempotencyKey,
      errorMessage: errorMessage,
      isTimedOut: isTimedOut ?? this.isTimedOut,
    );
  }
}

class ControlsController extends Notifier<ControlsState> {
  Timer? _ackTimer;

  @override
  ControlsState build() {
    ref.onDispose(() => _ackTimer?.cancel());
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
    // MOB-CTRL-010: In-flight prevention
    if (state.isInFlight) return;

    // MOB-CTRL-005: Reuse idempotency key on retry, or create new one
    final idempotencyKey = (isRetry && state.activeIdempotencyKey != null)
        ? state.activeIdempotencyKey!
        : IdempotencyUtil.generateKey();

    state = state.copyWith(
      isInFlight: true,
      activeCommandType: type,
      activeIdempotencyKey: idempotencyKey,
      errorMessage: null,
      isTimedOut: false,
    );

    // MOB-CTRL-009: Command timeout monitor
    _ackTimer?.cancel();
    _ackTimer = Timer(_config.commandAckTimeout, () {
      if (state.isInFlight) {
        state = state.copyWith(
          isInFlight: false,
          isTimedOut: true,
          errorMessage: 'No response from robot. Please retry or check status.',
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

      // In mock mode, transition to executing after short interval to demo lifecycle
      if (_config.enableMockMode) {
        Timer(const Duration(milliseconds: 1500), () {
          updateCommandState(
            result.copyWith(state: CommandLifecycleState.executing),
          );
        });
      }

      state = state.copyWith(
        isInFlight: false,
        lastCommand: result,
      );
    } catch (e) {
      _ackTimer?.cancel();
      state = state.copyWith(
        isInFlight: false,
        errorMessage: e.toString(),
      );
    }
  }

  void updateCommandState(CommandModel updated) {
    _ackTimer?.cancel();
    state = state.copyWith(
      isInFlight: false,
      lastCommand: updated,
      isTimedOut: false,
    );
  }

  void clearActiveCommand() {
    _ackTimer?.cancel();
    state = const ControlsState();
  }
}

final controlsControllerProvider =
    NotifierProvider<ControlsController, ControlsState>(ControlsController.new);
