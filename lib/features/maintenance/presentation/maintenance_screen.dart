import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../controls/domain/command_model.dart';
import '../../controls/presentation/controls_controller.dart';
import '../../robots/presentation/robots_controller.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRobot = ref.watch(robotsControllerProvider).activeRobot;
    final authUser = ref.watch(authControllerProvider).user;
    final controlsState = ref.watch(controlsControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance & Diagnostics'),
        actions: [
          // MOB-CTRL-011: Request status refresh command
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Request Status Refresh',
            onPressed: activeRobot == null || controlsState.isInFlight
                ? null
                : () {
                    ref.read(controlsControllerProvider.notifier).executeCommand(
                          robotId: activeRobot.id,
                          type: CommandType.requestStatusRefresh,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Status refresh command submitted.'),
                      ),
                    );
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sensor Diagnostics Overview (MOB-MAINT-001)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withValues(
                            alpha: isDark ? 0.5 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.memory_rounded,
                          size: 18,
                          color: AppColors.techOrange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Hardware Subsystem Health',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _subsystemStatus(
                    'LiDAR SLAM Sensor',
                    'Nominal',
                    AppColors.successGreen,
                    primaryTextColor,
                  ),
                  _subsystemStatus(
                    'Optical Flow Sensor',
                    'Nominal',
                    AppColors.successGreen,
                    primaryTextColor,
                  ),
                  _subsystemStatus(
                    'Suction Motor Turbine',
                    'Nominal',
                    AppColors.successGreen,
                    primaryTextColor,
                  ),
                  _subsystemStatus(
                    'Waste Container Level',
                    'Nominal',
                    AppColors.successGreen,
                    primaryTextColor,
                  ),
                  _subsystemStatus(
                    'Brush Roller Actuator',
                    'Maintenance Due Soon',
                    AppColors.techOrange,
                    primaryTextColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Maintenance Records & Due Items (MOB-MAINT-002)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Service Records',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              if (authUser?.role.canManageUsers ==
                  true) // MOB-MAINT-003: Admin add record
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log Service'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Log Service dialog opened (Admin only).'),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),

          _serviceRecordItem(
            'HEPA Air Filter Replacement',
            'Overdue by 3 days',
            AppColors.severityCritical,
            Icons.filter_alt_outlined,
            primaryTextColor,
            borderColor,
            isDark,
          ),
          _serviceRecordItem(
            'Wheel Gear Lubrication',
            'Due in 14 days',
            AppColors.techOrange,
            Icons.build_circle_outlined,
            primaryTextColor,
            borderColor,
            isDark,
          ),
          _serviceRecordItem(
            'Battery Calibration Cycle',
            'Completed 1 week ago',
            AppColors.successGreen,
            Icons.battery_charging_full,
            primaryTextColor,
            borderColor,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _subsystemStatus(
    String name,
    String status,
    Color color,
    Color primaryTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              color: primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                status,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _serviceRecordItem(
    String title,
    String status,
    Color statusColor,
    IconData icon,
    Color primaryTextColor,
    Color borderColor,
    bool isDark,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryNavy.withValues(
              alpha: isDark ? 0.5 : 0.08,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDark ? AppColors.techOrange : AppColors.primaryNavy,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: primaryTextColor,
          ),
        ),
        subtitle: Text(
          status,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
