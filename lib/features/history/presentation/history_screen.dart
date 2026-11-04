import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CleaningJobHistoryItem {
  final String id;
  final String robotName;
  final String zones;
  final String outcome; // completed, failed, cancelled
  final Duration duration;
  final double coverageM2;
  final DateTime date;

  CleaningJobHistoryItem({
    required this.id,
    required this.robotName,
    required this.zones,
    required this.outcome,
    required this.duration,
    required this.coverageM2,
    required this.date,
  });
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = [
      CleaningJobHistoryItem(
        id: 'job-9840',
        robotName: 'CleanBot Pro',
        zones: 'Main Lobby & Atrium',
        outcome: 'Completed',
        duration: const Duration(minutes: 42),
        coverageM2: 240.5,
        date: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      CleaningJobHistoryItem(
        id: 'job-9839',
        robotName: 'CleanBot Pro',
        zones: 'North Conference Hall',
        outcome: 'Completed',
        duration: const Duration(minutes: 28),
        coverageM2: 120.0,
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
      CleaningJobHistoryItem(
        id: 'job-9838',
        robotName: 'CleanBot Yard Guard',
        zones: 'Outer Courtyard',
        outcome: 'Fault Interrupted', // MOB-PROG-004
        duration: const Duration(minutes: 12),
        coverageM2: 45.2,
        date: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleaning Mission History'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final job = history[index];
          final isSuccess = job.outcome == 'Completed';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.lightBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        job.zones,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSuccess
                              ? AppColors.statusCleaning.withOpacity(0.12)
                              : AppColors.severityCritical.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          job.outcome,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSuccess
                                ? AppColors.statusCleaning
                                : AppColors.severityCritical,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Robot: ${job.robotName} • Mission ID: ${job.id}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Duration: ${job.duration.inMinutes} mins',
                          style: const TextStyle(fontSize: 13)),
                      Text('Coverage: ${job.coverageM2} m²',
                          style: const TextStyle(fontSize: 13)),
                      Text(
                        '${job.date.month}/${job.date.day} ${job.date.hour}:${job.date.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

