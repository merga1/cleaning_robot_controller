import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/utils/idempotency_util.dart';
import '../../../mock/mock_catalog.dart';
import '../../../mock/mock_telemetry.dart';
import '../../notifications/domain/notification_model.dart';
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
  StreamSubscription? _stateSub;
  StreamSubscription? _messageSub;
  Timer? _staleCheckTimer;

  AppConfig get _config => ref.read(appConfigProvider);

  @override
  DashboardState build() {
    ref.onDispose(() {
      _stateSub?.cancel();
      _messageSub?.cancel();
      _staleCheckTimer?.cancel();
    });

    Future.microtask(_init);
    return const DashboardState();
  }

  void _init() {
    loadDashboardData();
    _connectLiveUpdates();
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkStaleness();
    });
  }

  void _connectLiveUpdates() {
    if (_config.enableMockMode) {
      final telemetry = ref.read(mockTelemetryProvider);
      final activeRobotId = ref.read(robotsControllerProvider).activeRobot?.id;
      if (activeRobotId != null) telemetry.setRobot(activeRobotId);
      _stateSub = telemetry.stateStream.listen((connState) {
        state = state.copyWith(connectionState: connState);
        // MOB-RT-004: refresh the REST-equivalent snapshot on reconnect.
        if (connState == WebSocketConnectionState.connected) {
          loadDashboardData();
        }
      });
      _messageSub = telemetry.messageStream.listen(_onLiveMessage);
      if (telemetry.currentState == WebSocketConnectionState.connected) {
        state = state.copyWith(connectionState: WebSocketConnectionState.connected);
      }
      return;
    }

    final client = ref.read(webSocketClientProvider);
    _stateSub = client.stateStream.listen((connState) {
      state = state.copyWith(connectionState: connState);
      if (connState == WebSocketConnectionState.connected) {
        loadDashboardData();
      }
    });
    _messageSub = client.messageStream.listen(_onLiveMessage);
    client.connect();
  }

  /// Called by the robot selector so mock telemetry follows the active robot.
  void setActiveRobot(String robotId) {
    if (_config.enableMockMode) {
      ref.read(mockTelemetryProvider).setRobot(robotId);
    }
    loadDashboardData();
  }

  void _onLiveMessage(WebSocketMessage msg) {
    final activeRobotId = ref.read(robotsControllerProvider).activeRobot?.id;
    if (activeRobotId != null && msg.robotId != activeRobotId) return;
    _handleLiveUpdate(msg);
  }

  void _checkStaleness() {
    final summary = state.summary;
    if (summary == null) return;
    final isNowStale = summary.isStale(_config.staleDataThreshold);
    if (isNowStale != state.isStale) {
      state = state.copyWith(isStale: isNowStale);
    }
  }

  void _handleLiveUpdate(WebSocketMessage msg) {
    if (msg.type == 'robot_state') {
      final active = ref.read(robotsControllerProvider).activeRobot;
      if (active == null) return;
      final reportedConnection = msg.payload['connection_state'] == null
          ? null
          : RobotConnectionState.fromString(
              msg.payload['connection_state'] as String?);
      final reportedStatus = msg.payload['status'] == null
          ? null
          : RobotOperationalStatus.fromString(msg.payload['status'] as String?);
      ref.read(robotsControllerProvider.notifier).updateActiveRobotFromLive(
            active.copyWith(
              batteryLevel: DataValidators.clampPercentage(
                    msg.payload['battery_level'],
                  )?.toInt() ??
                  active.batteryLevel,
              isCharging:
                  msg.payload['is_charging'] as bool? ?? active.isCharging,
              connectionState: reportedConnection ?? active.connectionState,
              status: reportedStatus ?? active.status,
              hasSafetyFault:
                  msg.payload['has_safety_fault'] as bool? ??
                  active.hasSafetyFault,
              lastUpdatedAt: msg.timestamp.toLocal(),
            ),
          );
      return;
    }

    // Position messages are consumed by the map screen via its own telemetry
    // subscription; they are ignored here rather than corrupting the summary.
    if (msg.type == 'position' ||
        msg.type == 'detection' ||
        msg.type == 'command_state_change') {
      return;
    }

    final current = state.summary;
    if (current == null) {
      if (msg.type == 'container_reading' || msg.type == 'job_progress') {
        loadDashboardData();
      }
      return;
    }

    DashboardSummaryModel? next;
    switch (msg.type) {
      case 'container_reading':
        final fill = DataValidators.clampPercentage(
          msg.payload['fill_percentage'],
        );
        if (fill == null) return;
        next = DashboardSummaryModel(
          robotId: current.robotId,
          activeJob: current.activeJob,
          wasteFillPercentage: fill.toInt(),
          wasteSensorFault: msg.payload['sensor_fault'] as bool? ?? false,
          latestCleanliness: current.latestCleanliness,
          activeAlertCount: current.activeAlertCount,
          activeAlerts: current.activeAlerts,
          lastDataReceivedAt: msg.timestamp.toLocal(),
        );
      case 'job_progress':
        final progress =
            DataValidators.clampPercentage(msg.payload['progress_percentage']);
        final activeJob = current.activeJob;
        if (progress == null || activeJob == null) return;
        next = DashboardSummaryModel(
          robotId: current.robotId,
          activeJob: ActiveJobSummary(
            jobId: msg.payload['job_id'] as String? ?? activeJob.jobId,
            zoneName: msg.payload['zone_name'] as String? ?? activeJob.zoneName,
            progressPercentage: progress,
            elapsedTime: Duration(
              seconds: (msg.payload['elapsed_seconds'] as num?)?.toInt() ??
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
          activeAlerts: current.activeAlerts,
          lastDataReceivedAt: msg.timestamp.toLocal(),
        );
      case 'cleanliness':
        final score =
            DataValidators.clampPercentage(msg.payload['score']);
        final confidence =
            DataValidators.clampConfidence(msg.payload['confidence']);
        if (score == null || confidence == null) return;
        next = DashboardSummaryModel(
          robotId: current.robotId,
          activeJob: current.activeJob,
          wasteFillPercentage: current.wasteFillPercentage,
          wasteSensorFault: current.wasteSensorFault,
          latestCleanliness: CleanlinessSummary(
            score: score,
            confidence: confidence,
            timestamp: (msg.payload['timestamp'] != null
                    ? DataValidators.parseUtcToLocal(msg.payload['timestamp'])
                    : null) ??
                msg.timestamp.toLocal(),
            isSimulated: msg.isSimulated,
            zoneName: msg.payload['zone_name'] as String? ?? 'Cleaning zone',
          ),
          activeAlertCount: current.activeAlertCount,
          activeAlerts: current.activeAlerts,
          lastDataReceivedAt: msg.timestamp.toLocal(),
        );
      case 'alert':
        final alert = AlertNotificationModel(
          id: msg.payload['alert_id'] as String? ?? 'live-alert',
          robotId: current.robotId,
          title: msg.payload['title'] as String? ?? 'New alert',
          message: msg.payload['title'] as String? ?? 'Robot alert received.',
          severity: AlertSeverity.values.firstWhere(
            (s) => s.name == msg.payload['severity'],
            orElse: () => AlertSeverity.info,
          ),
          timestamp: msg.timestamp.toLocal(),
          isSimulated: msg.isSimulated,
        );
        final alerts = [alert, ...current.activeAlerts];
        next = DashboardSummaryModel(
          robotId: current.robotId,
          activeJob: current.activeJob,
          wasteFillPercentage: current.wasteFillPercentage,
          wasteSensorFault: current.wasteSensorFault,
          latestCleanliness: current.latestCleanliness,
          activeAlertCount: alerts.length,
          activeAlerts: alerts,
          lastDataReceivedAt: msg.timestamp.toLocal(),
        );
    }
    if (next != null) {
      state = state.copyWith(summary: next, isStale: false);
    }
  }

  Future<void> loadDashboardData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final activeRobotId = ref.read(robotsControllerProvider).activeRobot?.id;

    try {
      if (_config.enableMockMode) {
        await Future.delayed(const Duration(milliseconds: 250));
        final summary = MockCatalog.dashboardFor(
          activeRobotId ?? MockCatalog.alphaRobotId,
        );
        state = state.copyWith(
          isLoading: false,
          summary: summary,
          isStale: summary.isStale(_config.staleDataThreshold),
        );
        return;
      }

      final dio = ref.read(dioProvider);
      final response = await dio.get<Map<String, dynamic>>(
        '/dashboard/summary',
        queryParameters: activeRobotId == null
            ? null
            : {'robot_id': activeRobotId},
      );
      final data = response.data ?? const <String, dynamic>{};
      final summary = _summaryFromJson(data);
      state = state.copyWith(
        isLoading: false,
        summary: summary,
        isStale: summary.isStale(_config.staleDataThreshold),
      );
    } catch (e) {
      String message = 'Could not load dashboard data.';
      if (e is DioException) {
        message = e.response?.data?['detail']?.toString() ??
            'Could not reach the backend at ${_config.apiBaseUrl}.';
      }
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  DashboardSummaryModel _summaryFromJson(Map<String, dynamic> json) {
    final jobJson = json['active_job'] as Map<String, dynamic>?;
    final cleanlinessJson =
        json['latest_cleanliness'] as Map<String, dynamic>?;
    final progress = jobJson == null
        ? null
        : DataValidators.clampPercentage(jobJson['progress_percentage']);
    final fill =
        DataValidators.clampPercentage(json['waste_fill_percentage']);
    final score = cleanlinessJson == null
        ? null
        : DataValidators.clampPercentage(cleanlinessJson['score']);
    final confidence = cleanlinessJson == null
        ? null
        : DataValidators.clampConfidence(cleanlinessJson['confidence']);

    final alerts = (json['active_alerts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(
          (a) => AlertNotificationModel(
            id: a['id'] as String? ?? '',
            robotId: a['robot_id'] as String? ?? '',
            title: a['title'] as String? ?? 'Alert',
            message: a['message'] as String? ?? '',
            severity: AlertSeverity.values.firstWhere(
              (s) => s.name == a['severity'],
              orElse: () => AlertSeverity.info,
            ),
            timestamp: DataValidators.parseUtcToLocal(a['timestamp']) ??
                DateTime.now(),
            isRead: a['is_read'] as bool? ?? false,
            isSimulated: a['is_simulated'] as bool? ?? false,
          ),
        )
        .toList()
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return DashboardSummaryModel(
      robotId: json['robot_id'] as String? ?? MockCatalog.alphaRobotId,
      activeJob: jobJson == null || progress == null
          ? null
          : ActiveJobSummary(
              jobId: jobJson['job_id'] as String? ?? '',
              zoneName: jobJson['zone_name'] as String? ?? 'Cleaning zone',
              progressPercentage: progress,
              elapsedTime: Duration(
                seconds: (jobJson['elapsed_seconds'] as num?)?.toInt() ?? 0,
              ),
              coverageAreaM2:
                  (jobJson['coverage_area_m2'] as num?)?.toDouble() ?? 0,
            ),
      wasteFillPercentage: fill?.toInt() ?? 0,
      wasteSensorFault: json['waste_sensor_fault'] as bool? ?? false,
      latestCleanliness: cleanlinessJson == null ||
              score == null ||
              confidence == null
          ? null
          : CleanlinessSummary(
              score: score,
              confidence: confidence,
              timestamp: DataValidators.parseUtcToLocal(
                    cleanlinessJson['timestamp'],
                  ) ??
                  DateTime.now(),
              isSimulated: cleanlinessJson['is_simulated'] as bool? ?? false,
              zoneName:
                  cleanlinessJson['zone_name'] as String? ?? 'Cleaning zone',
            ),
      activeAlertCount: alerts.length,
      activeAlerts: alerts,
      lastDataReceivedAt: DataValidators.parseUtcToLocal(
            json['last_data_received_at'],
          ) ??
          DateTime.now(),
    );
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);
