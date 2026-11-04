import 'package:uuid/uuid.dart';

class IdempotencyUtil {
  static const _uuid = Uuid();

  /// Generates a unique idempotency key for a new command initiation.
  static String generateKey() => _uuid.v4();
}

class DataValidators {
  DataValidators._();

  /// Validates percentage values (0 - 100). Returns null if invalid.
  static double? clampPercentage(dynamic value) {
    if (value == null) return null;
    final num? parsed = value is num ? value : double.tryParse(value.toString());
    if (parsed == null) return null;
    if (parsed < 0 || parsed > 100) return null;
    return parsed.toDouble();
  }

  /// Validates confidence values (0.0 - 1.0). Returns null if invalid.
  static double? clampConfidence(dynamic value) {
    if (value == null) return null;
    final num? parsed = value is num ? value : double.tryParse(value.toString());
    if (parsed == null) return null;
    if (parsed < 0.0 || parsed > 1.0) return null;
    return parsed.toDouble();
  }

  /// Parses date from UTC string and converts to local display DateTime.
  static DateTime? parseUtcToLocal(dynamic timestamp) {
    if (timestamp == null) return null;
    try {
      final str = timestamp.toString();
      final parsed = DateTime.parse(str);
      return parsed.toLocal();
    } catch (_) {
      return null;
    }
  }
}

