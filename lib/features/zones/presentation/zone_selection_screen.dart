import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../controls/domain/command_model.dart';
import '../../controls/presentation/controls_controller.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/zone_model.dart';

final zonesListProvider = FutureProvider<List<ZoneModel>>((ref) async {
  // Mock zones representing real building floorplan
  await Future.delayed(const Duration(milliseconds: 300));
  return [
    ZoneModel(
      id: 'zone-101',
      name: 'Main Reception & Lobby',
      areaM2: 120.5,
      lastCleanedAt: DateTime.now().subtract(const Duration(hours: 4)),
      isAvailable: true,
    ),
    ZoneModel(
      id: 'zone-102',
      name: 'North Conference Hall',
      areaM2: 85.0,
      lastCleanedAt: DateTime.now().subtract(const Duration(hours: 18)),
      isAvailable: true,
    ),
    ZoneModel(
      id: 'zone-103',
      name: 'Executive Boardroom',
      areaM2: 64.2,
      lastCleanedAt: DateTime.now().subtract(const Duration(days: 1)),
      isAvailable: true,
    ),
    const ZoneModel(
      id: 'zone-104',
      name: 'Cafeteria & Dining Lounge',
      areaM2: 150.0,
      isAvailable: false,
      unavailabilityReason: 'Active human maintenance in progress',
    ),
    const ZoneModel(
      id: 'zone-105',
      name: 'Server Room Corridor',
      areaM2: 45.0,
      isAvailable: false,
      unavailabilityReason: 'Restricted high-security access',
    ),
  ];
});

class ZoneSelectionScreen extends ConsumerStatefulWidget {
  const ZoneSelectionScreen({super.key});

  @override
  ConsumerState<ZoneSelectionScreen> createState() =>
      _ZoneSelectionScreenState();
}

class _ZoneSelectionScreenState extends ConsumerState<ZoneSelectionScreen> {
  final Set<String> _selectedZoneIds = {};

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(zonesListProvider);
    final activeRobot = ref.watch(robotsControllerProvider).activeRobot;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Cleaning Zones'),
      ),
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
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.techOrange,
                foregroundColor: AppColors.white,
                disabledBackgroundColor:
                    isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.cleaning_services_rounded, size: 20),
              onPressed: _selectedZoneIds.isEmpty || activeRobot == null
                  ? null
                  : () async {
                      // MOB-ZONE-004: Summary and confirmation before starting job
                      final confirmed = await ConfirmationDialog.show(
                        context,
                        title: 'Start Cleaning Run',
                        message:
                            'Dispatch ${activeRobot.name} to clean ${_selectedZoneIds.length} selected zone(s)?',
                        confirmText: 'Dispatch Robot',
                      );

                      if (confirmed && mounted) {
                        await ref
                            .read(controlsControllerProvider.notifier)
                            .executeCommand(
                              robotId: activeRobot.id,
                              type: CommandType.startCleaning,
                              parameters: {'zones': _selectedZoneIds.toList()},
                            );
                        if (context.mounted) {
                          context.go('/dashboard');
                        }
                      }
                    },
              label: Text(
                _selectedZoneIds.isEmpty
                    ? 'Select Zones to Clean'
                    : 'Start Cleaning (${_selectedZoneIds.length} Zones)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      body: zonesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading zones: $err')),
        data: (zones) {
          return ListView.builder(
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
                                : const Color(0xFFF1F5F9),
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
                        'Area: ${zone.areaM2} m²',
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryTextColor.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (zone.lastCleanedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Last cleaned: ${zone.lastCleanedAt!.hour}:${zone.lastCleanedAt!.minute.toString().padLeft(2, '0')}',
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
          );
        },
      ),
    );
  }
}
