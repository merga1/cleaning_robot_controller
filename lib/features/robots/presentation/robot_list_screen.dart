import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/battery_indicator.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../domain/robot_model.dart';
import 'robots_controller.dart';

class RobotListScreen extends ConsumerWidget {
  const RobotListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final robotsState = ref.watch(robotsControllerProvider);
    final config = ref.watch(appConfigProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor = isDark
        ? Colors.white70
        : AppColors.secondaryText;
    final now = DateTime.now();
    final isStale = robotsState.robots.any(
      (robot) =>
          now.difference(robot.lastUpdatedAt) > config.staleDataThreshold,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Fleet Selection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Fleet',
            onPressed: () =>
                ref.read(robotsControllerProvider.notifier).loadRobots(),
          ),
        ],
      ),
      body: ScreenStateBuilder(
        isLoading:
            robotsState.isLoading ||
            (robotsState.robots.isEmpty && robotsState.errorMessage == null),
        errorMessage: robotsState.errorMessage,
        isEmpty:
            robotsState.robots.isEmpty &&
            robotsState.errorMessage == null &&
            !robotsState.isLoading,
        isStale: isStale,
        isDemo: config.enableMockMode,
        isSimulated: robotsState.robots.any((robot) => robot.isSimulated),
        emptyMessage: 'No robots are assigned to this account.',
        onRetry: () => ref.read(robotsControllerProvider.notifier).loadRobots(),
        builder: (context) => ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: robotsState.robots.length,
          itemBuilder: (context, index) {
            final robot = robotsState.robots[index];
            final isSelected = robotsState.activeRobot?.id == robot.id;
            final unavailableReason = _monitoringOnlyReason(robot);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.techOrange
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: isSelected ? 2 : 1,
                ),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                // Monitoring is always allowed, even for unavailable robots.
                onTap: () async {
                  await ref
                      .read(robotsControllerProvider.notifier)
                      .selectRobot(robot);
                  if (context.mounted) {
                    context.pop();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isSelected
                                ? AppColors.primaryNavy
                                : (isDark
                                      ? AppColors.darkBackground
                                      : AppColors.softBlue),
                            child: Icon(
                              Icons.smart_toy_rounded,
                              color: isSelected
                                  ? AppColors.techOrange
                                  : secondaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        robot.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ),
                                    if (robot.isSimulated) ...[
                                      const SizedBox(width: 6),
                                      SimulatedBadge(dark: isDark),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: ${robot.id} • FW: ${robot.firmwareVersion}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.techOrange,
                              size: 24,
                            ),
                          ],
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      robot.connectionState ==
                                          RobotConnectionState.online
                                      ? AppColors.levelNormal
                                      : AppColors.levelCritical,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                robot.connectionState.displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.techOrange.withValues(alpha: 0.12)
                                  : AppColors.primaryNavy.withValues(
                                      alpha: isDark ? 0.5 : 0.08,
                                    ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              robot.status.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.techOrange
                                    : primaryTextColor,
                              ),
                            ),
                          ),
                          BatteryIndicator(
                            levelPercentage: robot.batteryLevel,
                            isCharging: robot.isCharging,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Updated: ${formatDateTime(robot.lastUpdatedAt)} '
                        '(${formatRelative(robot.lastUpdatedAt)})',
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Capabilities: ${_capabilitySummary(robot.capabilities)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                        ),
                      ),
                      if (robot.hasSafetyFault) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.severityCritical.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.severityCritical.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.dangerous_outlined,
                                size: 16,
                                color: AppColors.severityCritical,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Critical: safety fault reported. Commands '
                                  'are blocked by the local safety controller.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.severityCritical,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (unavailableReason != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 13,
                              color: AppColors.mutedBlue,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                unavailableReason,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.mutedBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Why commands are not currently available, while making it explicit that
  /// the robot can still be selected for monitoring (MOB-ROB-003/MOB-SAF-002).
  String? _monitoringOnlyReason(RobotModel robot) {
    if (robot.hasSafetyFault) {
      return 'Safety fault — commands unavailable. Tap to monitor the last '
          'known state.';
    }
    if (robot.connectionState == RobotConnectionState.offline) {
      return 'Offline — commands cannot be delivered. Tap to monitor the last '
          'known state.';
    }
    if (robot.connectionState == RobotConnectionState.degraded) {
      return 'Degraded connection — telemetry may be delayed. Tap to monitor.';
    }
    return null;
  }

  String _capabilitySummary(RobotCapabilities capabilities) {
    final labels = <String>[
      if (capabilities.canClean) 'Clean',
      if (capabilities.canPause) 'Pause',
      if (capabilities.canResume) 'Resume',
      if (capabilities.canCancel) 'Cancel',
      if (capabilities.canInspect) 'Inspect',
      if (capabilities.canDock) 'Dock',
      if (capabilities.canCall) 'Call',
    ];
    if (labels.isEmpty) return 'No commands supported';
    return labels.join(' · ');
  }
}
