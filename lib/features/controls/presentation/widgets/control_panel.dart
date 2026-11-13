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

            // Command Lifecycle Badge (MOB-CTRL-006, Section 7)
            if (lastCommand != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: lastCommand.state == CommandLifecycleState.failed ||
                          lastCommand.state == CommandLifecycleState.rejected
                      ? AppColors.severityCritical.withValues(alpha: 0.1)
                      : lastCommand.state == CommandLifecycleState.executing
                          ? AppColors.techOrange.withValues(alpha: 0.12)
                          : AppColors.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: lastCommand.state == CommandLifecycleState.failed ||
                            lastCommand.state == CommandLifecycleState.rejected
                        ? AppColors.severityCritical.withValues(alpha: 0.3)
                        : lastCommand.state == CommandLifecycleState.executing
                            ? AppColors.techOrange.withValues(alpha: 0.5)
                            : AppColors.primaryNavy.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      lastCommand.state == CommandLifecycleState.completed
                          ? Icons.check_circle_outline
                          : lastCommand.state == CommandLifecycleState.executing
                              ? Icons.autorenew_rounded
                              : Icons.info_outline,
                      size: 18,
                      color: lastCommand.state == CommandLifecycleState.failed
                          ? AppColors.severityCritical
                          : lastCommand.state == CommandLifecycleState.executing
                              ? AppColors.techOrange
                              : AppColors.primaryNavy,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${lastCommand.type.displayName}: ${lastCommand.state.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: lastCommand.state == CommandLifecycleState.failed
                              ? AppColors.severityCritical
                              : lastCommand.state == CommandLifecycleState.executing
                                  ? AppColors.techOrange
                                  : AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Primary Movement & Operation Controls
            Column(
              children: [
                // Prominent Primary Action (Technology Orange)
                if (robot.status == RobotOperationalStatus.cleaning)
                  _buildPrimaryActionButton(
                    context: context,
                    ref: ref,
                    type: CommandType.pause,
                    icon: Icons.pause_circle_filled_rounded,
                    label: 'Pause Cleaning Mission',
                    isEnabled: !isInFlight && robot.capabilities.canPause,
                    backgroundColor: AppColors.techOrange,
                  )
                else if (robot.status == RobotOperationalStatus.paused)
                  _buildPrimaryActionButton(
                    context: context,
                    ref: ref,
                    type: CommandType.resume,
                    icon: Icons.play_circle_fill_rounded,
                    label: 'Resume Cleaning Mission',
                    isEnabled: !isInFlight && robot.capabilities.canResume,
                    backgroundColor: AppColors.techOrange,
                  )
                else
                  _buildPrimaryActionButton(
                    context: context,
                    ref: ref,
                    type: CommandType.startCleaning,
                    icon: Icons.cleaning_services_rounded,
                    label: 'Start Cleaning Mission',
                    isEnabled: !isInFlight &&
                        robot.capabilities.canClean &&
                        robot.connectionState != RobotConnectionState.offline,
                    backgroundColor: AppColors.techOrange,
                  ),
                const SizedBox(height: 10),

                // Secondary Navigation and Inspection Commands (Navy & Secondary Blue)
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryActionButton(
                        context: context,
                        ref: ref,
                        type: CommandType.call,
                        icon: Icons.ring_volume_rounded,
                        label: 'Call Robot',
                        isEnabled: !isInFlight && robot.capabilities.canCall,
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
                        isEnabled: !isInFlight && robot.capabilities.canInspect,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryActionButton(
                        context: context,
                        ref: ref,
                        type: CommandType.returnToDock,
                        icon: Icons.home_rounded,
                        label: 'Return to Dock',
                        isEnabled: !isInFlight &&
                            robot.capabilities.canDock &&
                            robot.status != RobotOperationalStatus.charging,
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
                          isEnabled: !isInFlight && robot.capabilities.canCancel,
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

  Widget _buildPrimaryActionButton({
    required BuildContext context,
    required WidgetRef ref,
    required CommandType type,
    required IconData icon,
    required String label,
    required bool isEnabled,
    required Color backgroundColor,
  }) {
    return ElevatedButton.icon(
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
      onPressed: isEnabled
          ? () => _handleCommandTap(context, ref, type, false)
          : null,
    );
  }

  Widget _buildSecondaryActionButton({
    required BuildContext context,
    required WidgetRef ref,
    required CommandType type,
    required IconData icon,
    required String label,
    required bool isEnabled,
    bool isDisruptive = false,
  }) {
    return OutlinedButton.icon(
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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: isEnabled
          ? () => _handleCommandTap(context, ref, type, isDisruptive)
          : null,
    );
  }

  void _handleCommandTap(
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
            'Are you sure you want to trigger "${type.displayName}"? '
            'This action commands physical motion on the robot.',
        isDestructive: isDisruptive,
      );
      if (!confirmed) return;
    }

    ref.read(controlsControllerProvider.notifier).executeCommand(
          robotId: robot.id,
          type: type,
        );
  }
}
