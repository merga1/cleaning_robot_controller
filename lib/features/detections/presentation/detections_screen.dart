import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/detection_model.dart';

final detectionsListProvider = FutureProvider<List<GarbageDetectionModel>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return [
    GarbageDetectionModel(
      id: 'det-001',
      robotId: 'robot-alpha-01',
      zoneName: 'Lobby & Main Hall',
      detectionClass: DetectionClass.wet,
      confidence: 0.92,
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
    GarbageDetectionModel(
      id: 'det-002',
      robotId: 'robot-alpha-01',
      zoneName: 'Lobby & Main Hall',
      detectionClass: DetectionClass.dry,
      confidence: 0.88,
      timestamp: DateTime.now().subtract(const Duration(minutes: 14)),
    ),
    GarbageDetectionModel(
      id: 'det-003',
      robotId: 'robot-alpha-01',
      zoneName: 'Corridor A',
      detectionClass: DetectionClass.mixed,
      confidence: 0.54, // MOB-DET-003: low confidence uncertain
      timestamp: DateTime.now().subtract(const Duration(minutes: 22)),
    ),
    GarbageDetectionModel(
      id: 'det-004',
      robotId: 'robot-alpha-01',
      zoneName: 'West Wing Entry',
      detectionClass: DetectionClass.dry,
      confidence: 0.95,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];
});

class DetectionsScreen extends ConsumerStatefulWidget {
  const DetectionsScreen({super.key});

  @override
  ConsumerState<DetectionsScreen> createState() => _DetectionsScreenState();
}

class _DetectionsScreenState extends ConsumerState<DetectionsScreen> {
  DetectionClass? _selectedClassFilter;

  @override
  Widget build(BuildContext context) {
    final detectionsAsync = ref.watch(detectionsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garbage Detections'),
      ),
      body: Column(
        children: [
          // Filter Chips (MOB-DET-002)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Classes'),
                  selected: _selectedClassFilter == null,
                  onSelected: (val) {
                    setState(() => _selectedClassFilter = null);
                  },
                ),
                const SizedBox(width: 8),
                ...DetectionClass.values.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(c.displayName),
                      selected: _selectedClassFilter == c,
                      onSelected: (val) {
                        setState(() {
                          _selectedClassFilter = val ? c : null;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: detectionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (items) {
                final filtered = _selectedClassFilter == null
                    ? items
                    : items.where((d) => d.detectionClass == _selectedClassFilter).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No detections recorded for this filter.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final det = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.lightBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // Snapshot Image / Placeholder (MOB-DET-004)
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.image_outlined,
                                color: Color(0xFF94A3B8),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        det.detectionClass.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Uncertain marker (MOB-DET-003)
                                      if (det.isUncertain)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.severityWarning.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
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
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Zone: ${det.zoneName}',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Confidence: ${(det.confidence * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: det.isUncertain
                                              ? AppColors.severityWarning
                                              : AppColors.statusCleaning,
                                        ),
                                      ),
                                      Text(
                                        '${det.timestamp.hour}:${det.timestamp.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

