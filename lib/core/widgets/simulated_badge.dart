import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SimulatedBadge extends StatelessWidget {
  final bool dark;

  const SimulatedBadge({super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.techOrange.withValues(alpha: 0.25)
            : AppColors.simulatedBadgeBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: dark
              ? AppColors.techOrange
              : AppColors.simulatedBadgeText.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.precision_manufacturing_outlined,
            size: 13,
            color: dark ? AppColors.techOrange : AppColors.simulatedBadgeText,
          ),
          const SizedBox(width: 4),
          Text(
            'Simulated',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: dark ? AppColors.white : AppColors.simulatedBadgeText,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
