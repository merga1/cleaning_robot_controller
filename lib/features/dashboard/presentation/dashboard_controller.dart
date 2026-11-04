import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_client.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/dashboard_summary_model.dart';

class DashboardState {
  final bool isLoading;
  final DashboardSummaryModel? summary;
  final bool isStale;
  final String? errorMessage;
  final WebSocketConnectionState connectionState;

  const DashboardState({
    this.isLoading = false,
    this.summary,
    this.isStale = false,
    this.errorMessage,
    this.connectionState = WebSocketConnectionState.disconnected,
  });

  DashboardState copyWith({
    bool? isLoading,
    DashboardSummaryModel? summary,
    bool? isStale,
    String? errorMessage,
    WebSocketConnectionState? connectionState,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      summary: summary ?? this.summary,
      isStale: isStale ?? this.isStale,
      errorMessage: errorMessage,
      connectionState: connectionState ?? this.connectionState,
    );
  }
}

class DashboardController extends Notifier<DashboardState> {
  StreamSubscription? _wsStateSub;
  StreamSubscription? _wsMessageSub;
  Timer? _staleCheckTimer;

  CleanBotWebSocketClient get _wsClient => ref.read(webSocketClientProvider);
  AppConfig get _config => ref.read(appConfigProvider);

  @override
  DashboardState build() {
    ref.onDispose(() {
      _wsStateSub?.cancel();
      _wsMessageSub?.cancel();
      _staleCheckTimer?.cancel();
    });

    Future.microtask(() => _init());
    return const DashboardState();
  }

  void _init() {
    loadDashboardData();
    _connectWebSocket();

    // MOB-RT-005: Periodic staleness monitor
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkStaleness();
    });
  }

  void _checkStaleness() {
    if (state.summary != null) {
      final isNowStale = state.summary!.isStale(_config.staleDataThreshold);
      if (isNowStale != state.isStale) {
        state = state.copyWith(isStale: isNowStale);
      }
    }
  }

  void _connectWebSocket() {
    _wsStateSub = _wsClient.stateStream.listen((connState) {
      state = state.copyWith(connectionState: connState);

      // MOB-RT-004: On reconnect, refresh state over REST before trusting live messages
      if (connState == WebSocketConnectionState.connected) {
        loadDashboardData();
      }
    });

    _wsMessageSub = _wsClient.messageStream.listen((msg) {
      final activeRobotId = ref.read(robotsControllerProvider).activeRobot?.id;
      if (activeRobotId != null && msg.robotId == activeRobotId) {
        _handleLiveUpdate(msg);
      }
    });

    _wsClient.connect();
  }

  void _handleLiveUpdate(WebSocketMessage msg) {
    final current = state.summary;
    if (current == null) return;

    if (msg.type == 'container_reading') {
      final fill =
          (msg.payload['fill_percentage'] as num?)?.toInt() ?? current.wasteFillPercentage;
      state = state.copyWith(
        summary: DashboardSummaryModel(
          robotId: current.robotId,
          activeJob: current.activeJob,
          wasteFillPercentage: fill,
          wasteSensorFault: msg.payload['sensor_fault'] as bool? ?? false,
          latestCleanliness: current.latestCleanliness,
          activeAlertCount: current.activeAlertCount,
          lastDataReceivedAt: msg.timestamp,
        ),
        isStale: false,
      );
    }
  }

  Future<void> loadDashboardData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      if (_config.enableMockMode) {
        await Future.delayed(const Duration(milliseconds: 350));
        final activeRobotId = ref.read(robotsControllerProvider).activeRobot?.id;
        state = state.copyWith(
          isLoading: false,
          summary: DashboardSummaryModel(
            robotId: activeRobotId ?? 'robot-alpha-01',
            activeJob: const ActiveJobSummary(
              jobId: 'job-9842',
              zoneName: 'Lobby & Main Hall',
              progressPercentage: 68.5,
              elapsedTime: Duration(minutes: 24, seconds: 12),
              coverageAreaM2: 145.8,
            ),
            wasteFillPercentage: 54,
            wasteSensorFault: false,
            latestCleanliness: CleanlinessSummary(
              score: 91.5,
              confidence: 0.94,
              timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
              isSimulated: false,
              zoneName: 'Lobby & Main Hall',
            ),
            activeAlertCount: 1,
            lastDataReceivedAt: DateTime.now(),
          ),
          isStale: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(DashboardController.new);
