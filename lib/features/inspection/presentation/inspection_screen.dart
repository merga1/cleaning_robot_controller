import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../../../mock/mock_catalog.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../controls/domain/command_model.dart';
import '../../controls/presentation/controls_controller.dart';
import '../../robots/domain/robot_model.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/assessment_model.dart';

/// Inspections are read from the central demo catalogue. A real backend is not
/// bundled with this frontend-only build, so live mode fails loudly instead of
/// showing invented figures.
final inspectionAssessmentsProvider =
    FutureProvider<List<FloorAssessmentModel>>((ref) async {
  final config = ref.watch(appConfigProvider);
  final activeId = ref.watch(robotsControllerProvider).activeRobot?.id ??
      MockCatalog.alphaRobotId;

  if (!config.enableMockMode) {
    throw StateError(
      'Live data endpoint is not available in this frontend-only demo build.',
    );
  }

  await Future.delayed(const Duration(milliseconds: 250));
  return MockCatalog.assessmentsFor(robotId: activeId);
});

class InspectionScreen extends ConsumerWidget {
  const InspectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final assessmentsAsync = ref.watch(inspectionAssessmentsProvider);
    final activeRobot = ref.watch(robotsControllerProvider).activeRobot;
    final activeId = activeRobot?.id ?? MockCatalog.alphaRobotId;
    final controlsState = ref.watch(controlsControllerProvider);
    final canControl =
        ref.watch(authControllerProvider).user?.role.canControlRobots ?? false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final assessments = assessmentsAsync.value ?? const <FloorAssessmentModel>[];
    final latest = assessments.isEmpty ? null : assessments.first;
    final isStale = latest != null &&
        DateTime.now().toUtc().difference(latest.timestamp.toUtc()) >
            config.staleDataThreshold;

    final disabledReason = _commandDisabledReason(
      canControl: canControl,
      activeRobot: activeRobot,
      isInFlight: controlsState.isInFlight,
    );
    final commandStatus = _commandStatus(
      controls: controlsState,
      borderColor: borderColor,
    );

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (commandStatus != null) ...[
                  commandStatus,
                  const SizedBox(height: 10),
                ],
                if (disabledReason != null) ...[
                  Text(
                    disabledReason,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.severityWarning,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.techOrange,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor:
                        isDark ? AppColors.darkBorder : AppColors.borderBlue,
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
                  onPressed: disabledReason == null
                      ? () async {
                          // MOB-INSP-001: explain the effect before commanding.
                          final confirmed = await ConfirmationDialog.show(
                            context,
                            title: 'Trigger new inspection?',
                            message:
                                'The robot will scan the floor and produce a fresh '
                                'cleanliness assessment. It may briefly pause its '
                                'current task; no cleaning zones are changed.',
                            confirmText: 'Trigger inspection',
                          );
                          if (!confirmed || !context.mounted) return;
                          ref
                              .read(controlsControllerProvider.notifier)
                              .executeCommand(
                                robotId: activeId,
                                type: CommandType.inspectFloor,
                              );
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      body: ScreenStateBuilder(
        isLoading: assessmentsAsync.isLoading,
        errorMessage: assessmentsAsync.hasError
            ? '${assessmentsAsync.error}'
            : null,
        isEmpty: assessmentsAsync.value?.isEmpty ?? false,
        emptyMessage: 'No inspections have been recorded for this robot yet.',
        isStale: isStale,
        isDemo: config.enableMockMode,
        onRetry: () => ref.invalidate(inspectionAssessmentsProvider),
        builder: (context) => ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (latest != null) ...[
              _assessmentCard(
                assessment: latest,
                isDark: isDark,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 20),
            ],

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
            ...assessments.map(
              (assessment) => _historyItem(
                assessment: assessment,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                borderColor: borderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Commands are only offered when the role, robot state, capabilities and
  /// lifecycle all allow them - the reason is surfaced next to the button.
  String? _commandDisabledReason({
    required bool canControl,
    required RobotModel? activeRobot,
    required bool isInFlight,
  }) {
    if (!canControl) {
      return 'Your role is read-only; you cannot send robot commands.';
    }
    if (activeRobot == null) return 'No robot is selected yet.';
    if (activeRobot.connectionState == RobotConnectionState.offline) {
      return 'The active robot is offline; commands are unavailable.';
    }
    if (activeRobot.hasSafetyFault) {
      return 'An active safety fault is blocking commands.';
    }
    if (!activeRobot.capabilities.canInspect) {
      return 'The active robot does not support floor inspection.';
    }
    if (isInFlight) return 'A command is already in progress.';
    return null;
  }

  Widget? _commandStatus({
    required ControlsState controls,
    required Color borderColor,
  }) {
    final command = controls.lastCommand;
    final isInspection =
        command != null && command.type == CommandType.inspectFloor;
    if (!controls.isTimedOut && !isInspection) return null;

    final title = controls.isTimedOut
        ? 'Inspection command timed out'
        : 'Inspection command: ${command?.state.label ?? 'Unknown'}';
    final detail = controls.isTimedOut
        ? (controls.errorMessage ?? 'No acknowledgement received.')
        : command?.rejectionReason;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryNavy,
            ),
          ),
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _assessmentCard({
    required FloorAssessmentModel assessment,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    // MOB-INSP-003: a low-confidence or faulty reading is never clean/dirty.
    final conclusive = !assessment.isInconclusive;
    final scoreColor = conclusive ? AppColors.techOrange : AppColors.severityWarning;

    return Card(
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
                if (assessment.isSimulated)
                  SimulatedBadge(dark: isDark) // Source: simulated.
                else
                  const Text(
                    'Source: Real',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mutedBlue,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scoreColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: scoreColor.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${assessment.score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              assessment.resultLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Zone: ${assessment.zoneName}',
              style: TextStyle(fontSize: 13, color: secondaryTextColor),
            ),
            const SizedBox(height: 4),
            Text(
              'Confidence: ${(assessment.confidence * 100).toStringAsFixed(0)}%'
              '  •  ${formatDateTime(assessment.timestamp)} '
              '(${formatRelative(assessment.timestamp)})',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            if (!conclusive) ...[
              const SizedBox(height: 8),
              Text(
                assessment.sensorFault ??
                    'Low confidence — result is inconclusive, not clean or dirty.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.severityWarning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _historyItem({
    required FloorAssessmentModel assessment,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    final conclusive = !assessment.isInconclusive;
    final scoreColor = conclusive ? AppColors.techOrange : AppColors.severityWarning;
    final scoreText = conclusive
        ? '${assessment.score.toStringAsFixed(1)}%'
        : 'Inconclusive';
    final confidenceText = 'Score ${assessment.score.toStringAsFixed(1)}%'
        '  •  Confidence ${(assessment.confidence * 100).toStringAsFixed(0)}%';
    final timestamp = formatDateTime(assessment.timestamp);
    final source = assessment.isSimulated ? ' • Simulated' : '';
    final fault = assessment.sensorFault == null
        ? ''
        : ' • ${assessment.sensorFault}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        title: Text(
          assessment.zoneName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: primaryTextColor,
          ),
        ),
        subtitle: Text(
          '$confidenceText • $timestamp$source$fault',
          style: TextStyle(fontSize: 12, color: secondaryTextColor),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scoreColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            scoreText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: scoreColor,
            ),
          ),
        ),
      ),
    );
  }
}
