import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_client.dart';
import '../../robots/domain/robot_model.dart';
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
    // Robot telemetry messages keep the shared robot list in sync so every
    // screen (dashboard, map, controls) reflects the Pi hardware state.
    if (msg.type == 'robot_state') {
      final active = ref.read(robotsControllerProvider).activeRobot;
      if (active != null) {
        ref.read(robotsControllerProvider.notifier).updateActiveRobotFromLive(
              active.copyWith(
                batteryLevel:
                    (msg.payload['battery_level'] as num?)?.toInt() ??
                        active.batteryLevel,
                isCharging: msg.payload['is_charging'] as bool? ??
                    active.isCharging,
                connectionState: RobotConnectionState.fromString(
                  msg.payload['connection_state'] as String?,
                ),
                status: RobotOperationalStatus.fromString(
                  msg.payload['status'] as String?,
                ),
                lastUpdatedAt: msg.timestamp,
              ),
            );
      }
      return;
    }

    final current = state.summary;
    if (current == null) {
      // The first live packet can arrive before the REST snapshot.
      if (msg.type == 'container_reading' || msg.type == 'job_progress') {
        loadDashboardData();
      }
      return;
    }

    switch (msg.type) {
      case 'container_reading':
        final fill = (msg.payload['fill_percentage'] as num?)?.toInt() ??
            current.wasteFillPercentage;
        state = state.copyWith(
          summary: DashboardSummaryModel(
            robotId: current.robotId,
            activeJob: current.activeJob,
            wasteFillPercentage: fill,
            wasteSensorFault:
                msg.payload['sensor_fault'] as bool? ?? false,
            latestCleanliness: current.latestCleanliness,
            activeAlertCount: current.activeAlertCount,
            lastDataReceivedAt: msg.timestamp,
          ),
          isStale: false,
        );
        break;

      case 'job_progress':
        final progress =
            (msg.payload['progress_percentage'] as num?)?.toDouble();
        final activeJob = current.activeJob;
        if (progress != null && activeJob != null) {
          state = state.copyWith(
            summary: DashboardSummaryModel(
              robotId: current.robotId,
              activeJob: ActiveJobSummary(
                jobId: msg.payload['job_id'] as String? ?? activeJob.jobId,
                zoneName:
                    msg.payload['zone_name'] as String? ?? activeJob.zoneName,
                progressPercentage: progress,
                elapsedTime: Duration(
                  seconds:
                      (msg.payload['elapsed_seconds'] as num?)?.toInt() ??
                          activeJob.elapsedTime.inSeconds,
                ),
                coverageAreaM2:
                    (msg.payload['coverage_area_m2'] as num?)?.toDouble() ??
                        activeJob.coverageAreaM2,
              ),
              wasteFillPercentage: current.wasteFillPercentage,
              wasteSensorFault: current.wasteSensorFault,
              latestCleanliness: current.latestCleanliness,
              activeAlertCount: current.activeAlertCount,
              lastDataReceivedAt: msg.timestamp,
            ),
            isStale: false,
          );
        }
        break;

      case 'cleanliness':
        final score = (msg.payload['score'] as num?)?.toDouble();
        final confidence = (msg.payload['confidence'] as num?)?.toDouble();
        if (score != null && confidence != null) {
          state = state.copyWith(
            summary: DashboardSummaryModel(
              robotId: current.robotId,
              activeJob: current.activeJob,
              wasteFillPercentage: current.wasteFillPercentage,
              wasteSensorFault: current.wasteSensorFault,
              latestCleanliness: CleanlinessSummary(
                score: score,
                confidence: confidence,
                timestamp: msg.timestamp,
                isSimulated: msg.isSimulated,
                zoneName:
                    msg.payload['zone_name'] as String? ?? 'Cleaning zone',
              ),
              activeAlertCount: current.activeAlertCount,
              lastDataReceivedAt: msg.timestamp,
            ),
            isStale: false,
          );
        }
        break;

      case 'alert':
        state = state.copyWith(
          summary: DashboardSummaryModel(
            robotId: current.robotId,
            activeJob: current.activeJob,
            wasteFillPercentage: current.wasteFillPercentage,
            wasteSensorFault: current.wasteSensorFault,
            latestCleanliness: current.latestCleanliness,
            activeAlertCount:
                (msg.payload['active_alert_count'] as num?)?.toInt() ??
                    current.activeAlertCount,
            lastDataReceivedAt: msg.timestamp,
          ),
          isStale: false,
        );
        break;
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
        final activeRobotId =
            ref.read(robotsControllerProvider).activeRobot?.id;
        final dio = ref.read(dioProvider);
        final response = await dio.get<Map<String, dynamic>>(
          '/dashboard/summary',
          queryParameters: activeRobotId == null
              ? null
              : {'robot_id': activeRobotId},
        );
        final data = response.data ?? const <String, dynamic>{};
        state = state.copyWith(
          isLoading: false,
          summary: _summaryFromJson(data),
          isStale: false,
        );
      }
    } catch (e) {
      String message = e.toString();
      if (e is DioException) {
        message = e.response?.data?['detail']?.toString() ??
            'Could not reach the Raspberry Pi backend at ${_config.apiBaseUrl}.';
      }
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  DashboardSummaryModel _summaryFromJson(Map<String, dynamic> json) {
    final jobJson = json['active_job'] as Map<String, dynamic>?;
    final cleanlinessJson =
        json['latest_cleanliness'] as Map<String, dynamic>?;

    return DashboardSummaryModel(
      robotId: json['robot_id'] as String? ?? 'robot-alpha-01',
      activeJob: jobJson == null
          ? null
          : ActiveJobSummary(
              jobId: jobJson['job_id'] as String? ?? '',
              zoneName: jobJson['zone_name'] as String? ?? 'Cleaning zone',
              progressPercentage:
                  (jobJson['progress_percentage'] as num?)?.toDouble() ?? 0,
              elapsedTime: Duration(
                seconds: (jobJson['elapsed_seconds'] as num?)?.toInt() ?? 0,
              ),
              coverageAreaM2:
                  (jobJson['coverage_area_m2'] as num?)?.toDouble() ?? 0,
            ),
      wasteFillPercentage:
          (json['waste_fill_percentage'] as num?)?.toInt() ?? 0,
      wasteSensorFault: json['waste_sensor_fault'] as bool? ?? false,
      latestCleanliness: cleanlinessJson == null
          ? null
          : CleanlinessSummary(
              score:
                  (cleanlinessJson['score'] as num?)?.toDouble() ?? 0,
              confidence:
                  (cleanlinessJson['confidence'] as num?)?.toDouble() ?? 0,
              timestamp: DateTime.tryParse(
                    cleanlinessJson['timestamp'] as String? ?? '',
                  ) ??
                  DateTime.now(),
              isSimulated:
                  cleanlinessJson['is_simulated'] as bool? ?? false,
              zoneName:
                  cleanlinessJson['zone_name'] as String? ?? 'Cleaning zone',
            ),
      activeAlertCount: (json['active_alert_count'] as num?)?.toInt() ?? 0,
      lastDataReceivedAt: DateTime.tryParse(
            json['last_data_received_at'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(DashboardController.new);
