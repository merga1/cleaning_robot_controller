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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Cleanliness Inspection'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Trigger New Inspection'),
            onPressed: controlsState.isInFlight || activeRobot == null
                ? null
                : () {
                    // MOB-INSP-001: Trigger inspection command
                    ref.read(controlsControllerProvider.notifier).executeCommand(
                          robotId: activeRobot.id,
                          type: CommandType.inspectFloor,
                        );
                  },
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
              side: const BorderSide(color: AppColors.lightBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Latest Inspection Result',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (activeRobot?.isSimulated == true)
                        const SimulatedBadge(), // MOB-INSP-002: source real vs sim
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.statusCleaning.withOpacity(0.1),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '92%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.statusCleaning,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Optimal Cleanliness',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Zone: Lobby & Main Hall • 0.94 Confidence',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Zone Assessment History (MOB-INSP-004)
          const Text(
            'Zone Inspection History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _historyItem(
            zoneName: 'Conference Room North',
            scoreText: '84%',
            confidenceText: 'High (0.89)',
            timestamp: 'Today, 08:30 AM',
            isConclusive: true,
          ),
          _historyItem(
            zoneName: 'West Wing Corridor',
            scoreText: 'Inconclusive',
            confidenceText: 'Low Confidence (0.42)',
            timestamp: 'Yesterday, 04:15 PM',
            isConclusive: false, // MOB-INSP-003: inconclusive label
          ),
          _historyItem(
            zoneName: 'Executive Suites',
            scoreText: '96%',
            confidenceText: 'High (0.97)',
            timestamp: 'Yesterday, 11:20 AM',
            isConclusive: true,
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
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      child: ListTile(
        title: Text(zoneName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('$confidenceText • $timestamp', style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isConclusive
                ? AppColors.statusCleaning.withOpacity(0.1)
                : AppColors.severityWarning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            scoreText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isConclusive ? AppColors.statusCleaning : AppColors.severityWarning,
            ),
          ),
        ),
      ),
    );
  }
}

