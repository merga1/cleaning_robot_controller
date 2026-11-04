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
        message: 'Physical bumper sensor actuated. Operation aborted automatically.',
        severity: AlertSeverity.critical,
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isRead: false,
      ),
      AlertNotificationModel(
        id: 'alt-02',
        robotId: 'robot-alpha-01',
        title: 'Container Capacity at 85%',
        message: 'Waste container nearing full threshold. Please schedule bin dump.',
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
    state = state.map((alt) => alt.id == id ? alt.copyWith(isRead: true) : alt).toList();
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
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  AlertSeverity? _selectedSeverity;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);

    final filtered = _selectedSeverity == null
        ? notifications
        : notifications.where((n) => n.severity == _selectedSeverity).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Severity Filter Tabs (MOB-NOTIF-002)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Severities'),
                  selected: _selectedSeverity == null,
                  onSelected: (val) {
                    setState(() => _selectedSeverity = null);
                  },
                ),
                const SizedBox(width: 8),
                ...AlertSeverity.values.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      avatar: Icon(s.icon, size: 16, color: s.color),
                      label: Text(s.displayName),
                      selected: _selectedSeverity == s,
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
                ? const Center(child: Text('No alerts found for this filter.'))
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
                                ? AppColors.lightBorder
                                : notif.severity.color.withOpacity(0.5),
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
                                  color: notif.severity.color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(notif.severity.icon, color: notif.severity.color, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: notif.severity.color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            notif.severity.displayName.toUpperCase(),
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
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notif.message,
                                      style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF475569)),
                                    ),
                                  ],
                                ),
                              ),
                              if (!notif.isRead)
                                IconButton(
                                  icon: const Icon(Icons.check, size: 18),
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
}
