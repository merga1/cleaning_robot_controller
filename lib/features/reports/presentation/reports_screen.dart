import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/screen_state_builder.dart';
import '../../../mock/mock_catalog.dart';
import '../domain/report_model.dart';

/// Reports are computed by the demo backend catalogue - the UI never derives
/// figures itself (MOB-REP-001..003).
final reportProvider =
    FutureProvider.family<CleaningReport, ReportPeriod>((ref, period) async {
  final isMockMode = ref.watch(appConfigProvider).enableMockMode;
  if (!isMockMode) {
    throw StateError(
      'Live data endpoint is not available in this frontend-only demo build.',
    );
  }
  await Future.delayed(const Duration(milliseconds: 250));
  return MockCatalog.reportFor(period);
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.last30Days;

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportProvider(_period));
    final isMockMode = ref.watch(appConfigProvider).enableMockMode;
    final report = reportAsync.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.white : AppColors.primaryNavy;
    final secondaryTextColor =
        isDark ? Colors.white70 : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final error = reportAsync.error;
    final errorMessage = reportAsync.hasError
        ? (error is StateError ? error.message : error.toString())
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleaning Analytics & Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh report',
            onPressed: () => ref.invalidate(reportProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final period in ReportPeriod.values)
                  ChoiceChip(
                    label: Text(period.displayName),
                    selected: period == _period,
                    onSelected: (_) => setState(() => _period = period),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ScreenStateBuilder(
              isLoading: reportAsync.isLoading && report == null,
              errorMessage: errorMessage,
              isEmpty: !reportAsync.isLoading &&
                  errorMessage == null &&
                  report == null,
              emptyMessage: 'No report data available.',
              isDemo: isMockMode,
              isSimulated: report?.isSimulated ?? false,
              onRetry: () => ref.invalidate(reportProvider),
              builder: (_) {
                final current = report;
                if (current == null) return const SizedBox.shrink();
                final metrics = current.metrics;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      '${current.period.displayName} performance overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            context,
                            title: 'Completed Missions',
                            value: '${metrics.jobsCompleted}',
                            valueColor: AppColors.successGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard(
                            context,
                            title: 'Failed / Faults',
                            value: '${metrics.jobsFailed}',
                            valueColor: AppColors.severityCritical,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            context,
                            title: 'Avg Coverage',
                            value:
                                '${metrics.averageCoveragePercentage.toStringAsFixed(1)}%',
                            valueColor: AppColors.techOrange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard(
                            context,
                            title: 'Total Runtime',
                            value: formatDuration(metrics.totalCleaningTime),
                            valueColor: AppColors.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _metricCard(
                      context,
                      title: 'Total AI Garbage Detections',
                      value: '${metrics.totalGarbageDetections} objects',
                      valueColor: AppColors.techOrange,
                    ),
                    const SizedBox(height: 16),
                    _trendsCard(
                      context,
                      current.trends,
                      primaryTextColor,
                      secondaryTextColor,
                      borderColor,
                    ),
                    const SizedBox(height: 16),
                    _detectionClassesCard(
                      context,
                      current.detectionsByClass,
                      primaryTextColor,
                      borderColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Generated ${formatDateTime(current.generatedAt)} · '
                      '${formatRelative(current.generatedAt)}',
                      style: TextStyle(fontSize: 11, color: secondaryTextColor),
                    ),
                    if (current.isSimulated)
                      const SizedBox(
                        height: 4,
                      ),
                    if (current.isSimulated)
                      const Text(
                        'Source: simulated report data',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedBlue,
                        ),
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

  Widget _metricCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color valueColor,
  }) {
    final borderColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBorder
            : AppColors.lightBorder;
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendsCard(
    BuildContext context,
    List<ReportTrendPoint> trends,
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
            const Text(
              'Performance trends',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cleanliness by period · detections · container events',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            const SizedBox(height: 12),
            Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(1.1),
                1: FlexColumnWidth(1.7),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.1),
              },
              children: [
                const TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Label',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mutedBlue,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6, right: 8),
                      child: Text(
                        'Cleanliness',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mutedBlue,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Detections',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mutedBlue,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Container',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.mutedBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                for (final point in trends)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          point.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          right: 8,
                          top: 6,
                          bottom: 6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              point.cleanlinessScore.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: (point.cleanlinessScore / 100)
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                              minHeight: 4,
                              backgroundColor: AppColors.softBlue,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.techOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${point.detections}',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${point.containerEvents}',
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detectionClassesCard(
    BuildContext context,
    Map<DetectionSummaryClass, int> counts,
    Color primaryTextColor,
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
            const Text(
              'Detections by class',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 10),
            for (final cls in DetectionSummaryClass.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _detectionClassLabel(cls),
                      style: TextStyle(fontSize: 13, color: primaryTextColor),
                    ),
                    Text(
                      '${counts[cls] ?? 0}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.techOrange,
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

  String _detectionClassLabel(DetectionSummaryClass value) {
    switch (value) {
      case DetectionSummaryClass.wet:
        return 'Wet liquid';
      case DetectionSummaryClass.dry:
        return 'Dry debris';
      case DetectionSummaryClass.mixed:
        return 'Mixed waste';
      case DetectionSummaryClass.unknown:
        return 'Unclassified';
    }
  }
}
