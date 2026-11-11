import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/notification_model.dart';

class NotificationsNotifier extends Notifier<List<AlertNotificationModel>> {
  @override
  List<AlertNotificationModel> build() {
    return [
      AlertNotificationModel(
        id: 'alt-01',
        robotId: 'robot-delta-03',
        title: 'Critical Emergency Stop Triggered',
        message:
            'Physical bumper sensor actuated. Operation aborted automatically.',
        severity: AlertSeverity.critical,
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isRead: false,
      ),
      AlertNotificationModel(
        id: 'alt-02',
        robotId: 'robot-alpha-01',
        title: 'Container Capacity at 85%',
        message:
            'Waste container nearing full threshold. Please schedule bin dump.',
        severity: AlertSeverity.warning,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        isRead: false,
      ),
      AlertNotificationModel(
        id: 'alt-03',
        robotId: 'robot-alpha-01',
        title: 'Cleaning Mission Completed',
        message: 'North Conference Hall cleaned with 98% coverage.',
        severity: AlertSeverity.info,
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isRead: true,
      ),
    ];
  }

  void markAsRead(String id) {
    state = state
        .map((alt) => alt.id == id ? alt.copyWith(isRead: true) : alt)
        .toList();
  }

  void markAllAsRead() {
    state = state.map((alt) => alt.copyWith(isRead: true)).toList();
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AlertNotificationModel>>(
        NotificationsNotifier.new);

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  AlertSeverity? _selectedSeverity;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final filtered = _selectedSeverity == null
        ? notifications
        : notifications.where((n) => n.severity == _selectedSeverity).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.white,
            ),
            onPressed: () =>
                ref.read(notificationsProvider.notifier).markAllAsRead(),
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Severity Filter Tabs (MOB-NOTIF-002)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All Severities',
                  selected: _selectedSeverity == null,
                  isDark: isDark,
                  onSelected: (_) =>
                      setState(() => _selectedSeverity = null),
                ),
                const SizedBox(width: 8),
                ...AlertSeverity.values.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildFilterChip(
                      label: s.displayName,
                      selected: _selectedSeverity == s,
                      icon: s.icon,
                      iconColor: s.color,
                      isDark: isDark,
                      onSelected: (val) {
                        setState(() {
                          _selectedSeverity = val ? s : null;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No alerts found for this filter.',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final notif = filtered[index];

                      // MOB-NOTIF-003: Warnings & critical faults visually distinct in color, icon, and text
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: notif.isRead
                                ? borderColor
                                : notif.severity.color.withValues(alpha: 0.6),
                            width: notif.isRead ? 1 : 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: notif.severity.color
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  notif.severity.icon,
                                  color: notif.severity.color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: notif.severity.color
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            notif.severity.displayName
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: notif.severity.color,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Robot: ${notif.robotId}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontWeight: notif.isRead
                                            ? FontWeight.w600
                                            : FontWeight.bold,
                                        fontSize: 15,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notif.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!notif.isRead)
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 20,
                                    color: AppColors.techOrange,
                                  ),
                                  tooltip: 'Mark as read',
                                  onPressed: () => ref
                                      .read(notificationsProvider.notifier)
                                      .markAsRead(notif.id),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required bool isDark,
    required ValueChanged<bool> onSelected,
    IconData? icon,
    Color? iconColor,
  }) {
    return FilterChip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: selected ? AppColors.white : iconColor,
            )
          : null,
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? AppColors.white
              : (isDark ? AppColors.white : AppColors.primaryNavy),
          fontWeight: selected ? FontWeight.bold : FontWeight.w600,
          fontSize: 12,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.techOrange,
      backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: selected
            ? AppColors.techOrange
            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: onSelected,
    );
  }
}
