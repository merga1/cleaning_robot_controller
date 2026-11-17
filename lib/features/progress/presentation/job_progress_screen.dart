import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../../mock/mock_catalog.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/job_progress_model.dart';

/// Progress for the active robot (MOB-PROG-001..004).
final jobProgressProvider =
    FutureProvider<DetailedJobProgressModel>((ref) async {
  final activeRobotId =
      ref.watch(robotsControllerProvider).activeRobot?.id ??
      MockCatalog.alphaRobotId;
  if (ref.read(appConfigProvider).enableMockMode) {
    return MockCatalog.jobProgressFor(activeRobotId);
  }
  throw StateError(
    'Live data endpoint is not available in this frontend-only demo build.',
  );
});

class JobProgressScreen extends ConsumerWidget {
  const JobProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(jobProgressProvider);
    final config = ref.watch(appConfigProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    void retry() => ref.invalidate(jobProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Cleaning Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Progress',
            onPressed: retry,
          ),
        ],
      ),
      body: progressAsync.when(
        loading: () => ScreenStateBuilder(
          isLoading: true,
          isDemo: config.enableMockMode,
          builder: (_) => const SizedBox.shrink(),
        ),
        error: (error, _) => ScreenStateBuilder(
          errorMessage: error.toString(),
          isDemo: config.enableMockMode,
          onRetry: retry,
          builder: (_) => const SizedBox.shrink(),
        ),
        data: (job) {
          final isFaultOrFailed = _isCritical(job.status);
          final latestUpdate = _latestTimelineTimestamp(job);
          final isStale = !job.status.isTerminal &&
              latestUpdate != null &&
              DateTime.now().toUtc().difference(latestUpdate.toUtc()) >
                  config.staleDataThreshold;

          return ScreenStateBuilder(
            isDemo: config.enableMockMode,
            isStale: isStale,
            isSimulated: MockCatalog.robotFor(job.robotId).isSimulated,
            onRetry: retry,
            builder: (_) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isFaultOrFailed) ...[
                  _criticalBanner(job, isDark),
                  const SizedBox(height: 12),
                ],
                _overallCard(
                  job: job,
                  isFaultOrFailed: isFaultOrFailed,
                  latestUpdate: latestUpdate,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                // Per-Zone Progress Breakdown (MOB-PROG-001)
                Text(
                  'Per-Zone Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                ...job.zones.map(
                  (zone) => _zoneCard(
                    zone: zone,
                    isFaultOrFailed: isFaultOrFailed,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    borderColor: borderColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 10),

                // Event Timeline (MOB-PROG-002)
                Text(
                  'Mission Event Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                ...job.timeline.asMap().entries.map(
                      (entry) => _timelineTile(
                        event: entry.value,
                        isLast: entry.key == job.timeline.length - 1,
                        isFaultOrFailed: isFaultOrFailed,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        borderColor: borderColor,
                        isDark: isDark,
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  static bool _isCritical(JobProgressStatus status) {
    return status == JobProgressStatus.failed ||
        status == JobProgressStatus.faultInterrupted;
  }

  static DateTime? _latestTimelineTimestamp(DetailedJobProgressModel job) {
    if (job.timeline.isEmpty) return null;
    return job.timeline
        .map((event) => event.timestamp)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Widget _criticalBanner(DetailedJobProgressModel job, bool isDark) {
    final criticalColor = isDark ? AppColors.white : AppColors.severityCritical;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.severityCritical.withValues(
          alpha: isDark ? 0.35 : 0.10,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.severityCritical),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: criticalColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Job ${job.status.displayName} — last known values are shown.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: criticalColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overallCard({
    required DetailedJobProgressModel job,
    required bool isFaultOrFailed,
    required DateTime? latestUpdate,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required bool isDark,
  }) {
    final criticalColor = isDark ? AppColors.white : AppColors.severityCritical;
    final statusColor = isFaultOrFailed ? criticalColor : AppColors.techOrange;
    final progressFraction =
        (job.overallProgress / 100).clamp(0.0, 1.0).toDouble();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isFaultOrFailed ? AppColors.severityCritical : borderColor,
          width: isFaultOrFailed ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.robotName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mission #${job.jobId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isFaultOrFailed
                        ? AppColors.severityCritical.withValues(
                            alpha: isDark ? 0.5 : 0.12,
                          )
                        : AppColors.techOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFaultOrFailed) ...[
                        Icon(
                          Icons.error_outline,
                          size: 13,
                          color: criticalColor,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        job.status.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (latestUpdate != null) ...[
              const SizedBox(height: 6),
              Text(
                'Last update ${formatDateTime(latestUpdate)} · '
                '${formatRelative(latestUpdate)}',
                style: TextStyle(fontSize: 11, color: secondaryTextColor),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overall Progress',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
                Text(
                  '${job.overallProgress.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 10,
                backgroundColor: borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statTile(
                  'Elapsed Time',
                  formatDuration(job.elapsedTime),
                  primaryTextColor,
                  secondaryTextColor,
                ),
                _statTile(
                  'Coverage Area',
                  '${job.totalCoverageM2.toStringAsFixed(1)} m²',
                  primaryTextColor,
                  secondaryTextColor,
                ),
                // MOB-PROG-003: only show ETA if supplied by the backend.
                if (job.estimatedFinishTime != null)
                  _statTile(
                    'Estimated Finish',
                    formatTime(job.estimatedFinishTime!),
                    primaryTextColor,
                    secondaryTextColor,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoneCard({
    required ZoneCleaningProgress zone,
    required bool isFaultOrFailed,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required bool isDark,
  }) {
    final criticalColor = isDark ? AppColors.white : AppColors.severityCritical;
    final useCritical = isFaultOrFailed && !zone.isCompleted;
    final accent = useCritical ? criticalColor : AppColors.techOrange;
    final progressFraction =
        (zone.progressPercentage / 100).clamp(0.0, 1.0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: useCritical ? AppColors.severityCritical : borderColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        zone.isCompleted
                            ? Icons.check_circle_rounded
                            : (useCritical
                                ? Icons.error_outline
                                : Icons.timelapse_rounded),
                        size: 18,
                        color: zone.isCompleted
                            ? AppColors.successGreen
                            : accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          zone.zoneName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${zone.progressPercentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: zone.isCompleted
                        ? AppColors.successGreen
                        : accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 6,
                backgroundColor: borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  zone.isCompleted ? AppColors.successGreen : accent,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cleaned ${zone.areaCleanedM2.toStringAsFixed(1)} m² of '
              '${zone.totalAreaM2.toStringAsFixed(1)} m²',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineTile({
    required JobEventTimelineItem event,
    required bool isLast,
    required bool isFaultOrFailed,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required bool isDark,
  }) {
    final criticalColor = isDark ? AppColors.white : AppColors.severityCritical;
    final isCriticalEvent = event.eventType == 'fault' ||
        event.eventType == 'failed' ||
        (isFaultOrFailed && isLast);
    final dotColor = isCriticalEvent
        ? criticalColor
        : (isLast ? AppColors.techOrange : AppColors.primaryNavy);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: Border.all(
                    color: isCriticalEvent
                        ? criticalColor
                        : (isDark
                            ? AppColors.white
                            : AppColors.primaryNavy.withValues(alpha: 0.2)),
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 44, color: borderColor),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color:
                                isCriticalEvent ? criticalColor : primaryTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatDateTime(event.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    event.description,
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(
    String label,
    String value,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: secondaryTextColor),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
      ],
    );
  }
}
