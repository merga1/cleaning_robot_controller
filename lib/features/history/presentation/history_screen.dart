import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../../mock/mock_catalog.dart';
import '../../progress/domain/job_progress_model.dart';
import '../../robots/presentation/robots_controller.dart';
import '../domain/job_history_model.dart';

/// Mission history is supplied by the central demo catalogue. There is no
/// live endpoint in this frontend-only build (MOB-HIST-001..003).
final jobHistoryProvider =
    FutureProvider.family<List<CleaningJobHistoryItem>, String>((
  ref,
  robotId,
) async {
  final isMockMode = ref.watch(appConfigProvider).enableMockMode;
  if (!isMockMode) {
    throw StateError(
      'Live data endpoint is not available in this frontend-only demo build.',
    );
  }
  await Future.delayed(const Duration(milliseconds: 250));
  return MockCatalog.jobHistoryFor(robotId);
});

enum _HistoryDateRange { all, last24Hours, last7Days, last30Days }

extension _HistoryDateRangeX on _HistoryDateRange {
  String get label {
    switch (this) {
      case _HistoryDateRange.all:
        return 'All dates';
      case _HistoryDateRange.last24Hours:
        return 'Last 24 hours';
      case _HistoryDateRange.last7Days:
        return 'Last 7 days';
      case _HistoryDateRange.last30Days:
        return 'Last 30 days';
    }
  }

  Duration? get window {
    switch (this) {
      case _HistoryDateRange.all:
        return null;
      case _HistoryDateRange.last24Hours:
        return const Duration(hours: 24);
      case _HistoryDateRange.last7Days:
        return const Duration(days: 7);
      case _HistoryDateRange.last30Days:
        return const Duration(days: 30);
    }
  }
}

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const int _pageSize = 5;
  static const String _allOutcomes = '__all__';

  String _outcomeFilter = _allOutcomes;
  _HistoryDateRange _dateRange = _HistoryDateRange.all;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final activeRobot = ref.watch(robotsControllerProvider).activeRobot;
    final robotId = activeRobot?.id ?? MockCatalog.alphaRobotId;
    final isMockMode = ref.watch(appConfigProvider).enableMockMode;
    final historyAsync = ref.watch(jobHistoryProvider(robotId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final jobs = historyAsync.value ?? const <CleaningJobHistoryItem>[];
    final outcomeOptions = jobs.map((job) => job.outcome).toSet().toList()
      ..sort();
    final dateWindow = _dateRange.window;
    final nowUtc = DateTime.now().toUtc();
    final filteredJobs = jobs.where((job) {
      final matchesOutcome =
          _outcomeFilter == _allOutcomes || job.outcome == _outcomeFilter;
      final matchesDate = dateWindow == null ||
          nowUtc.difference(job.date.toUtc()) <= dateWindow;
      return matchesOutcome && matchesDate;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final pageCount = filteredJobs.isEmpty
        ? 0
        : (filteredJobs.length + _pageSize - 1) ~/ _pageSize;
    final currentPage = pageCount == 0
        ? 0
        : (_page >= pageCount ? pageCount - 1 : _page);
    final visibleJobs = filteredJobs
        .skip(currentPage * _pageSize)
        .take(_pageSize)
        .toList();

    final error = historyAsync.error;
    final errorMessage = historyAsync.hasError
        ? (error is StateError ? error.message : error.toString())
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleaning Mission History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh history',
            onPressed: () => ref.invalidate(jobHistoryProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _filterDropdown(
                    label: 'Outcome',
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _outcomeFilter,
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem<String>(
                          value: _allOutcomes,
                          child: Text('All outcomes'),
                        ),
                        for (final outcome in outcomeOptions)
                          DropdownMenuItem<String>(
                            value: outcome,
                            child: Text(outcome),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _outcomeFilter = value ?? _allOutcomes;
                        _page = 0;
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _filterDropdown(
                    label: 'Date range',
                    child: DropdownButton<_HistoryDateRange>(
                      isExpanded: true,
                      value: _dateRange,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final range in _HistoryDateRange.values)
                          DropdownMenuItem<_HistoryDateRange>(
                            value: range,
                            child: Text(range.label),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _dateRange = value ?? _HistoryDateRange.all;
                        _page = 0;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ScreenStateBuilder(
              isLoading: historyAsync.isLoading && !historyAsync.hasValue,
              errorMessage: errorMessage,
              isEmpty: !historyAsync.isLoading &&
                  errorMessage == null &&
                  filteredJobs.isEmpty,
              emptyMessage: jobs.isEmpty
                  ? 'No cleaning jobs recorded for this robot.'
                  : 'No cleaning jobs match the selected filters.',
              isDemo: isMockMode,
              isSimulated: activeRobot?.isSimulated ?? false,
              onRetry: () => ref.invalidate(jobHistoryProvider),
              builder: (_) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: visibleJobs.length,
                itemBuilder: (context, index) => _jobCard(
                  visibleJobs[index],
                  primaryTextColor,
                  secondaryTextColor,
                  borderColor,
                ),
              ),
            ),
          ),
          if (pageCount > 0)
            _paginationBar(
              currentPage,
              pageCount,
              filteredJobs.length,
              secondaryTextColor,
              borderColor,
            ),
        ],
      ),
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

  Widget _paginationBar(
    int currentPage,
    int pageCount,
    int totalJobs,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${currentPage + 1} / $pageCount · $totalJobs jobs',
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous page',
                    onPressed: currentPage > 0
                        ? () => setState(() => _page = currentPage - 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next page',
                    onPressed: currentPage < pageCount - 1
                        ? () => setState(() => _page = currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jobCard(
    CleaningJobHistoryItem job,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    final outcomeColor = _outcomeColor(job.outcome);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openJobDetails(job),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.zones,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: outcomeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      job.outcome,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: outcomeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${job.robotName} • ${job.id}',
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule_outlined,
                      size: 13, color: AppColors.mutedBlue),
                  const SizedBox(width: 4),
                  Text(
                    formatDateTime(job.date),
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${formatRelative(job.date)})',
                    style: TextStyle(fontSize: 11, color: secondaryTextColor),
                  ),
                ],
              ),
              const Divider(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _infoChip(Icons.timer_outlined,
                      'Duration ${formatDuration(job.duration)}'),
                  _infoChip(Icons.grid_view,
                      'Coverage ${job.coverageM2.toStringAsFixed(1)} m²'),
                  _infoChip(Icons.linear_scale,
                      '${job.coveragePercentage.toStringAsFixed(1)}% covered'),
                  _infoChip(Icons.scatter_plot_outlined,
                      '${job.detectionCount} detections'),
                ],
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'View details →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.techOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedBlue),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.primaryNavy),
        ),
      ],
    );
  }

  Color _outcomeColor(String outcome) {
    final normalized = outcome.toLowerCase();
    if (normalized == 'completed') return AppColors.successGreen;
    if (normalized.contains('fault') || normalized == 'failed') {
      return AppColors.severityCritical;
    }
    if (normalized == 'cancelled') return AppColors.mutedBlue;
    return AppColors.severityWarning;
  }

  Future<void> _openJobDetails(CleaningJobHistoryItem job) async {
    if (!ref.read(appConfigProvider).enableMockMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job details are available in demo mode only.'),
        ),
      );
      return;
    }

    final progress = MockCatalog.jobProgressFor(job.robotId);
    final timeline = progress.jobId == job.id
        ? progress.timeline
        : <JobEventTimelineItem>[];
    final detections =
        MockCatalog.detectionsFor().where((d) => d.jobId == job.id).toList();
    final assessments = MockCatalog.assessmentsFor()
        .where((a) => job.zoneIds.contains(a.zoneId))
        .toList();
    // Mock history stores zone names in zoneIds; include name matches so the
    // linked assessments are still visible for archived jobs.
    for (final assessment in MockCatalog.assessmentsFor()) {
      if (job.zoneIds.contains(assessment.zoneName) &&
          !assessments.any((existing) => existing.id == assessment.id)) {
        assessments.add(assessment);
      }
    }
    assessments.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primary = isDark ? AppColors.white : AppColors.primaryNavy;
            final secondary =
                isDark ? Colors.white70 : AppColors.secondaryText;

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text(
                  'Mission ${job.id}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${job.robotName} · ${formatDateTime(job.date)}',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 8),
                Text(
                  job.zones,
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _infoChip(Icons.timer_outlined,
                        'Duration ${formatDuration(job.duration)}'),
                    _infoChip(Icons.grid_view,
                        'Coverage ${job.coverageM2.toStringAsFixed(1)} m²'),
                    _infoChip(Icons.linear_scale,
                        '${job.coveragePercentage.toStringAsFixed(1)}%'),
                    _infoChip(Icons.scatter_plot_outlined,
                        '${job.detectionCount} detections'),
                  ],
                ),
                const SizedBox(height: 16),
                _detailSection(
                  'Event timeline',
                  primary,
                  children: [
                    if (timeline.isEmpty)
                      Text(
                        'Event timeline unavailable for archived job.',
                        style: TextStyle(fontSize: 13, color: secondary),
                      ),
                    for (final event in timeline)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.techOrange,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event.description,
                                    style: TextStyle(
                                        fontSize: 12, color: secondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatDateTime(event.timestamp),
                                    style: TextStyle(
                                        fontSize: 11, color: secondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                _detailSection(
                  'Detections for this mission',
                  primary,
                  children: [
                    if (detections.isEmpty)
                      Text(
                        'No detections recorded for this job.',
                        style: TextStyle(fontSize: 13, color: secondary),
                      ),
                    for (final detection in detections)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.scatter_plot_outlined,
                          size: 18,
                          color: AppColors.techOrange,
                        ),
                        title: Text(
                          '${detection.detectionClass.displayName} · ${detection.zoneName}',
                          style: TextStyle(fontSize: 13, color: primary),
                        ),
                        subtitle: Text(
                          'Confidence ${(detection.confidence * 100).toStringAsFixed(0)}% · '
                          '${formatDateTime(detection.timestamp)}',
                          style: TextStyle(fontSize: 11, color: secondary),
                        ),
                      ),
                  ],
                ),
                _detailSection(
                  'Zone assessments',
                  primary,
                  children: [
                    if (assessments.isEmpty)
                      Text(
                        'No floor assessments linked to this job.',
                        style: TextStyle(fontSize: 13, color: secondary),
                      ),
                    for (final assessment in assessments)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.grid_view,
                          size: 18,
                          color: AppColors.mutedBlue,
                        ),
                        title: Text(
                          '${assessment.zoneName} · ${assessment.resultLabel}',
                          style: TextStyle(fontSize: 13, color: primary),
                        ),
                        subtitle: Text(
                          'Score ${assessment.score.toStringAsFixed(1)} · '
                          'Confidence ${(assessment.confidence * 100).toStringAsFixed(0)}% · '
                          '${formatDateTime(assessment.timestamp)}'
                          '${assessment.sensorFault == null ? '' : ' · ${assessment.sensorFault}'}',
                          style: TextStyle(fontSize: 11, color: secondary),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _detailSection(
    String title,
    Color titleColor, {
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
