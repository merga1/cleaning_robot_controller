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
        color: const Color(0xFFF1F5F9),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: Color(0xFF64748B)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Operator permissions required to dispatch commands. You are in Read-Only mode.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
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
                const Text(
                  'Robot Commands',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (isInFlight)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Command Lifecycle Badge (MOB-CTRL-006, Section 7)
            if (lastCommand != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: lastCommand.state == CommandLifecycleState.failed ||
                          lastCommand.state == CommandLifecycleState.rejected
                      ? AppColors.severityCritical.withOpacity(0.1)
                      : AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      lastCommand.state == CommandLifecycleState.completed
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      size: 16,
                      color: lastCommand.state == CommandLifecycleState.failed
                          ? AppColors.severityCritical
                          : AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${lastCommand.type.displayName}: ${lastCommand.state.label}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: lastCommand.state == CommandLifecycleState.failed
                              ? AppColors.severityCritical
                              : AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionButton(
                  context: context,
                  ref: ref,
                  type: CommandType.call,
                  icon: Icons.ring_volume_rounded,
                  label: 'Call Robot',
                  isEnabled: !isInFlight && robot.capabilities.canCall,
                ),
                if (robot.status == RobotOperationalStatus.cleaning)
                  _buildActionButton(
                    context: context,
                    ref: ref,
                    type: CommandType.pause,
                    icon: Icons.pause_circle_outline,
                    label: 'Pause',
                    isEnabled: !isInFlight && robot.capabilities.canPause,
                  )
                else if (robot.status == RobotOperationalStatus.paused)
                  _buildActionButton(
                    context: context,
                    ref: ref,
                    type: CommandType.resume,
                    icon: Icons.play_circle_outline,
                    label: 'Resume',
                    isEnabled: !isInFlight && robot.capabilities.canResume,
                  )
                else
                  _buildActionButton(
                    context: context,
                    ref: ref,
                    type: CommandType.startCleaning,
                    icon: Icons.cleaning_services_outlined,
                    label: 'Start Cleaning',
                    isEnabled: !isInFlight &&
                        robot.capabilities.canClean &&
                        robot.connectionState != RobotConnectionState.offline,
                  ),
                _buildActionButton(
                  context: context,
                  ref: ref,
                  type: CommandType.inspectFloor,
                  icon: Icons.search_rounded,
                  label: 'Inspect Floor',
                  isEnabled: !isInFlight && robot.capabilities.canInspect,
                ),
                _buildActionButton(
                  context: context,
                  ref: ref,
                  type: CommandType.returnToDock,
                  icon: Icons.home_outlined,
                  label: 'Return to Dock',
                  isEnabled: !isInFlight &&
                      robot.capabilities.canDock &&
                      robot.status != RobotOperationalStatus.charging,
                  isDisruptive: robot.status == RobotOperationalStatus.cleaning,
                ),
                if (robot.status == RobotOperationalStatus.cleaning ||
                    robot.status == RobotOperationalStatus.navigating)
                  _buildActionButton(
                    context: context,
                    ref: ref,
                    type: CommandType.cancel,
                    icon: Icons.cancel_outlined,
                    label: 'Cancel Cleaning',
                    isEnabled: !isInFlight && robot.capabilities.canCancel,
                    isDisruptive: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required WidgetRef ref,
    required CommandType type,
    required IconData icon,
    required String label,
    required bool isEnabled,
    bool isDisruptive = false,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDisruptive ? AppColors.severityCritical : AppColors.primaryBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFCBD5E1),
        minimumSize: const Size(140, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: isEnabled
          ? () async {
              if (isDisruptive || type.isDisruptive) {
                // MOB-CTRL-004: Confirmation dialog
                final confirmed = await ConfirmationDialog.show(
                  context,
                  title: 'Confirm ${type.displayName}',
                  message:
                      'Are you sure you want to trigger "${type.displayName}"? '
                      'This will interrupt current cleaning operations.',
                  isDestructive: isDisruptive,
                );
                if (!confirmed) return;
              }

              ref.read(controlsControllerProvider.notifier).executeCommand(
                    robotId: robot.id,
                    type: type,
                  );
            }
          : null,
    );
  }
}

