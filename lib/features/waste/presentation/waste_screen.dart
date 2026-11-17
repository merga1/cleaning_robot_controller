import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/capacity_gauge.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../../mock/mock_catalog.dart';
import '../../dashboard/domain/dashboard_summary_model.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/waste_model.dart';

/// Waste telemetry comes from the central demo catalogue; no network request is
/// made from this frontend-only build.
final wasteStatusProvider = FutureProvider<WasteStatusModel>((ref) async {
  final config = ref.watch(appConfigProvider);
  final activeId = ref.watch(robotsControllerProvider).activeRobot?.id ??
      MockCatalog.alphaRobotId;

  if (!config.enableMockMode) {
    throw StateError(
      'Live data endpoint is not available in this frontend-only demo build.',
    );
  }

  await Future.delayed(const Duration(milliseconds: 250));
  return MockCatalog.wasteFor(activeId);
});

class WasteScreen extends ConsumerWidget {
  const WasteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final wasteAsync = ref.watch(wasteStatusProvider);
    final activeJob = ref.watch(dashboardControllerProvider).summary?.activeJob;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final waste = wasteAsync.value;
    final isStale = waste != null &&
        DateTime.now().toUtc().difference(waste.timestamp.toUtc()) >
            config.staleDataThreshold;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Container Monitoring'),
      ),
      body: ScreenStateBuilder(
        isLoading: wasteAsync.isLoading,
        errorMessage:
            wasteAsync.hasError ? '${wasteAsync.error}' : null,
        isEmpty: waste == null || waste.history.isEmpty,
        emptyMessage: 'No waste readings have been recorded for this robot yet.',
        isStale: isStale,
        isDemo: config.enableMockMode,
        isSimulated: waste?.isSimulated ?? false,
        onRetry: () => ref.invalidate(wasteStatusProvider),
        builder: (context) {
          // ScreenStateBuilder handles loading/error/empty before this runs.
          final status = waste!;
          final fillColor = status.hasSensorFault
              ? AppColors.severityCritical
              : status.isFull
                  ? AppColors.levelCritical
                  : status.isWarning
                      ? AppColors.techOrange
                      : AppColors.primaryNavy;
          final valueLabel = status.hasSensorFault
              ? 'SENSOR FAULT'
              : status.isValidFill
                  ? '${status.fillPercentage.round()}%'
                  : 'No valid reading';
          final statusDetail = status.hasSensorFault
              ? 'Diagnostic error: waste level sensor unresponsive.'
              : status.isFull
                  ? 'Full: empty the container before dispatching new work.'
                  : status.isWarning
                      ? 'Warning: nearing maximum capacity.'
                      : 'Normal operating range.';

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // MOB-WASTE-004: state the consequence for the active job.
              if (status.isFull) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.severityCritical.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.severityCritical.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        color: AppColors.severityCritical,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Container Capacity Exceeded',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.severityCritical,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _jobEffectMessage(activeJob),
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Container Level Card (MOB-WASTE-001, MOB-WASTE-003)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Internal Waste Bin',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        valueLabel,
                        style: TextStyle(
                          fontSize: status.hasSensorFault ? 28 : 42,
                          fontWeight: FontWeight.bold,
                          color: fillColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CapacityGauge(
                        fillPercentage: status.fillPercentage.round(),
                        hasSensorFault: status.hasSensorFault,
                        height: 14,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        status.stateLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: fillColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusDetail,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: status.hasSensorFault
                              ? AppColors.severityCritical
                              : secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Warning at ${status.warningThreshold.toStringAsFixed(0)}%'
                        '  •  Full at ${status.fullThreshold.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, color: secondaryTextColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last reading: ${formatDateTime(status.timestamp)} '
                        '(${formatRelative(status.timestamp)})',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Reading History (MOB-WASTE-002)
              Text(
                'Recent Fill Readings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              if (status.history.isEmpty)
                Text(
                  'No reading history is available for this robot.',
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                )
              else
                _historyChart(
                  status.history,
                  warningThreshold: status.warningThreshold,
                  fullThreshold: status.fullThreshold,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                ),
            ],
          );
        },
      ),
    );
  }

  /// MOB-WASTE-004: make the operational effect of a full bin explicit,
  /// including the job that is currently running (if any).
  String _jobEffectMessage(ActiveJobSummary? activeJob) {
    const base = 'New cleaning jobs should be paused until the bin is emptied.';
    final job = activeJob;
    if (job == null) return '$base No cleaning job is currently active.';
    return '$base The active job in ${job.zoneName} '
        '(${job.progressPercentage.toStringAsFixed(0)}% complete) '
        'may be interrupted.';
  }

  Widget _historyChart(
    List<WasteReadingPoint> history, {
    required double warningThreshold,
    required double fullThreshold,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Fill level over the last ${history.length} readings',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 132,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: history.map((point) {
                  final value = point.fillPercentage.clamp(0.0, 100.0);
                  final barHeight = (value / 100 * 100).toDouble();
                  final color = value >= fullThreshold
                      ? AppColors.levelCritical
                      : value >= warningThreshold
                          ? AppColors.techOrange
                          : AppColors.primaryNavy;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            value.round().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: double.infinity,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            formatTime(point.timestamp),
                            style: TextStyle(
                              fontSize: 9,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
