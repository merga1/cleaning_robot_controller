import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../../../mock/mock_catalog.dart';
import '../domain/notification_model.dart';

class NotificationsNotifier extends Notifier<List<AlertNotificationModel>> {
  @override
  List<AlertNotificationModel> build() {
    final config = ref.watch(appConfigProvider);
    if (!config.enableMockMode) {
      throw StateError(
        'Live data endpoint is not available in this frontend-only demo build.',
      );
    }
    // Global inbox: alerts from every robot, newest first (MOB-NOTIF-001).
    return MockCatalog.allNotifications;
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
    final config = ref.watch(appConfigProvider);

    // A synchronous notifier exposes build failures by throwing. Capture that
    // so the shared state widget can offer a retry instead of a red screen.
    List<AlertNotificationModel> notifications = const [];
    String? loadError;
    try {
      notifications = ref.watch(notificationsProvider);
    } catch (error) {
      loadError = error.toString();
    }

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
            onPressed: loadError != null
                ? null
                : () =>
                    ref.read(notificationsProvider.notifier).markAllAsRead(),
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: ScreenStateBuilder(
        isLoading: false,
        errorMessage: loadError,
        isEmpty: filtered.isEmpty,
        emptyMessage: 'No alerts found for this filter.',
        isDemo: config.enableMockMode,
        onRetry: () => ref.invalidate(notificationsProvider),
        builder: (context) => Column(
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
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final notif = filtered[index];
                  final robotName =
                      MockCatalog.robotFor(notif.robotId).name;

                  // MOB-NOTIF-003: severity is distinguished by colour, icon
                  // and text - never by colour alone.
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
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        final route = notif.targetRoute;
                        if (route == null) return;
                        ref
                            .read(notificationsProvider.notifier)
                            .markAsRead(notif.id);
                        if (context.mounted) context.go(route);
                      },
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      Expanded(
                                        child: Text(
                                          robotName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: secondaryTextColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '${formatDateTime(notif.timestamp)} '
                                        '(${formatRelative(notif.timestamp)})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                      Text(
                                        notif.isRead ? 'Read' : 'Unread',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: notif.isRead
                                              ? AppColors.mutedBlue
                                              : AppColors.techOrange,
                                        ),
                                      ),
                                      if (notif.isSimulated)
                                        const SimulatedBadge(),
                                      if (notif.targetRoute != null)
                                        const Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 12,
                                          color: AppColors.mutedBlue,
                                        ),
                                    ],
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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.softBlue,
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
