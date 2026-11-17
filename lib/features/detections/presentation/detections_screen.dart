import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../../core/widgets/simulated_badge.dart';
import '../../../mock/mock_catalog.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/detection_model.dart';

/// Detections for the active robot (MOB-DET-001..004).
final detectionsListProvider =
    FutureProvider<List<GarbageDetectionModel>>((ref) async {
  final activeRobotId =
      ref.watch(robotsControllerProvider).activeRobot?.id ??
      MockCatalog.alphaRobotId;
  if (ref.read(appConfigProvider).enableMockMode) {
    final items = MockCatalog.detectionsFor(robotId: activeRobotId);
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }
  throw StateError(
    'Live data endpoint is not available in this frontend-only demo build.',
  );
});

enum _DetectionDateRange { all, last24Hours, last7Days, last30Days }

extension _DetectionDateRangeX on _DetectionDateRange {
  String get label {
    switch (this) {
      case _DetectionDateRange.all:
        return 'All';
      case _DetectionDateRange.last24Hours:
        return '24h';
      case _DetectionDateRange.last7Days:
        return '7d';
      case _DetectionDateRange.last30Days:
        return '30d';
    }
  }

  Duration? get window {
    switch (this) {
      case _DetectionDateRange.all:
        return null;
      case _DetectionDateRange.last24Hours:
        return const Duration(hours: 24);
      case _DetectionDateRange.last7Days:
        return const Duration(days: 7);
      case _DetectionDateRange.last30Days:
        return const Duration(days: 30);
    }
  }
}

class DetectionsScreen extends ConsumerStatefulWidget {
  const DetectionsScreen({super.key});

  @override
  ConsumerState<DetectionsScreen> createState() => _DetectionsScreenState();
}

class _DetectionsScreenState extends ConsumerState<DetectionsScreen> {
  static const int _pageSize = 8;
  // Sentinel control values; the real options below come from loaded data.
  static const String _allZones = '__all_zones__';
  static const String _allJobs = '__all_jobs__';

  DetectionClass? _selectedClassFilter;
  _DetectionDateRange _selectedDateRange = _DetectionDateRange.all;
  String _selectedZoneKey = _allZones;
  String _selectedJobId = _allJobs;
  int _currentPage = 0;

  void _resetFilters() {
    setState(() {
      _selectedClassFilter = null;
      _selectedDateRange = _DetectionDateRange.all;
      _selectedZoneKey = _allZones;
      _selectedJobId = _allJobs;
      _currentPage = 0;
    });
  }

  void _retry() {
    _resetFilters();
    ref.invalidate(detectionsListProvider);
  }

  List<GarbageDetectionModel> _filterItems(
    List<GarbageDetectionModel> items, {
    required String zoneKey,
    required String jobId,
  }) {
    final window = _selectedDateRange.window;
    final now = DateTime.now().toUtc();
    return items.where((detection) {
      if (_selectedClassFilter != null &&
          detection.detectionClass != _selectedClassFilter) {
        return false;
      }
      if (zoneKey != _allZones) {
        final key = detection.zoneId.isNotEmpty
            ? detection.zoneId
            : detection.zoneName;
        if (key != zoneKey) return false;
      }
      if (jobId != _allJobs && detection.jobId != jobId) {
        return false;
      }
      if (window != null &&
          now.difference(detection.timestamp.toUtc()) > window) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final detectionsAsync = ref.watch(detectionsListProvider);
    final config = ref.watch(appConfigProvider);
    final activeRobotId =
        ref.watch(robotsControllerProvider).activeRobot?.id ??
        MockCatalog.alphaRobotId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    // Filter choices are derived from the loaded catalogue data only.
    final loadedItems =
        detectionsAsync.value ?? const <GarbageDetectionModel>[];
    final zoneOptions = <String, String>{};
    for (final detection in loadedItems) {
      final key = detection.zoneId.isNotEmpty
          ? detection.zoneId
          : detection.zoneName;
      zoneOptions.putIfAbsent(key, () => detection.zoneName);
    }
    final jobOptions = loadedItems
        .map((detection) => detection.jobId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    // A selected option may disappear when the active robot changes; fall back
    // to "All" so the dropdown never receives a value outside its item list.
    final effectiveZoneKey = _selectedZoneKey == _allZones ||
            zoneOptions.containsKey(_selectedZoneKey)
        ? _selectedZoneKey
        : _allZones;
    final effectiveJobId = _selectedJobId == _allJobs ||
            jobOptions.contains(_selectedJobId)
        ? _selectedJobId
        : _allJobs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garbage Detections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Detections',
            onPressed: () => ref.invalidate(detectionsListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          if (detectionsAsync.hasValue) ...[
            _filterSection(
              zoneOptions: zoneOptions,
              jobOptions: jobOptions,
              zoneKey: effectiveZoneKey,
              jobId: effectiveJobId,
              isDark: isDark,
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: detectionsAsync.when(
              loading: () => ScreenStateBuilder(
                isLoading: true,
                isDemo: config.enableMockMode,
                builder: (_) => const SizedBox.shrink(),
              ),
              error: (error, _) => ScreenStateBuilder(
                errorMessage: error.toString(),
                isDemo: config.enableMockMode,
                onRetry: _retry,
                builder: (_) => const SizedBox.shrink(),
              ),
              data: (items) {
                final filtered = _filterItems(
                  items,
                  zoneKey: effectiveZoneKey,
                  jobId: effectiveJobId,
                );
                final totalPages = filtered.isEmpty
                    ? 0
                    : (filtered.length + _pageSize - 1) ~/ _pageSize;
                final page = totalPages == 0
                    ? 0
                    : (_currentPage >= totalPages
                        ? totalPages - 1
                        : (_currentPage < 0 ? 0 : _currentPage));
                final pageItems = filtered
                    .skip(page * _pageSize)
                    .take(_pageSize)
                    .toList();

                return ScreenStateBuilder(
                  isDemo: config.enableMockMode,
                  isSimulated:
                      MockCatalog.robotFor(activeRobotId).isSimulated,
                  isEmpty: filtered.isEmpty,
                  emptyMessage: 'No detections match the selected filters.',
                  onRetry: _retry,
                  builder: (_) => Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: pageItems.length,
                          itemBuilder: (context, index) => _detectionCard(
                            context,
                            pageItems[index],
                            isDark,
                            primaryTextColor,
                            secondaryTextColor,
                            borderColor,
                          ),
                        ),
                      ),
                      _paginationRow(page, totalPages, isDark, primaryTextColor),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterSection({
    required Map<String, String> zoneOptions,
    required List<String> jobOptions,
    required String zoneKey,
    required String jobId,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Class filters (MOB-DET-002).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip(
                label: 'All Classes',
                selected: _selectedClassFilter == null,
                isDark: isDark,
                onSelected: (_) =>
                    setState(() {
                      _selectedClassFilter = null;
                      _currentPage = 0;
                    }),
              ),
              const SizedBox(width: 8),
              ...DetectionClass.values.map(
                (detectionClass) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildFilterChip(
                    label: detectionClass.displayName,
                    selected: _selectedClassFilter == detectionClass,
                    isDark: isDark,
                    onSelected: (selected) => setState(() {
                      _selectedClassFilter = selected ? detectionClass : null;
                      _currentPage = 0;
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Date-range filters (MOB-DET-002).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              ..._DetectionDateRange.values.map(
                (range) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildFilterChip(
                    label: range.label,
                    selected: _selectedDateRange == range,
                    isDark: isDark,
                    onSelected: (selected) {
                      if (!selected) return;
                      setState(() {
                        _selectedDateRange = range;
                        _currentPage = 0;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Zone and job filters populated from the loaded detections.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: _filterDropdown(
                  label: 'Zone',
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: zoneKey,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<String>(
                        value: _allZones,
                        child: Text('All zones'),
                      ),
                      ...zoneOptions.entries.map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedZoneKey = value ?? _allZones;
                      _currentPage = 0;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _filterDropdown(
                  label: 'Job',
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: jobId,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<String>(
                        value: _allJobs,
                        child: Text('All jobs'),
                      ),
                      ...jobOptions.map(
                        (id) => DropdownMenuItem<String>(
                          value: id,
                          child: Text(id, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedJobId = value ?? _allJobs;
                      _currentPage = 0;
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterDropdown({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedBlue,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _paginationRow(
    int page,
    int totalPages,
    bool isDark,
    Color primaryTextColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: page > 0
                  ? () => setState(() => _currentPage = page - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
            Text(
              'Page ${page + 1} of $totalPages',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
            ),
            TextButton.icon(
              onPressed: page < totalPages - 1
                  ? () => setState(() => _currentPage = page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detectionCard(
    BuildContext context,
    GarbageDetectionModel detection,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    final snapshot = Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withValues(alpha: isDark ? 0.5 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Icon(
        Icons.center_focus_strong_outlined,
        color: detection.isUncertain
            ? AppColors.severityWarning
            : AppColors.techOrange,
        size: 28,
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Snapshot placeholder (MOB-DET-004).
            if (detection.imageUrl != null)
              Tooltip(
                message: 'View demo image reference',
                child: InkWell(
                  onTap: () => _showImageReferenceDialog(context, detection),
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      snapshot,
                      const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.image_outlined,
                          size: 13,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              snapshot,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        detection.detectionClass.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: primaryTextColor,
                        ),
                      ),
                      // Uncertain marker (MOB-DET-003).
                      if (detection.isUncertain)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.severityWarning.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Uncertain',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.severityWarning,
                            ),
                          ),
                        ),
                      if (detection.isSimulated) const SimulatedBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Zone: ${detection.zoneName}',
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Robot: ${detection.robotId}  ·  '
                    'Job: ${detection.jobId.isEmpty ? "—" : detection.jobId}',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Confidence: '
                          '${(detection.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: detection.isUncertain
                                ? AppColors.severityWarning
                                : AppColors.techOrange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${formatDateTime(detection.timestamp)} · '
                          '${formatRelative(detection.timestamp)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageReferenceDialog(
    BuildContext context,
    GarbageDetectionModel detection,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Demo image reference'),
        content: Text(
          'This frontend-only demo does not download images. The detection '
          'references ${detection.imageUrl} locally; no network request is '
          'made for this snapshot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
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
  }) {
    return FilterChip(
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
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.softBlue,
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
