import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CapacityGauge extends StatelessWidget {
  final int fillPercentage;
  final bool hasSensorFault;
  final double height;

  const CapacityGauge({
    super.key,
    required this.fillPercentage,
    this.hasSensorFault = false,
    this.height = 10,
  });

  Color get _fillColor {
    if (fillPercentage >= 85) return AppColors.levelCritical;
    if (fillPercentage >= 65) return AppColors.techOrange;
    return AppColors.primaryNavy;
  }

  @override
  Widget build(BuildContext context) {
    if (hasSensorFault) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.severityCritical.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: AppColors.severityCritical.withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child: const Text(
          'SENSOR FAULT',
          style: TextStyle(
            color: AppColors.severityCritical,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    final clampedFill = (fillPercentage / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            color: AppColors.lightBorder,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clampedFill,
              child: Container(color: _fillColor),
            ),
          ),
        ),
      ],
    );
  }
}
