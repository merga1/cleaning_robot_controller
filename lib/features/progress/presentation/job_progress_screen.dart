import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/job_progress_model.dart';

final jobProgressProvider =
    FutureProvider<DetailedJobProgressModel>((ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return DetailedJobProgressModel(
    jobId: 'job-9842',
    robotId: 'robot-alpha-01',
    robotName: 'CleanBot Pro (East Wing)',
    status: JobProgressStatus.active,
    overallProgress: 68.5,
    elapsedTime: const Duration(minutes: 24, seconds: 12),
    totalCoverageM2: 145.8,
    estimatedFinishTime: DateTime.now().add(const Duration(minutes: 11)),
    zones: const [
      ZoneCleaningProgress(
        zoneId: 'zone-101',
        zoneName: 'Main Reception & Lobby',
        progressPercentage: 100.0,
        areaCleanedM2: 120.5,
        totalAreaM2: 120.5,
        isCompleted: true,
      ),
      ZoneCleaningProgress(
        zoneId: 'zone-102',
        zoneName: 'North Conference Hall',
        progressPercentage: 37.0,
        areaCleanedM2: 25.3,
        totalAreaM2: 85.0,
        isCompleted: false,
      ),
    ],
    timeline: [
      JobEventTimelineItem(
        id: 'ev-1',
        eventType: 'started',
        title: 'Mission Initialized',
        description: 'Robot dispatched to Main Reception & Lobby.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 24)),
      ),
      JobEventTimelineItem(
        id: 'ev-2',
        eventType: 'obstacle',
        title: 'Dynamic Obstacle Avoided',
        description: 'Pedestrian detected in lobby corridor; path rerouted.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 16)),
      ),
      JobEventTimelineItem(
        id: 'ev-3',
        eventType: 'completed_zone',
        title: 'Zone Clean Completed',
        description: 'Main Reception & Lobby finished with 99% coverage.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
      JobEventTimelineItem(
        id: 'ev-4',
        eventType: 'active',
        title: 'Entering Next Zone',
        description: 'Cleaning North Conference Hall.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 7)),
      ),
    ],
  );
});

class JobProgressScreen extends ConsumerWidget {
  const JobProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(jobProgressProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Cleaning Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Progress',
            onPressed: () => ref.refresh(jobProgressProvider),
          ),
        ],
      ),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading progress: $err')),
        data: (job) {
          final isFaultOrFailed = job.status == JobProgressStatus.failed ||
              job.status == JobProgressStatus.faultInterrupted;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Overall Progress Card (MOB-PROG-001, MOB-PROG-004)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor),
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
                                  ? AppColors.severityCritical
                                      .withValues(alpha: 0.12)
                                  : AppColors.techOrange
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              job.status.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isFaultOrFailed
                                    ? AppColors.severityCritical
                                    : AppColors.techOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                              color: isFaultOrFailed
                                  ? AppColors.severityCritical
                                  : AppColors.techOrange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: job.overallProgress / 100,
                          minHeight: 10,
                          backgroundColor: borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isFaultOrFailed
                                ? AppColors.severityCritical
                                : AppColors.techOrange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statTile(
                            'Elapsed Time',
                            '${job.elapsedTime.inMinutes}m ${job.elapsedTime.inSeconds % 60}s',
                            primaryTextColor,
                            secondaryTextColor,
                          ),
                          _statTile(
                            'Coverage Area',
                            '${job.totalCoverageM2.toStringAsFixed(1)} m²',
                            primaryTextColor,
                            secondaryTextColor,
                          ),
                          // MOB-PROG-003: Only show ETA if supplied by backend
                          if (job.estimatedFinishTime != null)
                            _statTile(
                              'Estimated Finish',
                              '${job.estimatedFinishTime!.hour}:${job.estimatedFinishTime!.minute.toString().padLeft(2, '0')}',
                              primaryTextColor,
                              secondaryTextColor,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                (zone) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: borderColor),
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
                                        : Icons.timelapse_rounded,
                                    size: 18,
                                    color: zone.isCompleted
                                        ? AppColors.successGreen
                                        : AppColors.techOrange,
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
                                    : AppColors.techOrange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: zone.progressPercentage / 100,
                            minHeight: 6,
                            backgroundColor: borderColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              zone.isCompleted
                                  ? AppColors.successGreen
                                  : AppColors.techOrange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cleaned ${zone.areaCleanedM2.toStringAsFixed(1)} m² of ${zone.totalAreaM2} m²',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

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
              ...job.timeline.asMap().entries.map((entry) {
                final idx = entry.key;
                final event = entry.value;
                final isLast = idx == job.timeline.length - 1;

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
                              color: isLast
                                  ? AppColors.techOrange
                                  : AppColors.primaryNavy,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.white
                                    : AppColors.primaryNavy
                                        .withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 44,
                              color: borderColor,
                            ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    event.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  Text(
                                    '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}',
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
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
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
