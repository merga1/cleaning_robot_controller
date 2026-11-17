import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/websocket_client.dart';
import 'mock_catalog.dart';

/// Local replacement for the backend WebSocket in frontend-only demo mode.
///
/// It emits the same message types as the real socket (robot status, position,
/// job progress, detection, container reading, alert and command state change)
/// so the UI exercises the exact same code paths as a live deployment.
class MockTelemetryService {
  final StreamController<WebSocketMessage> _messageController =
      StreamController<WebSocketMessage>.broadcast();
  final StreamController<WebSocketConnectionState> _stateController =
      StreamController<WebSocketConnectionState>.broadcast();

  Timer? _tickTimer;
  Timer? _reconnectTimer;
  int _sequence = 0;
  int _tick = 0;
  String _robotId = MockCatalog.alphaRobotId;
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;

  Stream<WebSocketMessage> get messageStream => _messageController.stream;
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;
  WebSocketConnectionState get currentState => _state;
  String get robotId => _robotId;

  void setRobot(String robotId) {
    if (_robotId == robotId) return;
    _robotId = robotId;
    _tick = 0;
    // A snapshot follows immediately so screens do not wait for the next tick.
    emitSnapshot();
  }

  void start() {
    if (_tickTimer != null) return;
    _updateState(WebSocketConnectionState.connected);
    _tickTimer = Timer.periodic(const Duration(seconds: 2), (_) => _tickOnce());
  }

  /// Demonstrates MOB-RT-003/004/005 in the demo: connected -> disconnected ->
  /// reconnecting -> connected, with a REST-equivalent snapshot on reconnect.
  void simulateDisconnect({Duration duration = const Duration(seconds: 6)}) {
    _tickTimer?.cancel();
    _tickTimer = null;
    _updateState(WebSocketConnectionState.disconnected);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(duration, () {
      _updateState(WebSocketConnectionState.connecting);
      _reconnectTimer = Timer(const Duration(milliseconds: 600), () {
        emitSnapshot();
        start();
      });
    });
  }

  void emitSnapshot() {
    final robot = MockCatalog.robotFor(_robotId);
    final summary = MockCatalog.dashboardFor(_robotId);
    final pose = MockCatalog.mapFor(_robotId).currentPose;

    _emit('robot_state', {
      'battery_level': robot.batteryLevel,
      'is_charging': robot.isCharging,
      'connection_state': robot.connectionState.name,
      'status': robot.status.name,
      'has_safety_fault': robot.hasSafetyFault,
    }, isSimulated: robot.isSimulated);
    _emit('position', {
      'x': pose.x,
      'y': pose.y,
      'heading': pose.heading,
    }, isSimulated: robot.isSimulated);
    _emit('container_reading', {
      'fill_percentage': summary.wasteFillPercentage,
      'sensor_fault': summary.wasteSensorFault,
    }, isSimulated: robot.isSimulated);
    if (summary.activeJob != null) {
      _emit('job_progress', {
        'job_id': summary.activeJob!.jobId,
        'zone_name': summary.activeJob!.zoneName,
        'progress_percentage': summary.activeJob!.progressPercentage,
        'elapsed_seconds': summary.activeJob!.elapsedTime.inSeconds,
        'coverage_area_m2': summary.activeJob!.coverageAreaM2,
      }, isSimulated: robot.isSimulated);
    }
    if (summary.latestCleanliness != null) {
      final c = summary.latestCleanliness!;
      _emit('cleanliness', {
        'score': c.score,
        'confidence': c.confidence,
        'zone_name': c.zoneName,
        'timestamp': c.timestamp.toIso8601String(),
      }, isSimulated: c.isSimulated);
    }
    for (final alert in summary.activeAlerts) {
      _emit('alert', {
        'alert_id': alert.id,
        'title': alert.title,
        'severity': alert.severity.name,
        'active_alert_count': summary.activeAlertCount,
      }, isSimulated: alert.isSimulated);
    }
  }

  void emitCommandStateChange({
    required String commandId,
    required String state,
    String? reason,
  }) {
    _emit('command_state_change', {
      'command_id': commandId,
      'state': state,
      'reason': reason,
    });
  }

  void emitDetection() {
    final robot = MockCatalog.robotFor(_robotId);
    final detections = MockCatalog.detectionsFor(robotId: _robotId);
    if (detections.isEmpty) return;
    final detection = detections[_tick % detections.length];
    _emit('detection', {
      'detection_id': detection.id,
      'class': detection.detectionClass.name,
      'confidence': detection.confidence,
      'zone_name': detection.zoneName,
      'job_id': detection.jobId,
      'timestamp': detection.timestamp.toIso8601String(),
    }, isSimulated: robot.isSimulated);
  }

  void _tickOnce() {
    if (_state != WebSocketConnectionState.connected) return;
    _tick++;
    final robot = MockCatalog.robotFor(_robotId);
    final summary = MockCatalog.dashboardFor(_robotId);
    final pose = MockCatalog.mapFor(_robotId).currentPose;

    switch (_tick % 6) {
      case 0:
        final battery = robot.batteryLevel > 0 ? robot.batteryLevel - 1 : 100;
        _emit('robot_state', {
          'battery_level': battery,
          'is_charging': robot.isCharging,
          'connection_state': robot.connectionState.name,
          'status': robot.status.name,
          'has_safety_fault': robot.hasSafetyFault,
        }, isSimulated: robot.isSimulated);
      case 1:
        final t = _tick / 20;
        _emit('position', {
          'x': pose.x + (t * 12 % 90),
          'y': pose.y + (t * 7 % 60),
          'heading': (pose.heading + t / 10) % 6.283185,
        }, isSimulated: robot.isSimulated);
      case 2:
        _emit('container_reading', {
          'fill_percentage': summary.wasteFillPercentage,
          'sensor_fault': summary.wasteSensorFault,
        }, isSimulated: robot.isSimulated);
      case 3:
        if (summary.activeJob != null) {
          final progress = (summary.activeJob!.progressPercentage + 1)
              .clamp(0.0, 100.0)
              .toDouble();
          _emit('job_progress', {
            'job_id': summary.activeJob!.jobId,
            'zone_name': summary.activeJob!.zoneName,
            'progress_percentage': progress,
            'elapsed_seconds': summary.activeJob!.elapsedTime.inSeconds + _tick * 2,
            'coverage_area_m2': summary.activeJob!.coverageAreaM2,
          }, isSimulated: robot.isSimulated);
        }
      case 4:
        if (summary.latestCleanliness != null) {
          final c = summary.latestCleanliness!;
          _emit('cleanliness', {
            'score': c.score,
            'confidence': c.confidence,
            'zone_name': c.zoneName,
            'timestamp': c.timestamp.toIso8601String(),
          }, isSimulated: c.isSimulated);
        }
      case 5:
        emitDetection();
    }
  }

  void _emit(String type, Map<String, dynamic> payload, {bool isSimulated = false}) {
    if (!_messageController.isClosed) {
      _messageController.add(
        WebSocketMessage(
          robotId: _robotId,
          type: type,
          timestamp: MockCatalog.nowUtc,
          isSimulated: isSimulated,
          sequence: ++_sequence,
          payload: payload,
        ),
      );
    }
  }

  void _updateState(WebSocketConnectionState state) {
    if (_state == state) return;
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  void dispose() {
    _tickTimer?.cancel();
    _reconnectTimer?.cancel();
    _messageController.close();
    _stateController.close();
  }
}

final mockTelemetryProvider = Provider<MockTelemetryService>((ref) {
  final service = MockTelemetryService();
  ref.onDispose(service.dispose);
  service.start();
  return service;
});
