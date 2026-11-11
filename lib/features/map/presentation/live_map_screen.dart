import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stale_badge.dart';
import '../../robots/presentation/robots_controller.dart';

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  // Live simulated pose
  double _robotX = 140.0;
  double _robotY = 180.0;
  double _headingRadians = 0.78; // 45 degrees
  bool _isStale = false;

  @override
  Widget build(BuildContext context) {
    final activeRobot = ref.watch(robotsControllerProvider).activeRobot;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${activeRobot?.name ?? "CleanBot"} Live Map'),
        actions: [
          if (_isStale) ...[
            const Center(child: StaleBadge(label: 'Stale Pose')),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Simulate Pose Movement',
            onPressed: () {
              setState(() {
                _isStale = false;
                _robotX = 140.0 + math.Random().nextInt(40) - 20;
                _robotY = 180.0 + math.Random().nextInt(40) - 20;
                _headingRadians = math.Random().nextDouble() * 2 * math.pi;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Interactive pan and zoom floorplan canvas (MOB-MAP-004)
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(80),
            child: Center(
              child: Container(
                width: 360,
                height: 480,
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
                child: CustomPaint(
                  painter: _FloorplanPainter(
                    robotX: _robotX,
                    robotY: _robotY,
                    robotHeading: _headingRadians,
                    isStale: _isStale,
                    isDark: isDark,
                  ),
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
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _legendItem(AppColors.techOrange, 'Robot Pose', isDark),
                    _legendItem(AppColors.severityCritical, 'Obstacle', isDark),
                    _legendItem(AppColors.primaryNavy, 'Dock Station', isDark),
                    _legendItem(
                      isDark ? AppColors.white : AppColors.primaryNavy,
                      'Zone Boundary',
                      isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

class _FloorplanPainter extends CustomPainter {
  final double robotX;
  final double robotY;
  final double robotHeading;
  final bool isStale;
  final bool isDark;

  _FloorplanPainter({
    required this.robotX,
    required this.robotY,
    required this.robotHeading,
    required this.isStale,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark
          ? AppColors.darkBorder.withValues(alpha: 0.5)
          : const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    // Draw background grid
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Outer wall
    final wallPaint = Paint()
      ..color = isDark ? Colors.white70 : AppColors.primaryNavy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 12, size.width - 24, size.height - 24),
        const Radius.circular(10),
      ),
      wallPaint,
    );

    // Zone boundaries (MOB-MAP-001)
    final zonePaint = Paint()
      ..color = AppColors.primaryNavy.withValues(alpha: isDark ? 0.25 : 0.05)
      ..style = PaintingStyle.fill;
    final zoneBorderPaint = Paint()
      ..color = AppColors.primaryNavy.withValues(alpha: isDark ? 0.6 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final zone1 = Rect.fromLTWH(20, 20, 150, 200);
    final zone2 = Rect.fromLTWH(180, 20, 160, 200);
    final zone3 = Rect.fromLTWH(20, 240, 320, 210);

    canvas.drawRect(zone1, zonePaint);
    canvas.drawRect(zone1, zoneBorderPaint);
    canvas.drawRect(zone2, zonePaint);
    canvas.drawRect(zone2, zoneBorderPaint);
    canvas.drawRect(zone3, zonePaint);
    canvas.drawRect(zone3, zoneBorderPaint);

    // Dock Location (MOB-MAP-003)
    final dockPaint = Paint()..color = AppColors.primaryNavy;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(25, 30, 26, 26),
        const Radius.circular(6),
      ),
      dockPaint,
    );
    final dockAccentPaint = Paint()
      ..color = AppColors.techOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 32, 22, 22),
        const Radius.circular(4),
      ),
      dockAccentPaint,
    );

    // Planned Path (MOB-MAP-003)
    final pathPaint = Paint()
      ..color = AppColors.techOrange.withValues(alpha: 0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(40, 50)
      ..lineTo(80, 100)
      ..lineTo(robotX, robotY);
    canvas.drawPath(path, pathPaint);

    // Obstacle Marker (MOB-MAP-003)
    final obstaclePaint = Paint()..color = AppColors.severityCritical;
    canvas.drawCircle(const Offset(240, 120), 8, obstaclePaint);

    // Robot Heading & Position (MOB-MAP-002, MOB-MAP-005)
    final robotPaint = Paint()
      ..color = isStale ? AppColors.secondaryText : AppColors.techOrange;

    // Robot body circle
    canvas.drawCircle(Offset(robotX, robotY), 14, robotPaint);

    // Robot outer ring
    final ringPaint = Paint()
      ..color = AppColors.primaryNavy.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(robotX, robotY), 16, ringPaint);

    // Heading Arrow
    const arrowLength = 22.0;
    final headingX = robotX + arrowLength * math.cos(robotHeading);
    final headingY = robotY + arrowLength * math.sin(robotHeading);

    final arrowPaint = Paint()
      ..color = AppColors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(robotX, robotY),
      Offset(headingX, headingY),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FloorplanPainter oldDelegate) {
    return oldDelegate.robotX != robotX ||
        oldDelegate.robotY != robotY ||
        oldDelegate.robotHeading != robotHeading ||
        oldDelegate.isStale != isStale ||
        oldDelegate.isDark != isDark;
  }
}
