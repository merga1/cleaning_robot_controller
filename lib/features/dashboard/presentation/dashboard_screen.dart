import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/battery_indicator.dart';
import '../../../core/widgets/capacity_gauge.dart';
import '../../../core/widgets/connection_banner.dart';
import '../../../core/widgets/safety_banner.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../../../core/widgets/stale_badge.dart';
import '../../controls/presentation/widgets/control_panel.dart';
import '../../robots/domain/robot_model.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/dashboard_summary_model.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final robotsState = ref.watch(robotsControllerProvider);
    final dashboardState = ref.watch(dashboardControllerProvider);
    final activeRobot = robotsState.activeRobot;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  activeRobot?.name ?? 'CleanBot',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                if (activeRobot?.isSimulated == true) ...[
                  const SizedBox(width: 8),
                  const SimulatedBadge(), // MOB-DASH-009
                ],
              ],
            ),
            if (activeRobot != null)
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeRobot.connectionState == RobotConnectionState.online
                          ? AppColors.levelNormal
                          : AppColors.levelCritical,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${activeRobot.connectionState.displayName} • ${activeRobot.status.displayName}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          if (activeRobot != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: BatteryIndicator(
                levelPercentage: activeRobot.batteryLevel,
                isCharging: activeRobot.isCharging,
              ), // MOB-DASH-002
            ),
          ],
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Switch Robot',
            onPressed: () => context.push('/robots'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // MOB-RT-005: Live WebSocket Connection Banner
          ConnectionBanner(
            connectionState: dashboardState.connectionState,
            onRetry: () =>
                ref.read(webSocketClientProvider).connect(),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(robotsControllerProvider.notifier).loadRobots();
                await ref.read(dashboardControllerProvider.notifier).loadDashboardData();
              },
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // MOB-SAF-001: Operational safety notice
                  const SafetyBanner(compact: true),
                  const SizedBox(height: 12),

                  // Stale Data Banner (MOB-RT-005)
                  if (dashboardState.isStale) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.staleBadgeBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.staleBadgeText.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          StaleBadge(label: 'Telemetry Stale'),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Updates exceeded freshness threshold. Refresh to re-sync.',
                              style: TextStyle(fontSize: 12, color: AppColors.staleBadgeText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Current Active Job Card (MOB-DASH-004)
                  _buildActiveJobCard(context, dashboardState.summary?.activeJob),
                  const SizedBox(height: 12),

                  // Telemetry Metrics Grid (Waste Container & Cleanliness)
                  Row(
                    children: [
                      // Waste Container (MOB-DASH-005, MOB-WASTE-001)
                      Expanded(
                        child: _buildWasteContainerCard(
                          context,
                          dashboardState.summary?.wasteFillPercentage ?? 0,
                          dashboardState.summary?.wasteSensorFault ?? false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Cleanliness Assessment (MOB-DASH-006, MOB-DASH-008)
                      Expanded(
                        child: _buildCleanlinessCard(
                          context,
                          dashboardState.summary?.latestCleanliness,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Robot Controls Panel (MOB-CTRL-001..010)
                  if (activeRobot != null) ...[
                    ControlPanel(robot: activeRobot),
                    const SizedBox(height: 16),
                  ],

                  // Quick Navigation Shortcuts
                  _buildQuickLinks(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveJobCard(BuildContext context, ActiveJobSummary? job) {
    if (job == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.bedtime_outlined, color: Color(0xFF64748B), size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Active Cleaning Job',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Select a zone to start cleaning operations.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => context.push('/zones'),
                child: const Text('Zones'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cleaning_services, color: AppColors.statusCleaning, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      job.zoneName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Text(
                  '${job.progressPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: job.progressPercentage / 100,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.statusCleaning),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Coverage: ${job.coverageAreaM2.toStringAsFixed(1)} m²',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                Text(
                  'Elapsed: ${job.elapsedTime.inMinutes}m ${job.elapsedTime.inSeconds % 60}s',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                GestureDetector(
                  onTap: () => context.push('/map'),
                  child: const Text(
                    'Live Map →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWasteContainerCard(
    BuildContext context,
    int fillPercentage,
    bool hasSensorFault,
  ) {
    return InkWell(
      onTap: () => context.push('/waste'),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Waste Fill',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Icon(Icons.delete_outline, size: 18, color: Color(0xFF64748B)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                hasSensorFault ? 'Fault' : '$fillPercentage%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: hasSensorFault
                      ? AppColors.severityCritical
                      : fillPercentage >= 85
                          ? AppColors.levelCritical
                          : AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              CapacityGauge(
                fillPercentage: fillPercentage,
                hasSensorFault: hasSensorFault,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanlinessCard(
    BuildContext context,
    CleanlinessSummary? cleanliness,
  ) {
    return InkWell(
      onTap: () => context.push('/inspection'),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cleanliness',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Icon(Icons.auto_awesome_outlined, size: 18, color: Color(0xFF64748B)),
                ],
              ),
              const SizedBox(height: 10),
              // MOB-DASH-008: Never show "clean" without valid assessment
              if (cleanliness == null)
                const Text(
                  'No assessment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                  ),
                )
              else ...[
                Text(
                  cleanliness.isInconclusive
                      ? 'Inconclusive'
                      : '${cleanliness.score.toStringAsFixed(0)} / 100',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cleanliness.isInconclusive
                        ? AppColors.severityWarning
                        : AppColors.statusCleaning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Conf: ${(cleanliness.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLinks(BuildContext context) {
    final links = [
      {'title': 'Zones & Planning', 'icon': Icons.map_outlined, 'path': '/zones'},
      {'title': 'Live Map', 'icon': Icons.navigation_outlined, 'path': '/map'},
      {'title': 'Garbage Detections', 'icon': Icons.scatter_plot_outlined, 'path': '/detections'},
      {'title': 'Alerts & Notifications', 'icon': Icons.notifications_none, 'path': '/notifications'},
      {'title': 'Cleaning History', 'icon': Icons.history, 'path': '/history'},
      {'title': 'Diagnostics & Maintenance', 'icon': Icons.build_outlined, 'path': '/maintenance'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Features',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: links.length,
          itemBuilder: (context, index) {
            final link = links[index];
            return OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(link['icon'] as IconData, size: 20, color: AppColors.primaryBlue),
              label: Text(
                link['title'] as String,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => context.push(link['path'] as String),
            );
          },
        ),
      ],
    );
  }
}

