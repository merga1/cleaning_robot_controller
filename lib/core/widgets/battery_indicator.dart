import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BatteryIndicator extends StatelessWidget {
  final int levelPercentage;
  final bool isCharging;
  final bool showLabel;
  final bool isAppBar;

  const BatteryIndicator({
    super.key,
    required this.levelPercentage,
    this.isCharging = false,
    this.showLabel = true,
    this.isAppBar = false,
  });

  Color get _color {
    if (levelPercentage <= 20) return AppColors.levelCritical;
    if (levelPercentage <= 50) return AppColors.levelWarning;
    return AppColors.levelNormal;
  }

  IconData get _icon {
    if (isCharging) return Icons.battery_charging_full_rounded;
    if (levelPercentage <= 15) return Icons.battery_alert_rounded;
    if (levelPercentage <= 30) return Icons.battery_3_bar_rounded;
    if (levelPercentage <= 60) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (isAppBar) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              color: isCharging ? AppColors.techOrange : AppColors.white,
              size: 16,
            ),
            if (showLabel) ...[
              const SizedBox(width: 4),
              Text(
                '$levelPercentage%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, color: _color, size: 20),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            '$levelPercentage%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _color,
            ),
          ),
        ],
      ],
    );
  }
}
