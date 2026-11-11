import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/report_model.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

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
          Text(
            'Weekly Performance Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Completed Missions',
                  '${metrics.jobsCompleted}',
                  AppColors.successGreen,
                  primaryTextColor,
                  secondaryTextColor,
                  borderColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Failed / Faults',
                  '${metrics.jobsFailed}',
                  AppColors.severityCritical,
                  primaryTextColor,
                  secondaryTextColor,
                  borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Avg Coverage',
                  '${metrics.averageCoveragePercentage}%',
                  AppColors.techOrange,
                  primaryTextColor,
                  secondaryTextColor,
                  borderColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricCard(
                  'Total Runtime',
                  '${metrics.totalCleaningTime.inHours}h ${metrics.totalCleaningTime.inMinutes % 60}m',
                  isDark ? AppColors.white : AppColors.primaryNavy,
                  primaryTextColor,
                  secondaryTextColor,
                  borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.techOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.scatter_plot_outlined,
                      color: AppColors.techOrange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total AI Garbage Detections',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${metrics.totalGarbageDetections} Objects',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
    String title,
    String val,
    Color color,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              val,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
