import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SimulatedBadge extends StatelessWidget {
  const SimulatedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.simulatedBadgeBackground,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.simulatedBadgeText.withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.precision_manufacturing_outlined,
            size: 13,
            color: AppColors.simulatedBadgeText,
          ),
          SizedBox(width: 4),
          Text(
            'Simulated',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.simulatedBadgeText,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

