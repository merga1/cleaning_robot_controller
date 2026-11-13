import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/battery_indicator.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../domain/robot_model.dart';
import 'robots_controller.dart';

class RobotListScreen extends ConsumerWidget {
  const RobotListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final robotsState = ref.watch(robotsControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;

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
      body: robotsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : robotsState.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.severityCritical,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          robotsState.errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: primaryTextColor),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(140, 46),
                          ),
                          onPressed: () => ref
                              .read(robotsControllerProvider.notifier)
                              .loadRobots(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: robotsState.robots.length,
                  itemBuilder: (context, index) {
                    final robot = robotsState.robots[index];
                    final isSelected = robotsState.activeRobot?.id == robot.id;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.techOrange
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: robot.connectionState ==
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
                                          ? AppColors.techOrange
                                              .withValues(alpha: 0.12)
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
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
