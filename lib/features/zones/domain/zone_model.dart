import 'package:equatable/equatable.dart';

class ZoneModel extends Equatable {
  final String id;
  final String name;
  final double areaM2;
  final DateTime? lastCleanedAt;
  final bool isAvailable;
  final String? unavailabilityReason;

  const ZoneModel({
    required this.id,
    required this.name,
    required this.areaM2,
    this.lastCleanedAt,
    this.isAvailable = true,
    this.unavailabilityReason,
  });

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      areaM2: (json['area_m2'] as num?)?.toDouble() ?? 0.0,
      lastCleanedAt: json['last_cleaned_at'] != null
          ? DateTime.tryParse(json['last_cleaned_at'] as String)
          : null,
      isAvailable: json['is_available'] as bool? ?? true,
      unavailabilityReason: json['unavailability_reason'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        areaM2,
        lastCleanedAt,
        isAvailable,
        unavailabilityReason,
      ];
}

