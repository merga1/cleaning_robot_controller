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
                      const SnackBar(content: Text('Status refresh command submitted.')),
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
              side: const BorderSide(color: AppColors.lightBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hardware Subsystem Health',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _subsystemStatus('LiDAR SLAM Sensor', 'Nominal', AppColors.statusCleaning),
                  _subsystemStatus('Optical Flow Sensor', 'Nominal', AppColors.statusCleaning),
                  _subsystemStatus('Suction Motor Turbine', 'Nominal', AppColors.statusCleaning),
                  _subsystemStatus('Waste Container Level', 'Nominal', AppColors.statusCleaning),
                  _subsystemStatus('Brush Roller Actuator', 'Maintenance Due Soon', AppColors.severityWarning),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Maintenance Records & Due Items (MOB-MAINT-002)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Service Records',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (authUser?.role.canManageUsers == true) // MOB-MAINT-003: Admin add record
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log Service'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Log Service dialog opened (Admin only).')),
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
          ),
          _serviceRecordItem(
            'Wheel Gear Lubrication',
            'Due in 14 days',
            AppColors.severityWarning,
            Icons.build_circle_outlined,
          ),
          _serviceRecordItem(
            'Battery Calibration Cycle',
            'Completed 1 week ago',
            AppColors.statusCleaning,
            Icons.battery_charging_full,
          ),
        ],
      ),
    );
  }

  Widget _subsystemStatus(String name, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 14)),
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

  Widget _serviceRecordItem(String title, String status, Color statusColor, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

