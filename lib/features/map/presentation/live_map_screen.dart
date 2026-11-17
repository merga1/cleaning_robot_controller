import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../../core/widgets/stale_badge.dart';
import '../../../mock/mock_catalog.dart';
import '../../../mock/mock_telemetry.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/map_model.dart';

/// Map reference and geometry for the active robot (MOB-MAP-001..006).
///
/// The frontend-only demo reads the central catalogue. No network request is
/// attempted when a live endpoint is configured in this build.
final mapDataProvider = FutureProvider<MapDataModel>((ref) async {
  final activeRobotId =
      ref.watch(robotsControllerProvider).activeRobot?.id ??
      MockCatalog.alphaRobotId;
  if (ref.read(appConfigProvider).enableMockMode) {
    return MockCatalog.mapFor(activeRobotId);
  }
  throw StateError(
    'Live data endpoint is not available in this frontend-only demo build.',
  );
});

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  StreamSubscription<WebSocketMessage>? _messageSub;
  Timer? _staleTimer;

  RobotPose? _livePose;
  String? _poseRobotId;
  int _lastSequence = 0;
  DateTime _lastPoseTimestamp =
      DateTime.fromMillisecondsSinceEpoch(0).toUtc();

  @override
  void initState() {
    super.initState();
    if (ref.read(appConfigProvider).enableMockMode) {
      _messageSub = ref
          .read(mockTelemetryProvider)
          .messageStream
          .listen(_onPositionMessage);
    }
    // Keep the stale badge truthful even when no new packets arrive.
    _staleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _staleTimer?.cancel();
    super.dispose();
  }

  void _onPositionMessage(WebSocketMessage message) {
    if (!mounted || !ref.read(appConfigProvider).enableMockMode) return;
    if (message.type != 'position') return;

    final activeRobotId =
        ref.read(robotsControllerProvider).activeRobot?.id ??
        MockCatalog.alphaRobotId;
    if (message.robotId != activeRobotId) return;

    // MOB-RT-006: an older or duplicate packet must never move the pose back.
    if (message.sequence > 0 && message.sequence <= _lastSequence) return;
    if (message.timestamp.isBefore(_lastPoseTimestamp)) return;

    final x = (message.payload['x'] as num?)?.toDouble();
    final y = (message.payload['y'] as num?)?.toDouble();
    final heading = (message.payload['heading'] as num?)?.toDouble();
    if (x == null || y == null || heading == null) return;
    if (!x.isFinite || !y.isFinite || !heading.isFinite) return;

    if (message.sequence > 0) _lastSequence = message.sequence;
    _lastPoseTimestamp = message.timestamp.toUtc();
    _poseRobotId = message.robotId;

    setState(() {
      _livePose = RobotPose(
        x: x,
        y: y,
        heading: heading,
        timestamp: message.timestamp.toUtc(),
        isStale: false,
      );
    });
  }

  void _reloadMap() {
    setState(() {
      _livePose = null;
      _poseRobotId = null;
      _lastSequence = 0;
      _lastPoseTimestamp =
          DateTime.fromMillisecondsSinceEpoch(0).toUtc();
    });
    // MOB-MAP-006: reload the mock reference only - no network involved.
    ref.invalidate(mapDataProvider);
  }

  bool _isPoseStale(RobotPose? pose, Duration threshold) {
    if (pose == null) return true;
    if (pose.isStale) return true;
    return DateTime.now().toUtc().difference(pose.timestamp.toUtc()) >
        threshold;
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final activeRobot = ref.watch(robotsControllerProvider).activeRobot;
    final activeRobotId = activeRobot?.id ?? MockCatalog.alphaRobotId;
    final mapAsync = ref.watch(mapDataProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cachedMap = mapAsync.value;
    final badgePose = (_livePose != null && _poseRobotId == activeRobotId)
        ? _livePose!
        : cachedMap?.currentPose;
    final isBadgeStale = _isPoseStale(badgePose, config.staleDataThreshold);

    return Scaffold(
      appBar: AppBar(
        title: Text('${activeRobot?.name ?? "CleanBot"} Live Map'),
        actions: [
          if (isBadgeStale) ...[
            const Center(child: StaleBadge(label: 'Stale Pose')),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload mock map reference',
            onPressed: _reloadMap,
          ),
        ],
      ),
      body: mapAsync.when(
        loading: () => ScreenStateBuilder(
          isLoading: true,
          isDemo: config.enableMockMode,
          builder: (_) => const SizedBox.shrink(),
        ),
        error: (error, _) => ScreenStateBuilder(
          errorMessage: error.toString(),
          isDemo: config.enableMockMode,
          onRetry: _reloadMap,
          builder: (_) => const SizedBox.shrink(),
        ),
        data: (baseMap) {
          final map = (_livePose != null && _poseRobotId == activeRobotId)
              ? baseMap.copyWithPose(_livePose!)
              : baseMap;
          final isPoseStale =
              _isPoseStale(map.currentPose, config.staleDataThreshold);
          return ScreenStateBuilder(
            isDemo: config.enableMockMode,
            isStale: isPoseStale,
            isSimulated: map.isSimulated,
            onRetry: _reloadMap,
            builder: (_) => _mapBody(map, isPoseStale, isDark),
          );
        },
      ),
    );
  }

  Widget _mapBody(
    MapDataModel map,
    bool isPoseStale,
    bool isDark,
  ) {
    final extent = _mapExtent(map);
    return Stack(
      children: [
        // Interactive pan and zoom floorplan canvas (MOB-MAP-004).
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          boundaryMargin: const EdgeInsets.all(80),
          child: Center(
            child: Container(
              width: extent,
              height: extent,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryNavy.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _FloorplanPainter(
                    map: map,
                    isStale: isPoseStale,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Mock map reference and its local reload affordance (MOB-MAP-006).
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Card(
            color: (isDark ? AppColors.darkSurface : AppColors.white)
                .withValues(alpha: 0.96),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: isDark ? AppColors.white : AppColors.primaryNavy,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Map: ${map.mapId}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.white
                                : AppColors.primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reference: ${map.mapImageUrl}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white70
                                : AppColors.secondaryText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Loaded ${formatRelative(map.loadedAt)} · '
                          '${formatDateTime(map.loadedAt)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white60
                                : AppColors.mutedBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reload mock map reference',
                    onPressed: _reloadMap,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Map Legend Overlay
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkSurface : AppColors.white)
                  .withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNavy.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 12,
                runSpacing: 6,
                children: [
                  _legendItem(AppColors.techOrange, 'Robot Pose', isDark),
                  _legendItem(AppColors.severityCritical, 'Obstacle', isDark),
                  _legendItem(AppColors.primaryNavy, 'Dock Station', isDark),
                  _legendItem(
                    isDark ? AppColors.white : AppColors.primaryNavy,
                    'Zone Boundary',
                    isDark,
                  ),
                  _legendItem(AppColors.accentBlue, 'Planned Path', isDark),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.white : AppColors.primaryNavy,
          ),
        ),
      ],
    );
  }
}

/// Derives the square canvas extent from the model so every drawn feature fits.
double _mapExtent(MapDataModel map) {
  var extent = 200.0;

  void include(double x, double y) {
    if (!x.isFinite || !y.isFinite) return;
    extent = math.max(extent, math.max(x, y));
  }

  for (final zone in map.zones) {
    for (final point in zone.points) {
      include(point.dx, point.dy);
    }
  }
  for (final point in map.plannedPath) {
    if (point.length >= 2) include(point[0], point[1]);
  }
  include(map.dockLocation.dx, map.dockLocation.dy);
  for (final obstacle in map.obstacles) {
    include(obstacle.position.dx, obstacle.position.dy);
  }
  include(map.currentPose.x, map.currentPose.y);
  return extent + 40;
}

class _FloorplanPainter extends CustomPainter {
  final MapDataModel map;
  final bool isStale;
  final bool isDark;

  _FloorplanPainter({
    required this.map,
    required this.isStale,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark
          ? AppColors.darkBorder.withValues(alpha: 0.5)
          : AppColors.softBlue
      ..strokeWidth = 1.0;

    // Background grid.
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Outer wall.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
        const Radius.circular(10),
      ),
      Paint()
        ..color = isDark ? Colors.white70 : AppColors.primaryNavy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );

    // Zone polygons from the loaded map model (MOB-MAP-001).
    final zoneFill = Paint()
      ..color = AppColors.primaryNavy.withValues(alpha: isDark ? 0.25 : 0.05)
      ..style = PaintingStyle.fill;
    final selectedZoneFill = Paint()
      ..color = AppColors.accentBlue.withValues(alpha: isDark ? 0.35 : 0.12)
      ..style = PaintingStyle.fill;
    final zoneBorder = Paint()
      ..color = AppColors.primaryNavy.withValues(alpha: isDark ? 0.6 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final selectedZoneBorder = Paint()
      ..color = AppColors.accentBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (final zone in map.zones) {
      if (zone.points.isEmpty) continue;
      final path = Path()..moveTo(zone.points.first.dx, zone.points.first.dy);
      for (final point in zone.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, zone.isSelected ? selectedZoneFill : zoneFill);
      canvas.drawPath(path, zone.isSelected ? selectedZoneBorder : zoneBorder);
    }

    // Planned route (MOB-MAP-003).
    if (map.plannedPath.isNotEmpty) {
      final first = map.plannedPath.first;
      if (first.length >= 2) {
        final route = Path()..moveTo(first[0], first[1]);
        for (final point in map.plannedPath.skip(1)) {
          if (point.length >= 2) route.lineTo(point[0], point[1]);
        }
        canvas.drawPath(
          route,
          Paint()
            ..color = AppColors.accentBlue.withValues(alpha: 0.55)
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // Dock location (MOB-MAP-003).
    final dock = map.dockLocation;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCircle(center: Offset(dock.dx, dock.dy), radius: 13),
        const Radius.circular(6),
      ),
      Paint()..color = AppColors.primaryNavy,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCircle(center: Offset(dock.dx, dock.dy), radius: 10),
        const Radius.circular(4),
      ),
      Paint()
        ..color = AppColors.techOrange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Obstacles (MOB-MAP-003).
    final obstaclePaint = Paint()..color = AppColors.severityCritical;
    for (final obstacle in map.obstacles) {
      canvas.drawCircle(
        Offset(obstacle.position.dx, obstacle.position.dy),
        8,
        obstaclePaint,
      );
    }

    // Robot pose and heading (MOB-MAP-002, MOB-MAP-005).
    final pose = map.currentPose;
    canvas.drawCircle(
      Offset(pose.x, pose.y),
      14,
      Paint()..color = isStale ? AppColors.secondaryText : AppColors.techOrange,
    );
    canvas.drawCircle(
      Offset(pose.x, pose.y),
      16,
      Paint()
        ..color = AppColors.primaryNavy.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    const arrowLength = 22.0;
    canvas.drawLine(
      Offset(pose.x, pose.y),
      Offset(
        pose.x + arrowLength * math.cos(pose.heading),
        pose.y + arrowLength * math.sin(pose.heading),
      ),
      Paint()
        ..color = AppColors.white
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _FloorplanPainter oldDelegate) {
    return oldDelegate.map != map ||
        oldDelegate.isStale != isStale ||
        oldDelegate.isDark != isDark;
  }
}
