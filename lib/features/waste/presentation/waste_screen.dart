import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/capacity_gauge.dart';
import '../../dashboard/presentation/dashboard_controller.dart';

class WasteScreen extends ConsumerWidget {
  const WasteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardSummary = ref.watch(dashboardControllerProvider).summary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final fillPercentage = dashboardSummary?.wasteFillPercentage ?? 54;
    final hasSensorFault = dashboardSummary?.wasteSensorFault ?? false;
    final isFull = fillPercentage >= 90;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Container Monitoring'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Full Alert Banner (MOB-WASTE-004)
          if (isFull) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.severityCritical.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.severityCritical.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: AppColors.severityCritical,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Container Capacity Exceeded',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.severityCritical,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Empty the physical waste container before dispatching new cleaning tasks.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
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
                    hasSensorFault ? 'SENSOR FAULT' : '$fillPercentage%',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: hasSensorFault
                          ? AppColors.severityCritical
                          : fillPercentage >= 85
                              ? AppColors.levelCritical
                              : AppColors.techOrange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CapacityGauge(
                    fillPercentage: fillPercentage,
                    hasSensorFault: hasSensorFault,
                    height: 14,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    hasSensorFault
                        ? 'Diagnostic error: Container sensor unresponsive.'
                        : fillPercentage >= 85
                            ? 'Warning: Reaching maximum capacity limit.'
                            : 'Normal operating range.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: hasSensorFault
                          ? AppColors.severityCritical
                          : secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Reading History Timeline (MOB-WASTE-002)
          Text(
            'Recent Fill Readings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 10),

          _buildReadingItem(
            '54%',
            '10 mins ago',
            'Routine cycle update',
            AppColors.techOrange,
            primaryTextColor,
            secondaryTextColor,
            borderColor,
            isDark,
          ),
          _buildReadingItem(
            '48%',
            '35 mins ago',
            'Routine cycle update',
            AppColors.primaryNavy,
            primaryTextColor,
            secondaryTextColor,
            borderColor,
            isDark,
          ),
          _buildReadingItem(
            '32%',
            '1 hour ago',
            'Routine cycle update',
            AppColors.primaryNavy,
            primaryTextColor,
            secondaryTextColor,
            borderColor,
            isDark,
          ),
          _buildReadingItem(
            '0%',
            '2 hours ago',
            'Manual bin dump confirmed',
            AppColors.successGreen,
            primaryTextColor,
            secondaryTextColor,
            borderColor,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildReadingItem(
    String value,
    String time,
    String desc,
    Color color,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
    bool isDark,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: isDark ? 0.3 : 0.12),
          child: Text(
            value,
            style: TextStyle(
              color: color == AppColors.primaryNavy && isDark
                  ? AppColors.white
                  : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          desc,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        trailing: Text(
          time,
          style: TextStyle(fontSize: 12, color: secondaryTextColor),
        ),
      ),
    );
  }
}
