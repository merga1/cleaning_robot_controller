import '../features/auth/domain/user_model.dart';
import '../features/controls/domain/command_model.dart';
import '../features/dashboard/domain/dashboard_summary_model.dart';
import '../features/detections/domain/detection_model.dart';
import '../features/history/domain/job_history_model.dart';
import '../features/inspection/domain/assessment_model.dart';
import '../features/maintenance/domain/maintenance_model.dart';
import '../features/map/domain/map_model.dart';
import '../features/notifications/domain/notification_model.dart';
import '../features/progress/domain/job_progress_model.dart';
import '../features/reports/domain/report_model.dart';
import '../features/robots/domain/robot_model.dart';
import '../features/waste/domain/waste_model.dart';
import '../features/zones/domain/zone_model.dart';

/// A demo account the mock login accepts. Passwords live only here, in the
/// development mock layer - never in a widget or in production config.
class DemoAccount {
  final User user;
  final String password;

  const DemoAccount(this.user, this.password);
}

/// Central fixture catalogue for the frontend-only demo.
///
/// Every screen reads from here when [AppConfig.enableMockMode] is true, so the
/// whole app is testable without a Raspberry Pi, a FastAPI server or a broker.
/// All timestamps are generated in UTC and formatted locally by the UI.
class MockCatalog {
  MockCatalog._();

  static const String alphaRobotId = 'robot-alpha-01';
  static const String simRobotId = 'robot-sim-02';
  static const String deltaRobotId = 'robot-delta-03';
  static const String gammaRobotId = 'robot-gamma-04';

  static DateTime get nowUtc => DateTime.now().toUtc();

  static DateTime minutesAgo(int minutes) =>
      nowUtc.subtract(Duration(minutes: minutes));

  // ---------------------------------------------------------------------------
  // Accounts & roles
  // ---------------------------------------------------------------------------

  static List<DemoAccount> get accounts => [
        DemoAccount(
          const User(
            id: 'user-admin',
            email: 'admin@cleanbot.io',
            fullName: 'Alem Administrator',
            role: UserRole.admin,
          ),
          'Admin#2026',
        ),
        DemoAccount(
          const User(
            id: 'user-operator',
            email: 'operator@cleanbot.io',
            fullName: 'Sara Operator',
            role: UserRole.operator,
          ),
          'CleanBot#2026',
        ),
        DemoAccount(
          const User(
            id: 'user-readonly',
            email: 'readonly@cleanbot.io',
            fullName: 'Read-Only Supervisor',
            role: UserRole.readOnly,
          ),
          'ReadOnly#2026',
        ),
      ];

  static DemoAccount? accountFor(String email) {
    final normalized = email.trim().toLowerCase();
    for (final account in accounts) {
      if (account.user.email.toLowerCase() == normalized) return account;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Robots (multi-robot by design - MOB-ROB-005)
  // ---------------------------------------------------------------------------

  static List<RobotModel> get robots => [
        RobotModel(
          id: alphaRobotId,
          name: 'CleanBot Pro — East Wing',
          batteryLevel: 88,
          isCharging: false,
          connectionState: RobotConnectionState.online,
          status: RobotOperationalStatus.cleaning,
          capabilities: const RobotCapabilities(),
          isSimulated: false,
          hasSafetyFault: false,
          lastUpdatedAt: minutesAgo(4),
          firmwareVersion: 'v2.4.1',
        ),
        RobotModel(
          id: simRobotId,
          name: 'CleanBot Simulator — Beta',
          batteryLevel: 65,
          isCharging: true,
          connectionState: RobotConnectionState.online,
          status: RobotOperationalStatus.idle,
          // A restricted capability set exercises MOB-CTRL-002 in the demo.
          capabilities: const RobotCapabilities(
            canCall: false,
            canCancel: false,
            canDock: false,
          ),
          isSimulated: true,
          hasSafetyFault: false,
          lastUpdatedAt: minutesAgo(8),
          firmwareVersion: 'v2.4.1-sim',
        ),
        RobotModel(
          id: deltaRobotId,
          name: 'CleanBot Yard Guard',
          batteryLevel: 14,
          isCharging: false,
          connectionState: RobotConnectionState.offline,
          status: RobotOperationalStatus.fault,
          capabilities: const RobotCapabilities(
            canClean: false,
            canPause: false,
            canResume: false,
            canInspect: false,
          ),
          isSimulated: false,
          hasSafetyFault: true,
          lastUpdatedAt: minutesAgo(45),
          firmwareVersion: 'v2.3.8',
        ),
        RobotModel(
          id: gammaRobotId,
          name: 'CleanBot Mini — Reception',
          batteryLevel: 41,
          isCharging: false,
          connectionState: RobotConnectionState.degraded,
          status: RobotOperationalStatus.paused,
          capabilities: const RobotCapabilities(canCall: false),
          isSimulated: false,
          hasSafetyFault: false,
          lastUpdatedAt: minutesAgo(3),
          firmwareVersion: 'v2.4.0',
        ),
      ];

  static RobotModel robotFor(String? robotId) => robots.firstWhere(
        (robot) => robot.id == robotId,
        orElse: () => robots.first,
      );

  // ---------------------------------------------------------------------------
  // Zones (MOB-ZONE-001..004)
  // ---------------------------------------------------------------------------

  static List<ZoneModel> zonesFor(String robotId) {
    if (robotId == simRobotId) {
      return [
        ZoneModel(
          id: 'z-sim-lab',
          name: 'Simulation Lab',
          areaM2: 42.0,
          lastCleanedAt: minutesAgo(70),
        ),
        ZoneModel(
          id: 'z-sim-corridor',
          name: 'Simulation Corridor',
          areaM2: 28.5,
          lastCleanedAt: minutesAgo(240),
        ),
      ];
    }
    if (robotId == deltaRobotId) {
      return [
        ZoneModel(
          id: 'z-yard',
          name: 'Outer Courtyard',
          areaM2: 210.0,
          lastCleanedAt: minutesAgo(2880),
          isAvailable: false,
          unavailabilityReason: 'Safety fault — robot offline',
        ),
      ];
    }
    if (robotId == gammaRobotId) {
      return [
        ZoneModel(
          id: 'z-reception',
          name: 'Reception Area',
          areaM2: 36.0,
          lastCleanedAt: minutesAgo(300),
        ),
      ];
    }
    return [
      ZoneModel(
        id: 'z-lobby',
        name: 'Lobby & Main Hall',
        areaM2: 120.5,
        lastCleanedAt: minutesAgo(240),
      ),
      ZoneModel(
        id: 'z-corridor-a',
        name: 'Corridor A',
        areaM2: 65.0,
        lastCleanedAt: minutesAgo(1080),
      ),
      ZoneModel(
        id: 'z-west-entry',
        name: 'West Wing Entry',
        areaM2: 48.5,
        lastCleanedAt: minutesAgo(2880),
      ),
      ZoneModel(
        id: 'z-conference',
        name: 'North Conference Hall',
        areaM2: 84.0,
        lastCleanedAt: minutesAgo(4320),
      ),
      ZoneModel(
        id: 'z-server-room',
        name: 'Server Room',
        areaM2: 30.0,
        isAvailable: false,
        unavailabilityReason: 'Restricted access — cleaning not permitted',
      ),
      ZoneModel(
        id: 'z-roof-terrace',
        name: 'Roof Terrace',
        areaM2: 96.0,
        isAvailable: false,
        unavailabilityReason: 'Not mapped on this robot',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Dashboard (MOB-DASH-001..009)
  // ---------------------------------------------------------------------------

  static DashboardSummaryModel dashboardFor(String robotId) {
    final robot = robotFor(robotId);
    final isFaulty = robot.connectionState == RobotConnectionState.offline;
    final activeAlerts = notificationsFor(robotId).where((n) => !n.isRead).toList()
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return DashboardSummaryModel(
      robotId: robotId,
      activeJob: isFaulty
          ? null
          : ActiveJobSummary(
              jobId: 'job-9842',
              zoneName: robotId == simRobotId
                  ? 'Simulation Lab'
                  : 'Lobby & Main Hall',
              progressPercentage: robotId == simRobotId ? 100.0 : 62.5,
              elapsedTime: Duration(minutes: robotId == simRobotId ? 35 : 18),
              coverageAreaM2: robotId == simRobotId ? 42.0 : 75.3,
            ),
      wasteFillPercentage: isFaulty ? 96 : (robotId == simRobotId ? 42 : 78),
      wasteSensorFault: isFaulty,
      latestCleanliness: isFaulty
          ? null
          : CleanlinessSummary(
              score: robotId == simRobotId ? 84.0 : 91.4,
              // Simulated robot deliberately has inconclusive confidence.
              confidence: robotId == simRobotId ? 0.45 : 0.86,
              timestamp: minutesAgo(robotId == simRobotId ? 50 : 120),
              isSimulated: robot.isSimulated,
              zoneName: robotId == simRobotId
                  ? 'Simulation Lab'
                  : 'Lobby & Main Hall',
            ),
      activeAlertCount: activeAlerts.length,
      activeAlerts: activeAlerts,
      lastDataReceivedAt: isFaulty
          ? minutesAgo(45)
          : robot.lastUpdatedAt.toUtc(),
    );
  }

  // ---------------------------------------------------------------------------
  // Live map (MOB-MAP-001..006)
  // ---------------------------------------------------------------------------

  static MapDataModel mapFor(String robotId) {
    final robot = robotFor(robotId);
    final zones = <MapZonePolygon>[];
    if (robotId == simRobotId) {
      zones.addAll([
        const MapZonePolygon(
          id: 'z-sim-lab',
          name: 'Simulation Lab',
          points: [
            OffsetPoint(70, 70),
            OffsetPoint(270, 70),
            OffsetPoint(270, 240),
            OffsetPoint(70, 240),
          ],
          isSelected: true,
        ),
        const MapZonePolygon(
          id: 'z-sim-corridor',
          name: 'Simulation Corridor',
          points: [
            OffsetPoint(290, 70),
            OffsetPoint(450, 70),
            OffsetPoint(450, 240),
            OffsetPoint(290, 240),
          ],
        ),
      ]);
    } else {
      zones.addAll([
        const MapZonePolygon(
          id: 'z-lobby',
          name: 'Lobby & Main Hall',
          points: [
            OffsetPoint(60, 60),
            OffsetPoint(300, 60),
            OffsetPoint(300, 250),
            OffsetPoint(60, 250),
          ],
          isSelected: true,
        ),
        const MapZonePolygon(
          id: 'z-corridor-a',
          name: 'Corridor A',
          points: [
            OffsetPoint(320, 60),
            OffsetPoint(460, 60),
            OffsetPoint(460, 250),
            OffsetPoint(320, 250),
          ],
        ),
        const MapZonePolygon(
          id: 'z-west-entry',
          name: 'West Wing Entry',
          points: [
            OffsetPoint(60, 270),
            OffsetPoint(240, 270),
            OffsetPoint(240, 430),
            OffsetPoint(60, 430),
          ],
        ),
        const MapZonePolygon(
          id: 'z-conference',
          name: 'North Conference Hall',
          points: [
            OffsetPoint(260, 270),
            OffsetPoint(460, 270),
            OffsetPoint(460, 430),
            OffsetPoint(260, 430),
          ],
        ),
      ]);
    }

    final poseTime = robot.lastUpdatedAt.toUtc();
    return MapDataModel(
      mapId: 'map-floor-1',
      // Frontend-only demo: no network fetch is performed for this reference.
      mapImageUrl: 'mock://maps/floor-1.svg',
      currentPose: RobotPose(
        x: robotId == simRobotId ? 180 : 140,
        y: robotId == simRobotId ? 160 : 130,
        heading: 0.6,
        timestamp: poseTime,
        isStale: DateTime.now().toUtc().difference(poseTime) >
            const Duration(seconds: 20),
      ),
      plannedPath: const [
        [140, 130],
        [190, 140],
        [240, 190],
        [285, 210],
        [330, 175],
        [390, 150],
      ],
      dockLocation: const OffsetPoint(60, 460),
      zones: zones,
      obstacles: const [
        ObstacleMarker(position: OffsetPoint(352, 310), label: 'Trolley'),
        ObstacleMarker(position: OffsetPoint(412, 118), label: 'Pillar'),
      ],
      isSimulated: robot.isSimulated,
      loadedAt: nowUtc,
    );
  }

  // ---------------------------------------------------------------------------
  // Cleaning progress (MOB-PROG-001..004)
  // ---------------------------------------------------------------------------

  static DetailedJobProgressModel jobProgressFor(String robotId) {
    final robot = robotFor(robotId);
    final isSim = robot.isSimulated;
    final isFaulty = robot.connectionState == RobotConnectionState.offline;

    return DetailedJobProgressModel(
      jobId: 'job-9842',
      robotId: robotId,
      robotName: robot.name,
      // Failed/faulted jobs are never presented as successful (MOB-PROG-004).
      status: isFaulty
          ? JobProgressStatus.faultInterrupted
          : (isSim ? JobProgressStatus.completed : JobProgressStatus.active),
      overallProgress: isFaulty ? 34.0 : (isSim ? 100.0 : 62.5),
      elapsedTime: Duration(minutes: isSim ? 35 : 18),
      totalCoverageM2: isSim ? 42.0 : 75.3,
      // No ETA is supplied by the mock backend (MOB-PROG-003).
      estimatedFinishTime: null,
      zones: [
        ZoneCleaningProgress(
          zoneId: isSim ? 'z-sim-lab' : 'z-lobby',
          zoneName: isSim ? 'Simulation Lab' : 'Lobby & Main Hall',
          progressPercentage: isFaulty ? 60 : (isSim ? 100 : 78),
          areaCleanedM2: isFaulty ? 72.3 : (isSim ? 42.0 : 94.0),
          totalAreaM2: isSim ? 42.0 : 120.5,
          isCompleted: isSim,
        ),
        ZoneCleaningProgress(
          zoneId: isSim ? 'z-sim-corridor' : 'z-corridor-a',
          zoneName: isSim ? 'Simulation Corridor' : 'Corridor A',
          progressPercentage: isFaulty ? 0 : (isSim ? 100 : 40),
          areaCleanedM2: isFaulty ? 0 : (isSim ? 28.5 : 26.0),
          totalAreaM2: isSim ? 28.5 : 65.0,
          isCompleted: isSim,
        ),
      ],
      timeline: [
        JobEventTimelineItem(
          id: 'evt-1',
          eventType: 'started',
          title: 'Job started',
          description: 'Operator Sara started the cleaning job.',
          timestamp: minutesAgo(18),
        ),
        JobEventTimelineItem(
          id: 'evt-2',
          eventType: 'obstacle',
          title: 'Obstacle detected',
          description: 'Trolley detected in Corridor A; path adjusted.',
          timestamp: minutesAgo(12),
        ),
        if (isFaulty)
          JobEventTimelineItem(
            id: 'evt-3',
            eventType: 'fault',
            title: 'Safety fault',
            description: 'Robot stopped by local safety controller.',
            timestamp: minutesAgo(45),
          )
        else if (!isSim)
          JobEventTimelineItem(
            id: 'evt-4',
            eventType: 'container_full',
            title: 'Container nearly full',
            description: 'Waste level reached 78%; monitoring continues.',
            timestamp: minutesAgo(6),
          )
        else
          JobEventTimelineItem(
            id: 'evt-5',
            eventType: 'completed',
            title: 'Job completed',
            description: 'All selected zones were cleaned.',
            timestamp: minutesAgo(1),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Detections (MOB-DET-001..004)
  // ---------------------------------------------------------------------------

  static List<GarbageDetectionModel> detectionsFor({String? robotId}) {
    final specs = <List<dynamic>>[
      ['z-lobby', 'Lobby & Main Hall', DetectionClass.wet, 0.92, 8, 'job-9842'],
      ['z-lobby', 'Lobby & Main Hall', DetectionClass.dry, 0.88, 14, 'job-9842'],
      ['z-corridor-a', 'Corridor A', DetectionClass.mixed, 0.54, 22, 'job-9842'],
      ['z-west-entry', 'West Wing Entry', DetectionClass.dry, 0.95, 61, 'job-9841'],
      ['z-lobby', 'Lobby & Main Hall', DetectionClass.unknown, 0.41, 96, 'job-9841'],
      ['z-conference', 'North Conference Hall', DetectionClass.dry, 0.91, 140, 'job-9840'],
      ['z-corridor-a', 'Corridor A', DetectionClass.wet, 0.83, 210, 'job-9840'],
      ['z-lobby', 'Lobby & Main Hall', DetectionClass.mixed, 0.76, 280, 'job-9839'],
      ['z-west-entry', 'West Wing Entry', DetectionClass.dry, 0.97, 340, 'job-9839'],
      ['z-conference', 'North Conference Hall', DetectionClass.wet, 0.68, 420, 'job-9838'],
      ['z-lobby', 'Lobby & Main Hall', DetectionClass.dry, 0.89, 1500, 'job-9837'],
      ['z-corridor-a', 'Corridor A', DetectionClass.unknown, 0.38, 1700, 'job-9837'],
      ['z-west-entry', 'West Wing Entry', DetectionClass.mixed, 0.72, 2600, 'job-9836'],
      ['z-conference', 'North Conference Hall', DetectionClass.dry, 0.94, 2900, 'job-9836'],
      ['z-lobby', 'Lobby & Main Hall', DetectionClass.wet, 0.86, 4300, 'job-9835'],
      ['z-corridor-a', 'Corridor A', DetectionClass.dry, 0.79, 4600, 'job-9835'],
      ['z-sim-lab', 'Simulation Lab', DetectionClass.mixed, 0.57, 30, 'job-sim-01'],
      ['z-sim-corridor', 'Simulation Corridor', DetectionClass.dry, 0.81, 90, 'job-sim-01'],
      ['z-yard', 'Outer Courtyard', DetectionClass.unknown, 0.33, 2880, 'job-9834'],
      ['z-lobby', 'Lobby & Main Hall', DetectionClass.wet, 0.90, 5900, 'job-9833'],
    ];

    return specs.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      final zoneId = s[0] as String;
      final isSimZone = zoneId.startsWith('z-sim');
      final ownerId =
          isSimZone ? simRobotId : (zoneId == 'z-yard' ? deltaRobotId : alphaRobotId);
      if (robotId != null && ownerId != robotId) return null;
      return GarbageDetectionModel(
        id: 'det-${(i + 1).toString().padLeft(3, '0')}',
        robotId: ownerId,
        zoneId: zoneId,
        zoneName: s[1] as String,
        jobId: s[5] as String,
        detectionClass: s[2] as DetectionClass,
        confidence: s[3] as double,
        timestamp: minutesAgo(s[4] as int),
        // Only some detections carry an image reference (MOB-DET-004).
        imageUrl: i % 3 == 0 ? 'mock://detections/det-${i + 1}.jpg' : null,
        isSimulated: isSimZone,
      );
    }).whereType<GarbageDetectionModel>().toList();
  }

  // ---------------------------------------------------------------------------
  // Floor inspections (MOB-INSP-001..004)
  // ---------------------------------------------------------------------------

  static List<FloorAssessmentModel> assessmentsFor({String? robotId}) {
    final specs = <List<dynamic>>[
      ['z-lobby', 'Lobby & Main Hall', 91.4, 0.86, 120, null],
      ['z-corridor-a', 'Corridor A', 74.2, 0.78, 190, null],
      ['z-west-entry', 'West Wing Entry', 42.0, 0.91, 300, null],
      ['z-conference', 'North Conference Hall', 88.6, 0.44, 420, null],
      ['z-lobby', 'Lobby & Main Hall', 95.1, 0.93, 1500, null],
      ['z-corridor-a', 'Corridor A', 68.3, 0.82, 2900, null],
      ['z-sim-lab', 'Simulation Lab', 84.0, 0.45, 50, null],
      ['z-yard', 'Outer Courtyard', 0.0, 0.0, 2880, 'LiDAR sensor fault'],
    ];
    return specs.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      final zoneId = s[0] as String;
      final ownerId = zoneId.startsWith('z-sim')
          ? simRobotId
          : (zoneId == 'z-yard' ? deltaRobotId : alphaRobotId);
      if (robotId != null && ownerId != robotId) return null;
      return FloorAssessmentModel(
        id: 'ass-${(i + 1).toString().padLeft(3, '0')}',
        robotId: ownerId,
        zoneId: zoneId,
        zoneName: s[1] as String,
        score: s[2] as double,
        confidence: s[3] as double,
        timestamp: minutesAgo(s[4] as int),
        isSimulated: ownerId == simRobotId,
        sensorFault: s[5] as String?,
      );
    }).whereType<FloorAssessmentModel>().toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // ---------------------------------------------------------------------------
  // Waste container (MOB-WASTE-001..004)
  // ---------------------------------------------------------------------------

  static WasteStatusModel wasteFor(String robotId) {
    final robot = robotFor(robotId);
    final isFaulty = robot.connectionState == RobotConnectionState.offline;
    final current = isFaulty ? 96.0 : (robot.isSimulated ? 42.0 : 78.0);
    final history = <WasteReadingPoint>[];
    for (var i = 11; i >= 0; i--) {
      final value = (current - (i * 4.3)).clamp(0.0, 100.0).toDouble();
      history.add(
        WasteReadingPoint(
          timestamp: minutesAgo(i * 30),
          fillPercentage: value,
        ),
      );
    }
    return WasteStatusModel(
      robotId: robotId,
      fillPercentage: isFaulty ? -1 : current,
      warningThreshold: 75,
      fullThreshold: 90,
      hasSensorFault: isFaulty,
      isSimulated: robot.isSimulated,
      timestamp: isFaulty ? minutesAgo(45) : minutesAgo(2),
      history: history,
    );
  }

  // ---------------------------------------------------------------------------
  // Notifications (MOB-NOTIF-001..007)
  // ---------------------------------------------------------------------------

  static List<AlertNotificationModel> notificationsFor(String robotId) {
    final all = <AlertNotificationModel>[
      AlertNotificationModel(
        id: 'notif-001',
        robotId: alphaRobotId,
        title: 'Waste container nearly full',
        message: 'Container is at 78%. Plan emptying before the next job.',
        severity: AlertSeverity.warning,
        timestamp: minutesAgo(6),
        targetRoute: '/waste',
      ),
      AlertNotificationModel(
        id: 'notif-002',
        robotId: deltaRobotId,
        title: 'Safety fault reported',
        message: 'Local safety controller stopped the robot. Commands blocked.',
        severity: AlertSeverity.critical,
        timestamp: minutesAgo(45),
        targetRoute: '/maintenance',
      ),
      AlertNotificationModel(
        id: 'notif-003',
        robotId: alphaRobotId,
        title: 'Zone cleaned',
        message: 'Lobby & Main Hall completed with 91.4 cleanliness score.',
        severity: AlertSeverity.info,
        timestamp: minutesAgo(120),
        isRead: true,
        targetRoute: '/history',
      ),
      AlertNotificationModel(
        id: 'notif-004',
        robotId: simRobotId,
        title: 'Simulated inspection inconclusive',
        message: 'Low confidence (0.45) — result marked inconclusive.',
        severity: AlertSeverity.warning,
        timestamp: minutesAgo(50),
        isSimulated: true,
        targetRoute: '/inspection',
      ),
      AlertNotificationModel(
        id: 'notif-005',
        robotId: alphaRobotId,
        title: 'Obstacle cleared',
        message: 'Trolley removed from Corridor A. Path resumed.',
        severity: AlertSeverity.info,
        timestamp: minutesAgo(240),
        isRead: true,
        targetRoute: '/map',
      ),
      AlertNotificationModel(
        id: 'notif-006',
        robotId: gammaRobotId,
        title: 'Connection degraded',
        message: 'Wi-Fi signal is weak; telemetry may be delayed.',
        severity: AlertSeverity.warning,
        timestamp: minutesAgo(3),
        targetRoute: '/dashboard',
      ),
      AlertNotificationModel(
        id: 'notif-007',
        robotId: alphaRobotId,
        title: 'Low battery',
        message: 'Battery at 14%. The robot will return to dock soon.',
        severity: AlertSeverity.critical,
        timestamp: minutesAgo(600),
        isRead: true,
        targetRoute: '/dashboard',
      ),
      AlertNotificationModel(
        id: 'notif-008',
        robotId: simRobotId,
        title: 'Demo job completed',
        message: 'Simulation Lab cleaned in demo mode.',
        severity: AlertSeverity.info,
        timestamp: minutesAgo(70),
        isRead: true,
        isSimulated: true,
        targetRoute: '/progress',
      ),
    ];
    return all.where((n) => n.robotId == robotId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Alerts for every robot, used by the global notifications inbox.
  static List<AlertNotificationModel> get allNotifications {
    final all = <AlertNotificationModel>[];
    for (final robot in robots) {
      all.addAll(notificationsFor(robot.id));
    }
    return all..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // ---------------------------------------------------------------------------
  // History (MOB-HIST-001..003)
  // ---------------------------------------------------------------------------

  static List<CleaningJobHistoryItem> jobHistoryFor(String robotId) {
    final specs = <List<dynamic>>[
      ['job-9842', alphaRobotId, 'CleanBot Pro — East Wing', 'Lobby & Main Hall, Corridor A', 18, 75.3, 72.0, 'In Progress', 4, 8],
      ['job-9840', alphaRobotId, 'CleanBot Pro — East Wing', 'Main Lobby & Atrium', 42, 240.5, 96.0, 'Completed', 7, 240],
      ['job-9839', alphaRobotId, 'CleanBot Pro — East Wing', 'North Conference Hall', 28, 120.0, 92.5, 'Completed', 3, 1440],
      ['job-9838', deltaRobotId, 'CleanBot Yard Guard', 'Outer Courtyard', 12, 45.2, 21.0, 'Fault Interrupted', 2, 2880],
      ['job-9837', alphaRobotId, 'CleanBot Pro — East Wing', 'Corridor A, West Wing Entry', 34, 98.6, 88.4, 'Completed', 5, 4320],
      ['job-9836', alphaRobotId, 'CleanBot Pro — East Wing', 'West Wing Entry', 22, 48.5, 100.0, 'Completed', 2, 5760],
      ['job-9835', alphaRobotId, 'CleanBot Pro — East Wing', 'Lobby & Main Hall', 40, 120.5, 94.8, 'Completed', 6, 8640],
      ['job-sim-01', simRobotId, 'CleanBot Simulator — Beta', 'Simulation Lab, Simulation Corridor', 35, 70.5, 100.0, 'Completed', 2, 70],
      ['job-9834', deltaRobotId, 'CleanBot Yard Guard', 'Outer Courtyard', 9, 30.1, 14.0, 'Failed', 1, 10080],
      ['job-9833', alphaRobotId, 'CleanBot Pro — East Wing', 'Lobby & Main Hall', 38, 118.0, 97.9, 'Completed', 4, 12000],
      ['job-9832', gammaRobotId, 'CleanBot Mini — Reception', 'Reception Area', 15, 36.0, 91.0, 'Cancelled', 1, 13000],
    ];
    return specs.where((s) => s[1] == robotId).map((s) {
      return CleaningJobHistoryItem(
        id: s[0] as String,
        robotId: s[1] as String,
        robotName: s[2] as String,
        zones: s[3] as String,
        zoneIds: (s[3] as String).split(', '),
        duration: Duration(minutes: s[4] as int),
        coverageM2: s[5] as double,
        coveragePercentage: s[6] as double,
        outcome: s[7] as String,
        detectionCount: s[8] as int,
        date: minutesAgo(s[9] as int),
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Reports (MOB-REP-001..003) - figures are backend-computed in the demo
  // ---------------------------------------------------------------------------

  static CleaningReport reportFor(ReportPeriod period) {
    final metricsByPeriod = <ReportPeriod, CleaningReportMetrics>{
      ReportPeriod.last7Days: const CleaningReportMetrics(
        jobsCompleted: 12,
        jobsFailed: 1,
        totalCleaningTime: Duration(hours: 8, minutes: 35),
        averageCoveragePercentage: 95.2,
        totalGarbageDetections: 34,
      ),
      ReportPeriod.last30Days: const CleaningReportMetrics(
        jobsCompleted: 48,
        jobsFailed: 2,
        totalCleaningTime: Duration(hours: 36, minutes: 20),
        averageCoveragePercentage: 94.6,
        totalGarbageDetections: 134,
      ),
      ReportPeriod.last90Days: const CleaningReportMetrics(
        jobsCompleted: 141,
        jobsFailed: 7,
        totalCleaningTime: Duration(hours: 108, minutes: 45),
        averageCoveragePercentage: 93.8,
        totalGarbageDetections: 402,
      ),
    };

    final pointCount = period.days <= 7 ? 7 : 6;
    final trends = List.generate(pointCount, (i) {
      final base = period.days <= 7 ? 88 + (i % 4) * 2 : 90 + (i % 3) * 2;
      return ReportTrendPoint(
        label: period.days <= 7
            ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i]
            : 'W${i + 1}',
        cleanlinessScore: base.toDouble(),
        detections: 3 + ((i * 5) % 11),
        containerEvents: i % 3,
      );
    });

    return CleaningReport(
      period: period,
      metrics: metricsByPeriod[period]!,
      trends: trends,
      detectionsByClass: const {
        DetectionSummaryClass.wet: 41,
        DetectionSummaryClass.dry: 62,
        DetectionSummaryClass.mixed: 23,
        DetectionSummaryClass.unknown: 8,
      },
      generatedAt: nowUtc,
      isSimulated: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Maintenance & diagnostics (MOB-MAINT-001..004)
  // ---------------------------------------------------------------------------

  static RobotHealthReport healthFor(String robotId) {
    final robot = robotFor(robotId);
    final isFaulty = robot.connectionState == RobotConnectionState.offline;
    final sensors = <SensorHealthItem>[
      const SensorHealthItem(
        name: 'LiDAR',
        state: HealthState.nominal,
        detail: 'Scanning at 10 Hz',
      ),
      const SensorHealthItem(
        name: 'Wheel encoders',
        state: HealthState.nominal,
        detail: 'Both wheels reporting',
      ),
      SensorHealthItem(
        name: 'Waste level sensor',
        state: isFaulty ? HealthState.fault : HealthState.nominal,
        detail: isFaulty ? 'No reading for 45 minutes' : 'Reading every 30 s',
      ),
      SensorHealthItem(
        name: 'Camera',
        state: robot.isSimulated ? HealthState.warning : HealthState.nominal,
        detail: robot.isSimulated ? 'Simulated feed' : 'Streaming at 15 fps',
      ),
      SensorHealthItem(
        name: 'Connectivity',
        state: robot.connectionState == RobotConnectionState.degraded
            ? HealthState.warning
            : (isFaulty ? HealthState.fault : HealthState.nominal),
        detail: '${robot.connectionState.displayName} · Wi-Fi',
      ),
    ];

    return RobotHealthReport(
      robotId: robotId,
      connectionState: robot.connectionState.displayName,
      firmwareVersion: robot.firmwareVersion,
      sensors: sensors,
      activeFaults: isFaulty
          ? [
              ActiveFaultItem(
                id: 'fault-001',
                title: 'Safety stop engaged',
                robotId: robotId,
                severity: HealthState.fault,
                detectedAt: minutesAgo(45),
                blocksCommands: true,
              ),
            ]
          : const [],
      maintenanceRecords: [
        MaintenanceRecordItem(
          id: 'maint-001',
          title: 'Brush replacement',
          completedAt: minutesAgo(70000),
          dueAt: minutesAgo(-20000),
          notes: 'Front brush replaced after 300 operating hours.',
        ),
        MaintenanceRecordItem(
          id: 'maint-002',
          title: 'Filter cleaning',
          dueAt: minutesAgo(1400),
          notes: 'Due — clean the dust filter.',
        ),
        MaintenanceRecordItem(
          id: 'maint-003',
          title: 'Sensor calibration',
          dueAt: minutesAgo(-40000),
          notes: 'Quarterly LiDAR calibration.',
        ),
      ],
      commandHistory: commandHistoryFor(robotId),
      lastDiagnosticAt: minutesAgo(2),
    );
  }

  static List<CommandHistoryItem> commandHistoryFor(String robotId) => [
        CommandHistoryItem(
          id: 'cmd-h1',
          commandType: 'Start Cleaning',
          state: 'Done',
          timestamp: minutesAgo(18),
        ),
        CommandHistoryItem(
          id: 'cmd-h2',
          commandType: 'Inspect Floor',
          state: 'Done',
          timestamp: minutesAgo(120),
        ),
        CommandHistoryItem(
          id: 'cmd-h3',
          commandType: 'Return to Dock',
          state: 'Robot rejected (battery sufficient)',
          timestamp: minutesAgo(400),
          reason: 'Battery sufficient',
        ),
        CommandHistoryItem(
          id: 'cmd-h4',
          commandType: 'Call Robot',
          state: 'Expired, not executed',
          timestamp: minutesAgo(720),
          reason: 'No acknowledgement',
        ),
      ];

  // ---------------------------------------------------------------------------
  // Command lifecycle fixtures (MOB-CTRL-005..010)
  // ---------------------------------------------------------------------------

  static CommandModel seedCommand({
    required String robotId,
    required CommandType type,
    required String idempotencyKey,
    required CommandLifecycleState state,
    String? reason,
  }) {
    return CommandModel(
      id: 'cmd-${DateTime.now().microsecondsSinceEpoch}',
      robotId: robotId,
      type: type,
      idempotencyKey: idempotencyKey,
      state: state,
      rejectionReason: reason,
      createdAt: nowUtc,
    );
  }
}
