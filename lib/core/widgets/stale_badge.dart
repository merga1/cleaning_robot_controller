import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StaleBadge extends StatelessWidget {
  final String label;

  const StaleBadge({super.key, this.label = 'Stale'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.staleBadgeBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.staleBadgeText.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 12, color: AppColors.staleBadgeText),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.staleBadgeText,
            ),
          ),
        ],
      ),
    );
  }
}
