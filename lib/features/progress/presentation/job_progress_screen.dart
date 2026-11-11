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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Cleaning Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                  side: const BorderSide(color: AppColors.lightBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.robotName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Mission #${job.jobId}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isFaultOrFailed
                                  ? AppColors.severityCritical
                                      .withValues(alpha: 0.12)
                                  : AppColors.statusCleaning
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
                                    : AppColors.statusCleaning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Overall Progress',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${job.overallProgress.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
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
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isFaultOrFailed
                                ? AppColors.severityCritical
                                : AppColors.statusCleaning,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statTile('Elapsed Time',
                              '${job.elapsedTime.inMinutes}m ${job.elapsedTime.inSeconds % 60}s'),
                          _statTile('Coverage Area',
                              '${job.totalCoverageM2.toStringAsFixed(1)} m²'),
                          // MOB-PROG-003: Only show ETA if supplied by backend
                          if (job.estimatedFinishTime != null)
                            _statTile(
                              'Estimated Finish',
                              '${job.estimatedFinishTime!.hour}:${job.estimatedFinishTime!.minute.toString().padLeft(2, '0')}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Per-Zone Progress Breakdown (MOB-PROG-001)
              const Text(
                'Per-Zone Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...job.zones.map(
                (zone) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.lightBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  zone.isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.timelapse_rounded,
                                  size: 18,
                                  color: zone.isCompleted
                                      ? AppColors.statusCleaning
                                      : AppColors.primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  zone.zoneName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${zone.progressPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: zone.progressPercentage / 100,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              zone.isCompleted
                                  ? AppColors.statusCleaning
                                  : AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cleaned ${zone.areaCleanedM2.toStringAsFixed(1)} m² of ${zone.totalAreaM2} m²',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Event Timeline (MOB-PROG-002)
              const Text(
                'Mission Event Timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...job.timeline.map((event) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 40,
                            color: const Color(0xFFE2E8F0),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              event.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
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

  Widget _statTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

