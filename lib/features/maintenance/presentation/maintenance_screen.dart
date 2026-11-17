import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../../mock/mock_catalog.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../controls/domain/command_model.dart';
import '../../controls/presentation/controls_controller.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/maintenance_model.dart';

/// Diagnostics are supplied by the central demo catalogue. A live endpoint is
/// deliberately not wired in this frontend-only build (MOB-MAINT-001..004).
final healthReportProvider =
    FutureProvider.family<RobotHealthReport, String>((ref, robotId) async {
  final isMockMode = ref.watch(appConfigProvider).enableMockMode;
  if (!isMockMode) {
    throw StateError(
      'Live data endpoint is not available in this frontend-only demo build.',
    );
  }
  await Future.delayed(const Duration(milliseconds: 250));
  return MockCatalog.healthFor(robotId);
});

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  /// Local-only additions from the admin "Log Service" dialog. They are kept
  /// in screen state and intentionally not persisted (MOB-MAINT-003).
  final List<MaintenanceRecordItem> _localRecords = [];

  @override
  Widget build(BuildContext context) {
    final activeRobot = ref.watch(robotsControllerProvider).activeRobot;
    final robotId = activeRobot?.id ?? MockCatalog.alphaRobotId;
    final authUser = ref.watch(authControllerProvider).user;
    final canControlRobots = authUser?.role.canControlRobots ?? false;
    final canManageUsers = authUser?.role.canManageUsers ?? false;
    final controlsState = ref.watch(controlsControllerProvider);
    final isMockMode = ref.watch(appConfigProvider).enableMockMode;
    final healthAsync = ref.watch(healthReportProvider(robotId));
    final report = healthAsync.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final blockingFaults = report == null
        ? const <ActiveFaultItem>[]
        : report.activeFaults.where((fault) => fault.blocksCommands).toList();

    String? refreshDisabledReason;
    if (!canControlRobots) {
      refreshDisabledReason = 'Read-only role — command requests are disabled.';
    } else if (blockingFaults.isNotEmpty) {
      refreshDisabledReason =
          'Commands blocked by ${blockingFaults.first.title}.';
    } else if (controlsState.isInFlight) {
      refreshDisabledReason = 'A command is already in flight.';
    }

    final error = healthAsync.error;
    final errorMessage = healthAsync.hasError
        ? (error is StateError ? error.message : error.toString())
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance & Diagnostics'),
        actions: [
          // MOB-CTRL-011: request a status refresh; the real outcome is shown
          // from controls state below instead of claiming success upfront.
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: refreshDisabledReason ?? 'Request Status Refresh',
            onPressed: refreshDisabledReason != null
                ? null
                : () {
                    ref.read(controlsControllerProvider.notifier)
                        .executeCommand(
                      robotId: robotId,
                      type: CommandType.requestStatusRefresh,
                    );
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!canControlRobots || blockingFaults.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.severityCritical.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.severityCritical.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                refreshDisabledReason ?? '',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.white : AppColors.severityCritical,
                ),
              ),
            ),
          Expanded(
            child: ScreenStateBuilder(
              isLoading: healthAsync.isLoading && report == null,
              errorMessage: errorMessage,
              isEmpty: !healthAsync.isLoading &&
                  errorMessage == null &&
                  (report?.sensors.isEmpty ?? true),
              emptyMessage: 'No diagnostics available for this robot.',
              isDemo: isMockMode,
              isSimulated: activeRobot?.isSimulated ?? false,
              onRetry: () => ref.invalidate(healthReportProvider),
              builder: (_) {
                final health = report;
                if (health == null) return const SizedBox.shrink();
                final records = <MaintenanceRecordItem>[
                  ..._localRecords,
                  ...health.maintenanceRecords,
                ];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    _commandStatusCard(
                      context,
                      controlsState,
                      primaryTextColor,
                      secondaryTextColor,
                      borderColor,
                    ),
                    const SizedBox(height: 12),
                    _connectivityCard(
                      context,
                      health,
                      primaryTextColor,
                      secondaryTextColor,
                      borderColor,
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Hardware Subsystem Health', primaryTextColor),
                    const SizedBox(height: 8),
                    _sensorsCard(
                      context,
                      health.sensors,
                      primaryTextColor,
                      secondaryTextColor,
                      borderColor,
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Active Faults', primaryTextColor),
                    const SizedBox(height: 8),
                    if (health.activeFaults.isEmpty)
                      Text(
                        'No active faults reported.',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                    for (final fault in health.activeFaults)
                      _faultCard(context, fault, primaryTextColor,
                          secondaryTextColor),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionTitle('Service Records', primaryTextColor),
                        if (canManageUsers)
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Log Service'),
                            onPressed: _showLogServiceDialog,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (!canManageUsers)
                      Text(
                        'Only administrators can log service records.',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    if (!canManageUsers) const SizedBox(height: 8),
                    for (final record in records)
                      _recordCard(
                        context,
                        record,
                        primaryTextColor,
                        secondaryTextColor,
                        borderColor,
                      ),
                    const SizedBox(height: 16),
                    _sectionTitle('Recent Command History', primaryTextColor),
                    const SizedBox(height: 8),
                    if (health.commandHistory.isEmpty)
                      Text(
                        'No commands recorded.',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                    for (final command in health.commandHistory)
                      _commandHistoryTile(
                        command,
                        primaryTextColor,
                        secondaryTextColor,
                        borderColor,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _commandStatusCard(
    BuildContext context,
    ControlsState controls,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    final last = controls.lastCommand;
    final isRefresh =
        last != null && last.type == CommandType.requestStatusRefresh;
    final hasResult = isRefresh ||
        controls.isInFlight ||
        controls.errorMessage != null;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync_outlined,
                    size: 18, color: AppColors.techOrange),
                const SizedBox(width: 8),
                Text(
                  'Status refresh command',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (controls.isInFlight)
              Text(
                'Sending status refresh request…',
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            if (isRefresh)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Current state: ${last.state.label}'
                  '${last.rejectionReason == null ? '' : ' — ${last.rejectionReason}'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _commandStateColor(last.state),
                  ),
                ),
              ),
            if (controls.errorMessage != null && !controls.isInFlight)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  controls.errorMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.severityCritical,
                  ),
                ),
              ),
            if (!hasResult)
              Text(
                'No status refresh requested yet.',
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
          ],
        ),
      ),
    );
  }

  Color _commandStateColor(CommandLifecycleState state) {
    switch (state) {
      case CommandLifecycleState.completed:
        return AppColors.successGreen;
      case CommandLifecycleState.rejected:
      case CommandLifecycleState.failed:
      case CommandLifecycleState.expired:
        return AppColors.severityCritical;
      default:
        return AppColors.techOrange;
    }
  }

  Widget _connectivityCard(
    BuildContext context,
    RobotHealthReport health,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_outlined,
                    size: 18, color: AppColors.techOrange),
                const SizedBox(width: 8),
                Text(
                  'Connection & firmware',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _statusLine('Connection', health.connectionState, primaryTextColor,
                secondaryTextColor),
            const SizedBox(height: 6),
            _statusLine('Firmware', health.firmwareVersion, primaryTextColor,
                secondaryTextColor),
            const SizedBox(height: 6),
            _statusLine(
              'Last diagnostic',
              '${formatDateTime(health.lastDiagnosticAt)} '
              '(${formatRelative(health.lastDiagnosticAt)})',
              primaryTextColor,
              secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusLine(
    String label,
    String value,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sensorsCard(
    BuildContext context,
    List<SensorHealthItem> sensors,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final sensor in sensors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _healthColor(sensor.state),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sensor.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sensor.detail,
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sensor.state.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _healthColor(sensor.state),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _healthColor(HealthState state) {
    switch (state) {
      case HealthState.nominal:
        return AppColors.successGreen;
      case HealthState.warning:
        return AppColors.severityWarning;
      case HealthState.fault:
        return AppColors.severityCritical;
    }
  }

  Widget _faultCard(
    BuildContext context,
    ActiveFaultItem fault,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCritical = fault.severity == HealthState.fault ||
        fault.blocksCommands;
    final accentColor = isDark ? AppColors.white : AppColors.severityCritical;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isCritical
          ? AppColors.severityCritical.withValues(alpha: isDark ? 0.25 : 0.08)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCritical
              ? AppColors.severityCritical.withValues(alpha: 0.5)
              : AppColors.borderBlue,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: isCritical
                      ? AppColors.severityCritical
                      : AppColors.severityWarning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fault.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isCritical ? accentColor : primaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Severity: ${fault.severity.displayName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isCritical ? accentColor : secondaryTextColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Detected ${formatDateTime(fault.detectedAt)} '
              '(${formatRelative(fault.detectedAt)})',
              style: TextStyle(fontSize: 11, color: secondaryTextColor),
            ),
            if (fault.blocksCommands) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.severityCritical.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Commands blocked by this fault',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recordCard(
    BuildContext context,
    MaintenanceRecordItem record,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color statusColor;
    final String status;
    if (record.completedAt != null) {
      statusColor = AppColors.successGreen;
      status = 'Completed ${formatRelative(record.completedAt!)}';
    } else if (record.isOverdue) {
      statusColor = AppColors.severityCritical;
      status = 'Overdue — due ${formatDateTime(record.dueAt)}';
    } else {
      statusColor = AppColors.techOrange;
      status = 'Due ${formatDateTime(record.dueAt)}';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.build_circle_outlined,
            color: isDark ? AppColors.white : AppColors.primaryNavy,
            size: 22,
          ),
        ),
        title: Text(
          record.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: primaryTextColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : statusColor,
              ),
            ),
            if (record.notes != null) ...[
              const SizedBox(height: 2),
              Text(
                record.notes!,
                style: TextStyle(fontSize: 11, color: secondaryTextColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _commandHistoryTile(
    CommandHistoryItem item,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    final normalizedState = item.state.toLowerCase();
    final isFailure = item.reason != null ||
        normalizedState.contains('expired') ||
        normalizedState.contains('reject') ||
        normalizedState.contains('failed');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isFailure ? Icons.error_outline : Icons.check_circle_outline,
          size: 18,
          color: isFailure ? AppColors.severityCritical : AppColors.successGreen,
        ),
        title: Text(
          item.commandType,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${item.state} · ${formatDateTime(item.timestamp)}',
              style: TextStyle(fontSize: 11, color: secondaryTextColor),
            ),
            if (item.reason != null)
              Text(
                'Reason: ${item.reason}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.severityCritical,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogServiceDialog() async {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    final daysController = TextEditingController(text: '30');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Log Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Service title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: daysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Due in (days)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add record'),
            ),
          ],
        );
      },
    );

    final title = titleController.text.trim();
    final notes = notesController.text.trim();
    final days = int.tryParse(daysController.text.trim()) ?? 30;
    titleController.dispose();
    notesController.dispose();
    daysController.dispose();

    if (confirmed != true || !mounted) return;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a service title to log.')),
      );
      return;
    }

    setState(() {
      _localRecords.insert(
        0,
        MaintenanceRecordItem(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          title: title,
          dueAt: DateTime.now().toUtc().add(Duration(days: days)),
          notes: notes.isEmpty ? null : notes,
        ),
      );
    });
  }
}
