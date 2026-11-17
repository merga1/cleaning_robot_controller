import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../robots/domain/robot_model.dart';
import '../../domain/command_model.dart';
import '../controls_controller.dart';

class ControlPanel extends ConsumerWidget {
  final RobotModel robot;

  const ControlPanel({super.key, required this.robot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    // MOB-CTRL-003: Read-only users shall NOT see command controls
    if (user != null && !user.role.canControlRobots) {
      return Card(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.primaryNavy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Operator permissions required to dispatch commands. You are logged in as Supervisor / Read-Only.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controlsState = ref.watch(controlsControllerProvider);
    final isInFlight = controlsState.isInFlight;
    final lastCommand = controlsState.lastCommand;

    // MOB-SAF-002 / MOB-CTRL-010: reasons shared by every command. Safety
    // faults take precedence over connectivity and in-flight state.
    String? globalReason;
    if (robot.hasSafetyFault) {
      globalReason =
          'Safety fault active — the local safety controller is blocking '
          'commands.';
    } else if (robot.connectionState == RobotConnectionState.offline) {
      globalReason = 'Robot is offline — commands cannot be delivered.';
    } else if (isInFlight) {
      globalReason = 'A command is already in progress.';
    }

    // MOB-CTRL-002/004: capability- and state-specific reasons.
    String? commandReason(CommandType type) {
      final global = globalReason;
      if (global != null) return global;
      final capabilities = robot.capabilities;
      switch (type) {
        case CommandType.call:
          if (!capabilities.canCall) {
            return 'Call is not supported by this robot model.';
          }
          return null;
        case CommandType.inspectFloor:
          if (!capabilities.canInspect) {
            return 'Floor inspection is not supported by this robot model.';
          }
          return null;
        case CommandType.startCleaning:
          if (!capabilities.canClean) {
            return 'Cleaning is not supported by this robot model.';
          }
          if (robot.status != RobotOperationalStatus.idle) {
            return 'Start is available only while the robot is idle '
                '(currently ${robot.status.displayName}).';
          }
          return null;
        case CommandType.pause:
          if (!capabilities.canPause) {
            return 'Pause is not supported by this robot model.';
          }
          if (robot.status != RobotOperationalStatus.cleaning) {
            return 'Pause is available only while cleaning.';
          }
          return null;
        case CommandType.resume:
          if (!capabilities.canResume) {
            return 'Resume is not supported by this robot model.';
          }
          if (robot.status != RobotOperationalStatus.paused) {
            return 'Resume is available only while paused.';
          }
          return null;
        case CommandType.cancel:
          if (!capabilities.canCancel) {
            return 'Cancel is not supported by this robot model.';
          }
          if (robot.status != RobotOperationalStatus.cleaning &&
              robot.status != RobotOperationalStatus.navigating) {
            return 'Cancel is available only while cleaning or navigating.';
          }
          return null;
        case CommandType.returnToDock:
          if (!capabilities.canDock) {
            return 'Docking is not supported by this robot model.';
          }
          if (robot.status == RobotOperationalStatus.charging) {
            return 'The robot is already charging.';
          }
          if (robot.status == RobotOperationalStatus.returning) {
            return 'The robot is already returning to the dock.';
          }
          return null;
        case CommandType.requestStatusRefresh:
          return null;
      }
    }

    final CommandType primaryType;
    final IconData primaryIcon;
    final String primaryLabel;
    if (robot.status == RobotOperationalStatus.cleaning) {
      primaryType = CommandType.pause;
      primaryIcon = Icons.pause_circle_filled_rounded;
      primaryLabel = 'Pause Cleaning Mission';
    } else if (robot.status == RobotOperationalStatus.paused) {
      primaryType = CommandType.resume;
      primaryIcon = Icons.play_circle_fill_rounded;
      primaryLabel = 'Resume Cleaning Mission';
    } else {
      primaryType = CommandType.startCleaning;
      primaryIcon = Icons.cleaning_services_rounded;
      primaryLabel = 'Start Cleaning Mission';
    }

    return Card(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.gamepad_outlined,
                        size: 16,
                        color: AppColors.techOrange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Robot Command Console',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
                if (isInFlight)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.techOrange,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // MOB-SAF-002: a safety fault is called out explicitly.
            if (robot.hasSafetyFault) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.severityCritical.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.severityCritical.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.dangerous_outlined,
                      size: 18,
                      color: AppColors.severityCritical,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Safety fault reported. All robot commands are blocked '
                        'until the local safety controller clears it.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.severityCritical,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Command Lifecycle Badge (MOB-CTRL-006, Section 7)
            if (lastCommand != null)
              _buildCommandBadge(context, ref, controlsState),

            // Primary Movement & Operation Controls
            Column(
              children: [
                // Prominent Primary Action (Technology Orange)
                _buildPrimaryActionButton(
                  context: context,
                  ref: ref,
                  type: primaryType,
                  icon: primaryIcon,
                  label: primaryLabel,
                  disabledReason: commandReason(primaryType),
                  backgroundColor: AppColors.techOrange,
                ),
                const SizedBox(height: 10),

                // Secondary Navigation and Inspection Commands
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSecondaryActionButton(
                        context: context,
                        ref: ref,
                        type: CommandType.call,
                        icon: Icons.ring_volume_rounded,
                        label: 'Call Robot',
                        disabledReason: commandReason(CommandType.call),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSecondaryActionButton(
                        context: context,
                        ref: ref,
                        type: CommandType.inspectFloor,
                        icon: Icons.search_rounded,
                        label: 'Inspect Floor',
                        disabledReason: commandReason(CommandType.inspectFloor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSecondaryActionButton(
                        context: context,
                        ref: ref,
                        type: CommandType.returnToDock,
                        icon: Icons.home_rounded,
                        label: 'Return to Dock',
                        disabledReason: commandReason(CommandType.returnToDock),
                        isDisruptive:
                            robot.status == RobotOperationalStatus.cleaning,
                      ),
                    ),
                    if (robot.status == RobotOperationalStatus.cleaning ||
                        robot.status == RobotOperationalStatus.navigating) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSecondaryActionButton(
                          context: context,
                          ref: ref,
                          type: CommandType.cancel,
                          icon: Icons.cancel_rounded,
                          label: 'Cancel Run',
                          disabledReason: commandReason(CommandType.cancel),
                          isDisruptive: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandBadge(
    BuildContext context,
    WidgetRef ref,
    ControlsState controlsState,
  ) {
    final command = controlsState.lastCommand!;
    final state = command.state;
    final color = _stateColor(state);
    final isFailure =
        state == CommandLifecycleState.rejected ||
        state == CommandLifecycleState.failed ||
        state == CommandLifecycleState.expired;
    final noAcknowledgement =
        controlsState.isTimedOut || state == CommandLifecycleState.expired;
    final reason = command.rejectionReason ?? controlsState.errorMessage;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_stateIcon(state), size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${command.type.displayName}: ${state.label}',
                  style: TextStyle(
                    fontSize: 12,
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
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
          ],
          if (isFailure && reason == null) ...[
            const SizedBox(height: 6),
            Text(
              state.label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.secondaryText,
              ),
            ),
          ],
          // MOB-CTRL-009: an unacknowledged command is recoverable in place.
          if (noAcknowledgement) ...[
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

  Widget _buildPrimaryActionButton({
    required BuildContext context,
    required WidgetRef ref,
    required CommandType type,
    required IconData icon,
    required String label,
    required String? disabledReason,
    required Color backgroundColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: AppColors.white,
            disabledBackgroundColor: AppColors.paleBlue,
            minimumSize: const Size.fromHeight(50),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(icon, size: 22),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          onPressed: disabledReason == null
              ? () => _handleCommandTap(context, ref, type, false)
              : null,
        ),
        if (disabledReason != null) _buildDisabledReason(disabledReason),
      ],
    );
  }

  Widget _buildSecondaryActionButton({
    required BuildContext context,
    required WidgetRef ref,
    required CommandType type,
    required IconData icon,
    required String label,
    required String? disabledReason,
    bool isDisruptive = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDisruptive
                ? AppColors.severityCritical
                : AppColors.primaryNavy,
            backgroundColor: isDisruptive
                ? AppColors.severityCritical.withValues(alpha: 0.05)
                : AppColors.white,
            side: BorderSide(
              color: isDisruptive
                  ? AppColors.severityCritical.withValues(alpha: 0.4)
                  : AppColors.lightBorder,
              width: 1.5,
            ),
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: disabledReason == null
              ? () => _handleCommandTap(context, ref, type, isDisruptive)
              : null,
        ),
        if (disabledReason != null) _buildDisabledReason(disabledReason),
      ],
    );
  }

  Widget _buildDisabledReason(String reason) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 12, color: AppColors.mutedBlue),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(fontSize: 11, color: AppColors.mutedBlue),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCommandTap(
    BuildContext context,
    WidgetRef ref,
    CommandType type,
    bool isDisruptive,
  ) async {
    if (isDisruptive || type.isDisruptive) {
      final confirmed = await ConfirmationDialog.show(
        context,
        title: 'Confirm ${type.displayName}',
        message:
            '${_effectStatement(type)}\n\n'
            'The command is sent to the robot and its acknowledgement is '
            'shown in the command console.',
        isDestructive: isDisruptive,
      );
      if (!confirmed) return;
    }

    ref
        .read(controlsControllerProvider.notifier)
        .executeCommand(robotId: robot.id, type: type);
  }

  /// Explicit, action-specific effects for disruptive confirmations.
  String _effectStatement(CommandType type) {
    switch (type) {
      case CommandType.startCleaning:
        return 'The robot will travel to the selected zones and begin '
            'physical cleaning now.';
      case CommandType.pause:
        return 'The current cleaning pass will be held until it is resumed.';
      case CommandType.resume:
        return 'The held cleaning pass will continue from the current position.';
      case CommandType.cancel:
        return 'The current cleaning run will be ended and the robot will be '
            'available for a new assignment.';
      case CommandType.returnToDock:
        return 'The robot will navigate back to its dock and begin charging; '
            'the current cleaning run will be ended.';
      case CommandType.call:
        return 'The robot will signal its location so an operator can find it.';
      case CommandType.inspectFloor:
        return 'The robot will perform a floor assessment and record a '
            'cleanliness reading.';
      case CommandType.requestStatusRefresh:
        return 'A fresh status snapshot will be requested from the robot.';
    }
  }

  Color _stateColor(CommandLifecycleState state) {
    switch (state) {
      case CommandLifecycleState.completed:
      case CommandLifecycleState.accepted:
        return AppColors.levelNormal;
      case CommandLifecycleState.rejected:
      case CommandLifecycleState.failed:
      case CommandLifecycleState.expired:
        return AppColors.severityCritical;
      case CommandLifecycleState.executing:
      case CommandLifecycleState.dispatched:
        return AppColors.techOrange;
      case CommandLifecycleState.cancelled:
        return AppColors.mutedBlue;
      case CommandLifecycleState.submitting:
      case CommandLifecycleState.pending:
        return AppColors.primaryNavy;
    }
  }

  IconData _stateIcon(CommandLifecycleState state) {
    switch (state) {
      case CommandLifecycleState.completed:
        return Icons.check_circle_outline;
      case CommandLifecycleState.executing:
        return Icons.autorenew_rounded;
      case CommandLifecycleState.rejected:
      case CommandLifecycleState.failed:
      case CommandLifecycleState.expired:
        return Icons.error_outline;
      case CommandLifecycleState.cancelled:
        return Icons.cancel_outlined;
      case CommandLifecycleState.submitting:
      case CommandLifecycleState.pending:
      case CommandLifecycleState.dispatched:
      case CommandLifecycleState.accepted:
        return Icons.info_outline;
    }
  }
}
