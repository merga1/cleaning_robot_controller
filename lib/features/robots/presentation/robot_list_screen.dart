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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Robot Fleet Selection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Fleet',
            onPressed: () => ref.read(robotsControllerProvider.notifier).loadRobots(),
          ),
        ],
      ),
      body: robotsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : robotsState.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.severityCritical),
                      const SizedBox(height: 12),
                      Text(robotsState.errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(robotsControllerProvider.notifier).loadRobots(),
                        child: const Text('Retry'),
                      ),
                    ],
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
                          color: isSelected ? AppColors.primaryBlue : AppColors.lightBorder,
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
                                    backgroundColor: isSelected
                                        ? AppColors.primaryLight
                                        : const Color(0xFFF1F5F9),
                                    child: Icon(
                                      Icons.smart_toy_outlined,
                                      color: isSelected
                                          ? AppColors.primaryBlue
                                          : const Color(0xFF64748B),
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
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            if (robot.isSimulated) ...[
                                              const SizedBox(width: 6),
                                              const SimulatedBadge(),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${robot.id} • FW: ${robot.firmwareVersion}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppColors.primaryBlue,
                                      size: 22,
                                    ),
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
                                          color: robot.connectionState ==
                                                  RobotConnectionState.online
                                              ? AppColors.levelNormal
                                              : AppColors.levelCritical,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        robot.connectionState.displayName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      robot.status.displayName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF334155),
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

