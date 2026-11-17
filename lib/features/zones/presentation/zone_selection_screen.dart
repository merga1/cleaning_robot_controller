import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../controls/domain/command_model.dart';
import '../../controls/presentation/controls_controller.dart';
import '../../robots/domain/robot_model.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/zone_model.dart';
import 'zones_controller.dart';

class ZoneSelectionScreen extends ConsumerStatefulWidget {
  const ZoneSelectionScreen({super.key});

  @override
  ConsumerState<ZoneSelectionScreen> createState() =>
      _ZoneSelectionScreenState();
}

class _ZoneSelectionScreenState extends ConsumerState<ZoneSelectionScreen> {
  final Set<String> _selectedZoneIds = {};
  String? _submittedCommandId;

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zonesListProvider);
    final activeRobot = ref.watch(robotsControllerProvider).activeRobot;
    final user = ref.watch(authControllerProvider).user;
    final controlsState = ref.watch(controlsControllerProvider);
    final isMockMode = ref.watch(appConfigProvider).enableMockMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor = isDark
        ? Colors.white70
        : AppColors.secondaryText;

    final zones = zonesAsync.value ?? const <ZoneModel>[];
    // MOB-ZONE-003: unavailable zones are never selectable, even if their
    // availability changed after they were ticked.
    final selectableZones = zones.where((zone) => zone.isAvailable).toList();
    final selectedZones = selectableZones
        .where((zone) => _selectedZoneIds.contains(zone.id))
        .toList();
    final totalArea = selectedZones.fold<double>(
      0,
      (sum, zone) => sum + zone.areaM2,
    );

    final canControl = user?.role.canControlRobots ?? false;
    String? disabledReason;
    if (!canControl) {
      disabledReason =
          'Operator permissions are required to dispatch commands. '
          'This account is read-only.';
    } else if (activeRobot == null) {
      disabledReason = 'Select a robot before starting a cleaning run.';
    } else if (activeRobot.connectionState == RobotConnectionState.offline) {
      disabledReason =
          '${activeRobot.name} is offline — cleaning runs cannot be dispatched.';
    } else if (activeRobot.hasSafetyFault) {
      disabledReason =
          '${activeRobot.name} has an active safety fault. Commands are blocked '
          'by the local safety controller.';
    } else if (selectedZones.isEmpty) {
      disabledReason = 'Select at least one available zone.';
    } else if (controlsState.isInFlight) {
      disabledReason = 'A command is already in progress.';
    }
    final canStart = disabledReason == null;

    final showCommandState =
        _submittedCommandId != null &&
        controlsState.lastCommand?.id == _submittedCommandId;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Cleaning Zones')),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!canStart) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppColors.mutedBlue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            disabledReason,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.techOrange,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: isDark
                        ? AppColors.darkBorder
                        : AppColors.borderBlue,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.cleaning_services_rounded, size: 20),
                  onPressed: canStart
                      ? () => _confirmAndDispatch(
                          robot: activeRobot!,
                          selectedZones: selectedZones,
                          totalArea: totalArea,
                        )
                      : null,
                  label: Text(
                    selectedZones.isEmpty
                        ? 'Select Zones to Clean'
                        : 'Start Cleaning (${selectedZones.length} Zones)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // MOB-CTRL-006/009: never assume the dispatch succeeded. The command
          // state is shown here until the user navigates away explicitly.
          if (showCommandState)
            _buildCommandStateBanner(
              context,
              controlsState,
              activeRobot,
              isDark,
            ),
          Expanded(
            child: ScreenStateBuilder(
              isLoading: zonesAsync.isLoading,
              errorMessage: zonesAsync.hasError
                  ? zonesAsync.error.toString()
                  : null,
              isEmpty: zonesAsync.hasValue && zones.isEmpty,
              isDemo: isMockMode,
              isSimulated: activeRobot?.isSimulated == true,
              emptyMessage: 'No zones are configured for this robot.',
              onRetry: () => ref.invalidate(zonesListProvider),
              builder: (context) => ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: zones.length,
                itemBuilder: (context, index) {
                  final zone = zones[index];
                  final isSelected = _selectedZoneIds.contains(zone.id);

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.techOrange
                            : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      activeColor: AppColors.techOrange,
                      checkColor: AppColors.white,
                      value: isSelected,
                      enabled: zone.isAvailable, // MOB-ZONE-003
                      onChanged: (bool? checked) {
                        if (!zone.isAvailable) return;
                        setState(() {
                          if (checked == true) {
                            _selectedZoneIds.add(zone.id);
                          } else {
                            _selectedZoneIds.remove(zone.id);
                          }
                        });
                      },
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              zone.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: zone.isAvailable
                                    ? primaryTextColor
                                    : secondaryTextColor,
                              ),
                            ),
                          ),
                          if (!zone.isAvailable)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkBackground
                                    : AppColors.softBlue,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Unavailable',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'Area: ${zone.areaM2.toStringAsFixed(1)} m²',
                            style: TextStyle(
                              fontSize: 13,
                              color: primaryTextColor.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (zone.lastCleanedAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Last cleaned: '
                              '${formatDateTime(zone.lastCleanedAt!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                          if (!zone.isAvailable &&
                              zone.unavailabilityReason != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Reason: ${zone.unavailabilityReason}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.techOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDispatch({
    required RobotModel robot,
    required List<ZoneModel> selectedZones,
    required double totalArea,
  }) async {
    if (selectedZones.isEmpty) return;

    // MOB-ZONE-004: zone names, total area and the physical effect are all
    // included in the confirmation, not just a count.
    final zoneNames = selectedZones.map((zone) => '• ${zone.name}').join('\n');
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Start Cleaning Run',
      message:
          'Dispatch ${robot.name} to clean:\n'
          '$zoneNames\n\n'
          'Total area: ${totalArea.toStringAsFixed(1)} m²\n\n'
          'This will send the robot to physically travel to these zones and '
          'begin cleaning now. Any current run will be replaced.',
      confirmText: 'Dispatch Robot',
    );

    if (!confirmed || !mounted) return;

    await ref
        .read(controlsControllerProvider.notifier)
        .executeCommand(
          robotId: robot.id,
          type: CommandType.startCleaning,
          parameters: {'zones': selectedZones.map((zone) => zone.id).toList()},
        );
    if (!mounted) return;

    final result = ref.read(controlsControllerProvider);
    final command = result.lastCommand;
    setState(() {
      _submittedCommandId = command?.id;
    });

    // Do not navigate on a failed or unacknowledged submission: the inline
    // banner above keeps the real command state visible.
    final isFailed =
        command == null ||
        result.errorMessage != null ||
        result.isTimedOut ||
        _isFailedState(command.state);
    if (!isFailed && context.mounted) {
      context.go('/dashboard');
    }
  }

  bool _isFailedState(CommandLifecycleState state) {
    return state == CommandLifecycleState.rejected ||
        state == CommandLifecycleState.failed ||
        state == CommandLifecycleState.expired ||
        state == CommandLifecycleState.cancelled;
  }

  Widget _buildCommandStateBanner(
    BuildContext context,
    ControlsState controlsState,
    RobotModel? robot,
    bool isDark,
  ) {
    final command = controlsState.lastCommand;
    if (command == null) return const SizedBox.shrink();

    final isFailed =
        _isFailedState(command.state) ||
        controlsState.errorMessage != null ||
        controlsState.isTimedOut;
    final color = isFailed ? AppColors.severityCritical : AppColors.techOrange;
    final noAcknowledgement =
        controlsState.isTimedOut ||
        command.state == CommandLifecycleState.expired;
    final reason = command.rejectionReason ?? controlsState.errorMessage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: color.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${command.type.displayName}: ${command.state.label}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reason,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : AppColors.secondaryText,
              ),
            ),
          ],
          if (noAcknowledgement && robot != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: controlsState.isInFlight
                      ? null
                      : () => ref
                            .read(controlsControllerProvider.notifier)
                            .retryLastCommand(robotId: robot.id),
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: controlsState.isInFlight
                      ? null
                      : () => ref
                            .read(controlsControllerProvider.notifier)
                            .checkStatus(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Check Status'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
