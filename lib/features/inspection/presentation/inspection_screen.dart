import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../../controls/domain/command_model.dart';
import '../../controls/presentation/controls_controller.dart';
import '../../robots/presentation/robots_controller.dart';

class InspectionScreen extends ConsumerWidget {
  const InspectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRobot = ref.watch(robotsControllerProvider).activeRobot;
    final controlsState = ref.watch(controlsControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Cleanliness Inspection'),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.techOrange,
                foregroundColor: AppColors.white,
                disabledBackgroundColor:
                    isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.search_rounded),
              label: const Text(
                'Trigger New Inspection',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: controlsState.isInFlight || activeRobot == null
                  ? null
                  : () {
                      // MOB-INSP-001: Trigger inspection command
                      ref
                          .read(controlsControllerProvider.notifier)
                          .executeCommand(
                            robotId: activeRobot.id,
                            type: CommandType.inspectFloor,
                          );
                    },
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Active Assessment Showcase
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Latest Inspection Result',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: primaryTextColor,
                        ),
                      ),
                      if (activeRobot?.isSimulated == true)
                        SimulatedBadge(dark: isDark), // MOB-INSP-002: source real vs sim
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.techOrange.withValues(alpha: 0.12),
                      border: Border.all(
                        color: AppColors.techOrange.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '92%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.techOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Optimal Cleanliness',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Zone: Lobby & Main Hall • 0.94 Confidence',
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Zone Assessment History (MOB-INSP-004)
          Text(
            'Zone Inspection History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 10),

          _historyItem(
            zoneName: 'Conference Room North',
            scoreText: '84%',
            confidenceText: 'High (0.89)',
            timestamp: 'Today, 08:30 AM',
            isConclusive: true,
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            borderColor: borderColor,
          ),
          _historyItem(
            zoneName: 'West Wing Corridor',
            scoreText: 'Inconclusive',
            confidenceText: 'Low Confidence (0.42)',
            timestamp: 'Yesterday, 04:15 PM',
            isConclusive: false, // MOB-INSP-003: inconclusive label
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            borderColor: borderColor,
          ),
          _historyItem(
            zoneName: 'Executive Suites',
            scoreText: '96%',
            confidenceText: 'High (0.97)',
            timestamp: 'Yesterday, 11:20 AM',
            isConclusive: true,
            isDark: isDark,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            borderColor: borderColor,
          ),
        ],
      ),
    );
  }

  Widget _historyItem({
    required String zoneName,
    required String scoreText,
    required String confidenceText,
    required String timestamp,
    required bool isConclusive,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        title: Text(
          zoneName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: primaryTextColor,
          ),
        ),
        subtitle: Text(
          '$confidenceText • $timestamp',
          style: TextStyle(fontSize: 12, color: secondaryTextColor),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isConclusive
                ? AppColors.techOrange.withValues(alpha: 0.12)
                : AppColors.severityWarning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            scoreText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isConclusive
                  ? AppColors.techOrange
                  : AppColors.severityWarning,
            ),
          ),
        ),
      ),
    );
  }
}
