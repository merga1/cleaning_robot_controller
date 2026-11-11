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

    return Scaffold(
      appBar: AppBar(
        title: Text('${activeRobot?.name ?? "Robot"} Map'),
        actions: [
          if (_isStale) ...[
            const Center(child: StaleBadge(label: 'Stale Pose')),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _FloorplanPainter(
                    robotX: _robotX,
                    robotY: _robotY,
                    robotHeading: _headingRadians,
                    isStale: _isStale,
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
            child: Card(
              color: Colors.white.withValues(alpha: 0.92),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.lightBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _legendItem(AppColors.primaryBlue, 'Robot Pose'),
                    _legendItem(AppColors.severityCritical, 'Obstacle'),
                    _legendItem(AppColors.statusReturning, 'Dock Station'),
                    _legendItem(
                        AppColors.statusCleaning.withValues(alpha: 0.3),
                        'Zone Boundary'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _FloorplanPainter extends CustomPainter {
  final double robotX;
  final double robotY;
  final double robotHeading;
  final bool isStale;

  _FloorplanPainter({
    required this.robotX,
    required this.robotY,
    required this.robotHeading,
    required this.isStale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
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
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 10, size.width - 20, size.height - 20),
        const Radius.circular(8),
      ),
      wallPaint,
    );

    // Zone boundaries (MOB-MAP-001)
    final zonePaint = Paint()
      ..color = AppColors.statusCleaning.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final zoneBorderPaint = Paint()
      ..color = AppColors.statusCleaning.withValues(alpha: 0.4)
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
    final dockPaint = Paint()..color = AppColors.statusReturning;
    canvas.drawRect(const Rect.fromLTWH(25, 30, 24, 24), dockPaint);

    // Planned Path (MOB-MAP-003)
    final pathPaint = Paint()
      ..color = AppColors.primaryBlue.withValues(alpha: 0.4)
      ..strokeWidth = 2.0
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
      ..color = isStale ? const Color(0xFF94A3B8) : AppColors.primaryBlue;

    canvas.drawCircle(Offset(robotX, robotY), 14, robotPaint);

    // Heading Arrow
    const arrowLength = 22.0;
    final headingX = robotX + arrowLength * math.cos(robotHeading);
    final headingY = robotY + arrowLength * math.sin(robotHeading);

    final arrowPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(robotX, robotY), Offset(headingX, headingY), arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _FloorplanPainter oldDelegate) {
    return oldDelegate.robotX != robotX ||
        oldDelegate.robotY != robotY ||
        oldDelegate.robotHeading != robotHeading ||
        oldDelegate.isStale != isStale;
  }
}
