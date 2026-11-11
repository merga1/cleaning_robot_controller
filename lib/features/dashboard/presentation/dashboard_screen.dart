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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    activeRobot?.name ?? 'CleanBot Console',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (activeRobot?.isSimulated == true) ...[
                  const SizedBox(width: 8),
                  const SimulatedBadge(dark: true), // MOB-DASH-009
                ],
              ],
            ),
            if (activeRobot != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeRobot.connectionState ==
                              RobotConnectionState.online
                          ? AppColors.levelNormal
                          : AppColors.levelCritical,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${activeRobot.connectionState.displayName} • ${activeRobot.status.displayName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          if (activeRobot != null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: BatteryIndicator(
                  levelPercentage: activeRobot.batteryLevel,
                  isCharging: activeRobot.isCharging,
                  isAppBar: true,
                ), // MOB-DASH-002
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.white),
            tooltip: 'Switch Robot',
            onPressed: () => context.push('/robots'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.white),
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
            onRetry: () => ref.read(webSocketClientProvider).connect(),
          ),

          Expanded(
            child: RefreshIndicator(
              color: AppColors.techOrange,
              onRefresh: () async {
                await ref.read(robotsControllerProvider.notifier).loadRobots();
                await ref
                    .read(dashboardControllerProvider.notifier)
                    .loadDashboardData();
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
                        border: Border.all(
                          color: AppColors.staleBadgeText.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          StaleBadge(label: 'Telemetry Stale'),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Updates exceeded freshness threshold. Refresh to re-sync.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.staleBadgeText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Current Active Job Card (MOB-DASH-004, MOB-PROG-001)
                  _buildActiveJobCard(
                    context,
                    dashboardState.summary?.activeJob,
                    isDark,
                  ),
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
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Cleanliness Assessment (MOB-DASH-006, MOB-DASH-008)
                      Expanded(
                        child: _buildCleanlinessCard(
                          context,
                          dashboardState.summary?.latestCleanliness,
                          isDark,
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
                  _buildQuickLinks(context, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveJobCard(
    BuildContext context,
    ActiveJobSummary? job,
    bool isDark,
  ) {
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;

    if (job == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bedtime_outlined,
                  color: isDark ? Colors.white70 : AppColors.primaryNavy,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Active Cleaning Job',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select a zone to start cleaning operations.',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.techOrange,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(84, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () => context.push('/zones'),
                child: const Text('Zones', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => context.push('/progress'),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.techOrange.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.cleaning_services_rounded,
                            color: AppColors.techOrange,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            job.zoneName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.techOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${job.progressPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.techOrange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: job.progressPercentage / 100,
                  minHeight: 8,
                  backgroundColor:
                      isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.techOrange),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Coverage: ${job.coverageAreaM2.toStringAsFixed(1)} m²',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  Text(
                    'Elapsed: ${job.elapsedTime.inMinutes}m ${job.elapsedTime.inSeconds % 60}s',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  const Text(
                    'Details →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.techOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWasteContainerCard(
    BuildContext context,
    int fillPercentage,
    bool hasSensorFault,
    bool isDark,
  ) {
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;

    return InkWell(
      onTap: () => context.push('/waste'),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Waste Fill',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: secondaryTextColor,
                  ),
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
                          : primaryTextColor,
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
    bool isDark,
  ) {
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;

    return InkWell(
      onTap: () => context.push('/inspection'),
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cleanliness',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 18,
                    color: secondaryTextColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // MOB-DASH-008: Never show "clean" without valid assessment
              if (cleanliness == null)
                Text(
                  'No assessment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: secondaryTextColor,
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
                        : AppColors.techOrange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Conf: ${(cleanliness.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLinks(BuildContext context, bool isDark) {
    final links = [
      {
        'title': 'Zones & Planning',
        'icon': Icons.map_outlined,
        'path': '/zones',
      },
      {
        'title': 'Live Map',
        'icon': Icons.navigation_outlined,
        'path': '/map',
      },
      {
        'title': 'Mission Progress',
        'icon': Icons.insights_outlined,
        'path': '/progress',
      },
      {
        'title': 'Garbage Detections',
        'icon': Icons.scatter_plot_outlined,
        'path': '/detections',
      },
      {
        'title': 'Alerts & Notifications',
        'icon': Icons.notifications_none,
        'path': '/notifications',
      },
      {
        'title': 'Cleaning History',
        'icon': Icons.history,
        'path': '/history',
      },
      {
        'title': 'Reports & Analytics',
        'icon': Icons.bar_chart_outlined,
        'path': '/reports',
      },
      {
        'title': 'Diagnostics & Health',
        'icon': Icons.build_outlined,
        'path': '/maintenance',
      },
    ];

    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final tileBg = isDark ? AppColors.darkSurface : AppColors.white;
    final tileBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'System Features',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
        ),
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
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(link['path'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tileBorder, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy.withValues(
                          alpha: isDark ? 0.5 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        link['icon'] as IconData,
                        size: 18,
                        color: AppColors.techOrange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        link['title'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
