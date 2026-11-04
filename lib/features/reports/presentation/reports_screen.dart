import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/report_model.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const metrics = CleaningReportMetrics(
      jobsCompleted: 48,
      jobsFailed: 2,
      totalCleaningTime: Duration(hours: 36, minutes: 20),
      averageCoveragePercentage: 94.6,
      totalGarbageDetections: 134,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleaning Analytics & Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Weekly Performance Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard('Completed', '${metrics.jobsCompleted}', AppColors.statusCleaning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard('Failed / Fault', '${metrics.jobsFailed}', AppColors.severityCritical),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard('Avg Coverage', '${metrics.averageCoveragePercentage}%', AppColors.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard('Total Runtime', '${metrics.totalCleaningTime.inHours} hrs', AppColors.statusReturning),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, String val, Color color) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

