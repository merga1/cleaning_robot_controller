import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

class SafetyBanner extends StatelessWidget {
  final bool compact;

  const SafetyBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.severityWarning.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.severityWarning.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, size: 16, color: AppColors.severityWarning),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Safety notice: App is not an emergency stop.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.severityWarning,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      color: AppColors.severityWarning.withOpacity(0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        side: BorderSide(color: AppColors.severityWarning.withOpacity(0.25)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: AppColors.severityWarning, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational Safety Notice',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.severityWarning,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    AppConstants.safetyNoticeText,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

