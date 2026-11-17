import 'package:cleanbot_app/features/auth/domain/user_model.dart';
import 'package:cleanbot_app/features/controls/domain/command_model.dart';
import 'package:cleanbot_app/features/map/domain/map_model.dart';
import 'package:cleanbot_app/features/notifications/domain/notification_model.dart';
import 'package:cleanbot_app/features/progress/domain/job_progress_model.dart';
import 'package:cleanbot_app/features/reports/domain/report_model.dart';
import 'package:cleanbot_app/features/robots/domain/robot_model.dart';
import 'package:cleanbot_app/mock/mock_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockCatalog', () {
    test('provides distinct demo identities for every role', () {
      expect(MockCatalog.accounts.length, 3);
      expect(
        MockCatalog.accounts.map((a) => a.user.role).toSet(),
        {UserRole.admin, UserRole.operator, UserRole.readOnly},
      );
      expect(
        MockCatalog.accountFor(' ADMIN@CLEANBOT.IO ')?.user.role,
        UserRole.admin,
      );
      expect(MockCatalog.accountFor('nobody@cleanbot.io'), isNull);
    });

    test('provides robots that exercise all states and capability limits', () {
      final robots = MockCatalog.robots;
      expect(robots.length, greaterThan(1));
      expect(
        robots.map((r) => r.connectionState).toSet(),
        {
          RobotConnectionState.online,
          RobotConnectionState.offline,
          RobotConnectionState.degraded,
        },
      );
      expect(
        robots.map((r) => r.status).toSet(),
        contains(RobotOperationalStatus.cleaning),
      );
      expect(
        robots.map((r) => r.isSimulated).toSet(),
        {true, false},
      );

      final sim = MockCatalog.robotFor(MockCatalog.simRobotId);
      expect(sim.capabilities.canCall, isFalse);
      expect(sim.capabilities.canCancel, isFalse);
      final faulty = MockCatalog.robotFor(MockCatalog.deltaRobotId);
      expect(faulty.hasSafetyFault, isTrue);
      expect(faulty.connectionState, RobotConnectionState.offline);
    });

    test('zone fixtures include unavailable zones with reasons', () {
      final zones = MockCatalog.zonesFor(MockCatalog.alphaRobotId);
      expect(zones, isNotEmpty);
      expect(zones.any((z) => !z.isAvailable), isTrue);
      expect(
        zones.where((z) => !z.isAvailable).every(
              (z) => (z.unavailabilityReason ?? '').isNotEmpty,
            ),
        isTrue,
      );
      final yard = MockCatalog.zonesFor(MockCatalog.deltaRobotId).single;
      expect(yard.isAvailable, isFalse);
    });

    test('dashboard data is robot-specific, sorted and honest about faults', () {
      final healthy = MockCatalog.dashboardFor(MockCatalog.alphaRobotId);
      final faulty = MockCatalog.dashboardFor(MockCatalog.deltaRobotId);

      expect(healthy.activeJob, isNotNull);
      expect(healthy.latestCleanliness, isNotNull);
      expect(healthy.activeAlerts, isNotEmpty);
      for (var i = 1; i < healthy.activeAlerts.length; i++) {
        expect(
          healthy.activeAlerts[i - 1].severity.index,
          greaterThanOrEqualTo(healthy.activeAlerts[i].severity.index),
        );
      }

      expect(faulty.activeJob, isNull);
      expect(faulty.latestCleanliness, isNull);
      expect(faulty.wasteSensorFault, isTrue);
      expect(
        faulty.activeAlertCount,
        MockCatalog.notificationsFor(MockCatalog.deltaRobotId)
            .where((n) => !n.isRead)
            .length,
      );
    });

    test('map data is supplied by reference with pose, zones and obstacles', () {
      final map = MockCatalog.mapFor(MockCatalog.alphaRobotId);
      expect(map.mapImageUrl, startsWith('mock://'));
      expect(map.currentPose.timestamp, isNotNull);
      expect(map.zones, isNotEmpty);
      expect(map.plannedPath, isNotEmpty);
      expect(map.obstacles, isNotEmpty);
      expect(map.dockLocation, isA<OffsetPoint>());
    });

    test('job progress never reports a fabricated ETA or successful fault', () {
      final active = MockCatalog.jobProgressFor(MockCatalog.alphaRobotId);
      final faulty = MockCatalog.jobProgressFor(MockCatalog.deltaRobotId);
      final sim = MockCatalog.jobProgressFor(MockCatalog.simRobotId);

      expect(active.estimatedFinishTime, isNull);
      expect(active.status, JobProgressStatus.active);
      expect(faulty.status, JobProgressStatus.faultInterrupted);
      expect(faulty.timeline.any((e) => e.eventType == 'fault'), isTrue);
      expect(sim.status, JobProgressStatus.completed);
      expect(sim.overallProgress, 100.0);
    });

    test('detections carry class, confidence, zone, job and optional images', () {
      final detections = MockCatalog.detectionsFor(
        robotId: MockCatalog.alphaRobotId,
      );
      expect(detections, isNotEmpty);
      expect(detections.every((d) => d.zoneName.isNotEmpty), isTrue);
      expect(detections.every((d) => d.jobId.isNotEmpty), isTrue);
      expect(detections.any((d) => d.imageUrl != null), isTrue);
      expect(detections.any((d) => d.isUncertain), isTrue);
      expect(
        MockCatalog.detectionsFor(robotId: MockCatalog.deltaRobotId).every(
          (d) => d.robotId == MockCatalog.deltaRobotId,
        ),
        isTrue,
      );
    });

    test('assessments label low confidence and sensor faults as inconclusive', () {
      final sim = MockCatalog.assessmentsFor(robotId: MockCatalog.simRobotId);
      expect(sim.single.isInconclusive, isTrue);
      expect(sim.single.resultLabel, 'Inconclusive');

      final faulty = MockCatalog.assessmentsFor(
        robotId: MockCatalog.deltaRobotId,
      );
      expect(faulty.single.sensorFault, isNotNull);
      expect(faulty.single.isInconclusive, isTrue);
    });

    test('waste status distinguishes sensor fault from a valid reading', () {
      final normal = MockCatalog.wasteFor(MockCatalog.alphaRobotId);
      final faulty = MockCatalog.wasteFor(MockCatalog.deltaRobotId);

      expect(normal.isValidFill, isTrue);
      expect(normal.warningThreshold, 75);
      expect(normal.fullThreshold, 90);
      expect(normal.history, isNotEmpty);
      expect(faulty.hasSensorFault, isTrue);
      expect(faulty.isValidFill, isFalse);
      expect(faulty.stateLabel, 'Sensor fault');
    });

    test('notifications expose severity, read state and target routes', () {
      final all = MockCatalog.allNotifications;
      expect(all, isNotEmpty);
      expect(all.every((n) => n.targetRoute != null), isTrue);
      expect(all.any((n) => n.severity == AlertSeverity.critical), isTrue);
      expect(all.any((n) => !n.isRead), isTrue);
    });

    test('history, reports and maintenance fixtures are complete', () {
      final history = MockCatalog.jobHistoryFor(MockCatalog.deltaRobotId);
      expect(history.any((j) => j.outcome == 'Fault Interrupted'), isTrue);
      expect(history.every((j) => j.zoneIds.isNotEmpty), isTrue);

      for (final period in ReportPeriod.values) {
        final report = MockCatalog.reportFor(period);
        expect(report.period, period);
        expect(report.trends, isNotEmpty);
        expect(report.detectionsByClass.length, 4);
      }

      final health = MockCatalog.healthFor(MockCatalog.deltaRobotId);
      expect(health.activeFaults, isNotEmpty);
      expect(health.activeFaults.first.blocksCommands, isTrue);
      expect(
        health.commandHistory
            .any((c) => c.state == 'Expired, not executed'),
        isTrue,
      );
      expect(
        MockCatalog.commandHistoryFor(MockCatalog.alphaRobotId)
            .any((c) => c.reason != null),
        isTrue,
      );
      expect(
        CommandLifecycleState.values.contains(CommandLifecycleState.submitting),
        isTrue,
      );
    });
  });
}
